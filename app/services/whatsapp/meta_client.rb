module Whatsapp
  class MetaClient
    def initialize(
      access_token: ENV["META_WA_ACCESS_TOKEN"],
      phone_number_id: ENV["META_WA_PHONE_NUMBER_ID"],
      api_version: ENV["META_WA_API_VERSION"].presence || "v21.0"
    )
      @access_token = access_token.to_s
      @phone_number_id = phone_number_id.to_s
      @api_version = api_version.to_s
    end

    def enabled?
      @access_token.present? && @phone_number_id.present?
    end

    def send_text(to_phone_e164, text)
      raise "Meta WhatsApp no configurado (META_WA_ACCESS_TOKEN/META_WA_PHONE_NUMBER_ID)" unless enabled?

      payload = {
        messaging_product: "whatsapp",
        to: to_phone_e164.to_s,
        type: "text",
        text: { body: text.to_s }
      }

      HTTPX
        .with(
          headers: {
            "Authorization" => "Bearer #{@access_token}",
            "Content-Type" => "application/json"
          }
        )
        .post("https://graph.facebook.com/#{@api_version}/#{@phone_number_id}/messages", json: payload)
    end
  end
end


