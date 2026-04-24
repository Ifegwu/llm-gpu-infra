#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${MI300X_ENV_FILE:-${SCRIPT_DIR}/../mi300x.env}"
source "${ENV_FILE}"

MODE="${1:-serve}"
OUT_DIR="${WORKDIR_HOST}/logs"
mkdir -p "${OUT_DIR}"

if ! docker ps --format '{{.Names}}' | rg -x "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "Container ${CONTAINER_NAME} is not running."
  exit 1
fi

run_in_container() {
  docker exec "${CONTAINER_NAME}" bash -lc "$1"
}

timestamp="$(date +%Y%m%d-%H%M%S)"

case "${MODE}" in
  serve)
    echo "Running serving benchmark..."
    run_in_container "vllm bench serve \
      --model '${MODEL_ID}' \
      --dataset-name random \
      --random-input-len 4096 \
      --random-output-len 1024 \
      --max-concurrency 8 \
      --num-prompts 80 \
      --ignore-eos \
      --percentile-metrics ttft,tpot,itl,e2el \
      | tee '${OUT_DIR}/bench-serve-${timestamp}.log'"
    ;;
  latency)
    echo "Running latency benchmark..."
    run_in_container "pkill -f 'vllm serve' || true; \
      vllm bench latency \
      --model '${MODEL_ID}' \
      --input-len 4096 \
      --output-len 1024 \
      --tensor-parallel-size '${TP_SIZE}' \
      | tee '${OUT_DIR}/bench-latency-${timestamp}.log'"
    ;;
  throughput)
    echo "Running throughput benchmark..."
    run_in_container "pkill -f 'vllm serve' || true; \
      vllm bench throughput \
      --model '${MODEL_ID}' \
      --dataset-name random \
      --input-len 4096 \
      --output-len 1024 \
      --num-prompts 4 \
      --tensor-parallel-size '${TP_SIZE}' \
      | tee '${OUT_DIR}/bench-throughput-${timestamp}.log'"
    ;;
  *)
    echo "Usage: $0 {serve|latency|throughput}"
    exit 1
    ;;
esac

echo "Benchmark '${MODE}' completed."
