# frozen_string_literal: true

class ExpenseTextParser
  # Devuelve [amount_cents, description, kind]
  # kind: "expense" | "income"
  def self.parse(text, currency: "ARS", usd_venta: nil)
    raw = text.to_s.strip
    return [nil, raw, detect_kind(raw), nil] if raw.blank?

    payment = PaymentMethodDetector.extract(raw)
    kind = detect_kind(raw)
    expanded = expand_shorthand_amounts(raw)

    if (usd = extract_usd_amount(expanded)) && usd_venta.to_f.positive?
      amount_cents = (usd * usd_venta.to_f * 100).round
      description = finalize_description(strip_usd_tokens(expanded), raw)
      return [amount_cents, description, kind, payment.method]
    end

    # "2 menús ... 9000 cada uno" => 2 * 9000
    if (qty_match = expanded.match(/(\d+)\s+.{0,80}?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+)(?:\s*pesos?)?\s*cada\s+(?:uno|una)\b/i))
      qty = qty_match[1].to_i
      unit_cents = parse_to_cents(qty_match[2], currency: currency)
      if qty.positive? && unit_cents
        description = expanded.sub(qty_match[2], " ")
        description = description.sub(/\bcada\s+(?:uno|una)\b/i, " ")
        description = finalize_description(description, raw)
        return [qty * unit_cents, description, kind, payment.method]
      end
    end

    # Busca el último número "grande" del mensaje (suele ser el monto)
    number_tokens = expanded.scan(/(?:\$|\b)(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?:\b)?/)
    token = number_tokens.flatten.last

    amount_cents = token ? parse_to_cents(token, currency: currency) : nil
    description = token ? expanded.sub(token, "") : expanded
    description = finalize_description(description, raw)

    [amount_cents, description, kind, payment.method]
  end

  STRONG_INCOME = /
    \b(
      cobr[eo]|cobré|ingreso|ingres[eé]|
      me\s+transfer|me\s+deposit|deposit[oó]|
      recib[ií]|me\s+pagaron|pago\s+recibido|
      sueldo|honorarios?\s+cobrad
    )\b
  /ix

  BARE_TRANSFER_INCOME = /\btransferencia\b/i

  def self.detect_kind(text)
    t = text.to_s
    return "income" if t.match?(STRONG_INCOME)
    return "expense" if PaymentMethodDetector.outflow?(t)
    return "income" if t.match?(BARE_TRANSFER_INCOME)
    "expense"
  end

  def self.strong_income?(text)
    text.to_s.match?(STRONG_INCOME)
  end

  def self.finalize_description(text, fallback)
    description = clean_description(PaymentMethodDetector.strip(text.to_s))
    description.presence || PaymentMethodDetector.strip(fallback).presence || fallback
  end

  # Limpia palabras típicas de moneda y signos sueltos, para dejar una descripción usable.
  def self.clean_description(text)
    s = text.to_s
    s = s.gsub("$", " ")
    s = s.gsub(/\b(pesos?|ars|usd|u\$s|u\$d|d[oó]lares?)\b/i, " ")
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

  def self.extract_usd_amount(text)
    if (m = text.to_s.match(/(\d+(?:[.,]\d{1,2})?)\s*(usd|u\$s|u\$d|d[oó]lares?)\b/i))
      return normalize_usd_token(m[1])
    end
    if (m = text.to_s.match(/\b(usd|u\$s|u\$d)\s*(\d+(?:[.,]\d{1,2})?)/i))
      return normalize_usd_token(m[2])
    end

    nil
  end

  def self.strip_usd_tokens(text)
    s = text.to_s
    s = s.gsub(/(\d+(?:[.,]\d{1,2})?)\s*(usd|u\$s|u\$d|d[oó]lares?)\b/i, " ")
    s.gsub(/\b(usd|u\$s|u\$d)\s*(\d+(?:[.,]\d{1,2})?)/i, " ")
  end

  def self.normalize_usd_token(token)
    token.to_s.tr(",", ".").to_f
  end
end
