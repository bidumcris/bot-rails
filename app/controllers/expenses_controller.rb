class ExpensesController < ApplicationController
  before_action :dashboard_basic_auth!

  def index
    @expenses = Expense.includes(:user).order(spent_at: :desc).limit(200)
  end

  private

  def dashboard_basic_auth!
    user = ENV["DASHBOARD_USER"].to_s
    pass = ENV["DASHBOARD_PASS"].to_s
    return if user.blank? || pass.blank?

    authenticate_or_request_with_http_basic("Dashboard") do |u, p|
      ActiveSupport::SecurityUtils.secure_compare(u.to_s, user) &&
        ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass)
    end
  end
end
