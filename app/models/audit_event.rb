class AuditEvent < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :import, optional: true

  # Registro append-only de un hecho de negocio.
  def self.record!(entity_type:, entity_id:, event_type:, actor: nil, import: nil, data: {})
    create!(
      entity_type: entity_type,
      entity_id: entity_id,
      event_type: event_type,
      actor: actor,
      actor_type: actor.present? ? "user" : "system",
      import: import,
      data: data
    )
  end

  # Una sola consulta reconstruye el recorrido completo de una entidad:
  # hechos de negocio ordenados cronológicamente.
  scope :for_entity, ->(entity_type, entity_id) { where(entity_type: entity_type, entity_id: entity_id.to_s).order(:created_at) }

  def actor_label
    return "sistema" if actor.nil?

    actor.email_address
  end
end
