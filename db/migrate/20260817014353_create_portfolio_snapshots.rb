class CreatePortfolioSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :portfolio_snapshots do |t|
      t.date :snapshot_date, null: false
      t.json :totals
      t.json :aging
      t.json :top_deudores

      t.timestamps
    end

    add_index :portfolio_snapshots, :snapshot_date, unique: true
  end
end
