Rails.application.routes.draw do
  namespace :api do
    resources :expenses, only: %i[index create]
  end

  resources :expenses, only: %i[index]
  root "expenses#index"

  post "/webhooks/mercadopago", to: "webhooks/mercado_pago#create"
  get "/webhooks/mercadopago", to: "webhooks/mercado_pago#create"
  get "/pro/ok", to: "pro#ok"
  get "/pro/error", to: "pro#error"

  get "up" => "rails/health#show", as: :rails_health_check
end
