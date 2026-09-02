# frozen_string_literal: true

class ExpenseAiExtractor
  Extraction = Struct.new(
    :amount_cents, :description, :category, :subcategory, :confidence, :provider, :model,
    keyword_init: true
  )

  CATEGORIES = ["Comida", "Servicios", "Transporte", "Salud", "Compras", "Hogar", "Ocio", "Impuestos", "Suscripciones", "Otros"].freeze

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

  # Extrae un gasto desde texto libre.
  # Devuelve amount_cents como Integer o nil si no encontró monto.
  def extract(text, currency: "ARS")
    raw = text.to_s.strip
    blank = Extraction.new(
      amount_cents: nil, description: raw, category: nil, subcategory: nil,
      confidence: 0.0, provider: @provider, model: model_name
    )
    return blank if raw.blank?
    return blank unless enabled?

    data =
      case @provider
      when "ollama"
        extract_with_ollama(raw)
      when "openai"
        extract_with_openai(raw)
      end

    return blank if data.nil?

    category = data["category"].to_s
    category = "Otros" unless CATEGORIES.include?(category)

    amount_cents = data["amount_cents"]
    amount_cents = amount_cents.to_i if amount_cents.is_a?(Numeric) || amount_cents.to_s.match?(/\A\d+\z/)
    amount_cents = nil if amount_cents.to_i <= 0

    desc = data["description"].to_s.strip
    desc = raw if desc.blank?

    Extraction.new(
      amount_cents: amount_cents,
      description: desc,
      category: category,
      subcategory: data["subcategory"].presence,
      confidence: data["confidence"].to_f.clamp(0.0, 1.0),
      provider: @provider,
      model: model_name
    )
  rescue StandardError
    Extraction.new(
      amount_cents: nil, description: raw, category: nil, subcategory: nil,
      confidence: 0.0, provider: @provider, model: model_name
    )
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

  def system_prompt
    <<~SYS.strip
      Sos un asistente que interpreta gastos personales en Argentina.
      Respondé SOLO JSON válido. Moneda: ARS. Si no hay monto, poné amount_cents = null.
    SYS
  end

  def user_prompt(raw)
    <<~TEXT
      Extraé un gasto desde el texto y devolvé JSON con:
      - amount_cents: integer (ARS * 100) o null
      - description: string (descripción normalizada sin el monto, SIN dígitos y sin palabras de moneda como "pesos"/"ARS")
      - category: una de #{CATEGORIES}
      - subcategory: string o null
      - confidence: número 0..1

      Reglas:
      - "23k", "23 mil", "23.000" => 23000 ARS => amount_cents 2300000
      - "Futbol 4500 pesos" => amount_cents: 450000, description: "Futbol"
      - No inventes números. Si no hay monto, amount_cents debe ser null.
      - Si hay fecha tipo "ayer", ignorala (no la necesitamos ahora).
      - Si el texto es ambiguo, elegí category = "Otros" y confidence baja.

      Texto: "#{raw}"
    TEXT
  end

  def extract_with_ollama(raw)
    ollama.chat_json(system: system_prompt, user: user_prompt(raw))
  end

  def extract_with_openai(raw)
    payload = {
      model: model_name,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system_prompt },
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
