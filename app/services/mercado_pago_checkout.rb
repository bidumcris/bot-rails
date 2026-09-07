# frozen_string_literal: true

require "uri"
require "json"

class MercadoPagoCheckout
  API = "https://api.mercadopago.com"

  Result = Struct.new(:ok, :url, :preference_id, :error, keyword_init: true)

  def self.enabled?
    ENV["MP_ACCESS_TOKEN"].to_s.present?
  end

  def self.create_preference(user)
    new.create_preference(user)
  end

  def self.sync_user!(user)
    new.sync_user!(user)
  end

  def self.sync_notification(params)
    new.sync_notification(params)
  end

  def create_preference(user)
    return Result.new(ok: false, error: "missing_token") unless self.class.enabled?

    payload = {
      items: [
        {
          title: "Bot Pro #{ProPlan.paid_days} días",
          quantity: 1,
          currency_id: "ARS",
          unit_price: ProPlan.price_ars
        }
      ],
      external_reference: external_reference(user),
      statement_descriptor: "BIDUM PRO",
      expires: true,
      expiration_date_from: Time.current.utc.iso8601,
      expiration_date_to: 2.days.from_now.utc.iso8601
    }
    if public_base.present?
      payload[:notification_url] = "#{public_base}/webhooks/mercadopago"
      payload[:back_urls] = {
        success: "#{public_base}/pro/ok",
        pending: "#{public_base}/pro/ok",
        failure: "#{public_base}/pro/error"
      }
      payload[:auto_return] = "approved"
    end

    res = http.post("#{API}/checkout/preferences", json: payload)
    return Result.new(ok: false, error: "http") if res.is_a?(HTTPX::ErrorResponse) || res.status.to_i >= 300

    body = JSON.parse(res.to_s)
    preference_id = body["id"].to_s
    url = sandbox? ? body["sandbox_init_point"] : body["init_point"]
    user.update!(mp_preference_id: preference_id) if preference_id.present?
    Result.new(ok: url.present?, url: url, preference_id: preference_id)
  rescue StandardError => e
    warn("[MercadoPagoCheckout] preference #{e.class}: #{e.message}")
    Result.new(ok: false, error: e.message)
  end

  def sync_user!(user)
    return false unless self.class.enabled?

    payment = latest_approved_payment(user)
    return false unless payment

    grant!(user, payment)
  end

  def sync_notification(params)
    return false unless self.class.enabled?

    payment_id = notification_payment_id(params)
    return false if payment_id.blank?

    payment = get_payment(payment_id)
    return false unless payment && payment["status"].to_s == "approved"

    user = user_from_reference(payment["external_reference"])
    return false unless user

    grant!(user, payment)
  end

  private

  def grant!(user, payment)
    payment_id = payment["id"].to_s
    return true if user.mp_payment_id.to_s == payment_id

    user.grant_pro!(source: "mercadopago", payment_id: payment_id)
    true
  end

  def latest_approved_payment(user)
    res = http.get(
      "#{API}/v1/payments/search?#{URI.encode_www_form(
        sort: "date_created",
        criteria: "desc",
        external_reference: external_reference(user),
        status: "approved"
      )}"
    )
    return nil if res.is_a?(HTTPX::ErrorResponse) || res.status.to_i >= 300

    results = JSON.parse(res.to_s).dig("results")
    Array(results).first
  rescue StandardError
    nil
  end

  def get_payment(payment_id)
    res = http.get("#{API}/v1/payments/#{payment_id}")
    return nil if res.is_a?(HTTPX::ErrorResponse) || res.status.to_i >= 300

    JSON.parse(res.to_s)
  rescue StandardError
    nil
  end

  def notification_payment_id(params)
    h = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    h = h.with_indifferent_access
    id = h.dig("data", "id") || h["id"] || h.dig(:data, :id)
    type = h["type"].to_s.presence || h["topic"].to_s
    return if type.present? && !type.match?(/payment/i)

    id.to_s.presence
  end

  def user_from_reference(ref)
    telegram_id = ref.to_s.sub(/\Atg:/, "")
    return if telegram_id.blank?

    User.find_by(telegram_user_id: telegram_id)
  end

  def external_reference(user)
    "tg:#{user.telegram_user_id}"
  end

  def public_base
    ENV["PRO_PUBLIC_URL"].to_s.strip.chomp("/")
  end

  def sandbox?
    ENV["MP_SANDBOX"].to_s == "true"
  end

  def http
    HTTPX.with(
      timeout: { connect_timeout: 8, read_timeout: 20 },
      headers: {
        "Authorization" => "Bearer #{ENV["MP_ACCESS_TOKEN"]}",
        "Content-Type" => "application/json"
      }
    )
  end
end
