require "test_helper"

class ImportServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "i@example.com", password: "password123")
  end

  def csv_file(content, name: "test.csv")
    file = Tempfile.new(name)
    file.write(content)
    file.rewind
    ActionDispatch::Http::UploadedFile.new(filename: name, type: "text/csv", tempfile: file)
  end

  test "importa facturas con formatos mezclados normalizando todo" do
    csv = <<~CSV
      folio,rut_cliente,rut_deudor,fecha_emision,fecha_vencimiento,monto,moneda
      104742,958507930,90.060.626-7,2025-08-02,01/10/2025,12666000,$
      104657,67.313.577-1,662194211,2025-08-11,10/10/2025,"24.963.000,00",CLP
      101279,67.313.577-1,99119291-7,06-10-2025,05/12/2025,"61,26",uf
    CSV

    result = ImportService.new(kind: "invoices", file: csv_file(csv), user: @user).call

    assert result.ok
    assert_equal 3, Invoice.count
    assert_equal "900606267", Invoice.find_by(folio: "104742").rut_deudor
    assert_equal 24_963_000, Invoice.find_by(folio: "104657").monto
    assert_equal "UF", Invoice.find_by(folio: "101279").moneda
  end

  test "una fila inválida no aborta la importación del resto" do
    csv = <<~CSV
      folio,rut_cliente,rut_deudor,fecha_emision,fecha_vencimiento,monto,moneda
      104742,958507930,900606267,2025-08-02,01/10/2025,12666000,$
      104743,@@@,900606267,2025-08-02,01/10/2025,12666000,$
    CSV

    result = ImportService.new(kind: "invoices", file: csv_file(csv), user: @user).call

    assert result.ok
    assert_equal 1, Invoice.count
    assert_equal 1, result.import.counts["errors"]
    assert_equal 1, result.import.counts["imported"]
  end

  test "reimportar el mismo archivo no duplica nada" do
    csv = <<~CSV
      folio,rut_cliente,rut_deudor,fecha_emision,fecha_vencimiento,monto,moneda
      104742,958507930,900606267,2025-08-02,01/10/2025,12666000,$
    CSV

    r1 = ImportService.new(kind: "invoices", file: csv_file(csv), user: @user).call
    r2 = ImportService.new(kind: "invoices", file: csv_file(csv), user: @user).call

    assert r1.ok
    assert r2.reimported
    assert_equal 1, Invoice.count
    assert_equal 1, Import.kind_invoices.count
  end

  test "movimientos duplicados por fingerprint se marcan y no se insertan dos veces" do
    csv = <<~CSV
      fecha,monto,descripcion,referencia
      2025-10-28,"25.125.000,00",PAGO FACTURA 102464,DISTRIBUIDORA
      28-10-2025,"25.125.000,00",PAGO FACTURA 102464,DISTRIBUIDORA
    CSV

    result = ImportService.new(kind: "movements", file: csv_file(csv), user: @user).call

    assert result.ok
    assert_equal 1, Movement.count
    assert_equal 1, result.import.counts["duplicates"]
  end

  test "encabezados incorrectos fallan la importación" do
    csv = <<~CSV
      foo,bar
      1,2
    CSV

    result = ImportService.new(kind: "invoices", file: csv_file(csv), user: @user).call

    assert_not result.ok
  end
end
