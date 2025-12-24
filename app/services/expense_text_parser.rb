class ExpenseTextParser
  # Devuelve [amount_cents, description]
  # Soporta: "hamburguesa 8500", "$8.500 hamburguesa", "pagué luz 23.000,50"
  def self.parse(text, currency: "ARS")
    raw = text.to_s.strip
    return [nil, raw] if raw.blank?

    raw = expand_shorthand_amounts(raw)

    # Busca el último número "grande" del mensaje (suele ser el monto)
    # Formatos: 8500 | 8.500 | 8,500 | 23.000,50 | 23000.50
    # Importante: el branch con miles exige al menos un separador ( + ) para no capturar solo los primeros 3 dígitos
    # de números largos sin separadores (ej "4500" => no debe capturar "450").
    number_tokens = raw.scan(/(?:\$|\b)(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?:\b)?/)
    token = number_tokens.flatten.last

    amount_cents = token ? parse_to_cents(token, currency: currency) : nil
    description = token ? raw.sub(token, "") : raw
    description = clean_description(description)

    [amount_cents, description.presence || raw]
  end

  # Limpia palabras típicas de moneda y signos sueltos, para dejar una descripción usable.
  def self.clean_description(text)
    s = text.to_s
    s = s.gsub("$", " ")
    s = s.gsub(/\b(pesos?|ars)\b/i, " ")
    s = s.gsub(/\s+/, " ").strip
    s = s.gsub(/\A[-–—:;,]+\s*/, "").gsub(/\s*[-–—:;,]+\z/, "").strip
    s
  end

  # Expande atajos comunes (23k, 23 mil) a números normales para que el parser sea determinístico.
  def self.expand_shorthand_amounts(text)
    s = text.to_s
    s.gsub(/(\d+(?:[.,]\d+)?)\s*(k|mil)\b/i) do
      num = Regexp.last_match(1).tr(",", ".")
      base = num.to_f
      expanded = (base * 1000).round
      expanded.to_s
    end
  end

  def self.parse_to_cents(token, currency:)
    s = token.to_s.strip
    s = s.gsub(/[^\d.,]/, "")
    return nil if s.blank?

    decimal_sep = nil
    thousand_sep = nil

    if s.include?(",") && s.include?(".")
      # El último separador suele ser decimal; el otro miles
      if s.rindex(",") > s.rindex(".")
        decimal_sep = ","
        thousand_sep = "."
      else
        decimal_sep = "."
        thousand_sep = ","
      end
    elsif s.include?(".")
      if s.count(".") > 1
        thousand_sep = "."
      else
        tail = s.split(".", 2).last
        decimal_sep = (tail.size <= 2) ? "." : nil
        thousand_sep = decimal_sep ? nil : "."
      end
    elsif s.include?(",")
      if s.count(",") > 1
        thousand_sep = ","
      else
        tail = s.split(",", 2).last
        decimal_sep = (tail.size <= 2) ? "," : nil
        thousand_sep = decimal_sep ? nil : ","
      end
    end

    s = s.delete(thousand_sep) if thousand_sep

    int_part, dec_part =
      if decimal_sep
        parts = s.split(decimal_sep, 2)
        [parts[0], parts[1]]
      else
        [s, nil]
      end

    int_digits = int_part.gsub(/[^\d]/, "")
    return nil if int_digits.blank?

    decimals = dec_part.to_s.gsub(/[^\d]/, "")[0, 2]
    decimals = decimals.ljust(2, "0") if decimals.present?
    decimals = "00" if decimals.blank?

    (int_digits.to_i * 100) + decimals.to_i
  end
end


