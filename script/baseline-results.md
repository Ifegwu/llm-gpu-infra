# Baseline Results Template

## Run Metadata
- Date (UTC):
- Operator:
- Host public IP:
- Hostname:
- Git commit:

## Runtime Configuration
- Model ID:
- vLLM image:
- Tensor parallel size:
- Host port:
- AITER flags:
  - `VLLM_ROCM_USE_AITER=`
  - `VLLM_USE_AITER_UNIFIED_ATTENTION=`
  - `VLLM_ROCM_USE_AITER_MHA=`

## Functional Validation
- Endpoint tested:
- Status:
- Returned model:
- Sample output (first 200 chars):

## Benchmarks

### Serve
- Log file:
- Key metrics (TTFT/TPOT/ITL/E2EL):

### Latency
- Log file:
- Key metrics:

### Throughput
- Log file:
- Key metrics:

## Notes
- Any OOM/restarts:
- Known caveats:
- Next tuning action:
