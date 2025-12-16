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

Tip: en desarrollo podés usar `.env` (por `dotenv-rails`).

### Correr el bot (polling)

```bash
cd /home/koma/dev/bot
TELEGRAM_BOT_TOKEN="xxx" bundle exec ruby bin/telegram_bot
```

Comandos en Telegram:
- `/start`
- `/help`
- `/phone` (opcional, para guardar teléfono si compartís contacto)

Nota sobre multiusuario:
- Por defecto se identifica por `telegram_user_id` (cada cuenta de Telegram).
- Si compartís `/phone`, se guarda `phone_e164` y se intenta mantener **un único usuario por teléfono** (si ya existía, se mergean gastos/borradores).

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

### WhatsApp (Meta Cloud API)

Este proyecto soporta WhatsApp via **Meta WhatsApp Cloud API** (webhook + respuesta). Endpoint:

- **GET** `/webhooks/meta/whatsapp` (verificación)
- **POST** `/webhooks/meta/whatsapp` (mensajes entrantes)

Variables de entorno:
- **META_WA_VERIFY_TOKEN**: token que configurás en Meta para validar el webhook
- **META_WA_ACCESS_TOKEN**: token (Bearer) para enviar mensajes por Graph API
- **META_WA_PHONE_NUMBER_ID**: el `phone_number_id` del número de WhatsApp en Cloud API
- **META_WA_API_VERSION** (opcional): default `v21.0`

Notas importantes:
- Meta permite **responder libremente** dentro de la **ventana de 24h** desde el último mensaje del usuario. Fuera de esa ventana, necesitás **templates** aprobados.
- Para probar local, necesitás exponer tu app (ej. con un túnel tipo ngrok) y registrar ese URL como webhook en Meta.

Flujo:
- El webhook recibe mensajes, resuelve al usuario por **teléfono** (`phone_e164`) y usa el mismo flujo de parsing/categorización que Telegram (`ExpenseIngestor`).

### Deploy en Fly.io + Postgres (recomendado)

Resumen: Fly te da HTTPS público (ideal para webhooks) y Postgres manejado.

Prerrequisitos:
- Tener `flyctl` instalado y estar logueado (`fly auth login`)
- Repositorio en GitHub (opcional, pero recomendado)

#### Opción A (recomendada): Fly **sin Docker** (buildpacks)

Nota: este repo incluye `Dockerfile`. Si querés **evitar Docker**, tenés 2 caminos:
- Renombrar temporalmente `Dockerfile` (ej. `Dockerfile.off`) antes de `fly launch`, o
- Forzar buildpacks en `fly.toml` con `[build] buildpacks = [...]` (ver abajo).

1) Crear la app (genera `fly.toml`):

```bash
cd /home/koma/dev/bot
fly launch --no-deploy
```

2) (Si existe `Dockerfile`) Forzar buildpacks editando `fly.toml` y agregando:

```toml
[build]
  builder = "paketobuildpacks/builder-jammy-base"
  buildpacks = ["gcr.io/paketo-buildpacks/ruby"]
```

3) Crear Postgres y adjuntarlo (esto setea `DATABASE_URL` automáticamente):

```bash
fly postgres create
fly postgres attach --app <TU_APP> <NOMBRE_DEL_CLUSTER>
```

4) Setear secrets mínimos:

```bash
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)"
fly secrets set DASHBOARD_USER="admin" DASHBOARD_PASS="cambia-esto"
fly secrets set META_WA_VERIFY_TOKEN="..." META_WA_ACCESS_TOKEN="..." META_WA_PHONE_NUMBER_ID="..."
```

5) Deploy:

```bash
fly deploy
```

#### Opción B: Fly con Docker (válida)

Si preferís Docker, mirá `fly.toml.example` (usa `Dockerfile`) y corré `fly deploy`.

Notas:
- En producción usamos Postgres vía `DATABASE_URL` (SQLite queda para dev/test).
- El deploy corre `bin/rails db:migrate` como `release_command`.
- Para ver logs: `fly logs`

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
