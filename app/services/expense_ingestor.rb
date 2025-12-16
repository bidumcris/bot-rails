class ExpenseIngestor
  Result = Struct.new(:status, :reply_text, :expense_id, keyword_init: true)

  def initialize(classifier: ExpenseClassifier.new)
    @classifier = classifier
  end

  # Procesa un texto libre y devuelve qué contestar.
  # Flujo:
  # - Si falta monto: crea DraftExpense y pregunta el monto.
  # - Si hay Draft awaiting_amount y llega un monto: crea Expense y borra el Draft.
  def ingest(user:, text:)
    text = text.to_s.strip
    return Result.new(status: "ignored", reply_text: nil, expense_id: nil) if text.blank?

    # Si hay un borrador esperando monto, aceptar número como respuesta.
    draft = user.draft_expenses.order(created_at: :desc).find_by(state: "awaiting_amount")
    if draft && text.match?(/\d/)
      amount_cents, _ = ExpenseTextParser.parse(text, currency: user.currency)
      return Result.new(status: "need_amount", reply_text: "No entendí el monto. Probá: 8500 o 23.000,50", expense_id: nil) if amount_cents.nil?

      description = draft.extracted["description"].presence || draft.raw_text
      cat = @classifier.classify(description)

      expense = user.expenses.create!(
        amount_cents: amount_cents,
        currency: user.currency,
        description: description,
        category: cat.category,
        subcategory: cat.subcategory,
        raw_text: draft.raw_text,
        llm_provider: ENV["LLM_PROVIDER"],
        llm_model: ENV["OPENAI_MODEL"],
        llm_confidence: cat.confidence,
        metadata: { flow: "draft_amount" }
      )

      draft.destroy!
      return Result.new(status: "created", reply_text: format_created(expense), expense_id: expense.id)
    end

    amount_cents, description = ExpenseTextParser.parse(text, currency: user.currency)
    if amount_cents.nil?
      user.draft_expenses.create!(raw_text: text, extracted: { "description" => description }, state: "awaiting_amount")
      return Result.new(status: "need_amount", reply_text: "¿Cuánto fue el monto en ARS para: \"#{description}\"?", expense_id: nil)
    end

    cat = @classifier.classify(description)
    expense = user.expenses.create!(
      amount_cents: amount_cents,
      currency: user.currency,
      description: description,
      category: cat.category,
      subcategory: cat.subcategory,
      spent_at: Time.zone.now,
      raw_text: text,
      llm_provider: ENV["LLM_PROVIDER"],
      llm_model: ENV["OPENAI_MODEL"],
      llm_confidence: cat.confidence,
      metadata: { flow: "direct" }
    )

    Result.new(status: "created", reply_text: format_created(expense), expense_id: expense.id)
  end

  private

  def format_ars(amount_cents)
    pesos = amount_cents.to_i / 100.0
    format("$%.2f ARS", pesos)
  end

  def format_created(expense)
    cat = [expense.category, expense.subcategory].compact.join(" / ")
    "Registrado: #{format_ars(expense.amount_cents)} — #{cat} — #{expense.description}"
  end
end


