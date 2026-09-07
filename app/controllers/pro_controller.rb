# frozen_string_literal: true

class ProController < ActionController::Base
  skip_forgery_protection

  def ok
    render html: page("Pago recibido", "Volvé a Telegram y tocá /pro para activar el mes.")
  end

  def error
    render html: page("No se completó el pago", "Reintentá desde Telegram con /pro.")
  end

  private

  def page(title, body)
    html = <<~HTML
      <!doctype html>
      <html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>#{title}</title></head>
      <body style="font-family:sans-serif;max-width:28rem;margin:3rem auto;padding:0 1rem;line-height:1.45">
        <h1>#{title}</h1>
        <p>#{body}</p>
      </body></html>
    HTML
    html.html_safe
  end
end
