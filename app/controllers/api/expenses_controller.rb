module Api
  class ExpensesController < BaseController
    def index
      user = find_user!
      render json: user.expenses.order(spent_at: :desc).limit(100).as_json(only: %i[id amount_cents currency description category subcategory spent_at raw_text created_at])
    end

    def create
      user = find_user!

      expense = user.expenses.new(expense_params)
      expense.raw_text ||= expense.description.to_s
      expense.spent_at ||= Time.zone.now

      if expense.save
        render json: { ok: true, id: expense.id }, status: :created
      else
        render json: { ok: false, errors: expense.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def find_user!
      telegram_user_id = params[:telegram_user_id].presence || params.dig(:user, :telegram_user_id).presence
      phone_e164 = params[:phone_e164].presence || params.dig(:user, :phone_e164).presence

      user =
        if telegram_user_id.present?
          User.find_or_create_by!(telegram_user_id: telegram_user_id.to_s)
        elsif phone_e164.present?
          User.find_or_create_by_phone!(phone_e164)
        end

      raise ActionController::BadRequest, "telegram_user_id o phone_e164 requerido" if user.nil?
      user
    end

    def expense_params
      params.require(:expense).permit(
        :amount_cents, :currency, :description, :category, :subcategory, :spent_at,
        :raw_text, :llm_provider, :llm_model, :llm_confidence, metadata: {}
      )
    end
  end
end


