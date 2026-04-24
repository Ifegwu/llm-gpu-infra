#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

echo "[1/4] Updating packages..."
apt-get update -y

echo "[2/4] Installing base packages..."
apt-get install -y ca-certificates curl gnupg lsb-release jq

if ! command -v docker >/dev/null 2>&1; then
  echo "[3/4] Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  # shellcheck disable=SC1091
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "[3/4] Docker already installed, skipping."
fi

echo "[4/4] Preparing directories..."
mkdir -p /opt/llm/hf-cache /opt/llm/logs
chmod -R 755 /opt/llm

echo "Done. Next: run script/run-vllm-container.sh on the host."
