# frozen_string_literal: true

class ExpenseClassifier
  Category = Struct.new(:category, :subcategory, :confidence, keyword_init: true)

  def classify(description, kind: "expense")
    desc = description.to_s.strip
    if desc.blank?
      fallback = kind == "income" ? "Otros ingresos" : "Otros"
      return Category.new(category: fallback, subcategory: nil, confidence: 0.2)
    end

    kind == "income" ? classify_income(desc) : classify_expense(desc)
  rescue StandardError
    fallback = kind == "income" ? "Otros ingresos" : "Otros"
    Category.new(category: fallback, subcategory: nil, confidence: 0.2)
  end

  private

  def classify_expense(desc)
    d = desc.downcase
    rules = [
      [/regalo|maestro|cumple|navidad/, ["Regalos", nil]],
      [/hamburg|pizza|comida|men[uú]|kiosko|gaseosa|coca|almuerzo|cena|desayuno|milanesa|pollo/, ["Comida", nil]],
      [/internet|wifi|fibra|movistar|personal|claro|telecentro/, ["Servicios", "Internet"]],
      [/luz|edenor|edesur|energia|epe/, ["Servicios", "Luz"]],
      [/gas\b|metrogas|naturgy/, ["Servicios", "Gas"]],
      [/agua|aysa/, ["Servicios", "Agua"]],
      [/sube|uber|cabify|taxi|colectivo|tren|nafta|combustible/, ["Transporte", nil]],
      [/farmacia|medico|clínica|obra social|osde|swiss/, ["Salud", nil]],
      [/netflix|spotify|youtube|disney|prime|hbo|\bmax\b|flow|crunchyroll|chatgpt|icloud|google\s*one|suscrip/, ["Suscripciones", nil]]
    ]

    match = rules.find { |re, _| d.match?(re) }
    if match
      cat, sub = match[1]
      return Category.new(category: cat, subcategory: sub, confidence: 0.7)
    end

    Category.new(category: "Otros", subcategory: nil, confidence: 0.35)
  end

  def classify_income(desc)
    d = desc.downcase
    rules = [
      [/pilates|sistema|servicio|freelance|trabajo|cliente|honorario/, ["Trabajo", nil]],
      [/transfer|gime|dep[oó]sit/, ["Transferencias", nil]],
      [/venta|vend[ií]/, ["Ventas", nil]]
    ]
    match = rules.find { |re, _| d.match?(re) }
    if match
      cat, sub = match[1]
      return Category.new(category: cat, subcategory: sub, confidence: 0.7)
    end
    Category.new(category: "Otros ingresos", subcategory: nil, confidence: 0.4)
  end
end
