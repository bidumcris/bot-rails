# frozen_string_literal: true

class ExpenseTextParser
  Item = Struct.new(:amount_cents, :description, :kind, :payment_method, :raw_text, keyword_init: true)

  MAX_ITEMS = 8
  SPLIT_CONJ = /\s*(?:,|;|\n|\by\b|\be\b|\bm[aá]s\b|\btambi[eé]n\b|\bluego\b|\bdespu[eé]s\b)\s*/i
  AMOUNT_FINDER = /
    (?<![\d.])
    (?:\$\s*)?
    (?:
      \d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?
      |
      \d+(?:[.,]\d{1,2})?\s*(?:usd|u\$s|u\$d|d[oó]lares?)\b
      |
      (?:usd|u\$s|u\$d)\s*\d+(?:[.,]\d{1,2})?
      |
      \d{3,}(?:[.,]\d{1,2})?
    )
    (?!\d)(?![.,]\d)
  /ix

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

  def self.parse_many(text, currency: "ARS", usd_venta: nil)
    raw = text.to_s.strip
    return [] if raw.blank?

    segments = split_segments(raw)
    items = segments.filter_map do |seg|
      amount_cents, description, kind, payment_method = parse(seg, currency: currency, usd_venta: usd_venta)
      next if amount_cents.to_i <= 0

      Item.new(
        amount_cents: amount_cents,
        description: description,
        kind: kind,
        payment_method: payment_method,
        raw_text: seg
      )
    end.first(MAX_ITEMS)

    return items if items.size >= 2

    amount_cents, description, kind, payment_method = parse(raw, currency: currency, usd_venta: usd_venta)
    [
      Item.new(
        amount_cents: amount_cents,
        description: description,
        kind: kind,
        payment_method: payment_method,
        raw_text: raw
      )
    ]
  end

  def self.split_segments(text)
    expanded = expand_shorthand_amounts(text.to_s)
    lines = expanded.split(/\n+/).map { |l| l.to_s.strip }.reject(&:blank?)
    if lines.size >= 2
      lined = lines.flat_map { |line| split_line_by_amounts(line) }
      return lined if lined.size >= 2
    end

    split_line_by_amounts(expanded)
  end

  def self.split_line_by_amounts(expanded)
    ranges = amount_ranges(expanded)
    return [expanded] if ranges.size < 2

    cuts = [0]
    ranges.each_cons(2) do |(_s1, e1, _), (s2, _e2, _)|
      between = expanded[e1...s2].to_s
      if (m = between.match(SPLIT_CONJ))
        cuts << (e1 + m.begin(0))
        cuts << (e1 + m.end(0))
      elsif trailing_for_current?(between)
        cuts << s2
      else
        cuts << e1
        cuts << e1
      end
    end
    cuts << expanded.length

    segments = []
    cuts.each_slice(2) do |from, to|
      next if from.nil? || to.nil? || to <= from

      seg = clean_segment(expanded[from...to].to_s)
      segments << seg if seg.present?
    end
    segments.presence || [expanded]
  end

  def self.amount_ranges(text)
    ranges = []
    text.to_s.scan(AMOUNT_FINDER) do
      m = Regexp.last_match
      ranges << [m.begin(0), m.end(0), m[0]]
    end
    ranges
  end

  def self.trailing_for_current?(chunk)
    cleaned = clean_description(PaymentMethodDetector.strip(chunk.to_s))
    cleaned.blank?
  end

  def self.clean_segment(text)
    s = text.to_s.strip
    s = s.sub(/\A(?:y|e|m[aá]s|tambi[eé]n|despu[eé]s|luego|,|;)\s+/i, "")
    s = s.sub(/\s+(?:y|e|m[aá]s|tambi[eé]n|,|;)\s*\z/i, "")
    s.gsub(/\s+/, " ").strip
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
    s = s.gsub(/\A(?:hoy\s+)?(?:gast[eé]|pagu[eé]|compr[eé]|anot[eé])\s+/i, "")
    s = s.gsub(/\s+/, " ").strip
    s = s.gsub(/\A[-–—:;,]+\s*/, "").gsub(/\s*[-–—:;,]+\z/, "").strip
    s = s.gsub(/\A(?:en|por|un|una|el|la|los|las|del|al|de)\s+/i, "")
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
