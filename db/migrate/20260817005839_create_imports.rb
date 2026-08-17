class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.string :kind, null: false
      t.string :file_name
      t.string :content_hash, null: false
      t.string :status, null: false, default: "processing"
      t.json :counts
      t.json :error_summary
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :imports, [ :kind, :content_hash ], unique: true
  end
end
