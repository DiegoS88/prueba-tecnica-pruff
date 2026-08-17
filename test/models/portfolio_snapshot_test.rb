require "test_helper"

class PortfolioSnapshotTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email_address: "snap@example.com", password: "password123")
  end

  test "captura la foto del día y guarda métricas" do
    import = Import.create!(kind: "invoices", content_hash: "s1", user: @user, status: :completed)
    Invoice.create!(folio: "1", rut_cliente: "123456789", rut_deudor: "111111111",
                    fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 2, 1),
                    monto: 10_000, moneda: "CLP", import: import)

    snapshot = PortfolioSnapshot.capture!(date: Date.new(2025, 3, 1))

    assert_equal Date.new(2025, 3, 1), snapshot.snapshot_date
    assert_equal 10_000.0, snapshot.totals["saldo_total"].to_f
    assert_equal 10_000.0, snapshot.totals["saldo_vencido"].to_f
    assert snapshot.top_deudores.key?("111111111")
  end

  test "no permite dos fotos el mismo día" do
    PortfolioSnapshot.capture!(date: Date.new(2025, 3, 1))
    PortfolioSnapshot.capture!(date: Date.new(2025, 3, 1))

    assert_equal 1, PortfolioSnapshot.where(snapshot_date: Date.new(2025, 3, 1)).count
  end

  test "changes_vs_previous devuelve deltas respecto al día anterior" do
    import = Import.create!(kind: "invoices", content_hash: "s2", user: @user, status: :completed)
    Invoice.create!(folio: "1", rut_cliente: "123456789", rut_deudor: "111111111",
                    fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 2, 1),
                    monto: 10_000, moneda: "CLP", import: import)

    PortfolioSnapshot.capture!(date: Date.new(2025, 3, 1))
    Invoice.create!(folio: "2", rut_cliente: "123456789", rut_deudor: "222222222",
                    fecha_emision: Date.new(2025, 1, 1), fecha_vencimiento: Date.new(2025, 2, 1),
                    monto: 5_000, moneda: "CLP", import: import)
    today = PortfolioSnapshot.capture!(date: Date.new(2025, 3, 2))

    changes = today.changes_vs_previous
    assert_equal Date.new(2025, 3, 1), changes[:previous_date]
    assert_equal 5_000.0, changes[:deltas]["saldo_total"]
  end
end
