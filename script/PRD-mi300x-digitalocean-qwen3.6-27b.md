# PRD: Deploy Qwen/Qwen3.6-27B on AMD Instinct MI300X (DigitalOcean) with vLLM

## 1) Document Control
- Product: Managed/self-managed LLM inference endpoint on DigitalOcean GPU Droplet
- Model: `Qwen/Qwen3.6-27B` (replacing `openai/gpt-oss-120b`)
- GPU Target: AMD Instinct MI300X
- Inference Stack: ROCm + vLLM (AITER enabled)
- Primary Outcome: Production-ready OpenAI-compatible endpoint (`/v1/completions` and optionally `/v1/chat/completions`)

## 2) Context and Rationale

AMD Day-0 guidance emphasizes ROCm-optimized serving on Instinct GPUs using vLLM/SGLang, with ROCm-compatible Triton/AITER paths and OpenAI-compatible APIs. The existing notebook establishes the right serving and benchmark workflow pattern:
- launch vLLM with MI300X-oriented env flags
- validate with curl
- benchmark serve latency/throughput using `vllm bench`

This PRD adapts that workflow to DigitalOcean and to `Qwen/Qwen3.6-27B`.

## 3) Goals and Non-Goals

### Goals
- Provision MI300X-capable DigitalOcean environment
- Stand up `Qwen/Qwen3.6-27B` with vLLM and ROCm optimizations
- Expose reliable OpenAI-compatible API on port `8000`
- Produce repeatable benchmark and validation results
- Define production hardening (monitoring, restart, security, rollback)

### Non-Goals
- Multi-model routing gateway (out of scope v1)
- Fine-tuning/training pipeline
- Kubernetes orchestration (single-node first)

## 4) Success Metrics (Acceptance Targets)

### Functional
- Server responds to health and completion requests
- Model ID in responses is `Qwen/Qwen3.6-27B`

### Performance
- Stable serving under target concurrency tiers (8, 16, 32, optional 64/128)
- No repeated OOM or worker crashes in 24h soak

### Reliability
- Auto-restart on failure
- Logs/metrics retained and queryable

### Security
- API access limited to approved CIDRs and token/auth layer

### Operability
- One-command start/stop/redeploy runbook exists

## 5) User Stories
- As an ML engineer, I can deploy Qwen3.6-27B on MI300X and call it with OpenAI-compatible clients.
- As an SRE, I can restart/roll back quickly and inspect GPU/service logs.
- As a product engineer, I can benchmark TTFT/TPOT/ITL/E2EL before go-live.

## 6) Technical Requirements

### Infrastructure
- DigitalOcean GPU Droplet with AMD Instinct MI300X
- Ubuntu image compatible with Docker + ROCm container runtime prerequisites
- Attached volume for model cache/logs (recommended)

### Software
- Docker
- AMD ROCm-compatible vLLM image (nightly/stable tag validated for MI300X)
- Hugging Face access token (if model requires gated auth)
- vLLM CLI tools (`vllm serve`, `vllm bench`)

### Networking
- Port `8000` (private or public with strict ACL)
- SSH access for ops
- Optional reverse proxy + TLS termination

## 7) Proposed Architecture (Single Node)
- Client -> (Optional Nginx/API gateway) -> vLLM server (port 8000) -> MI300X GPU
- Persistent paths:
  - `/workspace/models` (HF cache)
  - `/workspace/logs` (server + benchmark output)

## 8) Step-by-Step Implementation Plan

### Phase A: Provision and Base Setup
1. Create DigitalOcean MI300X GPU instance.
2. Harden host:
   - update packages
   - configure firewall (`22`, `8000` restricted)
   - set timezone/NTP
3. Install Docker and verify daemon.
4. Validate GPU visibility prerequisites (ROCm container compatibility path).

Exit criteria: Host reachable, Docker running, GPU devices available to containers.

### Phase B: Launch ROCm vLLM Container
1. Pull ROCm vLLM image (use the currently validated AMD tag).
2. Run container with MI300X-required device flags:

```bash
docker run -it --rm \
  --device /dev/dri \
  --device /dev/kfd \
  --group-add video \
  --ipc host \
  --network host \
  --security-opt seccomp=unconfined \
  -v /opt/llm:/workspace \
  rocm/vllm-dev:<validated-tag> /bin/bash
```

3. (If needed) install latest transformers in-container:

```bash
pip install -U "git+https://github.com/huggingface/transformers.git"
```

Exit criteria: Container starts and can access GPU devices.

### Phase C: Serve `Qwen/Qwen3.6-27B` with vLLM (Adapted from notebook)
Use the notebook pattern, replacing model and keeping MI300X tuning flags:

