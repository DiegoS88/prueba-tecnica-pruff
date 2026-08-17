class CreatePaymentApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_applications do |t|
      t.references :movement, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :status, null: false, default: "suggested"
      t.string :rule
      t.decimal :score, precision: 6, scale: 2
      t.json :evidence
      t.references :decided_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :payment_applications, [ :movement_id, :invoice_id ], unique: true
    add_index :payment_applications, :status
  end
end
