# Deploy híbrido: Bot en Oracle + IA en la notebook

## Estado real de tu VM (`bot` / `165.1.121.75`)

Ya revisado por SSH. **No hace falta tocar Energía Pilates.**

### Caddy (`/etc/caddy/Caddyfile`)

| Público | Backend local | App |
|---------|---------------|-----|
| `energiapilates.com.ar` (+ www) :443/:80 | `127.0.0.1:3000` | **Pilates** (`pilates.service`) |
| `:3001` y `http://165.1.121.75` | `127.0.0.1:3013` | Cochera |
| `:3006` | `127.0.0.1:3014` | Trazabilidad rollos |
| `:3003` / `:3015` | `127.0.0.1:3016` | NovaClubes |

Pilates solo escucha en **localhost:3000** y Caddy le pone HTTPS en el dominio.  
Eso es lo correcto: **no abras 3000 a internet**.

### Bot de gastos (Telegram)

Ya existe y está corriendo:

- Servicio: `bot-telegram.service`
- Código: `/home/deploy/apps/bot` (repo `bidumcris/bot-rails`)
- Usuario: `deploy`
- **No usa Caddy ni puerto público** (Telegram polling saliente)

Por eso **no necesitás regla nueva en OCI** para el bot.  
Los puertos 80/443/3001/3003/3006 son de las otras apps.

> Nota: en OCI el label “Bot Rails (3001)” en realidad es **Cochera** según el Caddyfile actual.

---

## Arquitectura recomendada (opción 1)

```
Telegram ──► Oracle (bot-telegram.service)     ← ya está
                    │
                    │ SSH -R 11434 (desde notebook)
                    ▼
             Notebook Ollama (qwen2.5:3b + GPU)
```

- **Pilates / Caddy:** no se tocan.
- **Bot:** sigue en Oracle 24/7.
- **IA:** notebook + túnel cuando esté prendida.
- Sin IA: el bot categoriza con reglas.

---

## Qué hacer (sin romper Pilates)

### A) Actualizar el bot en Oracle (código nuevo: Ollama + `/septiembre`)

Desde tu notebook:

```bash
# 1) Subí cambios a GitHub (bidumcris/bot-rails) o rsync
ssh bot-deploy 'cd /home/deploy/apps/bot && git pull && bundle install'

# 2) Ajustar .env en la VM (como deploy)
#    LLM_PROVIDER=ollama
#    OLLAMA_HOST=http://127.0.0.1:11434
#    OLLAMA_MODEL=qwen2.5:3b
#    OLLAMA_TIMEOUT=90

ssh bot 'sudo systemctl restart bot-telegram && sudo systemctl status bot-telegram --no-pager | head -15'
```

### B) Túnel de IA (notebook → Oracle)

```bash
systemctl --user start ollama
cd /home/koma/dev/bot
./script/tunnel_ollama_to_oracle.sh
# usa Host "bot" → ubuntu@165.1.121.75
```

Si el usuario SSH del túnel debe ser `ubuntu` (Host `bot`), está bien: el puerto reenviado queda en `127.0.0.1:11434` de la VM y el bot (`deploy`) lo consume ahí.

### C) (Opcional) Dashboard web del bot

Solo si querés ver gastos en browser. Elegí un puerto libre, ej. **3007**:

1. OCI Security List: TCP **3007**
2. Caddy — **agregar al final**, sin tocar el bloque de pilates:

```caddy
# Bot gastos (dashboard) — TCP 3007
http://:3007 {
  encode gzip
  reverse_proxy 127.0.0.1:3020
}
```

3. Puma del bot en `127.0.0.1:3020` + systemd aparte.

**Para Telegram no hace falta.** Priorizá A + B.

---

## Checklist “no romper Pilates”

- [ ] No editar el bloque `energiapilates.com.ar` en Caddy
- [ ] No cambiar `pilates.service` ni el puerto 3000
- [ ] No abrir `:3000` en OCI
- [ ] Tras editar Caddy: `sudo caddy validate --config /etc/caddy/Caddyfile && sudo systemctl reload caddy`
- [ ] Probar `https://energiapilates.com.ar` después de cualquier cambio

---

## Comandos útiles en la VM

```bash
ssh bot

sudo systemctl status pilates bot-telegram caddy --no-pager
sudo journalctl -u bot-telegram -f
curl -s http://127.0.0.1:11434/api/tags   # solo con túnel activo

# Notas de voz (una vez):
# sudo ./script/install_whisper_oracle.sh
# deja /opt/whisper/whisper-cli + ggml-base.bin
```

---

## Resumen

| App | ¿La tocamos? |
|-----|----------------|
| Energía Pilates + Caddy dominio | **No** |
| Cochera / NovaClubes / Trazabilidad | **No** |
| `bot-telegram.service` | **Sí** — actualizar + Ollama vía túnel |
| Puerto OCI nuevo | **No** (salvo dashboard opcional 3007) |
