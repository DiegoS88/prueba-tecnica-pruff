class CreateMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :movements do |t|
      t.date :fecha, null: false
      t.decimal :monto, precision: 14, scale: 2, null: false
      t.text :descripcion
      t.string :referencia
      t.string :fingerprint, null: false
      t.references :import, null: false

      t.timestamps
    end

    add_index :movements, :fingerprint, unique: true
    add_index :movements, :fecha
  end
end
