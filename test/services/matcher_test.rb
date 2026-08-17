require "test_helper"

class MatcherTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "m@example.com", password: "password123")
    @import = Import.create!(kind: "invoices", content_hash: "abc", user: @user, status: :completed)
  end

  def create_invoice(folio:, monto:, deudor: "987654321", moneda: "CLP", emision: Date.new(2025, 1, 1), vencimiento: Date.new(2025, 2, 1))
    Invoice.create!(folio: folio, rut_cliente: "123456789", rut_deudor: deudor,
                    fecha_emision: emision, fecha_vencimiento: vencimiento,
                    monto: monto, moneda: moneda, import: @import)
  end

  def create_movement(monto:, referencia: nil, descripcion: nil, fecha: Date.new(2025, 1, 15))
    Movement.create!(fecha: fecha, monto: monto, descripcion: descripcion,
                     referencia: referencia, fingerprint: "fp_#{SecureRandom.hex(8)}", import: @import)
  end

  test "confirma match cuando referencia tiene el folio y el monto coincide" do
    invoice = create_invoice(folio: "1001", monto: 5_000)
    movement = create_movement(monto: 5_000, referencia: "PAGO 1001")

    Matcher.run

    app = PaymentApplication.find_by(movement: movement, invoice: invoice)
    assert app.present?
    assert_equal "confirmed", app.status
    assert_includes app.evidence, "folio_en_referencia"
    assert_includes app.evidence, "monto_completo"
  end

  test "confirma con folio aunque el monto no coincida (regla: folio + fecha)" do
    invoice = create_invoice(folio: "1002", monto: 5_000)
    movement = create_movement(monto: 9_000, referencia: "1002")

    Matcher.run

    app = PaymentApplication.find_by(movement: movement, invoice: invoice)
    assert app.present?
    assert_equal "confirmed", app.status
  end

  test "NO asigna un pago dos veces (movimiento ya resuelto se ignora)" do
    invoice = create_invoice(folio: "1003", monto: 5_000)
    movement = create_movement(monto: 5_000, referencia: "1003")

    Matcher.run
    Matcher.run

    assert_equal 1, PaymentApplication.where(movement: movement).count
  end

  test "match por monto único queda como sugerido, no confirmado" do
    create_invoice(folio: "2001", monto: 3_500)
    movement = create_movement(monto: 3_500, descripcion: "TRANSFERENCIA SIN REFERENCIA")

    Matcher.run

    app = PaymentApplication.find_by(movement: movement)
    assert app.present?
    assert_equal "suggested", app.status
  end

  test "un movimiento puede tener varios candidatos sugeridos (ambiguo)" do
    create_invoice(folio: "3001", monto: 3_500)
    create_invoice(folio: "3002", monto: 3_500)
    movement = create_movement(monto: 3_500, descripcion: "TRANSFERENCIA SIN REFERENCIA")

    Matcher.run

    assert_equal 2, PaymentApplication.where(movement: movement).count
    assert_equal [ "suggested" ], PaymentApplication.where(movement: movement).pluck(:status).uniq
  end

  test "factura ya pagada no recibe más pagos" do
    invoice = create_invoice(folio: "4001", monto: 5_000)
    m1 = create_movement(monto: 5_000, referencia: "4001")

    Matcher.run
    assert_equal 1, PaymentApplication.where(invoice: invoice).count

    # segundo movimiento con el mismo folio, distinto fingerprint
    m2 = Movement.create!(fecha: Date.new(2025, 2, 1), monto: 5_000, descripcion: nil,
                          referencia: "4001", fingerprint: "fp_second", import: @import)
    Matcher.run

    assert_equal 1, PaymentApplication.where(invoice: invoice).count
  end

  test "movimiento sin ningún candidato queda sin conciliar" do
    create_invoice(folio: "5001", monto: 5_000)
    movement = create_movement(monto: 9_999, descripcion: "GASTO BANCARIO")

    Matcher.run

    assert_empty PaymentApplication.where(movement: movement)
    assert_equal "no_conciliado", movement.conciliacion
  end

  test "varios pagos parciales con folio suman hasta pagar la factura" do
    invoice = create_invoice(folio: "6001", monto: 10_000)
    m1 = create_movement(monto: 4_000, referencia: "6001")
    m2 = create_movement(monto: 6_000, referencia: "6001")

    Matcher.run

    apps = PaymentApplication.where(invoice: invoice).order(:created_at)
    assert_equal 2, apps.count
    assert_equal [ "confirmed", "confirmed" ], apps.pluck(:status)
    assert_equal 10_000, invoice.pagado
    assert_equal 0, invoice.saldo
    assert_equal "conciliada", invoice.estado_conciliacion
  end

  test "pago parcial único queda como confirmado solo con folio + monto menor" do
    invoice = create_invoice(folio: "6002", monto: 10_000)
    movement = create_movement(monto: 3_000, referencia: "6002")

    Matcher.run

    app = PaymentApplication.find_by(movement: movement, invoice: invoice)
    assert app.present?
    assert_equal "confirmed", app.status
    assert_equal 3_000, app.amount
    assert_equal "pago_parcial", (app.evidence & %w[pago_parcial]).first
  end

  test "pago parcial sin folio queda como sugerido (multi-pago) y respeta cronología" do
    invoice = create_invoice(folio: "7001", monto: 10_000, vencimiento: Date.new(2025, 2, 15))
    movement = create_movement(monto: 4_000, descripcion: "TRANSFERENCIA", fecha: Date.new(2025, 2, 1))

    Matcher.run

    app = PaymentApplication.find_by(movement: movement, invoice: invoice)
    assert app.present?
    assert_equal "suggested", app.status
    assert_equal 4_000, app.amount
    assert_includes app.evidence, "pago_parcial"
    assert_includes app.evidence, "pago_en_plazo"
  end

  test "factura UF se concilia contra un movimiento CLP usando UF_VALUE fijo" do
    invoice = create_invoice(folio: "8001", monto: 10_000, moneda: "UF")
    monto_clp = (10_000 * Matcher::UF_VALUE).round(2)
    movement = create_movement(monto: monto_clp, referencia: "8001")

    Matcher.run

    app = PaymentApplication.find_by(movement: movement, invoice: invoice)
    assert app.present?
    assert_equal "confirmed", app.status
    assert_includes app.evidence, "monto_completo"
    assert_equal monto_clp, app.amount
    assert_equal monto_clp, invoice.pagado
    assert_equal "conciliada", invoice.estado_conciliacion
  end

  test "abono parcial en CLP de una factura UF se sugiere como pago parcial" do
    invoice = create_invoice(folio: "8002", monto: 100.0, moneda: "UF")
    movement = create_movement(monto: (50.0 * Matcher::UF_VALUE).round(2), descripcion: "ABONO PARCIAL FAC 8002")

    Matcher.run

    app = PaymentApplication.find_by(movement: movement, invoice: invoice)
    assert app.present?
    assert_equal "confirmed", app.status
    assert_includes app.evidence, "pago_parcial"
    assert_equal (50.0 * Matcher::UF_VALUE).round(2), app.amount
    assert_equal (50.0 * Matcher::UF_VALUE).round(2), invoice.saldo
  end

  test "movimiento anterior a la emisión de la factura no se sugiere como pago" do
    invoice = create_invoice(folio: "7002", monto: 10_000, emision: Date.new(2025, 3, 1))
    movement = create_movement(monto: 4_000, descripcion: "TRANSFERENCIA", fecha: Date.new(2025, 2, 1))

    Matcher.run

    assert_empty PaymentApplication.where(movement: movement)
  end

  test "una factura pagada con varios movimientos queda conciliada y sin sobrepago" do
    invoice = create_invoice(folio: "7003", monto: 10_000)
    m1 = create_movement(monto: 4_000, descripcion: "TRANSFERENCIA A")
    m2 = create_movement(monto: 6_000, descripcion: "TRANSFERENCIA B")

    Matcher.run

    apps = PaymentApplication.where(invoice: invoice)
    assert_equal 2, apps.count
    assert_equal [ "suggested", "suggested" ], apps.pluck(:status).sort

    apps.order(:id).each { |app| app.approve! }
    assert_equal 10_000, invoice.pagado
    assert_equal "conciliada", invoice.estado_conciliacion

    extra = create_invoice(folio: "7004", monto: 100)
    over = PaymentApplication.create!(movement: m1, invoice: extra, amount: 100, status: "suggested", rule: "monto", score: 10, evidence: [])
    assert_raises(StandardError) { over.approve! }
  end
end
