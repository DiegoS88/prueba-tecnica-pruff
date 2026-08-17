class Import < ApplicationRecord
  belongs_to :user
  has_many :invoices
  has_many :movements
  has_many :audit_events

  enum :kind, { invoices: "invoices", movements: "movements" }, prefix: true
  enum :status, { processing: "processing", completed: "completed", failed: "failed" }, prefix: true

  validates :kind, :content_hash, presence: true

  def summary
    {
      total: counts&.fetch("total", 0),
      imported: counts&.fetch("imported", 0),
      updated: counts&.fetch("updated", 0),
      duplicates: counts&.fetch("duplicates", 0),
      errors: counts&.fetch("errors", 0)
    }
  end
end
