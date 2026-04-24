#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${MI300X_ENV_FILE:-${SCRIPT_DIR}/../mi300x.env}"
source "${ENV_FILE}"

LOG_FILE="${WORKDIR_HOST}/logs/vllm-serve.log"

if ! docker ps --format '{{.Names}}' | rg -x "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Container ${CONTAINER_NAME} is not running. Start it first with run-vllm-container.sh."
  exit 1
fi

echo "Ensuring transformers is available in container..."
docker exec "${CONTAINER_NAME}" bash -lc "python3 -m pip install -U pip setuptools wheel && python3 -m pip install -U 'git+https://github.com/huggingface/transformers.git'"

echo "Starting vLLM server for ${MODEL_ID}..."
docker exec -d "${CONTAINER_NAME}" bash -lc "
pkill -f 'vllm serve' || true
export MODEL_ID='${MODEL_ID}'
export VLLM_ROCM_USE_AITER='${VLLM_ROCM_USE_AITER}'
export VLLM_USE_AITER_UNIFIED_ATTENTION='${VLLM_USE_AITER_UNIFIED_ATTENTION}'
export VLLM_ROCM_USE_AITER_MHA='${VLLM_ROCM_USE_AITER_MHA}'
export HF_HOME='${HF_HOME}'
vllm serve \"\${MODEL_ID}\" \
  --port '${HOST_PORT}' \
  --tensor-parallel-size '${TP_SIZE}' \
  --no-enable-prefix-caching \
  --disable-log-requests \
  --compilation-config '{\"full_cuda_graph\": true}' \
  > '${LOG_FILE}' 2>&1
"

echo "vLLM launch requested. Tail logs with:"
echo "docker exec ${CONTAINER_NAME} bash -lc 'tail -n 100 ${LOG_FILE}'"
