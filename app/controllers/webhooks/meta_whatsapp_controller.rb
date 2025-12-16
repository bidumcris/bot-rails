module Webhooks
  class MetaWhatsappController < BaseController
    # Meta verification (GET):
    # - hub.mode=subscribe
    # - hub.verify_token=...
    # - hub.challenge=...
    def verify
      mode = params["hub.mode"].to_s
      token = params["hub.verify_token"].to_s
      challenge = params["hub.challenge"].to_s

      if mode == "subscribe" && ActiveSupport::SecurityUtils.secure_compare(token, ENV["META_WA_VERIFY_TOKEN"].to_s)
        render plain: challenge, status: :ok
      else
        render plain: "forbidden", status: :forbidden
      end
    end

    # Meta messages webhook (POST):
    # Responde 200 rápido, procesa textos entrantes y contesta por Graph API.
    def receive
      data = params.to_unsafe_h
      messages = extract_messages(data)

      ingestor = ExpenseIngestor.new
      client = Whatsapp::MetaClient.new

      messages.each do |msg|
        from = msg[:from] # teléfono (sin "whatsapp:")
        text = msg[:text]
        next if from.blank? || text.blank?

        user = User.find_or_create_by_phone!(from)
        result = ingestor.ingest(user: user, text: text)

        # Nota: Meta solo permite responder libremente dentro de la ventana de 24h desde el último mensaje del usuario.
        if client.enabled? && result.reply_text.present?
          client.send_text(User.normalize_phone(from), result.reply_text)
        end
      end

      head :ok
    end

    private

    # Devuelve array de {from:, text:}
    def extract_messages(data)
      out = []
      entries = Array(data["entry"])
      entries.each do |entry|
        changes = Array(entry["changes"])
        changes.each do |change|
          value = change["value"] || {}
          Array(value["messages"]).each do |m|
            next unless m.is_a?(Hash)
            from = m["from"].to_s
            text = m.dig("text", "body").to_s
            out << { from: from, text: text }
          end
        end
      end
      out
    end
  end
end


