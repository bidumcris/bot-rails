# frozen_string_literal: true

class BnaOfficialDollar
  Rate = Struct.new(:compra, :venta, :updated_at, :source, :stale, keyword_init: true)

  CACHE_KEY = "bna_official_dollar"
  CACHE_TTL = 30 * 60
  STALE_TTL = 24 * 60 * 60

  ENDPOINTS = [
    ["https://dolarapi.com/v1/ambito/dolares/bna", "bna"],
    ["https://dolarapi.com/v1/dolares/oficial", "oficial"]
  ].freeze

  def self.current
    new.current
  end

  def self.ars_to_usd(amount_cents, rate: current)
    new.ars_to_usd(amount_cents, rate: rate)
  end

  def self.usd_to_ars_cents(usd, rate: current)
    new.usd_to_ars_cents(usd, rate: rate)
  end

  def current
    cached = read_cache
    return cached unless stale_for_refresh?(cached)

    fetched = fetch
    if fetched
      write_cache(fetched)
      return fetched
    end

    mark_stale(cached)
  rescue StandardError
    mark_stale(cached)
  end

  def ars_to_usd(amount_cents, rate: current)
    return nil unless rate&.venta.to_f.positive?

    (amount_cents.to_i / 100.0) / rate.venta
  end

  def usd_to_ars_cents(usd, rate: current)
    return nil unless rate&.venta.to_f.positive?

    (usd.to_f * rate.venta * 100).round
  end

  private

  def fetch
    ENDPOINTS.each do |url, source|
      rate = fetch_endpoint(url, source)
      return rate if rate
    end
    nil
  end

  def fetch_endpoint(url, source)
    res = HTTPX.with(timeout: { connect_timeout: 4, read_timeout: 8 }).get(url)
    return nil if res.is_a?(HTTPX::ErrorResponse)
    return nil unless res.status.to_i == 200

    data = JSON.parse(res.to_s)
    compra = data["compra"].to_f
    venta = data["venta"].to_f
    return nil unless compra.positive? && venta.positive?

    updated =
      begin
        Time.zone.parse(data["fechaActualizacion"].to_s)
      rescue StandardError
        Time.zone.now
      end

    Rate.new(compra: compra, venta: venta, updated_at: updated, source: source, stale: false)
  rescue StandardError
    nil
  end

  def stale_for_refresh?(rate)
    return true if rate.nil?

    fetched_at = cache_written_at(rate)
    fetched_at.nil? || fetched_at < Time.now - CACHE_TTL
  end

  def read_cache
    payload = Rails.cache.read(CACHE_KEY)
    deserialize(payload)
  rescue StandardError
    nil
  end

  def write_cache(rate)
    Rails.cache.write(CACHE_KEY, serialize(rate), expires_in: STALE_TTL)
  rescue StandardError
    nil
  end

  def mark_stale(rate)
    return nil unless rate

    Rate.new(
      compra: rate.compra,
      venta: rate.venta,
      updated_at: rate.updated_at,
      source: rate.source,
      stale: true
    )
  end

  def serialize(rate)
    {
      "compra" => rate.compra,
      "venta" => rate.venta,
      "updated_at" => rate.updated_at&.iso8601,
      "source" => rate.source,
      "cached_at" => Time.now.iso8601
    }
  end

  def deserialize(payload)
    return nil unless payload.is_a?(Hash)

    Rate.new(
      compra: payload["compra"].to_f,
      venta: payload["venta"].to_f,
      updated_at: payload["updated_at"].present? ? Time.zone.parse(payload["updated_at"]) : nil,
      source: payload["source"],
      stale: false
    )
  rescue StandardError
    nil
  end

  def cache_written_at(rate)
    payload = Rails.cache.read(CACHE_KEY)
    return nil unless payload.is_a?(Hash) && payload["cached_at"].present?

    Time.parse(payload["cached_at"].to_s)
  rescue StandardError
    nil
  end
end
