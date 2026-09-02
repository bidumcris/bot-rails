# frozen_string_literal: true

class PaymentMethodDetector
  Result = Struct.new(:method, :cleaned_text, keyword_init: true)

  METHODS = [
    [/mercado\s*pago|\bmercadopago\b|\bmp\b/, "Mercado Pago"],
    [/cuenta\s*dni/, "Cuenta DNI"],
    [/personal\s*pay/, "Personal Pay"],
    [/naranja\s*x/, "Naranja X"],
    [/\bual[aá]\b/, "Ualá"],
    [/\bbrubank\b/, "Brubank"],
    [/\bmodo\b/, "MODO"],
    [/d[eé]bito\s+autom[aá]tico/, "Débito automático"],
    [/tarjeta\s+de\s+cr[eé]dito|con\s+la\s+de\s+cr[eé]dito/, "Tarjeta de crédito"],
    [/tarjeta\s+de\s+d[eé]bito|con\s+(el\s+)?d[eé]bito/, "Tarjeta de débito"],
    [/\bvisa\b|\bmastercard\b|\bamex\b|\btarjeta\b/, "Tarjeta"],
    [/\bqr\b/, "QR"],
    [/efectivo|en\s+mano|\bcash\b|\bcontado\b/, "Efectivo"],
    [/transferencia|transfer[ií]|transferiste/, "Transferencia"]
  ].freeze

  LABELS = METHODS.map { |_, label| label }.uniq.freeze

  OUTFLOW = /
    \b(?:por|con|v[ií]a|usando)\s+(?:una?\s+)?
    (?:transferencia|mercado\s*pago|mercadopago|\bmp\b|tarjeta|efectivo|qr|modo|ual[aá]|d[eé]bito|cr[eé]dito)
    | \b(?:pagu[eé]|pagado|compr[eé]|le\s+transfer)
  /ix

  PHRASE = /
    \b(?:por|con|v[ií]a|usando|en)\s+(?:una?\s+)?
    (?:
      transferencia(?:\s+de\s+(?:mercado\s*pago|mercadopago|\bmp\b))?|
      mercado\s*pago|mercadopago|\bmp\b|
      tarjeta(?:\s+de\s+(?:d[eé]bito|cr[eé]dito))?|
      la\s+de\s+(?:d[eé]bito|cr[eé]dito)|
      d[eé]bito(?:\s+autom[aá]tico)?|cr[eé]dito|
      efectivo|qr|modo|ual[aá]|brubank|cuenta\s*dni|personal\s*pay|naranja\s*x|
      mano|cash|contado
    )
    (?:\s+de\s+(?:mercado\s*pago|mercadopago|\bmp\b))?
  /ix

  LEFTOVERS = /
    \b(?:de\s+)?(?:mercado\s*pago|mercadopago)\b
    | \btransferencia\b
  /ix

  def self.extract(text)
    raw = text.to_s
    method = detect(raw)
    Result.new(method: method, cleaned_text: strip(raw))
  end

  def self.detect(text)
    d = text.to_s.downcase
    match = METHODS.find { |re, _| d.match?(re) }
    match&.last
  end

  def self.strip(text)
    s = text.to_s
    had_phrase = s.match?(PHRASE)
    s = s.gsub(PHRASE, " ")
    s = s.gsub(LEFTOVERS, " ") if had_phrase
    s.gsub(/\s+/, " ").strip.gsub(/\A[-–—:;,]+\s*/, "").gsub(/\s*[-–—:;,]+\z/, "").strip
  end

  def self.outflow?(text)
    text.to_s.match?(OUTFLOW)
  end
end
