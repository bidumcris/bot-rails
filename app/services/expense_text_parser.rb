# frozen_string_literal: true

class ExpenseTextParser
  # Devuelve [amount_cents, description, kind]
  # kind: "expense" | "income"
  def self.parse(text, currency: "ARS")
    raw = text.to_s.strip
    return [nil, raw, detect_kind(raw)] if raw.blank?

    kind = detect_kind(raw)
    expanded = expand_shorthand_amounts(raw)

    # "2 menús ... 9000 cada uno" => 2 * 9000
    if (qty_match = expanded.match(/(\d+)\s+.{0,80}?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+)(?:\s*pesos?)?\s*cada\s+(?:uno|una)\b/i))
      qty = qty_match[1].to_i
      unit_cents = parse_to_cents(qty_match[2], currency: currency)
      if qty.positive? && unit_cents
        description = expanded.sub(qty_match[2], " ")
        description = description.sub(/\bcada\s+(?:uno|una)\b/i, " ")
        description = clean_description(description)
        return [qty * unit_cents, description.presence || raw, kind]
      end
    end

    # Busca el último número "grande" del mensaje (suele ser el monto)
    number_tokens = expanded.scan(/(?:\$|\b)(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?:\b)?/)
    token = number_tokens.flatten.last

    amount_cents = token ? parse_to_cents(token, currency: currency) : nil
    description = token ? expanded.sub(token, "") : expanded
    description = clean_description(description)

    [amount_cents, description.presence || raw, kind]
  end

  def self.detect_kind(text)
    t = text.to_s.downcase
    income_re = /\b(cobr[eo]|cobré|ingreso|ingres[eé]|transferencia|me\s+transfer|deposit[oó]|me\s+deposit|recib[ií]|me\s+pagaron|pago\s+recibido|sueldo|honorarios?\s+cobrad)\b/i
    # "pago X" suele ser gasto; "me pagaron" / "cobro" es ingreso
    return "income" if t.match?(income_re)
    "expense"
  end

  # Limpia palabras típicas de moneda y signos sueltos, para dejar una descripción usable.
  def self.clean_description(text)
    s = text.to_s
    s = s.gsub("$", " ")
    s = s.gsub(/\b(pesos?|ars)\b/i, " ")
    s = s.gsub(/\bcada\s+(uno|una)\b/i, " ")
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
