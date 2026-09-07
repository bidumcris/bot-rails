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

  def pro?
    return true if ProPlan.whitelisted?(telegram_user_id)

    pro_until.present? && pro_until > Time.current
  end

  def trial_available?
    trial_used_at.blank? && !pro? && !ProPlan.whitelisted?(telegram_user_id)
  end

  def start_trial!
    return false unless trial_available?

    update!(
      trial_used_at: Time.current,
      pro_until: ProPlan.trial_days.days.from_now,
      pro_source: "trial"
    )
    true
  end

  def grant_pro!(source:, payment_id: nil, days: ProPlan.paid_days)
    base = [pro_until, Time.current].compact.max
    attrs = {
      pro_until: base + days.days,
      pro_source: source.to_s
    }
    attrs[:mp_payment_id] = payment_id.to_s if payment_id.present?
    update!(attrs)
  end

  def movements_this_month
    now = Time.zone.now
    expenses.where(spent_at: now.beginning_of_month..now.end_of_month).count
  end

  def free_movements_left
    return Float::INFINITY if pro?

    [ProPlan.free_movements - movements_this_month, 0].max
  end

  def can_add_movements?(count = 1)
    return true if pro?

    free_movements_left >= count.to_i
  end

  def plan_label
    return "Pro (tester)" if ProPlan.whitelisted?(telegram_user_id)
    return "Pro hasta #{pro_until.in_time_zone.strftime('%d/%m %H:%M')}" if pro?

    "Gratis (#{movements_this_month}/#{ProPlan.free_movements} este mes)"
  end

  private

  def apply_defaults
    self.currency = "ARS" if currency.blank?
    self.time_zone = "America/Argentina/Buenos_Aires" if time_zone.blank?
  end
end
