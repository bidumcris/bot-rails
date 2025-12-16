class User < ApplicationRecord
  has_many :expenses, dependent: :destroy
  has_many :draft_expenses, dependent: :destroy

  validates :telegram_user_id, presence: true, uniqueness: true
  validates :phone_e164, uniqueness: true, allow_nil: true
  validates :currency, inclusion: { in: %w[ARS] }, allow_nil: true

  before_validation :apply_defaults
  before_validation :normalize_phone

  def self.normalize_phone(phone)
    p = phone.to_s.strip
    return nil if p.blank?
    p = "+#{p}" unless p.start_with?("+")
    p
  end

  def self.find_or_create_by_phone!(phone)
    normalized = normalize_phone(phone)
    raise ArgumentError, "phone vacío" if normalized.blank?

    find_by(phone_e164: normalized) ||
      find_by(telegram_user_id: "phone:#{normalized}") ||
      create!(telegram_user_id: "phone:#{normalized}", phone_e164: normalized)
  end

  private

  def apply_defaults
    self.currency = "ARS" if currency.blank?
    self.time_zone = "America/Argentina/Buenos_Aires" if time_zone.blank?
  end

  def normalize_phone
    return if phone_e164.blank?
    self.phone_e164 = self.class.normalize_phone(phone_e164)
  end
end
