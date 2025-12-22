## Bot de gastos (Telegram) + Rails 8

MVP: mandás un mensaje por Telegram tipo **"hamburguesa 8500"** y el bot lo guarda como `Expense` con categoría (por reglas o OpenAI si configurás API key). Si mandás sin monto, te pregunta y lo guarda como borrador (`DraftExpense`) hasta que respondas.

### Requisitos

- Ruby via `rbenv` (recomendado)
- Bundler

### Setup

```bash
cd /home/koma/dev/bot
rbenv local 3.2.2
bundle install
bin/rails db:prepare
```

### Variables de entorno

- **TELEGRAM_BOT_TOKEN**: token del bot
- **OPENAI_API_KEY** (opcional): para clasificar con LLM
- **OPENAI_MODEL** (opcional): default `gpt-4o-mini`
- **LLM_PROVIDER** (opcional): por ahora `openai` (default)
- **API_TOKEN** (opcional): si se setea, protege `/api/*` con header `X-Api-Token`
- **DASHBOARD_USER / DASHBOARD_PASS** (opcional): activa Basic Auth para la UI web

Tip: en desarrollo podés usar `.env` (por `dotenv-rails`). Usá `env.example` como plantilla.

### Correr el bot (polling)

```bash
cd /home/koma/dev/bot
TELEGRAM_BOT_TOKEN="xxx" bundle exec ruby bin/telegram_bot
```

Comandos en Telegram:
- `/start`
- `/help`
- `/phone` (opcional, para guardar teléfono si compartís contacto)

### Correr la web

```bash
cd /home/koma/dev/bot
bin/rails s
```

Abrí `http://localhost:3000` (lista últimos gastos).

### API (opcional)

- `GET /api/expenses?telegram_user_id=123`
- `POST /api/expenses?telegram_user_id=123`

Ejemplo:

```bash
curl -X POST "http://localhost:3000/api/expenses?telegram_user_id=123" \
  -H "Content-Type: application/json" \
  -H "X-Api-Token: $API_TOKEN" \
  -d '{"expense":{"amount_cents":850000,"currency":"ARS","description":"hamburguesa","category":"Comida","raw_text":"hamburguesa 8500"}}'
```

# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
