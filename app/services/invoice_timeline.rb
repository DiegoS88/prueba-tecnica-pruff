# Reconstruye el recorrido completo de una entidad (factura o movimiento)
# como una lista cronológica de hechos de negocio, uniendo los audit_events
# con el detalle de cada entidad relacionada.
class InvoiceTimeline
  def initialize(entity)
    @entity = entity
  end

  def events
    case @entity
    when Invoice then invoice_events
    when Movement then movement_events
    else []
    end
  end

  private

  def invoice_events
    result = []

    # Origen: factura + su importación.
    result << fact("factura_creada", @entity.import, { folio: @entity.folio, monto: @entity.monto.to_s, moneda: @entity.moneda, fecha_emision: @entity.fecha_emision.to_s, fecha_vencimiento: @entity.fecha_vencimiento.to_s })
    result += audit_for("Invoice", @entity.id)

    @entity.payment_applications.order(:created_at).each do |app|
      result << fact(
        conciliacion_event_type(app),
        app,
        {
          amount: app.amount.to_s,
          status: app.status,
          score: app.score&.to_s,
          rule: app.rule,
          signals: app.evidence,
          movement_fecha: app.movement.fecha.to_s,
          movement_monto: app.movement.monto.to_s,
          movement_referencia: app.movement.referencia
        }
      )
    end

    result
  end

  def movement_events
    result = []
    result << fact("movimiento_creado", @entity.import, { fecha: @entity.fecha.to_s, monto: @entity.monto.to_s, descripcion: @entity.descripcion, referencia: @entity.referencia })
    result += audit_for("Movement", @entity.id)
    @entity.payment_applications.order(:created_at).each do |app|
      result << fact(conciliacion_event_type(app), app, { amount: app.amount.to_s, invoice_folio: app.invoice.folio, score: app.score&.to_s, rule: app.rule, signals: app.evidence })
    end
    result
  end

  # La conciliación de un movimiento es un hecho de negocio con actor humano
  # (decided_by); solo los candidatos sin decidir quedan como "aplicación".
  def conciliacion_event_type(app)
    case app.status
    when "confirmed" then "movimiento_conciliado"
    when "rejected" then "movimiento_rechazado"
    else "aplicacion_#{app.status}"
    end
  end

  # Los audit events de payment_application_* son la traza cruda del matcher y de
  # la decisión; las aplicaciones ya se muestran como hechos derivados con su
  # estado y actor, así que se excluyen para no duplicar el mismo evento.
  def audit_for(entity_type, entity_id)
    AuditEvent.for_entity(entity_type, entity_id)
              .reject { |event| event.event_type.start_with?("payment_application") }
              .map { |event| fact("evento_#{event.event_type}", event, event.data) }
  end

  def fact(titulo, source, details)
    actor =
      if source.respond_to?(:user) && source.user
        source.user.email_address
      elsif source.is_a?(AuditEvent)
        source.actor_label
      elsif source.respond_to?(:decided_by) && source.decided_by
        source.decided_by.email_address
      else
        "sistema"
      end

    {
      tipo: titulo,
      fecha: source&.created_at || Time.current,
      actor: actor,
      detalles: details
    }
  end
end
