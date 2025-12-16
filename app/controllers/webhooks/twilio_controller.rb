module Webhooks
  class TwilioController < BaseController
    # POST /webhooks/twilio/whatsapp
    #
    # Twilio params típicos:
    # - From: "whatsapp:+54911..."
    # - Body: "hamburguesa 8500"
    def whatsapp
      from = params["From"].to_s
      body = params["Body"].to_s

      phone = from.sub(/\Awhatsapp:/, "")
      user = User.find_or_create_by_phone!(phone)

      result = ExpenseIngestor.new.ingest(user: user, text: body)
      reply = result.reply_text.presence || "OK"

      render xml: twiml_message(reply), content_type: "text/xml"
    rescue StandardError => e
      render xml: twiml_message("Error: #{e.class} - #{e.message}"), content_type: "text/xml", status: :ok
    end

    private

    def twiml_message(text)
      escaped = ERB::Util.html_escape(text.to_s)
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Message>#{escaped}</Message>
        </Response>
      XML
    end
  end
end