```bash
export TP=1
export MODEL_ID="Qwen/Qwen3.6-27B"
export VLLM_ROCM_USE_AITER=1
export VLLM_USE_AITER_UNIFIED_ATTENTION=1
export VLLM_ROCM_USE_AITER_MHA=0

vllm serve $MODEL_ID \
  --port 8000 \
  --tensor-parallel-size $TP \
  --no-enable-prefix-caching \
  --disable-log-requests \
  --compilation-config '{"full_cuda_graph": true}'
```

For larger throughput targets, scale `TP` to GPU count allocated to this service.

Exit criteria: vLLM boot logs show successful startup and listening service.

### Phase D: Functional Validation
Run a completion request:

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3.6-27B",
    "prompt": "The future of AI is",
    "max_tokens": 100,
    "temperature": 0
  }'
```

Validate:
- HTTP 200
- non-empty `choices[0].text`
- `model` is `Qwen/Qwen3.6-27B`

### Phase E: Benchmarking Plan (Notebook-aligned)

#### E1. Online Serving Benchmark
```bash
vllm bench serve \
  --model Qwen/Qwen3.6-27B \
  --dataset-name random \
  --random-input-len 4096 \
  --random-output-len 1024 \
  --max-concurrency 8 \
  --num-prompts 80 \
  --ignore-eos \
  --percentile-metrics ttft,tpot,itl,e2el
```

Repeat for concurrency: `8, 16, 32` (optional `64, 128` if stable).

#### E2. Latency Benchmark (single request path)
First stop serve process:

```bash
pkill -9 -f vllm
```

Then:

```bash
vllm bench latency \
  --model Qwen/Qwen3.6-27B \
  --input-len 4096 \
  --output-len 1024 \
  --tensor-parallel-size 1
```

#### E3. Throughput Benchmark
```bash
vllm bench throughput \
  --model Qwen/Qwen3.6-27B \
  --dataset-name random \
  --input-len 4096 \
  --output-len 1024 \
  --num-prompts 4 \
  --tensor-parallel-size 1
```

Exit criteria: Baseline TTFT/TPOT/ITL/E2EL + tokens/sec captured in artifact file.

### Phase F: Production Hardening
1. Create systemd unit or supervisor for containerized vLLM.
2. Add health checks (`/v1/models` or lightweight completion probe).
3. Add log rotation and structured logs.
4. Protect endpoint:
   - private network preferred
   - API key gateway or reverse proxy auth
5. Set resource guardrails:
   - max request tokens
   - queue/backpressure policy
   - request timeout policy
6. Add monitoring:
   - GPU utilization/memory
   - process uptime/restarts
   - API latency percentiles and error rates

Exit criteria: Service survives restart/reboot and exposes operational telemetry.

### Phase G: Rollout and Handover
1. Smoke test from application environment.
2. Canary traffic (5% -> 25% -> 100%).
3. Freeze baseline config in runbook.
4. Handover docs:
   - start/stop commands
   - rollback steps
   - known limits and tuning knobs

## 9) Configuration Matrix (Initial Recommendations)
- Model: `Qwen/Qwen3.6-27B`
- TP size: start `1`; increase if multi-GPU serving needed
- Input/Output test lens: `4096/1024`
- Concurrency sweep: `8,16,32` then higher if stable
- AITER flags:
  - `VLLM_ROCM_USE_AITER=1`
  - `VLLM_USE_AITER_UNIFIED_ATTENTION=1`
  - `VLLM_ROCM_USE_AITER_MHA=0`

## 10) Risks and Mitigations
- Image/tag drift: nightly tag behavior changes
  - Mitigation: pin known-good image digest
- Model compatibility changes (`Qwen3.6` parser/tool options)
  - Mitigation: test with fixed vLLM + transformers versions
- OOM at high concurrency
  - Mitigation: cap `max_concurrency`, tune max tokens, TP strategy
- Public endpoint abuse
  - Mitigation: IP allowlist + auth + rate limit
- Operational restart gaps
  - Mitigation: systemd + health checks + alerting

## 11) Deliverables
- Deployment script(s) for container launch
- `systemd` service file (or compose stack)
- Benchmark report (serve/latency/throughput)
- Runbook (deploy, verify, rollback, troubleshoot)
- Final config snapshot (env vars + vLLM arguments)

## 12) Definition of Done
- `Qwen/Qwen3.6-27B` responds reliably via OpenAI-compatible API on DigitalOcean MI300X
- Benchmarks completed and recorded
- Security controls and restart automation in place
- Team can redeploy and recover using documented runbook
