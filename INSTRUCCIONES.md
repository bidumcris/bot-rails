# Instructivo — Bot de gastos (Telegram + Ollama)

Creado por **BidumSystems**.

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

Menú del bot (español): `/inicio` `/ayuda` `/resumen` `/reporte` `/movimientos` `/dolar` `/perfil` `/trabajo` `/borrarultimo`

### Al empezar

`/inicio` pregunta **a qué te dedicás** (Empleado, Docente, Vendedor, Estudiante, Otro).  
Eso ayuda a clasificar cobros vs gastos. Se cambia con `/trabajo`.

### Registrar un gasto o ingreso

Escribí en lenguaje natural (pesos ARS o dólares):

| Ejemplo | Qué hace |
|---------|----------|
| `hamburguesa 8500` | **Gasto** Comida $8.500 (y el equivalente en USD oficial BNA) |
| `almohadillas 2500 por transferencia de mercadopago` | **Gasto** Comida $2.500 · Mercado Pago |
| `super 18000 en efectivo` | **Gasto** Comida $18.000 · Efectivo |
| `netflix 8 usd` | **Gasto** Suscripciones, convierte 8 USD → ARS con venta BNA |
| `hamburguesa 125000` | **Duda**: una hamburguesa a ~USD 80 no cierra; te pide confirmar o usar $12.500 |
| `cobro 84150 servicio pilates` | **Ingreso** Trabajo $84.150 |
| `transferencia 21mil de gime` | **Ingreso** Transferencias $21.000 |
| `2 menús 9000 cada uno` | **Gasto** Comida $18.000 |
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
cd /home/koma/dev/bot
bundle exec ruby bin/telegram_bot
```

---

## Deploy híbrido (Oracle + notebook)

Tu VM Oracle `VM.Standard.A1.Flex` (4 OCPU / 24 GB, IP `165.1.121.75`) corre el **bot**.  
La **IA** queda en esta notebook vía túnel SSH.

Guía completa: **[DEPLOY_ORACLE.md](./DEPLOY_ORACLE.md)**  
Plan de cobro (todavía no activo): **[MONETIZACION.md](./MONETIZACION.md)**

Resumen:

```bash
# En Oracle: Rails + bin/telegram_bot (siempre)
# En notebook (cuando quieras IA):
systemctl --user start ollama
./script/tunnel_ollama_to_oracle.sh
```

## Tips

- El monto se parsea de forma fija (`8500`, `23.000`, `23k`, `8 usd`). La IA (Ollama 3B) ayuda sobre todo a **categorizar**.
- Si decís cómo pagaste (`por transferencia de mercadopago`, `en efectivo`, `con débito`), se guarda el **medio de pago**. “Pagué por transferencia” es gasto; “transferencia de gime” sigue siendo ingreso.
- Las **notas de voz** se transcriben en la VM (Whisper `base`, español) y después se tratan como texto. Máx. 45 s.
- Los montos se muestran también en **USD oficial Banco Nación** (venta). Si un gasto conocido (comida, suscripciones, etc.) queda muy por encima de lo habitual, el bot **pregunta antes de guardar**.
- Zona horaria: `Buenos Aires` (los meses se cortan con esa zona).
- Para ver todo en tabla: abrí la web en `http://localhost:3000`.
- Si Ollama/túnel no están, el bot igual guarda gastos con reglas.
