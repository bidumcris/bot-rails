# frozen_string_literal: true

module ProPlan
  module_function

  def trial_days
    ENV.fetch("PRO_TRIAL_DAYS", "5").to_i
  end

  def paid_days
    ENV.fetch("PRO_PAID_DAYS", "30").to_i
  end

  def free_movements
    ENV.fetch("PRO_FREE_MOVEMENTS", "40").to_i
  end

  def price_ars
    ENV.fetch("PRO_PRICE_ARS", "2499").to_i
  end

  def price_label
    MoneyFormat.ars(price_ars * 100)
  end

  def whitelist_ids
    ENV.fetch("PRO_TELEGRAM_IDS", "").split(",").map { |s| s.to_s.strip }.reject(&:blank?)
  end

  def whitelisted?(telegram_user_id)
    whitelist_ids.include?(telegram_user_id.to_s)
  end
end
