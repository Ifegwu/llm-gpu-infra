# MI300X vLLM Deployment

This repository deploys `Qwen/Qwen3.6-27B` on AMD Instinct MI300X using an Ansible-first workflow, with shell scripts as reusable execution backends.

## MI300X GPU Server Spec

### AMD Instinct MI300X (accelerator baseline)
- Architecture: AMD CDNA 3
- HBM memory: 192 GB HBM3
- Memory bandwidth: up to 5.3 TB/s
- Interconnect: Infinity Fabric links for multi-GPU scaling

### Current deployment target (DigitalOcean)
- Public IP: `********`
- GPU: AMD Instinct MI300X
- Inference runtime: ROCm + vLLM (`Qwen/Qwen3.6-27B`)

Update this section if instance size, GPU count, or host sizing (vCPU/RAM/disk) changes.

## Folder Structure

```text
.
├── ansible/
│   ├── ansible.cfg
│   ├── hosts.ini
│   ├── deploy-mi300x.yml
│   ├── group_vars/
│   │   └── mi300x.yml
│   └── roles/
│       └── mi300x_vllm/
│           └── tasks/
│               └── main.yml
├── script/
│   ├── PRD-mi300x-digitalocean-qwen3.6-27b.md
│   ├── RUNBOOK-mi300x-do.md
│   ├── install-host-prereqs.sh
│   ├── run-vllm-container.sh
│   ├── start-qwen36-27b.sh
│   ├── validate-endpoint.sh
│   ├── benchmark-qwen36-27b.sh
│   └── vllm-mi300x.service
├── mi300x.env
└── mi300x-vllm-serving.ipynb
```

## What Goes Where

- `ansible/`: Inventory, variables, and playbooks for remote deployment.
- `script/`: Script entrypoints used by Ansible and for manual fallback.
- `mi300x.env`: Root-level runtime config consumed by scripts.
- `mi300x-vllm-serving.ipynb`: Notebook reference for serving and benchmarking patterns.

## Deploy

From repository root:

```bash
cp mi300x.env.example mi300x.env
set -a && source mi300x.env && set +a
ansible-playbook -i ansible/hosts.ini ansible/deploy-mi300x.yml
```

## Common Overrides

```bash
ansible-playbook -i ansible/hosts.ini ansible/deploy-mi300x.yml \
  -e mi300x_tp_size=1 \
  -e mi300x_vllm_image='rocm/vllm-dev:nightly_main_20260211' \
  -e mi300x_hf_token='YOUR_TOKEN'
```

## Notes

- Deployment syncs this repo to `/opt/llm-gpu-infra` on the target host.
- Ansible rewrites remote `/opt/llm-gpu-infra/mi300x.env` from `ansible/group_vars/mi300x.yml`.
- Script execution is still supported directly for manual operations.

## GitHub Secrets

Add these repository secrets for CI/CD-based deployment:

- `MI300X_PUBLIC_IP`: public IP of the GPU host (required)
- `MI300X_SSH_USER`: SSH user, usually `root` (required)
- `MI300X_SSH_PRIVATE_KEY`: private key for SSH auth from GitHub Actions (required for remote deploy jobs)
- `MI300X_HF_TOKEN`: Hugging Face token for gated model pulls (optional)
- `MI300X_VLLM_IMAGE`: override image tag if you deploy from CI (optional)
- `MI300X_TP_SIZE`: tensor parallel size override for CI deployment (optional)

For local runs, these can be exported from `mi300x.env`.
