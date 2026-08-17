# Normalizadores de datos sucios: RUTs, fechas, montos, monedas y folios.
# Cada función es pura y devuelve valores normalizados o nil si no puede parsear.
module Normalizers
  module_function

  # RUT chileno: quita puntos, guiones y espacios; deja dígito verificador en mayúscula.
  # "90.060.626-7" -> "900606267" | "67.313.577-1" -> "673135771"
  def rut(value)
    return nil if value.blank?

    normalized = value.to_s.strip.delete(" .-").upcase
    return nil unless normalized.match?(/\A\d{1,8}[0-9K]\z/)

    normalized
  end

  # Monto: acepta "24.963.000,00", "32.053.000", "61,26" (separador de miles = ".", decimal = ",").
  def monto(value)
    return nil if value.blank?

    text = value.to_s.strip
    sign = text.start_with?("-") ? -1 : 1
    text = text.delete_prefix("+").delete_prefix("-").tr("$", "").strip

    # Si hay ambos separadores, el último es el decimal.
    if text.include?(".") && text.include?(",")
      if text.rindex(",") > text.rindex(".")
        text = text.delete(".").tr(",", ".")
      else
        text = text.delete(",")
      end
    elsif text.include?(",")
      # Sin punto: la coma es decimal ("61,26").
      text = text.tr(",", ".")
    elsif text.include?(".")
      # Sin coma: el punto es separador de miles.
      text = text.delete(".")
    end

    parsed = Float(text)
    (parsed * sign).round(2)
  rescue ArgumentError, TypeError
    nil
  end

  # Fecha: acepta YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY. Retorna Date o nil.
  def fecha(value)
    return nil if value.blank?

    text = value.to_s.strip
    case text
    when /\A(\d{4})-(\d{2})-(\d{2})\z/
      y, m, d = Regexp.last_match.captures.map(&:to_i)
    when /\A(\d{2})[-\/](\d{2})[-\/](\d{4})\z/
      d, m, y = Regexp.last_match.captures.map(&:to_i)
    else
      return nil
    end

    Date.new(y, m, d)
  rescue Date::Error
    nil
  end

  # Moneda: "$" -> CLP; "clp"/"CLP"/"$" -> CLP; "uf"/"UF" -> UF. Retorna símbolo ISO o nil.
  def moneda(value)
    return nil if value.blank?

    case value.to_s.strip.upcase
    when "$", "CLP" then "CLP"
    when "UF" then "UF"
    end
  end

  # Folio: busca un número de 4 a 8 dígitos en un texto (referencia/descripción).
  def folio(text)
    return nil if text.blank?

    match = text.to_s.match(/\b(\d{4,8})\b/)
    match && match[1]
  end

  # Fingerprint para idempotencia: hash de los campos que definen una fila.
  def fingerprint(*parts)
    Digest::SHA256.hexdigest(parts.map { |p| p.to_s.strip }.join("|"))
  end
end
