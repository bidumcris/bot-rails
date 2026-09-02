# Instructivo — Bot de gastos (Telegram + Ollama)

## Arranque rápido

```bash
# 1) Ollama (modelo local)
systemctl --user start ollama
ollama ps

# 2) Bot de Telegram
cd /home/koma/dev/bot
bundle exec ruby bin/telegram_bot
```

Variables en `.env` (ver `env.example`):

- `TELEGRAM_BOT_TOKEN`
- `LLM_PROVIDER=ollama`
- `OLLAMA_MODEL=qwen2.5:3b`

Panel web (opcional):

```bash
cd /home/koma/dev/bot
bin/rails s
# http://localhost:3000
```

---

## Comandos en Telegram

### Registrar un gasto o ingreso

Escribí en lenguaje natural (pesos ARS):

| Ejemplo | Qué hace |
|---------|----------|
| `hamburguesa 8500` | **Gasto** Comida $8500 |
| `cobro 84150 servicio pilates` | **Ingreso** Trabajo $84150 |
| `transferencia 21mil de gime` | **Ingreso** Transferencias $21000 |
| `2 menús 9000 cada uno` | **Gasto** Comida $18000 |
| `pago regalo maestro 10000` | **Gasto** Regalos $10000 |

### Ver el mes

| Comando | Resultado |
|---------|-----------|
| `/resumen` | Ingresos + gastos + **balance** del mes actual |
| `/septiembre` | Idem para septiembre |
| `/mes septiembre 2025` | Otro año |
| `/ultimos` | Últimos 10 movimientos (+ ingreso / − gasto) |


---

## Monitoreo de Ollama / GPU

```bash
# Modelo cargado
ollama ps

# VRAM / uso GPU en vivo
watch -n 0.5 nvidia-smi

# Requests del bot al modelo
journalctl --user -u ollama -f
```

---

## Reiniciar el bot

```bash
pkill -f 'bin/telegram_bot'
cd /home/koma/dev/bot
bundle exec ruby bin/telegram_bot
```

---

## Deploy híbrido (Oracle + notebook)

Tu VM Oracle `VM.Standard.A1.Flex` (4 OCPU / 24 GB, IP `165.1.121.75`) corre el **bot**.  
La **IA** queda en esta notebook vía túnel SSH.

Guía completa: **[DEPLOY_ORACLE.md](./DEPLOY_ORACLE.md)**

Resumen:

```bash
# En Oracle: Rails + bin/telegram_bot (siempre)
# En notebook (cuando quieras IA):
systemctl --user start ollama
./script/tunnel_ollama_to_oracle.sh
```

## Tips

- El monto se parsea de forma fija (`8500`, `23.000`, `23k`). La IA (Ollama 3B) ayuda sobre todo a **categorizar**.
- Zona horaria: `Buenos Aires` (los meses se cortan con esa zona).
- Para ver todo en tabla: abrí la web en `http://localhost:3000`.
- Si Ollama/túnel no están, el bot igual guarda gastos con reglas.
