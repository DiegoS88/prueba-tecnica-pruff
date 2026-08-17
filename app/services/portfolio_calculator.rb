# Calcula métricas de cartera sobre la foto actual de la base de datos.
# Todo es derivado: no se persisten agregados (evita drift).
class PortfolioCalculator
  def initialize(as_of: Date.current)
    @as_of = as_of
    @invoices = Invoice.includes(:payment_applications).all
    @confirmed_by_invoice = PaymentApplication.confirmed.group(:invoice_id).sum(:amount)
    @movements = Movement.includes(:payment_applications).all
    @confirmed_by_movement = PaymentApplication.confirmed.group(:movement_id).sum(:amount)
  end

  def pagado(invoice)
    @confirmed_by_invoice.fetch(invoice.id, 0)
  end

def totals
    saldo_por_invoice = @invoices.map { |i| [ i, saldo_de(i) ] }
    saldo_total = saldo_por_invoice.sum(&:last)
    saldo_vencido = saldo_por_invoice.sum { |i, saldo| i.vencida?(as_of: @as_of, preloaded_pagado: pagado(i)) ? saldo : 0 }
    {
      saldo_total: saldo_total,
      saldo_vencido: saldo_vencido,
      saldo_por_vencer: saldo_total - saldo_vencido,
      monto_emitido: @invoices.sum(&:monto_clp),
      monto_pagado_confirmado: PaymentApplication.confirmed.sum(:amount),
      movimientos_sin_asignar: @movements.sum { |m| m.monto - @confirmed_by_movement.fetch(m.id, 0) },
      n_facturas: @invoices.size,
      n_facturas_con_saldo: saldo_por_invoice.count { |_, saldo| saldo.positive? },
      n_facturas_vencidas: saldo_por_invoice.count { |i, saldo| saldo.positive? && i.vencida?(as_of: @as_of, preloaded_pagado: pagado(i)) },
      n_movimientos_sin_conciliar: @movements.count { |m| @confirmed_by_movement.fetch(m.id, 0) <= 0 }
    }
  end

  # Distribución de la deuda por antigüedad (aging) en buckets de días de atraso.
  def aging
    buckets = { "0-30" => 0, "31-60" => 0, "61-90" => 0, "91+" => 0 }
    @invoices.each do |invoice|
      saldo = saldo_de(invoice)
      next unless saldo.positive?

      if invoice.vencida?(as_of: @as_of, preloaded_pagado: pagado(invoice))
        dias = invoice.dias_atraso(as_of: @as_of, preloaded_pagado: pagado(invoice))
        key = if dias <= 30 then "0-30"
        elsif dias <= 60 then "31-60"
        elsif dias <= 90 then "61-90"
        else "91+"
        end
        buckets[key] += saldo
      end
    end
    buckets
  end

  # Deuda por deudor (top 10), útil para ranking de riesgo.
  def deuda_por_deudor(limit: 10)
    @invoices.each_with_object(Hash.new(0)) do |invoice, acc|
      saldo = saldo_de(invoice)
      acc[invoice.rut_deudor] += saldo if saldo.positive?
    end.sort_by { |_, monto| -monto }.first(limit)
  end

  private

  def saldo_de(invoice)
    invoice.monto_clp - pagado(invoice)
  end
end
