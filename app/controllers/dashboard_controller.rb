class DashboardController < ApplicationController
  def index
    calculator = PortfolioCalculator.new
    @totals = calculator.totals
    @aging = calculator.aging
    @snapshot = PortfolioSnapshot.capture!(date: Date.current)
    @changes = @snapshot.changes_vs_previous
    @recent_events = AuditEvent.order(created_at: :desc).limit(15).includes(:actor)
    confirmed_by_movement = PaymentApplication.confirmed.group(:movement_id).sum(:amount)
    @needs_attention = {
      no_conciliados: Movement.all.count { |m| confirmed_by_movement.fetch(m.id, 0) <= 0 },
      sugeridas: PaymentApplication.suggested.count
    }
  end
end
