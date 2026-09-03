#!/usr/bin/env bash
# Túnel: Ollama de la notebook → localhost:11434 en el VPS
# Uso: ./script/tunnel_ollama_to_oracle.sh
# Destino: Host de ~/.ssh/config (default: bot). No hardcodear IP.
set -euo pipefail

SSH_TARGET="${SSH_TARGET:-bot}"
LOCAL_OLLAMA="${LOCAL_OLLAMA:-127.0.0.1:11434}"
REMOTE_PORT="${REMOTE_PORT:-11434}"

echo "Chequeando Ollama local en ${LOCAL_OLLAMA}..."
if ! curl -sf "http://${LOCAL_OLLAMA}/api/tags" >/dev/null; then
  echo "Ollama no responde. Arrancalo:"
  echo "  systemctl --user start ollama"
  exit 1
fi

echo "Abriendo túnel SSH (Ollama solo en localhost del VPS)..."
echo "  destino: ${SSH_TARGET}  remote:${REMOTE_PORT} → local ${LOCAL_OLLAMA}"
echo "Dejá esta terminal abierta. Ctrl+C para cortar."
echo

exec ssh -N \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -R "${REMOTE_PORT}:${LOCAL_OLLAMA}" \
  "${SSH_TARGET}"
