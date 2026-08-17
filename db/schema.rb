# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_17_014353) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type", default: "system", null: false
    t.datetime "created_at", null: false
    t.json "data"
    t.string "entity_id", null: false
    t.string "entity_type", null: false
    t.string "event_type", null: false
    t.bigint "import_id"
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["created_at"], name: "index_audit_events_on_created_at"
    t.index ["entity_type", "entity_id"], name: "index_audit_events_on_entity_type_and_entity_id"
    t.index ["import_id"], name: "index_audit_events_on_import_id"
  end

  create_table "imports", force: :cascade do |t|
    t.string "content_hash", null: false
    t.json "counts"
    t.datetime "created_at", null: false
    t.json "error_summary"
    t.string "file_name"
    t.string "kind", null: false
    t.string "status", default: "processing", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["kind", "content_hash"], name: "index_imports_on_kind_and_content_hash", unique: true
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "fecha_emision", null: false
    t.date "fecha_vencimiento", null: false
    t.string "folio", null: false
    t.bigint "import_id", null: false
    t.string "moneda", default: "CLP", null: false
    t.decimal "monto", precision: 14, scale: 2, null: false
    t.string "rut_cliente", null: false
    t.string "rut_deudor", null: false
    t.datetime "updated_at", null: false
    t.index ["fecha_vencimiento"], name: "index_invoices_on_fecha_vencimiento"
    t.index ["import_id"], name: "index_invoices_on_import_id"
    t.index ["moneda"], name: "index_invoices_on_moneda"
    t.index ["rut_cliente", "folio"], name: "index_invoices_on_rut_cliente_and_folio", unique: true
    t.index ["rut_deudor"], name: "index_invoices_on_rut_deudor"
  end

  create_table "movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "descripcion"
    t.date "fecha", null: false
    t.string "fingerprint", null: false
    t.bigint "import_id", null: false
    t.decimal "monto", precision: 14, scale: 2, null: false
    t.string "referencia"
    t.datetime "updated_at", null: false
    t.index ["fecha"], name: "index_movements_on_fecha"
    t.index ["fingerprint"], name: "index_movements_on_fingerprint", unique: true
    t.index ["import_id"], name: "index_movements_on_import_id"
  end

  create_table "payment_applications", force: :cascade do |t|
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "decided_by_id"
    t.json "evidence"
    t.bigint "invoice_id", null: false
    t.bigint "movement_id", null: false
    t.string "rule"
    t.decimal "score", precision: 6, scale: 2
    t.string "status", default: "suggested", null: false
    t.datetime "updated_at", null: false
    t.index ["decided_by_id"], name: "index_payment_applications_on_decided_by_id"
    t.index ["invoice_id"], name: "index_payment_applications_on_invoice_id"
    t.index ["movement_id", "invoice_id"], name: "index_payment_applications_on_movement_id_and_invoice_id", unique: true
    t.index ["movement_id"], name: "index_payment_applications_on_movement_id"
    t.index ["status"], name: "index_payment_applications_on_status"
  end

  create_table "portfolio_snapshots", force: :cascade do |t|
    t.json "aging"
    t.datetime "created_at", null: false
    t.date "snapshot_date", null: false
    t.json "top_deudores"
    t.json "totals"
    t.datetime "updated_at", null: false
    t.index ["snapshot_date"], name: "index_portfolio_snapshots_on_snapshot_date", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "imports", "users"
  add_foreign_key "payment_applications", "invoices"
  add_foreign_key "payment_applications", "movements"
  add_foreign_key "payment_applications", "users", column: "decided_by_id"
  add_foreign_key "sessions", "users"
end
