module Api
  class BaseController < ActionController::API
    before_action :authenticate!

    private

    def authenticate!
      expected = ENV["API_TOKEN"]
      return if expected.blank? # allow in dev if not set

      provided = request.headers["X-Api-Token"].to_s
      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
    end
  end
end


