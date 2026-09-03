# frozen_string_literal: true

class ExpenseAiExtractor
  Extraction = Struct.new(
    :amount_cents, :description, :category, :subcategory, :confidence, :provider, :model, :kind, :payment_method,
    keyword_init: true
  )

  EXPENSE_CATEGORIES = [
    "Comida", "Servicios", "Transporte", "Salud", "Compras", "Hogar",
    "Ocio", "Impuestos", "Suscripciones", "Regalos", "Otros"
  ].freeze

  INCOME_CATEGORIES = [
    "Trabajo", "Transferencias", "Ventas", "Otros ingresos"
  ].freeze

  def initialize(provider: ENV["LLM_PROVIDER"].presence || "ollama")
    @provider = provider
  end

  def enabled?
    case @provider
    when "ollama"
      ollama.available?
    when "openai"
      ENV["OPENAI_API_KEY"].present?
    else
      false
    end
  end

  def extract(text, currency: "ARS", occupation: nil)
    extract_all(text, currency: currency, occupation: occupation).first
  end

  def extract_all(text, currency: "ARS", occupation: nil)
    raw = text.to_s.strip
    fallback = [blank_extraction(raw)]
    return fallback if raw.blank?
    return fallback unless enabled?

    data =
      case @provider
      when "ollama" then extract_with_ollama(raw, occupation: occupation)
      when "openai" then extract_with_openai(raw, occupation: occupation)
      end

    rows = normalize_payload(data)
    return fallback if rows.empty?

    items = rows.filter_map { |row| row_to_extraction(row, raw) }
    items.presence || fallback
  rescue StandardError
    [blank_extraction(raw)]
  end

  private

  def ollama
    @ollama ||= OllamaClient.new
  end

  def model_name
    case @provider
    when "ollama"
      ENV["OLLAMA_MODEL"].presence || "qwen2.5:3b"
    else
      ENV["OPENAI_MODEL"].presence || "gpt-4o-mini"
    end
  end

  def blank_extraction(raw)
    Extraction.new(
      amount_cents: nil, description: raw.to_s, category: nil, subcategory: nil,
      confidence: 0.0, provider: @provider, model: model_name,
      kind: ExpenseTextParser.detect_kind(raw),
      payment_method: PaymentMethodDetector.detect(raw)
    )
  end

  def normalize_payload(data)
    return [] if data.nil?
    return data["items"] if data.is_a?(Hash) && data["items"].is_a?(Array)
    return [data] if data.is_a?(Hash)

    []
  end

  def row_to_extraction(data, raw)
    return nil unless data.is_a?(Hash)

    snippet = data["description"].presence || raw
    kind_guess = ExpenseTextParser.detect_kind(snippet)
    payment_guess = PaymentMethodDetector.detect(snippet)

    kind = data["kind"].to_s
    kind = kind_guess unless %w[expense income].include?(kind)
    if PaymentMethodDetector.outflow?(snippet) && !ExpenseTextParser.strong_income?(snippet)
      kind = "expense"
    end

    categories = kind == "income" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES
    category = data["category"].to_s
    category = (kind == "income" ? "Otros ingresos" : "Otros") unless categories.include?(category)

    amount_cents = data["amount_cents"]
    amount_cents = amount_cents.to_i if amount_cents.is_a?(Numeric) || amount_cents.to_s.match?(/\A\d+\z/)
    amount_cents = nil if amount_cents.to_i <= 0

    desc = data["description"].to_s.strip
    desc = raw if desc.blank?
    desc = PaymentMethodDetector.strip(desc)

    payment = data["payment_method"].to_s.strip
    payment = payment_guess unless PaymentMethodDetector::LABELS.include?(payment)
    payment ||= payment_guess

    Extraction.new(
      amount_cents: amount_cents,
      description: desc,
      category: category,
      subcategory: data["subcategory"].presence,
      confidence: data["confidence"].to_f.clamp(0.0, 1.0),
      provider: @provider,
      model: model_name,
      kind: kind,
      payment_method: payment
    )
  end

  def system_prompt(occupation: nil)
    extra =
      if occupation.present?
        "El usuario se dedica a: #{occupation}. Si habla de clientes, servicios o cobros de ese rubro, suele ser ingreso (Trabajo)."
      else
        ""
      end

    <<~SYS.strip
      Sos un asistente de finanzas personales en Argentina.
      Respondé SOLO JSON válido. Moneda ARS.
      Distinguí gasto (expense) vs ingreso (income).
      Cobros, transferencias RECIBIDAS, depósitos = income.
      Pagos, compras, regalos que vos diste = expense.
      Si dice que PAGÓ por transferencia, Mercado Pago, tarjeta o efectivo, es expense. El medio de pago no lo convierte en ingreso.
      Si el mensaje tiene VARIOS movimientos, devolvé uno por cada monto. No los sumes.
      #{extra}
    SYS
  end

  def user_prompt(raw)
    <<~TEXT
      Interpretá el mensaje y devolvé JSON:
      {"items":[...]}
      Cada item:
      - kind: "expense" o "income"
      - amount_cents: integer (ARS * 100) o null. Si dice "2 menús 9000 cada uno" => 1800000
      - description: string corta sin monto ni moneda
      - category: si kind=expense una de #{EXPENSE_CATEGORIES}; si kind=income una de #{INCOME_CATEGORIES}
      - subcategory: string o null
      - payment_method: una de #{PaymentMethodDetector::LABELS} o null
      - confidence: 0..1

      Ejemplos:
      - "Cobro 84150 por servicio pilates" => items: [{income, Trabajo, 8415000}]
      - "Transferencia 21mil de gime a mi" => items: [{income, Transferencias, 2100000, Transferencia}]
      - "hamburguesa 8500 en efectivo" => items: [{expense, Comida, 850000, Efectivo}]
      - "hamburguesa 8500 y coca 2000" => items: [{expense, Comida, 850000, hamburguesa}, {expense, Comida, 200000, coca}]
      - "Compra 2 menús 9000 cada uno" => items: [{expense, Comida, 1800000}]
      - "6000 milanesas de pollo" => items: [{expense, Comida, 600000}]

      Texto: "#{raw}"
    TEXT
  end

  def extract_with_ollama(raw, occupation: nil)
    ollama.chat_json(system: system_prompt(occupation: occupation), user: user_prompt(raw))
  end

  def extract_with_openai(raw, occupation: nil)
    payload = {
      model: model_name,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system_prompt(occupation: occupation) },
        { role: "user", content: user_prompt(raw) }
      ]
    }

    res = HTTPX
      .with(
        timeout: { connect_timeout: 5, read_timeout: 20, write_timeout: 20 },
        headers: {
          "Authorization" => "Bearer #{ENV["OPENAI_API_KEY"]}",
          "Content-Type" => "application/json"
        }
      )
      .post("https://api.openai.com/v1/chat/completions", json: payload)

    body = JSON.parse(res.to_s)
    content = body.dig("choices", 0, "message", "content").to_s
    JSON.parse(content)
  end
end
