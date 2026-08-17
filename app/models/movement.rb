class Movement < ApplicationRecord
  belongs_to :import
  has_many :payment_applications, dependent: :restrict_with_error
  has_many :invoices, through: :payment_applications

  validates :fecha, :monto, :fingerprint, presence: true
  validates :fingerprint, uniqueness: true
  validates :monto, numericality: { greater_than: 0 }

  # Estado de conciliación del movimiento (cuánto de su monto está asignado).
  def confirmed_amount(preloaded: nil)
    return preloaded unless preloaded.nil?

    payment_applications.confirmed.sum(:amount)
  end

  def unassigned_amount(preloaded: nil)
    monto - confirmed_amount(preloaded: preloaded)
  end

  def conciliado?(preloaded: nil)
    unassigned_amount(preloaded: preloaded) <= 0
  end

  def conciliacion(preloaded: nil)
    return "conciliado" if conciliado?(preloaded: preloaded)
    return "parcialmente_conciliado" if confirmed_amount(preloaded: preloaded).positive?

    "no_conciliado"
  end
end
