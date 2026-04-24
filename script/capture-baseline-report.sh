#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${MI300X_ENV_FILE:-${SCRIPT_DIR}/../mi300x.env}"
# shellcheck disable=SC1090
source "${ENV_FILE}"

REPORT_DIR="${1:-${SCRIPT_DIR}}"
BASE_URL="${2:-http://127.0.0.1:${HOST_PORT}}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
REPORT_FILE="${REPORT_DIR}/baseline-results-${STAMP}.md"

mkdir -p "${REPORT_DIR}"

if ! docker ps --format '{{.Names}}' | rg -x "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Container ${CONTAINER_NAME} is not running."
  exit 1
fi

VALIDATION_JSON="$(curl -sS "${BASE_URL}/v1/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL_ID}\",
    \"prompt\": \"The future of AI is\",
    \"max_tokens\": 64,
    \"temperature\": 0
  }")"

RETURNED_MODEL="$(echo "${VALIDATION_JSON}" | jq -r '.model // "unknown"')"
SAMPLE_TEXT="$(echo "${VALIDATION_JSON}" | jq -r '.choices[0].text // ""' | tr '\n' ' ' | cut -c1-200)"
VALID_STATUS="pass"
if [[ "${RETURNED_MODEL}" != "${MODEL_ID}" || -z "${SAMPLE_TEXT}" ]]; then
  VALID_STATUS="fail"
fi

HOSTNAME_VAL="$(hostname)"
GIT_COMMIT="$(git -C "${SCRIPT_DIR}/.." rev-parse --short HEAD 2>/dev/null || echo "unknown")"
IMAGE_DIGEST="$(docker inspect --format '{{.Image}}' "${CONTAINER_NAME}" 2>/dev/null || echo "unknown")"

latest_log_file() {
  local pattern="$1"
  find /opt/llm/logs -maxdepth 1 -type f -name "${pattern}" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
}

LATEST_SERVE_LOG="$(latest_log_file 'bench-serve-*.log')"
LATEST_LATENCY_LOG="$(latest_log_file 'bench-latency-*.log')"
LATEST_THROUGHPUT_LOG="$(latest_log_file 'bench-throughput-*.log')"

cat >"${REPORT_FILE}" <<EOF
# Baseline Results (${STAMP} UTC)

## Run Metadata
- Date (UTC): ${STAMP}
- Operator: ${USER:-unknown}
- Host public IP: ${MI300X_PUBLIC_IP:-unknown}
- Hostname: ${HOSTNAME_VAL}
- Git commit: ${GIT_COMMIT}

## Runtime Configuration
- Model ID: ${MODEL_ID}
- vLLM image: ${VLLM_IMAGE}
- Container image digest/id: ${IMAGE_DIGEST}
- Tensor parallel size: ${TP_SIZE}
- Host port: ${HOST_PORT}
- AITER flags:
  - \`VLLM_ROCM_USE_AITER=${VLLM_ROCM_USE_AITER}\`
  - \`VLLM_USE_AITER_UNIFIED_ATTENTION=${VLLM_USE_AITER_UNIFIED_ATTENTION}\`
  - \`VLLM_ROCM_USE_AITER_MHA=${VLLM_ROCM_USE_AITER_MHA}\`

## Functional Validation
- Endpoint tested: ${BASE_URL}/v1/completions
- Status: ${VALID_STATUS}
- Returned model: ${RETURNED_MODEL}
- Sample output (first 200 chars): ${SAMPLE_TEXT}

## Benchmarks

### Serve
- Log file: ${LATEST_SERVE_LOG:-none}

### Latency
- Log file: ${LATEST_LATENCY_LOG:-none}

### Throughput
- Log file: ${LATEST_THROUGHPUT_LOG:-none}

## Notes
- If you ran benchmarks, copy TTFT/TPOT/ITL/E2EL and throughput numbers from the log files.
EOF

echo "Baseline report written to: ${REPORT_FILE}"
