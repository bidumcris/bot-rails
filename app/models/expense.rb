class Expense < ApplicationRecord
  belongs_to :user

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: false
  validates :currency, inclusion: { in: %w[ARS] }
  validates :raw_text, presence: true
  validates :spent_at, presence: true
  validates :category, presence: true

  before_validation :apply_defaults

  def amount_ars
    amount_cents.to_i / 100.0
  end

  private

  def apply_defaults
    self.currency = "ARS" if currency.blank?
    self.spent_at ||= Time.zone.now
  end
end
