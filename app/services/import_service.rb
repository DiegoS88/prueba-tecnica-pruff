# Pipeline de importación de un CSV (facturas o movimientos).
#  1. Validación del archivo
#  2. Hash de contenido -> idempotencia (mismo archivo no se reimporta)
#  3. Parsing fila a fila con normalización
#  4. Errores parciales no abortan el import (solo un umbral alto lo hace fallar)
#  5. Persistencia con claves naturales (factura) y fingerprints (movimientos)
#  6. Matching de movimientos contra facturas
#  7. Auditoría de cada hecho
class ImportService
  require "csv"

  MAX_ROW_COUNT = 100_000
  ERROR_ABORT_RATIO = 0.5

  Result = Struct.new(:import, :ok, :reimported, keyword_init: true) do
    def errors
      import.error_summary || []
    end
  end

  def initialize(kind:, file:, user:)
    @kind = kind.to_s
    @file = file
    @user = user
  end

  def call
    return Result.new(import: nil, ok: false) unless valid_file?

    content = @file.read
    hash = Digest::SHA256.hexdigest(content)

    existing = Import.find_by(kind: @kind, content_hash: hash)
    if existing
      return Result.new(import: existing, ok: true, reimported: true)
    end

    import = Import.create!(kind: @kind, file_name: @file.original_filename, content_hash: hash, user: @user, status: :processing, counts: {})

    begin
      rows = CSV.parse(content, headers: true, liberal_parsing: true)
      unless headers_valid?(rows)
        import.update!(status: :failed, error_summary: [ "Encabezados inválidos: se esperaban #{expected_headers.join(', ')}" ])
        return Result.new(import: import, ok: false)
      end

      process_rows(import, rows)
      import.update!(status: :completed)
      Result.new(import: import, ok: true, reimported: false)
    rescue CSV::MalformedCSVError, EncodingError, ArgumentError => e
      import.update!(status: :failed, error_summary: [ e.message ])
      Result.new(import: import, ok: false)
    end
  end

  private

  def expected_headers
    case @kind
    when "invoices" then %w[folio rut_cliente rut_deudor fecha_emision fecha_vencimiento monto moneda]
    when "movements" then %w[fecha monto descripcion referencia]
    else []
    end
  end

  def valid_file?
    return false if @file.blank? || @file.size > 10_000_000
    return false unless @file.original_filename.to_s.downcase.end_with?(".csv")
    return false unless %w[invoices movements].include?(@kind)

    true
  end

  def headers_valid?(rows)
    actual = rows.headers.to_a.map(&:to_s).map(&:strip)
    (expected_headers - actual).empty?
  end

  def process_rows(import, rows)
    counts = { "total" => rows.count, "imported" => 0, "updated" => 0, "duplicates" => 0, "errors" => 0 }
    errors = []

    rows.each_with_index do |row, index|
      result = @kind == "invoices" ? upsert_invoice(import, row) : upsert_movement(import, row)

      case result
      when :imported then counts["imported"] += 1
      when :updated then counts["updated"] += 1
      when :duplicate then counts["duplicates"] += 1
      else
        counts["errors"] += 1
        errors << { row: index + 2, message: result }
      end

      raise "Demasiadas filas inválidas (#{counts['errors']}/#{counts['total']})" if counts["total"] > 0 && counts["errors"].to_f / counts["total"] > ERROR_ABORT_RATIO
    end

    run_matcher(import) if @kind == "movements"

    import.update!(counts: counts, error_summary: errors.first(200))
  end

  def upsert_invoice(import, row)
    folio = row["folio"].to_s.strip
    rut_cliente = Normalizers.rut(row["rut_cliente"])
    rut_deudor = Normalizers.rut(row["rut_deudor"])
    fecha_emision = Normalizers.fecha(row["fecha_emision"])
    fecha_vencimiento = Normalizers.fecha(row["fecha_vencimiento"])
    monto = Normalizers.monto(row["monto"])
    moneda = Normalizers.moneda(row["moneda"])

    return "rut_cliente inválido" if rut_cliente.nil?
    return "rut_deudor inválido" if rut_deudor.nil?
    return "fecha_emision inválida" if fecha_emision.nil?
    return "fecha_vencimiento inválida" if fecha_vencimiento.nil?
    return "monto inválido" if monto.nil?
    return "moneda inválida (#{row['moneda']})" if moneda.nil?

    invoice = Invoice.find_by(rut_cliente: rut_cliente, folio: folio)
    if invoice
      invoice.update!(rut_deudor: rut_deudor, fecha_emision: fecha_emision, fecha_vencimiento: fecha_vencimiento, monto: monto, moneda: moneda)
      :updated
    else
      Invoice.create!(folio: folio, rut_cliente: rut_cliente, rut_deudor: rut_deudor,
                      fecha_emision: fecha_emision, fecha_vencimiento: fecha_vencimiento,
                      monto: monto, moneda: moneda, import: import)
      :imported
    end
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.full_messages.join(", ")
  end

  def upsert_movement(import, row)
    fecha = Normalizers.fecha(row["fecha"])
    monto = Normalizers.monto(row["monto"])
    descripcion = row["descripcion"].to_s.strip
    referencia = row["referencia"].to_s.strip
    fingerprint = Normalizers.fingerprint(fecha, monto, descripcion, referencia)

    return "fecha inválida" if fecha.nil?
    return "monto inválido" if monto.nil?

    if Movement.exists?(fingerprint: fingerprint)
      :duplicate
    else
      Movement.create!(fecha: fecha, monto: monto, descripcion: descripcion, referencia: referencia,
                       fingerprint: fingerprint, import: import)
      :imported
    end
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.full_messages.join(", ")
  end

  def run_matcher(import)
    Matcher.run(import: import)
  end
end
