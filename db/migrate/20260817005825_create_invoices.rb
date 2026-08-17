class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.string :folio, null: false
      t.string :rut_cliente, null: false
      t.string :rut_deudor, null: false
      t.date :fecha_emision, null: false
      t.date :fecha_vencimiento, null: false
      t.decimal :monto, precision: 14, scale: 2, null: false
      t.string :moneda, null: false, default: "CLP"
      t.references :import, null: false

      t.timestamps
    end

    add_index :invoices, [ :rut_cliente, :folio ], unique: true
    add_index :invoices, :rut_deudor
    add_index :invoices, :fecha_vencimiento
    add_index :invoices, :moneda
  end
end
