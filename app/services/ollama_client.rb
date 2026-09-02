# frozen_string_literal: true

class OllamaClient
  def initialize(
    host: ENV.fetch("OLLAMA_HOST", "http://127.0.0.1:11434"),
    model: ENV.fetch("OLLAMA_MODEL", "qwen2.5:3b"),
    timeout: ENV.fetch("OLLAMA_TIMEOUT", "60").to_i
  )
    @host = normalize_host(host)
    @model = model
    @timeout = timeout
  end

  def available?
    res = HTTPX
      .with(timeout: { connect_timeout: 2, read_timeout: 2 })
      .get("#{@host}/api/tags")
    return false if res.is_a?(HTTPX::ErrorResponse)

    res.status.to_i == 200
  rescue StandardError
    false
  end

  # Pide JSON al modelo. Devuelve un Hash o nil si falla.
  def chat_json(system:, user:)
    payload = {
      model: @model,
      stream: false,
      format: "json",
      options: { temperature: 0.1 },
      messages: [
        { role: "system", content: system },
        { role: "user", content: user }
      ]
    }

    res = HTTPX
      .with(timeout: { connect_timeout: 5, read_timeout: @timeout, write_timeout: @timeout })
      .post("#{@host}/api/chat", json: payload)

    return nil if res.is_a?(HTTPX::ErrorResponse)
    return nil unless res.status.to_i == 200

    body = JSON.parse(res.to_s)
    content = body.dig("message", "content").to_s
    return nil if content.blank?

    JSON.parse(content)
  rescue StandardError
    nil
  end

  attr_reader :model

  private

  # Ollama usa OLLAMA_HOST=127.0.0.1:11434 (sin esquema) para el server.
  # Para HTTP desde Rails necesitamos URL completa.
  def normalize_host(host)
    h = host.to_s.strip.chomp("/")
    return "http://127.0.0.1:11434" if h.blank?
    return h if h.start_with?("http://", "https://")

    "http://#{h}"
  end
end
