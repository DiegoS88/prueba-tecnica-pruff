class MovementsController < ApplicationController
  def index
    @movements = Movement.includes(:payment_applications, :invoices).order(fecha: :desc)
    @confirmed_by_movement = PaymentApplication.confirmed.group(:movement_id).sum(:amount)

    status = params[:status]
    if status == "conciliado"
      @movements = @movements.select { |m| m.monto - @confirmed_by_movement.fetch(m.id, 0) <= 0 }
    elsif status == "no_conciliado"
      @movements = @movements.reject { |m| m.monto - @confirmed_by_movement.fetch(m.id, 0) <= 0 }
    end

    if params[:referencia].present?
      @movements = @movements.where("referencia ILIKE ?", "%#{params[:referencia]}%")
    end

    if params[:movimiento_id] =~ /\A\d+\z/
      @movements = @movements.where(id: params[:movimiento_id].to_i)
    end

    @movements = Paginator.new(@movements.to_a, page: params[:page])
  end

  def show
    @movement = Movement.includes(:payment_applications, :invoices).find(params[:id])
    @confirmed_by_movement = PaymentApplication.confirmed.where(movement_id: @movement.id).sum(:amount)
    @timeline = InvoiceTimeline.new(@movement).events
  end
end
