# Instructivo — Monetizar el bot de gastos

Plan: **freemium**. 5 días de prueba Pro, después **Mercado Pago** ($2.499 ARS / 30 días).  
El plan gratis sigue pudiendo anotar gastos por texto, con un tope mensual.

---

## 1. Qué es gratis y qué es Pro

| | Gratis | Pro (trial o pago) |
|---|---|---|
| Texto (`hamburguesa 8500`) | Sí | Sí |
| Foto de comprobante | Sí | Sí |
| `/resumen` `/septiembre` `/dolar` | Sí | Sí |
| `/movimientos` | Últimos 10 | Últimos 10 |
| Tope de movimientos por mes | **40** | Sin tope |
| Nota de voz | No → `/pro` | Sí |
| `/reporte` PDF | No → `/pro` | Sí |
| IA (Ollama) | No; reglas | Sí |
| Dólar BNA en cada carga | No | Sí |
| Duda de montos raros | No | Sí |

**Dueños / testers:** `PRO_TELEGRAM_IDS` en `.env`. Pro sin pagar.

---

## 2. Precio y prueba

| | Valor |
|--|--|
| Trial | **5 días** Pro, una vez, con `/pro` |
| Pro | **$2.499 ARS** por **30 días** (Mercado Pago) |
| Gratis | 40 movimientos / mes calendario (zona Buenos Aires) |

No es una suscripción que MP debita sola (todavía). Cada mes el usuario entra a `/pro` y paga de nuevo. El bot suma 30 días a `pro_until`.

Cuando haya volumen, se puede pasar a **Suscripciones** de MP (débito automático). Ahora el flujo simple es más fácil de soportar.

---

## 3. Cómo se cobra

1. Usuario manda `/pro`
2. Primera vez → se activan 5 días Pro
3. Vencido → el bot manda un botón a Mercado Pago
4. Paga $2.499
5. Vuelve a Telegram y toca `/pro` otra vez (el bot busca el pago aprobado y activa 30 días)
6. Si hay URL pública (`PRO_PUBLIC_URL`), el webhook de MP puede activarlo sin ese segundo `/pro`

El checkout **no** vive adentro de Telegram: es un link HTTPS a MP. El bot no abre Ollama ni Caddy de Pilates.

---

## 4. Cómo se limita el mensual (gratis)

`user.expenses` del **mes calendario actual** (`Time.zone` = Buenos Aires).

- Si `count >= 40` y no es Pro → no guarda el 41. Mensaje: tocá `/pro`.
- El 1° de cada mes el contador vuelve a 0.
- Pro (`pro_until` futuro o lista blanca) no tiene tope.

No es “40 cada 30 días desde el alta”. Es **por mes de calendario**, más simple de explicar.

Pro pago: `pro_until = max(ahora, pro_until) + 30 días`. Si paga antes de vencer, se **acumula**.

---

## 5. Qué tenés que configurar vos

En Mercado Pago (cuenta de productor):

1. Creá una aplicación en [Tus integraciones](https://www.mercadopago.com.ar/developers/panel/app)
2. Copiá el **Access Token** de producción (`APP_USR-...`)
3. En el `.env` de Oracle (usuario `deploy`):

```
PRO_TRIAL_DAYS=5
PRO_PAID_DAYS=30
PRO_FREE_MOVEMENTS=40
PRO_PRICE_ARS=2499
PRO_TELEGRAM_IDS=tu_id   # lo ves en /perfil o en la tabla users
MP_ACCESS_TOKEN=APP_USR-...
# Opcional, cuando Rails tenga HTTPS público (otro bloque Caddy, no Pilates):
# PRO_PUBLIC_URL=https://tudominio
```

4. `rails db:migrate` y restart del bot

Sin `MP_ACCESS_TOKEN` igual funcionan trial y tope; `/pro` no puede cobrar.

---

## 6. Cómo se lo contamos

> Plan gratis: anotás gastos por texto (40 por mes).  
> Pro ($2.499 / 30 días): voz, PDF, IA.  
> 5 días de prueba con `/pro`.

---

## 7. Estado

| Ítem | Estado |
|------|--------|
| `pro?` / trial 5 días / tope 40 | Hecho |
| `/pro` + Mercado Pago (pago 30 días) | Hecho (falta tu token MP) |
| Webhook MP | Hecho (hace falta `PRO_PUBLIC_URL` + Puma/Caddy) |
| Telegram Stars | No (no hace falta para Argentina) |
| Débito automático MP | No (pago cada 30 días a mano) |
