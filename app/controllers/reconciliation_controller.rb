class ReconciliationController < ApplicationController
  def index
    applications = PaymentApplication.includes(:movement, :invoice).where(status: %w[suggested])
    if params[:movimiento_id].present?
      applications = applications.where(movement_id: params[:movimiento_id].to_i) if params[:movimiento_id] =~ /\A\d+\z/
    end
    if params[:folio].present?
      applications = applications.joins(:invoice).where("invoices.folio ILIKE ?", "%#{params[:folio]}%")
    end
    @applications = Paginator.new(applications.order(score: :desc).to_a, page: params[:page])
    unmatched = Movement.includes(:payment_applications).select { |m| m.payment_applications.none? }
    if params[:referencia].present?
      pattern = "%#{params[:referencia]}%"
      unmatched = unmatched.select { |m| m.referencia.to_s.match?(/#{Regexp.escape(params[:referencia])}/i) }
    end
    @unmatched_movements = Paginator.new(unmatched, page: params[:page])
  end

  def approve
    application = PaymentApplication.find(params[:id])
    application.approve!(actor: Current.user)
    redirect_back fallback_location: reconciliation_index_path, notice: "Pago #{application.amount} aplicado a la factura #{application.invoice.folio}."
  rescue StandardError => e
    redirect_back fallback_location: reconciliation_index_path, alert: e.message
  end

  def reject
    application = PaymentApplication.find(params[:id])
    application.reject!(actor: Current.user)
    redirect_back fallback_location: reconciliation_index_path, notice: "Candidato rechazado."
  end
end
