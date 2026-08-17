class PortfolioSnapshot < ApplicationRecord
  validates :snapshot_date, uniqueness: true, presence: true

  # Toma la foto del día y la persiste para comparar "qué cambió" mañana.
  def self.capture!(date: Date.current)
    calculator = PortfolioCalculator.new(as_of: date)
    totals = calculator.totals

    snapshot = find_or_initialize_by(snapshot_date: date)
    snapshot.totals = totals.slice(:saldo_total, :saldo_vencido, :saldo_por_vencer, :monto_emitido, :n_facturas, :n_facturas_vencidas, :n_movimientos_sin_conciliar)
    snapshot.aging = calculator.aging
    snapshot.top_deudores = calculator.deuda_por_deudor(limit: 10).to_h
    snapshot.save!
    snapshot
  end

  # Cambios vs la foto del día anterior: la respuesta a "¿qué cambió?".
  def changes_vs_previous
    previous = self.class.where(snapshot_date: snapshot_date - 1.day).order(snapshot_date: :desc).first
    return nil if previous.nil?

    deltas = {}
    %w[saldo_total saldo_vencido saldo_por_vencer].each do |key|
      deltas[key] = (totals[key].to_f - previous.totals[key].to_f).round(2)
    end
    {
      previous_date: previous.snapshot_date,
      deltas: deltas
    }
  end
end
