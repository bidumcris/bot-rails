class DraftExpense < ApplicationRecord
  belongs_to :user

  STATES = %w[awaiting_amount awaiting_confirmation].freeze

  validates :raw_text, presence: true
  validates :state, inclusion: { in: STATES }, allow_nil: true

  before_validation :apply_defaults

  private

  def apply_defaults
    self.state = "awaiting_amount" if state.blank?
    self.extracted ||= {}
  end
end
