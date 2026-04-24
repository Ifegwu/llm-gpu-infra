# MI300X DigitalOcean Runbook (Ansible First, No K8s)

This runbook deploys `Qwen/Qwen3.6-27B` with vLLM on AMD MI300X using Ansible.  
The shell scripts in `script/` remain the execution backend and can still be run manually.

## 1) Local prerequisites
On your laptop/WSL environment:

```bash
ansible --version
rsync --version
```

## 2) Review Ansible inventory and variables
Files:
- `ansible/hosts.ini`
- `ansible/group_vars/mi300x.yml`

Adjust as needed:
- host/user
- `mi300x_vllm_image`
- `mi300x_hf_token` (if required for model access)
- `mi300x_tp_size`

## 3) Run deployment playbook
From repo root:

```bash
cd /home/akwari/workspace/llm-gpu-infra
ansible-playbook -i ansible/hosts.ini ansible/deploy-mi300x.yml
```

What this does:
- syncs repo to `/opt/llm-gpu-infra` on the remote host
- writes repo-root `mi300x.env` from Ansible vars
- runs script-based install/start flow:
  - `install-host-prereqs.sh`
  - `run-vllm-container.sh`
  - `start-qwen36-27b.sh`
  - optional `validate-endpoint.sh`

## 4) Verify service
From laptop:

```bash
curl http://134.199.193.99:8000/v1/models
```

From remote host:

```bash
docker exec vllm-mi300x bash -lc "tail -n 120 /opt/llm/logs/vllm-serve.log"
```

## 5) Run benchmarks (script backend)
Over SSH on remote host:

```bash
cd /opt/llm-gpu-infra
script/benchmark-qwen36-27b.sh serve
script/benchmark-qwen36-27b.sh latency
script/benchmark-qwen36-27b.sh throughput
```

Outputs are in `/opt/llm/logs`.

## 6) Capture baseline report
After validation and benchmarks, generate a timestamped baseline report:

```bash
cd /opt/llm-gpu-infra
script/capture-baseline-report.sh
```

This writes `script/baseline-results-<timestamp>.md` with runtime config, validation summary, and references to the latest benchmark logs.

## 7) Manual fallback (without Ansible)
If needed, execute directly on remote:

```bash
cd /opt/llm-gpu-infra
script/install-host-prereqs.sh
script/run-vllm-container.sh
script/start-qwen36-27b.sh
script/validate-endpoint.sh
```

## 8) Troubleshooting
- model download failure: set `mi300x_hf_token` in `ansible/group_vars/mi300x.yml`
- OOM: reduce concurrency/output length or increase `mi300x_tp_size`
- endpoint unreachable: verify DigitalOcean firewall + host firewall on `8000`
