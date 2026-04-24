#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${MI300X_ENV_FILE:-${SCRIPT_DIR}/../mi300x.env}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

mkdir -p "${WORKDIR_HOST}/hf-cache" "${WORKDIR_HOST}/logs"

if docker ps -a --format '{{.Names}}' | rg -x "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Container ${CONTAINER_NAME} exists. Removing it for clean start..."
  docker rm -f "${CONTAINER_NAME}"
fi

echo "Pulling ${VLLM_IMAGE}..."
docker pull "${VLLM_IMAGE}"

echo "Starting ${CONTAINER_NAME}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  --device /dev/dri \
  --device /dev/kfd \
  --group-add video \
  --ipc host \
  --network host \
  --security-opt seccomp=unconfined \
  -e HF_HOME="${HF_HOME}" \
  -e HUGGING_FACE_HUB_TOKEN="${HUGGING_FACE_HUB_TOKEN}" \
  -v "${WORKDIR_HOST}:${WORKDIR_CONTAINER}" \
  "${VLLM_IMAGE}" \
  bash -lc "sleep infinity"

echo "Container is up. Next: run script/start-qwen36-27b.sh"
