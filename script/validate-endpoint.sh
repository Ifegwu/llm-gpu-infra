#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${MI300X_ENV_FILE:-${SCRIPT_DIR}/../mi300x.env}"
source "${ENV_FILE}"

BASE_URL="${1:-http://127.0.0.1:${HOST_PORT}}"

echo "Validating ${BASE_URL}/v1/completions with model ${MODEL_ID}..."
RESP="$(curl -sS "${BASE_URL}/v1/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL_ID}\",
    \"prompt\": \"The future of AI is\",
    \"max_tokens\": 64,
    \"temperature\": 0
  }")"

echo "${RESP}" | jq .

MODEL_RET="$(echo "${RESP}" | jq -r '.model // empty')"
TEXT_RET="$(echo "${RESP}" | jq -r '.choices[0].text // empty')"

if [[ "${MODEL_RET}" != "${MODEL_ID}" ]]; then
  echo "Validation failed: returned model '${MODEL_RET}' != '${MODEL_ID}'"
  exit 1
fi

if [[ -z "${TEXT_RET}" ]]; then
  echo "Validation failed: empty completion text"
  exit 1
fi

echo "Validation passed."
