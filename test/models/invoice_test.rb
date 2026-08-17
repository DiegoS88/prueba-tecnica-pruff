require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "t@example.com", password: "password123")
    @import = Import.create!(kind: "invoices", content_hash: "abc", user: @user, status: :completed)
  end

  test "saldo es monto menos pagos confirmados" do
    invoice = Invoice.create!(folio: "1", rut_cliente: "123456789", rut_deudor: "987654321",
                              fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 2, 1),
                              monto: 10_000, moneda: "CLP", import: @import)
    movement = Movement.create!(fecha: Date.new(2025, 1, 15), monto: 4_000, descripcion: "PAGO FACTURA 1",
                                referencia: "1", fingerprint: "fp1", import: @import)
    PaymentApplication.create!(movement: movement, invoice: invoice, amount: 4_000, status: "confirmed")

    assert_equal 4_000, invoice.pagado
    assert_equal 6_000, invoice.saldo
    assert invoice.saldo_pendiente?
  end

  test "vencida solo si hay saldo y la fecha de vencimiento ya pasó" do
    invoice = Invoice.create!(folio: "2", rut_cliente: "123456789", rut_deudor: "987654321",
                              fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 2, 1),
                              monto: 10_000, moneda: "CLP", import: @import)

    assert invoice.vencida?(as_of: Date.new(2025, 3, 1))
    assert_equal 28, invoice.dias_atraso(as_of: Date.new(2025, 3, 1))
    assert_not invoice.vencida?(as_of: Date.new(2025, 1, 15))
  end

  test "factura totalmente pagada no se considera vencida aunque pasó la fecha" do
    invoice = Invoice.create!(folio: "3", rut_cliente: "123456789", rut_deudor: "987654321",
                              fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 1, 15),
                              monto: 10_000, moneda: "CLP", import: @import)
    movement = Movement.create!(fecha: Date.new(2025, 1, 10), monto: 10_000, descripcion: "PAGO FACTURA 3",
                                referencia: "3", fingerprint: "fp3", import: @import)
    PaymentApplication.create!(movement: movement, invoice: invoice, amount: 10_000, status: "confirmed")

    assert invoice.pagada?
    assert_not invoice.vencida?(as_of: Date.new(2025, 2, 1))
    assert_equal "pagada", invoice.estado_financiero
  end

  test "estado de conciliación refleja facturas explicadas por el banco" do
    invoice = Invoice.create!(folio: "4", rut_cliente: "123456789", rut_deudor: "987654321",
                              fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 2, 1),
                              monto: 10_000, moneda: "CLP", import: @import)

    assert_equal "no_conciliada", invoice.estado_conciliacion
  end

  test "el folio es único por rut_cliente" do
    Invoice.create!(folio: "5", rut_cliente: "123456789", rut_deudor: "111111111", fecha_emision: Date.today,
                    fecha_vencimiento: Date.today + 1, monto: 100, moneda: "CLP", import: @import)
    duplicate = Invoice.new(folio: "5", rut_cliente: "123456789", rut_deudor: "222222222", fecha_emision: Date.today,
                            fecha_vencimiento: Date.today + 1, monto: 100, moneda: "CLP", import: @import)

    assert_not duplicate.valid?
  end
end
