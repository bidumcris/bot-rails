class User < ApplicationRecord
  has_many :expenses, dependent: :destroy
  has_many :draft_expenses, dependent: :destroy

  OCCUPATIONS = [
    "Empleado",
    "Docente",
    "Vendedor",
    "Estudiante",
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
    return "Docente" if t.match?(/docente|profesor|profe|maestro|maestra|enseña/)
    return "Vendedor" if t.match?(/vendedor|venta|comercio|kiosco|kiosko|negocio|local/)
    return "Estudiante" if t.match?(/estudiante|estudio|alumno|facultad|universidad|secundario/)
    return "Empleado" if t.match?(/empleado|program|desarroll|sistemas|software|sueldo|dependencia|oficina|trabajo/)

    raw.truncate(80)
  end

  private

  def apply_defaults
    self.currency = "ARS" if currency.blank?
    self.time_zone = "America/Argentina/Buenos_Aires" if time_zone.blank?
  end
end
