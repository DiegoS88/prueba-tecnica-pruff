class PaymentApplication < ApplicationRecord
  belongs_to :movement
  belongs_to :invoice
  belongs_to :decided_by, class_name: "User", optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[confirmed suggested rejected] }
  validates :movement_id, uniqueness: { scope: [ :invoice_id ] }

  scope :confirmed, -> { where(status: "confirmed") }
  scope :suggested, -> { where(status: "suggested") }
  scope :rejected, -> { where(status: "rejected") }

  def confirmed?
    status == "confirmed"
  end

  def suggested?
    status == "suggested"
  end

  # Aprobar o rechazar una aplicación deja traza de auditoría (actor = Current.user).
  # Al aprobar un candidato de una factura pagada con varios movimientos, se valida
  # contra el saldo vigente para no sobrepagar la factura.
  def approve!(actor: Current.user)
    saldo_vigente = invoice.saldo
    raise "La factura #{invoice.folio} ya está pagada o su saldo no alcanza (#{amount})." if saldo_vigente < amount

    asignado_movimiento = movement.payment_applications.confirmed.sum(:amount)
    raise "El movimiento ya está asignado por completo (no queda monto para este pago)." if asignado_movimiento + amount > movement.monto

    update!(status: "confirmed", decided_by: actor)
    AuditEvent.record!(
      entity_type: "PaymentApplication",
      entity_id: id.to_s,
      event_type: "payment_application_confirmed",
      actor: actor,
      data: {
        movement_id: movement_id, invoice_id: invoice_id, amount: amount.to_s,
        folio: invoice.folio, score: score.to_s, rule: rule
      }
    )
  end

  def reject!(actor: Current.user)
    update!(status: "rejected", decided_by: actor)
    AuditEvent.record!(
      entity_type: "PaymentApplication",
      entity_id: id.to_s,
      event_type: "payment_application_rejected",
      actor: actor,
      data: { movement_id: movement_id, invoice_id: invoice_id, amount: amount.to_s, folio: invoice.folio }
    )
  end
end
