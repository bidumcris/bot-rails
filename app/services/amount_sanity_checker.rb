# frozen_string_literal: true

class AmountSanityChecker
  Check = Struct.new(
    :suspicious, :item_label, :usd, :min_usd, :max_usd, :suggestions, :reason,
    keyword_init: true
  )
  Suggestion = Struct.new(:amount_cents, :usd, keyword_init: true)

  # Rangos en USD oficial: no se desactualizan con la inflación en ARS.
  ITEMS = [
    [/hamburg|burger|whopper|big\s*mac|mccombo/, 3.0..18.0, "una hamburguesa"],
    [/pizza/, 4.0..35.0, "una pizza"],
    [/\bcaf[eé]\b|cafeter[ií]a/, 1.0..6.0, "un café"],
    [/almuerzo|men[uú]|vianda/, 4.0..25.0, "un almuerzo"],
    [/\bcena\b/, 8.0..50.0, "una cena"],
    [/desayuno/, 2.0..15.0, "un desayuno"],
    [/milanesa/, 4.0..20.0, "una milanesa"],
    [/empanada/, 0.6..4.0, "una empanada"],
    [/helado|helader/, 2.0..12.0, "un helado"],
    [/gaseosa|coca|sprite|agua mineral/, 0.6..4.0, "una bebida"],
    [/delivery|rappi|pedidos?\s*ya/, 5.0..35.0, "un delivery"],
    [/super(mercado)?|\bchino\b|carrefour|\bcoto\b|\bdisco\b|\bvea\b|jumbo/, 8.0..200.0, "el súper"],
    [/kiosco|kiosko/, 0.4..12.0, "el kiosco"],
    [/netflix/, 5.0..22.0, "Netflix"],
    [/spotify/, 2.5..12.0, "Spotify"],
    [/youtube|yt\s*premium/, 4.0..16.0, "YouTube Premium"],
    [/disney/, 5.0..18.0, "Disney+"],
    [/\bprime\b|amazon\s*prime/, 3.0..15.0, "Prime Video"],
    [/\bhbo\b|\bmax\b/, 5.0..18.0, "Max/HBO"],
    [/\bflow\b/, 5.0..25.0, "Flow"],
    [/crunchyroll/, 4.0..12.0, "Crunchyroll"],
    [/chatgpt|openai/, 15.0..25.0, "ChatGPT"],
    [/icloud|google\s*one/, 1.0..15.0, "almacenamiento en la nube"],
    [/suscrip|subscription|premium/, 2.0..30.0, "una suscripción"],
    [/uber|cabify|taxi|didi/, 1.5..25.0, "un viaje"],
    [/colectivo|subte|\bsube\b|\btren\b/, 0.2..3.0, "el transporte"],
    [/nafta|combustible|\bypf\b|\bshell\b|axion/, 8.0..80.0, "nafta"],
    [/m[eé]dic[oa]|doctor|doctora|consultorio|consulta/, 12.0..90.0, "una consulta médica"],
    [/dentist|odont[oó]log/, 15.0..120.0, "el dentista"],
    [/psic[oó]log|psiquiatra|terapia/, 15.0..80.0, "la consulta"],
    [/farmacia|remedio|medicament/, 3.0..40.0, "la farmacia"]
  ].freeze

  CATEGORY_USD = {
    "Comida" => 1.0..40.0,
    "Suscripciones" => 2.0..30.0,
    "Transporte" => 0.4..40.0,
    "Ocio" => 1.0..80.0,
    "Salud" => 4.0..90.0,
    "Servicios" => 8.0..150.0
  }.freeze

  HIGH_MULTIPLIER = 2.2
  LOW_FACTOR = 3.0

  def self.check(amount_cents:, description:, kind:, category: nil, user: nil, rate: nil)
    new.check(
      amount_cents: amount_cents,
      description: description,
      kind: kind,
      category: category,
      user: user,
      rate: rate
    )
  end

  def check(amount_cents:, description:, kind:, category: nil, user: nil, rate: nil)
    ok = Check.new(suspicious: false, item_label: nil, usd: nil, min_usd: nil, max_usd: nil, suggestions: [], reason: nil)
    return ok unless kind.to_s == "expense"
    return ok unless amount_cents.to_i.positive?

    rate ||= BnaOfficialDollar.current
    usd = BnaOfficialDollar.ars_to_usd(amount_cents, rate: rate)
    item = match_item(description)
    range = item ? item[1] : CATEGORY_USD[category.to_s]
    label = item ? item[2] : category.presence

    history_cents = historical_median_cents(user, description)
    if history_cents && history_cents.positive? && amount_cents > history_cents * 4
      range ||= 0.0..(BnaOfficialDollar.ars_to_usd(history_cents, rate: rate).to_f * 2)
      label ||= description.to_s.strip
    end

    return ok if range.nil? || usd.nil?

    too_high = usd > range.max * HIGH_MULTIPLIER
    too_low = usd < (range.min / LOW_FACTOR)

    return ok unless too_high || too_low

    suggestions =
      if too_low
        build_low_suggestions(amount_cents, range, rate, history_cents)
      else
        build_suggestions(amount_cents, range, rate, history_cents)
      end

    Check.new(
      suspicious: true,
      item_label: label,
      usd: usd,
      min_usd: range.min,
      max_usd: range.max,
      suggestions: suggestions,
      reason: too_low ? :too_low : :too_high
    )
  end

  private

  def match_item(description)
    d = description.to_s.downcase
    ITEMS.find { |re, _, _| d.match?(re) }
  end

  def build_low_suggestions(amount_cents, range, rate, history_cents)
    candidates = [1000, 100].filter_map do |mult|
      cents = amount_cents.to_i * mult
      usd = BnaOfficialDollar.ars_to_usd(cents, rate: rate)
      next unless usd && range.cover?(usd)

      Suggestion.new(amount_cents: cents, usd: usd)
    end

    if history_cents.to_i.positive?
      usd = BnaOfficialDollar.ars_to_usd(history_cents, rate: rate)
      if usd && range.cover?(usd) && candidates.none? { |s| s.amount_cents == history_cents }
        candidates << Suggestion.new(amount_cents: history_cents, usd: usd)
      end
    end

    pesos = amount_cents.to_i / 100.0
    if pesos <= 500
      candidates.sort_by! { |s| s.amount_cents == amount_cents.to_i * 1000 ? 0 : 1 }
    end
    candidates.uniq(&:amount_cents).first(2)
  end

  def build_suggestions(amount_cents, range, rate, history_cents)
    candidates = [10, 100, 1000].filter_map do |div|
      next unless (amount_cents % div).zero?

      cents = amount_cents / div
      usd = BnaOfficialDollar.ars_to_usd(cents, rate: rate)
      next unless usd && range.cover?(usd)

      Suggestion.new(amount_cents: cents, usd: usd)
    end

    if history_cents.to_i.positive?
      usd = BnaOfficialDollar.ars_to_usd(history_cents, rate: rate)
      if usd && range.cover?(usd) && candidates.none? { |s| s.amount_cents == history_cents }
        candidates << Suggestion.new(amount_cents: history_cents, usd: usd)
      end
    end

    candidates.uniq(&:amount_cents).first(2)
  end

  def historical_median_cents(user, description)
    return nil unless user

    token = description.to_s.downcase.scan(/[a-záéíóúñ]{4,}/).first
    return nil unless token

    amounts = user.expenses.expenses_only
      .where("lower(description) LIKE ?", "%#{sanitize_like(token)}%")
      .limit(40)
      .pluck(:amount_cents)
    return nil if amounts.size < 2

    sorted = amounts.sort
    sorted[sorted.size / 2]
  end

  def sanitize_like(token)
    token.to_s.gsub(/[%_\\]/, "")
  end
end
