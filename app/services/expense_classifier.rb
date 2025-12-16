class ExpenseClassifier
  Category = Struct.new(:category, :subcategory, :confidence, keyword_init: true)

  def initialize(provider: ENV["LLM_PROVIDER"].presence || "openai")
    @provider = provider
  end

  def classify(description)
    desc = description.to_s.strip
    return Category.new(category: "Otros", subcategory: nil, confidence: 0.2) if desc.blank?

    if ENV["OPENAI_API_KEY"].present? && @provider == "openai"
      classify_with_openai(desc)
    else
      classify_with_rules(desc)
    end
  rescue StandardError
    classify_with_rules(description)
  end

  private

  def classify_with_rules(desc)
    d = desc.downcase

    rules = [
      [/hamburg|pizza|comida|kiosko|gaseosa|coca|almuerzo|cena|desayuno/, ["Comida", nil]],
      [/internet|wifi|fibra|movistar|personal|claro|telecentro/, ["Servicios", "Internet"]],
      [/luz|edenor|edesur|energia|epe/, ["Servicios", "Luz"]],
      [/gas\b|metrogas|naturgy/, ["Servicios", "Gas"]],
      [/agua|aysa/, ["Servicios", "Agua"]],
      [/sube|uber|cabify|taxi|colectivo|tren|nafta|combustible/, ["Transporte", nil]],
      [/farmacia|medico|clínica|obra social|osde|swiss/, ["Salud", nil]],
      [/netflix|spotify|youtube|disney|prime/, ["Suscripciones", nil]]
    ]

    match = rules.find { |re, _| d.match?(re) }
    if match
      cat, sub = match[1]
      return Category.new(category: cat, subcategory: sub, confidence: 0.65)
    end

    Category.new(category: "Otros", subcategory: nil, confidence: 0.35)
  end

  def classify_with_openai(desc)
    payload = {
      model: ENV["OPENAI_MODEL"].presence || "gpt-4o-mini",
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: "Sos un asistente que clasifica gastos personales en Argentina. Respondé SOLO JSON." },
        { role: "user", content: <<~TEXT }
          Dada la descripción de un gasto, devolvé un JSON con:
          - category: una de ["Comida","Servicios","Transporte","Salud","Compras","Hogar","Ocio","Impuestos","Suscripciones","Otros"]
          - subcategory: string o null
          - confidence: número 0..1

          Descripción: "#{desc}"
        TEXT
      ]
    }

    res = HTTPX
      .with(headers: {
        "Authorization" => "Bearer #{ENV["OPENAI_API_KEY"]}",
        "Content-Type" => "application/json"
      })
      .post("https://api.openai.com/v1/chat/completions", json: payload)

    body = JSON.parse(res.to_s)
    content = body.dig("choices", 0, "message", "content").to_s
    data = JSON.parse(content)

    Category.new(
      category: data["category"].presence || "Otros",
      subcategory: data["subcategory"],
      confidence: data["confidence"].to_f.clamp(0.0, 1.0)
    )
  end
end


