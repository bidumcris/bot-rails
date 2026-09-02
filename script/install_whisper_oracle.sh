#!/usr/bin/env bash
# Instala ffmpeg + whisper.cpp (CPU) en la VM Oracle. No toca Pilates/Caddy.
set -euo pipefail

PREFIX="${WHISPER_PREFIX:-/opt/whisper}"
MODEL_NAME="${WHISPER_MODEL_NAME:-ggml-base.bin}"
REPO_URL="https://github.com/ggml-org/whisper.cpp.git"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_NAME}"

echo "Instalando dependencias (ffmpeg, cmake)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ffmpeg cmake make g++ git

echo "Preparando ${PREFIX}..."
sudo mkdir -p "${PREFIX}/models" "${PREFIX}/src"
sudo chown -R "$(id -u)":"$(id -g)" "${PREFIX}"

if [[ ! -d "${PREFIX}/src/whisper.cpp/.git" ]]; then
  rm -rf "${PREFIX}/src/whisper.cpp"
  git clone --depth 1 "${REPO_URL}" "${PREFIX}/src/whisper.cpp"
else
  git -C "${PREFIX}/src/whisper.cpp" pull --ff-only || true
fi

echo "Compilando whisper.cpp..."
cmake -S "${PREFIX}/src/whisper.cpp" -B "${PREFIX}/src/whisper.cpp/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "${PREFIX}/src/whisper.cpp/build" -j"$(nproc)" --config Release

BIN=""
for candidate in \
  "${PREFIX}/src/whisper.cpp/build/bin/whisper-cli" \
  "${PREFIX}/src/whisper.cpp/build/whisper-cli" \
  "${PREFIX}/src/whisper.cpp/build/bin/main"
do
  if [[ -x "${candidate}" ]]; then
    BIN="${candidate}"
    break
  fi
done

if [[ -z "${BIN}" ]]; then
  echo "No encontré el binario de whisper-cli" >&2
  find "${PREFIX}/src/whisper.cpp/build" -type f -executable | head
  exit 1
fi

cp -f "${BIN}" "${PREFIX}/whisper-cli"
chmod +x "${PREFIX}/whisper-cli"

MODEL_PATH="${PREFIX}/models/${MODEL_NAME}"
if [[ ! -s "${MODEL_PATH}" ]]; then
  echo "Descargando modelo ${MODEL_NAME}..."
  curl -L --fail -o "${MODEL_PATH}" "${MODEL_URL}"
fi

echo
echo "Listo."
"${PREFIX}/whisper-cli" --help 2>/dev/null | head -n 5 || true
ls -lh "${PREFIX}/whisper-cli" "${MODEL_PATH}"
echo "ffmpeg: $(command -v ffmpeg)"
