# Etiquetas de presentación en español para estados calculados por los modelos.
# El modelo devuelve identificadores estables (snake_case); esta capa solo traduce.
module StatusLabelsHelper
  ESTADOS_FINANCIEROS = {
    "pagada" => "Pagada",
    "vencida" => "Vencida",
    "parcialmente_pagada" => "Parcialmente pagada",
    "pendiente" => "Pendiente"
  }.freeze

  ESTADOS_CONCILIACION = {
    "conciliada" => "Conciliada",
    "parcialmente_conciliada" => "Parcialmente conciliada",
    "requiere_revision" => "Requiere revisión",
    "no_conciliada" => "No conciliada"
  }.freeze

  CONCILIACION_MOVIMIENTO = {
    "conciliado" => "Conciliado",
    "parcialmente_conciliado" => "Parcialmente conciliado",
    "no_conciliado" => "No conciliado"
  }.freeze

  APLICACION_STATUS = {
    "confirmed" => "Confirmada",
    "suggested" => "Sugerida",
    "rejected" => "Rechazada"
  }.freeze

  EVENTOS = {
    "factura_creada" => "Factura creada",
    "movimiento_creado" => "Movimiento creado",
    "aplicacion_confirmed" => "Pago aplicado",
    "aplicacion_suggested" => "Pago sugerido",
    "aplicacion_rejected" => "Pago rechazado",
    "movimiento_conciliado" => "Movimiento conciliado",
    "movimiento_rechazado" => "Movimiento rechazado",
    "evento_payment_application_confirmed" => "Pago confirmado",
    "evento_payment_application_suggested" => "Pago sugerido",
    "evento_payment_application_rejected" => "Pago rechazado",
    "evento_import_created" => "Archivo importado",
    "evento_import_completed" => "Importación finalizada",
    "payment_application_confirmed" => "Pago confirmado",
    "payment_application_suggested" => "Pago sugerido",
    "payment_application_rejected" => "Pago rechazado"
  }.freeze

  SENALES = {
    "folio_en_referencia" => "Folio en la referencia",
    "folio_en_descripcion" => "Folio en la descripción",
    "monto_completo" => "Monto igual al de la factura",
    "pago_parcial" => "Pago parcial",
    "pago_en_plazo" => "Dentro del plazo",
    "pago_tardio" => "Pago tardío",
    "moneda_igual" => "Misma moneda"
  }.freeze

  def estado_financiero_label(estado)
    ESTADOS_FINANCIEROS.fetch(estado.to_s, estado.to_s.humanize)
  end

  def estado_conciliacion_label(estado)
    ESTADOS_CONCILIACION.fetch(estado.to_s, estado.to_s.humanize)
  end

  def conciliacion_movimiento_label(estado)
    CONCILIACION_MOVIMIENTO.fetch(estado.to_s, estado.to_s.humanize)
  end

  def aplicacion_status_label(status)
    APLICACION_STATUS.fetch(status.to_s, status.to_s.humanize)
  end

  def evento_label(tipo)
    EVENTOS.fetch(tipo.to_s, tipo.to_s.humanize)
  end

  def senal_label(senal)
    SENALES.fetch(senal.to_s, senal.to_s.humanize)
  end

  # Nivel de evidencia cualitativo a partir del score numérico del matcher.
  def confianza(score)
    return "baja" if score.nil? || score < 50
    return "media" if score < 80

    "alta"
  end

  def confianza_label(score)
    { "alta" => "Alta", "media" => "Media", "baja" => "Baja" }.fetch(confianza(score))
  end
end
