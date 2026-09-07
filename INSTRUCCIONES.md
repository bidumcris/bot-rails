# Instructivo — Bot de gastos (Telegram + Ollama)

Creado por **BidumSystems**.

## Arranque rápido

```bash
# 1) Ollama (modelo local)
systemctl --user start ollama
ollama ps

# 2) Bot de Telegram
bundle exec ruby bin/telegram_bot
```

Variables en `.env` (ver `env.example`):

- `TELEGRAM_BOT_TOKEN`
- `LLM_PROVIDER=ollama`
- `OLLAMA_MODEL=qwen2.5:3b`

Panel web (opcional):

```bash
bin/rails s
# http://localhost:3000
```

---

## Comandos en Telegram

Menú del bot (español): `/inicio` `/ayuda` `/resumen` `/reporte` `/movimientos` `/dolar` `/perfil` `/nombre` `/trabajo` `/pro` `/borrarultimo`

### Al empezar

`/inicio` pregunta **cómo te llamás** y **a qué te dedicás**. El bot te habla por tu nombre. El nombre se cambia con `/nombre`.

### Registrar un gasto o ingreso

Escribí en lenguaje natural (pesos ARS o dólares):

| Ejemplo | Qué hace |
|---------|----------|
| `hamburguesa 8500` | **Gasto** Comida $8.500 (y el equivalente en USD oficial BNA) |
| `super 18000 por transferencia de mercadopago` | **Gasto** Comida $18.000 · Mercado Pago |
| `super 18000 en efectivo` | **Gasto** Comida $18.000 · Efectivo |
| `netflix 8 usd` | **Gasto** Suscripciones, convierte 8 USD → ARS con venta BNA |
| `hamburguesa 125000` | **Duda**: una hamburguesa a ~USD 80 no cierra; te pide confirmar o usar $12.500 |
| `gasté 30 en el médico` | **Duda**: $30 es poco; te pregunta si eran **$30.000** (30 mil) |
| `cobro 25000` | **Ingreso** Trabajo $25.000 |
| `transferencia 21000` | **Ingreso** Transferencias $21.000 |
| `2 menús 9000 cada uno` | **Gasto** Comida $18.000 |
| `hamburguesa 8500 y coca 2000` | **Dos gastos** (también en una nota de voz) |
| `pago regalo maestro 10000` | **Gasto** Regalos $10.000 |

### Ver el mes

| Comando | Resultado |
|---------|-----------|
| `/resumen` | Ingresos + gastos + **balance** del mes actual |
| `/reporte` | **PDF** del mes (también `/reporte septiembre`) |
| `/septiembre` | Idem para septiembre |
| `/mes septiembre 2025` | Otro año |
| `/movimientos` | Últimos 10 movimientos (+ ingreso / − gasto) |
| `/dolar` | Compra/venta oficial Banco Nación |
| `/perfil` | Rubro y configuración |
| Foto de comprobante | Si hay Tesseract, lee el texto; si no, te pide el monto |
| Nota de voz | Transcribe en español (Whisper) y sigue el mismo flujo que el texto |


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
bundle exec ruby bin/telegram_bot
```

---

## Deploy híbrido (VPS + notebook)

El **bot** corre en un VPS. La **IA** queda en la notebook vía túnel SSH.

Guía: **[DEPLOY_ORACLE.md](./DEPLOY_ORACLE.md)**

```bash
# En el VPS: Rails + bin/telegram_bot (siempre)
# En la notebook (cuando quieras IA):
systemctl --user start ollama
./script/tunnel_ollama_to_oracle.sh
```

## Plan gratis y Pro

- **Gratis:** texto, foto, `/resumen`, `/dolar`. **15 movimientos por mes** (calendario, zona Buenos Aires).
- **Prueba:** `/pro` activa **5 días** de Pro, una sola vez.
- **Pro:** voz, PDF, IA, duda de montos, dólar en cada carga, sin tope. **$2.499 ARS / 30 días** por Mercado Pago (`/pro`).

Tu usuario puede ir siempre Pro con `PRO_TELEGRAM_IDS` en `.env`.

## Tips

- El monto se parsea de forma fija (`8500`, `23.000`, `23k`, `8 usd`). La IA (Ollama 3B) ayuda sobre todo a **categorizar**.
- Si decís cómo pagaste (`por transferencia de mercadopago`, `en efectivo`, `con débito`), se guarda el **medio de pago**. “Pagué por transferencia” es gasto; “transferencia 21000” sigue siendo ingreso.
- Las **notas de voz** se transcriben en la VM (Whisper `base`, español) y después se tratan como texto. Máx. 45 s.
- Los montos se muestran también en **USD oficial Banco Nación** (venta). Si un gasto conocido (comida, suscripciones, etc.) queda muy por encima de lo habitual, el bot **pregunta antes de guardar**.
- Zona horaria: `Buenos Aires` (los meses se cortan con esa zona).
- Para ver todo en tabla: abrí la web en `http://localhost:3000`.
- Si Ollama/túnel no están, el bot igual guarda gastos con reglas.
