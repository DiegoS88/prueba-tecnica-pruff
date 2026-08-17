class Invoice < ApplicationRecord
  belongs_to :import
  has_many :payment_applications, dependent: :restrict_with_error
  has_many :movements, through: :payment_applications

  validates :folio, :rut_cliente, :rut_deudor, :fecha_emision, :fecha_vencimiento, :monto, :moneda, presence: true
  validates :monto, numericality: { greater_than: 0 }
  validates :folio, uniqueness: { scope: [ :rut_cliente ], message: "ya existe para este cliente" }

  before_validation :normalize_ruts

  MONEDAS = %w[CLP UF].freeze

  # Valor UF fijo del dataset (verificado consistente). Usado para comparar
  # montos de facturas UF contra movimientos CLP.
  UF_VALUE = 39_500.0

  # Monto de la factura en CLP (las facturas UF se convierten con UF_VALUE).
  def monto_clp
    moneda == "UF" ? (monto * UF_VALUE).round(2) : monto
  end

  # Saldo pendiente = monto menos todos los pagos confirmados.
  def pagado(preloaded: nil)
    return preloaded unless preloaded.nil?

    payment_applications.confirmed.sum(:amount)
  end

  def saldo(preloaded_pagado: nil)
    monto_clp - pagado(preloaded: preloaded_pagado)
  end

  def saldo_pendiente?(preloaded_pagado: nil)
    saldo(preloaded_pagado: preloaded_pagado).positive?
  end

  def pagada?(preloaded_pagado: nil)
    saldo(preloaded_pagado: preloaded_pagado) <= 0
  end

  def vencida?(as_of: Date.current, preloaded_pagado: nil)
    fecha_vencimiento < as_of && saldo_pendiente?(preloaded_pagado: preloaded_pagado)
  end

  def dias_atraso(as_of: Date.current, preloaded_pagado: nil)
    return 0 unless vencida?(as_of: as_of, preloaded_pagado: preloaded_pagado)

    (as_of - fecha_vencimiento).to_i
  end

  # Estado financiero calculado (no persistido).
  def estado_financiero(as_of: Date.current, preloaded_pagado: nil)
    saldo_actual = saldo(preloaded_pagado: preloaded_pagado)
    return "pagada" if saldo_actual <= 0
    return "vencida" if vencida?(as_of: as_of, preloaded_pagado: preloaded_pagado)
    return "parcialmente_pagada" if saldo_actual < monto_clp

    "pendiente"
  end

  # Estado de conciliación: qué tan explicada está la factura por movimientos del banco.
  def estado_conciliacion(preloaded_pagado: nil)
    pagado_confirmado = pagado(preloaded: preloaded_pagado)
    return "conciliada" if pagado_confirmado == monto_clp
    return "parcialmente_conciliada" if pagado_confirmado.positive?
    return "requiere_revision" if payment_applications.suggested.exists?

    "no_conciliada"
  end

  def confirmed_amount
    payment_applications.confirmed.sum(:amount)
  end

  private

  def normalize_ruts
    self.rut_cliente = Normalizers.rut(rut_cliente) if rut_cliente.present?
    self.rut_deudor = Normalizers.rut(rut_deudor) if rut_deudor.present?
  end
end
