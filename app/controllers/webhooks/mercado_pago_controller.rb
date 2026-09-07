# frozen_string_literal: true

class Webhooks::MercadoPagoController < ActionController::API
  def create
    MercadoPagoCheckout.sync_notification(params)
    head :ok
  end
end
