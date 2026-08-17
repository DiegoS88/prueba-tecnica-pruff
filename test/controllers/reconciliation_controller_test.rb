require "test_helper"

class ReconFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "recon@example.com", password: "password123")
    @import = Import.create!(kind: "invoices", content_hash: "rcon", user: @user, status: :completed)
    @invoice = Invoice.create!(folio: "R100", rut_cliente: "123456789", rut_deudor: "987654321",
                               fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 2, 1),
                               monto: 5_000, moneda: "CLP", import: @import)
    @movement = Movement.create!(fecha: Date.new(2025, 1, 15), monto: 5_000, descripcion: nil,
                                 referencia: "R100", fingerprint: "fp_r100", import: @import)
    @payment_app = PaymentApplication.create!(movement: @movement, invoice: @invoice, amount: 5_000,
                                      status: "suggested", rule: "folio", score: 80, evidence: [ "folio_en_referencia" ])
  end

  test "aprobar desde el show de la factura vuelve al show" do
    sign_in_as(@user)

    post "/reconciliation/#{@payment_app.id}/approve", headers: { "Referer" => "http://www.example.com/invoices/#{@invoice.id}" }

    assert_redirected_to invoice_path(@invoice)
    assert @payment_app.reload.confirmed?
  end

  test "aprobar desde el show del movimiento vuelve al show" do
    sign_in_as(@user)

    post "/reconciliation/#{@payment_app.id}/approve", headers: { "Referer" => "http://www.example.com/movements/#{@movement.id}" }

    assert_redirected_to movement_path(@movement)
    assert @payment_app.reload.confirmed?
  end

  test "aprobar desde el index del conciliador vuelve al index (fallback)" do
    sign_in_as(@user)

    post "/reconciliation/#{@payment_app.id}/approve", headers: { "Referer" => "http://www.example.com/reconciliation" }

    assert_redirected_to reconciliation_index_path
    assert @payment_app.reload.confirmed?
  end
end
