class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.string :entity_type, null: false
      t.string :entity_id, null: false
      t.string :event_type, null: false
      t.string :actor_type, null: false, default: "system"
      t.references :actor, foreign_key: { to_table: :users }
      t.references :import
      t.json :data

      t.timestamps
    end

    add_index :audit_events, [ :entity_type, :entity_id ]
    add_index :audit_events, :created_at
  end
end
