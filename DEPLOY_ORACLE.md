# Deploy híbrido: bot en un VPS + IA en la notebook

El proceso de Telegram corre 24/7 en un VPS. Ollama queda en la notebook (GPU) y se expone al VPS **solo por un túnel SSH**. Si la notebook o el túnel están apagados, el bot sigue registrando con reglas.

```
Telegram ──► VPS (systemd + bin/telegram_bot)
                 │
                 │ SSH -R 11434 (desde la notebook)
                 ▼
          Notebook Ollama (qwen2.5:3b)
```

No abras Ollama a internet. En el VPS el bot habla con `http://127.0.0.1:11434`.

La IP, usuarios SSH y otras apps del servidor no van en este repo. Esas notas quedan en local (`DEPLOY_ORACLE.local.md`, gitignored).

---

## Actualizar el bot en el VPS

```bash
# 1) git push desde la notebook
# 2) en el VPS, como el usuario de deploy:
git pull --ff-only
# si hay migration: bin/rails db:migrate
sudo systemctl restart bot-telegram
```

`.env` en el VPS (no se commitea):

```
LLM_PROVIDER=ollama
OLLAMA_HOST=http://127.0.0.1:11434
OLLAMA_MODEL=qwen2.5:3b
OLLAMA_TIMEOUT=90
```

El bot usa **polling** de Telegram: no hace falta puerto HTTP público ni reverse proxy.

---

## Túnel de IA (notebook → VPS)

En `~/.ssh/config` tené un `Host` que apunte al VPS. El script usa `SSH_TARGET=bot` por defecto.

```bash
systemctl --user start ollama
./script/tunnel_ollama_to_oracle.sh
```

Dejá esa terminal abierta. Ctrl+C corta el túnel.

Chequeo en el VPS (con el túnel activo):

```bash
curl -s http://127.0.0.1:11434/api/tags
sudo journalctl -u bot-telegram -f
```

---

## Notas de voz (Whisper, una vez)

En el VPS:

```bash
sudo ./script/install_whisper_oracle.sh
```

Deja el binario y el modelo `ggml-base` en `/opt/whisper`. Variables opcionales en `.env`: `WHISPER_BIN`, `WHISPER_MODEL`, `WHISPER_LANGUAGE=es`.

---

## Dashboard web (opcional)

Telegram no lo necesita. Si lo levantás, que Puma escuche solo en localhost y no abras el puerto 3000 del VPS a internet.
