# Motor de conciliación factura <-> movimiento.
#
# Principio de producto: PRECISIÓN > RECALL. Preferimos dejar un movimiento
# "sin conciliar" o "requiere revisión" antes que asignarlo incorrectamente.
#
# Regla de CONFIRMACIÓN automática (decidida con el negocio):
#   folio encontrado en referencia/descripción (normalizado, delimitado)
#   + la fecha del movimiento es cronológicamente válida (fecha_mov >= fecha_emision).
# El monto NO se exige: una factura UF pagada en CLP es un match válido.
#   La protección contra sobrepago vive en PaymentApplication#approve!.
#
# Niveles:
#   CONFIRMADO  - folio + cronología válida. Se aplica automáticamente.
#   SUGERIDO    - hay evidencia pero sin folio (monto exacto único, pago parcial,
#                 múltiples candidatos). Requiere revisión humana.
#   SIN MATCH   - no hay candidatos razonables.
#
# La ambigüedad se representa naturalmente: un movimiento con varios candidatos
# sugeridos queda visible para que un humano decida.
#
# Monedas: las facturas UF se convierten a CLP con UF_VALUE (constante del
# dataset). Los montos de aplicación siempre se persisten en CLP.
class Matcher
  FOLIO_WEIGHT = 60
  FOLIO_DESCRIPCION_WEIGHT = 50
  MONTO_COMPLETO_WEIGHT = 30
  PAGO_PARCIAL_WEIGHT = 20
  PAGO_EN_PLAZO_WEIGHT = 15
  MONEDA_WEIGHT = 10
  MONTO_UNICO_BONUS = 25

  # Valor UF fijo del dataset (definido en Invoice): todas las facturas UF se
  # convierten a CLP multiplicando por este factor (verificado consistente).
  UF_VALUE = Invoice::UF_VALUE

  # Umbrales (a la fecha son parte de la heurística; se revisan con datos reales).
  AMOUNT_TOLERANCE = 1
  MAX_CANDIDATES_PER_MOVEMENT = 5

  def self.run(import: nil)
    new(import: import).run
  end

  def initialize(import: nil)
    @import = import
  end

  def run
    movements = Movement.includes(:payment_applications).order(:fecha)

    movements.find_each do |movement|
      next if movement.payment_applications.exists? # ya resuelto (evita reprocesar)

      resolve(movement)
    end
  end

  private

  def resolve(movement)
    candidates = build_candidates(movement)
    return if candidates.empty?

    best = candidates.max_by { |c| c[:score] }
    folio_evidence = best[:signals].any? { |s| s.include?("folio") }

    if folio_evidence && chronologically_valid?(movement, best[:invoice])
      apply(movement, best, "confirmed")
    else
      candidates = candidates.sort_by { |c| -c[:score] }.first(MAX_CANDIDATES_PER_MOVEMENT)
      candidates.each { |c| apply(movement, c, "suggested") }
    end
  end

  # Genera candidatos: folio desde referencia/descripción, monto exacto único,
  # y pagos parciales (factura pagada con varios movimientos) cuando no hay folio.
  def build_candidates(movement)
    candidates = []
    folio = Normalizers.folio(movement.referencia) || Normalizers.folio(movement.descripcion)

    if folio
      invoice = Invoice.find_by(folio: folio)
      candidates << score_candidate(movement, invoice) if invoice && chronologically_valid?(movement, invoice)
    end

    # Candidato por monto exacto (solo si no tenemos folio, o como adicional).
    amount_candidates = Invoice.where(monto: movement.monto).where(moneda: "CLP")
    unique = amount_candidates.count == 1
    amount_candidates.each do |invoice|
      next unless chronologically_valid?(movement, invoice)

      candidate = score_candidate(movement, invoice)
      candidate[:score] += MONTO_UNICO_BONUS if unique
      candidates << candidate
    end

    # Pago parcial sin folio: la factura pudo haberse pagado en varios movimientos.
    # Solo se sugiere (nunca se confirma) y se acota por cronología para no inundar.
    if folio.nil? && candidates.empty?
      candidates.concat(partial_payment_candidates(movement))
    end

    candidates.compact.uniq { |c| c[:invoice].id }.sort_by { |c| -c[:score] }.first(MAX_CANDIDATES_PER_MOVEMENT)
  end

  def chronologically_valid?(movement, invoice)
    movement.fecha >= invoice.fecha_emision
  end

  # Facturas con saldo suficiente para absorber este movimiento como pago parcial,
  # ordenadas por coherencia cronológica: primero las que vencen cerca de la fecha
  # del movimiento (un pago suele llegar en torno al vencimiento) y, entre iguales,
  # la que deja menor saldo remanente. Los montos se comparan en CLP (UF convertido).
  def partial_payment_candidates(movement)
    Invoice.where(moneda: %w[CLP UF]).select do |invoice|
      monto = monto_clp(invoice)
      saldo = saldo_de(invoice)
      monto > movement.monto &&
        saldo >= movement.monto &&
        chronologically_valid?(movement, invoice)
    end.sort_by do |invoice|
      [ (invoice.fecha_vencimiento - movement.fecha).abs, saldo_de(invoice) ]
    end.first(MAX_CANDIDATES_PER_MOVEMENT).map { |invoice| score_candidate(movement, invoice) }
  end

  def confirmed_by_invoice
    @confirmed_by_invoice ||= PaymentApplication.confirmed.group(:invoice_id).sum(:amount)
  end

  # Monto de la factura en CLP (las facturas UF se convierten con UF_VALUE).
  def monto_clp(invoice)
    invoice.monto_clp
  end

  # Saldo en CLP: monto de la factura convertido menos lo confirmado.
  def saldo_de(invoice)
    monto_clp(invoice) - confirmed_by_invoice.fetch(invoice.id, 0)
  end

  def score_candidate(movement, invoice)
    signals = []
    score = 0
    folio_matches = invoice.folio == Normalizers.folio(movement.referencia)
    descripcion_matches = invoice.folio == Normalizers.folio(movement.descripcion)

    if folio_matches
      score += FOLIO_WEIGHT
      signals << "folio_en_referencia"
    elsif descripcion_matches
      score += FOLIO_DESCRIPCION_WEIGHT
      signals << "folio_en_descripcion"
    end

    saldo = saldo_de(invoice)
    monto_factura_clp = monto_clp(invoice)
    if (movement.monto - monto_factura_clp).abs <= AMOUNT_TOLERANCE
      score += MONTO_COMPLETO_WEIGHT
      signals << "monto_completo"
    elsif movement.monto <= saldo && movement.monto < monto_factura_clp
      score += PAGO_PARCIAL_WEIGHT
      signals << "pago_parcial"
    end

    if movement.fecha <= invoice.fecha_vencimiento
      score += PAGO_EN_PLAZO_WEIGHT
      signals << "pago_en_plazo"
    else
      signals << "pago_tardio"
    end

    if invoice.moneda == "CLP"
      score += MONEDA_WEIGHT
      signals << "moneda_igual"
    end

    {
      invoice: invoice,
      score: score,
      signals: signals,
      amount: applied_amount(movement, invoice),
      rule: folio_matches || descripcion_matches ? "folio" : "monto"
    }
  end

  def applied_amount(movement, invoice)
    [ movement.monto, saldo_de(invoice) ].min
  end

  def apply(movement, candidate, status)
    application = PaymentApplication.create!(
      movement: movement,
      invoice: candidate[:invoice],
      amount: candidate[:amount],
      status: status,
      rule: candidate[:rule],
      score: candidate[:score],
      evidence: candidate[:signals],
      decided_by: nil
    )

    AuditEvent.record!(
      entity_type: "Movement",
      entity_id: movement.id.to_s,
      event_type: "payment_application_#{status}",
      import: @import,
      data: {
        application_id: application.id,
        invoice_id: candidate[:invoice].id,
        folio: candidate[:invoice].folio,
        amount: candidate[:amount].to_s,
        score: candidate[:score].to_s,
        rule: candidate[:rule],
        signals: candidate[:signals]
      }
    )
  rescue ActiveRecord::RecordInvalid
    # Aplicación duplicada (ya resuelta entre corridas) -> ignorar.
    nil
  end
end
