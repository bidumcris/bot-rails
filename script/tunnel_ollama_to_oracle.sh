#!/usr/bin/env bash
# Túnel: Ollama de la notebook → localhost:11434 en la VM Oracle
# Uso: ./script/tunnel_ollama_to_oracle.sh
set -euo pipefail

ORACLE_HOST="${ORACLE_HOST:-165.1.121.75}"
# Host SSH local: "bot" (ubuntu). Override: ORACLE_USER=ubuntu ORACLE_HOST=bot
ORACLE_USER="${ORACLE_USER:-ubuntu}"
SSH_TARGET="${SSH_TARGET:-bot}"
LOCAL_OLLAMA="${LOCAL_OLLAMA:-127.0.0.1:11434}"
REMOTE_PORT="${REMOTE_PORT:-11434}"

echo "Chequeando Ollama local en ${LOCAL_OLLAMA}..."
if ! curl -sf "http://${LOCAL_OLLAMA}/api/tags" >/dev/null; then
  echo "Ollama no responde. Arrancalo:"
  echo "  systemctl --user start ollama"
  exit 1
fi

echo "Abriendo túnel SSH (no toca Caddy ni Pilates)..."
echo "  destino: ${SSH_TARGET}  remote:${REMOTE_PORT} → local ${LOCAL_OLLAMA}"
echo "Dejá esta terminal abierta. Ctrl+C para cortar."
echo

exec ssh -N \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -R "${REMOTE_PORT}:${LOCAL_OLLAMA}" \
  "${SSH_TARGET}"
