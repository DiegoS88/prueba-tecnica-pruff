class InvoicesController < ApplicationController
  def index
    @invoices = Invoice.includes(:payment_applications).order(fecha_vencimiento: :asc)
    @confirmed_by_invoice = PaymentApplication.confirmed.group(:invoice_id).sum(:amount)

    @invoices = @invoices.where("rut_deudor ILIKE ?", "%#{params[:rut_deudor]}%") if params[:rut_deudor].present?
    @invoices = @invoices.where("folio ILIKE ?", "%#{params[:folio]}%") if params[:folio].present?

    scope = params[:scope]
    if scope.present?
      @invoices = @invoices.select { |i| i.estado_financiero(preloaded_pagado: @confirmed_by_invoice.fetch(i.id, 0)) == scope }
    end

    @invoices = Paginator.new(@invoices.to_a, page: params[:page])
  end

  def show
    @invoice = Invoice.includes(:payment_applications, :movements).find(params[:id])
    @timeline = InvoiceTimeline.new(@invoice).events
  end
end
