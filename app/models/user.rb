class User < ApplicationRecord
  has_many :expenses, dependent: :destroy
  has_many :draft_expenses, dependent: :destroy

  validates :telegram_user_id, presence: true, uniqueness: true
  validates :currency, inclusion: { in: %w[ARS] }, allow_nil: true

  before_validation :apply_defaults

  private

  def apply_defaults
    self.currency = "ARS" if currency.blank?
    self.time_zone = "America/Argentina/Buenos_Aires" if time_zone.blank?
  end
end
