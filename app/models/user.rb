class User < ApplicationRecord
  has_many :expenses, dependent: :destroy
  has_many :draft_expenses, dependent: :destroy

  OCCUPATIONS = [
    "Sistemas / desarrollo",
    "Pilates / servicios",
    "Comercio",
    "Empleado",
    "Otro"
  ].freeze

  validates :telegram_user_id, presence: true, uniqueness: true
  validates :currency, inclusion: { in: %w[ARS] }, allow_nil: true

  before_validation :apply_defaults

  def onboarded?
    occupation.present?
  end

  def needs_onboarding?
    !onboarded? || onboarding_step.present?
  end

  def self.normalize_occupation(text)
    raw = text.to_s.strip
    return if raw.blank?
    return raw if OCCUPATIONS.include?(raw)
    return if raw.start_with?("/")

    t = raw.downcase
    return "Sistemas / desarrollo" if t.match?(/program|desarroll|sistemas|software|dev|codigo|código|rails|web/)
    return "Pilates / servicios" if t.match?(/pilates|entren|profe|profesor|servicio/)
    return "Comercio" if t.match?(/comercio|kiosco|kiosko|local|venta|negocio/)
    return "Empleado" if t.match?(/empleado|relaci[oó]n\s+de\s+dependencia|sueldo/)

    raw.truncate(80)
  end

  private

  def apply_defaults
    self.currency = "ARS" if currency.blank?
    self.time_zone = "America/Argentina/Buenos_Aires" if time_zone.blank?
  end
end
