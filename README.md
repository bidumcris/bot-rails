# Bot de gastos (Telegram + Ollama)

Mandás un mensaje por Telegram (`hamburguesa 8500`) y el bot lo guarda con categoría usando **Ollama local** (`qwen2.5:3b`). También podés pedir el resumen de un mes (`/septiembre`, `/resumen`).

## Instructivo completo

Ver **[INSTRUCCIONES.md](./INSTRUCCIONES.md)** — comandos, arranque, monitoreo GPU.

## Setup rápido

```bash
cd /home/koma/dev/bot
bundle install
bin/rails db:prepare
cp env.example .env   # completar TELEGRAM_BOT_TOKEN
systemctl --user start ollama
bundle exec ruby bin/telegram_bot
```

## Comandos principales (Telegram)

- Registrar: `hamburguesa 8500`, `pago luz 23000`
- Mes actual: `/resumen`
- Un mes: `/septiembre` · `/mes septiembre` · `/mes 9` · `/mes 2025-09`
- Últimos: `/ultimos`
- Ayuda: `/help`

## Web

```bash
bin/rails s
# http://localhost:3000
```
