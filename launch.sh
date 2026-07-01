#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-webhie/Qwen3.6-27B-int4-AutoRound-Code}"
HOST="${VLLM_HOST:-0.0.0.0}"
PORT="${VLLM_PORT:-8000}"
GPU_MEM="${VLLM_GPU_MEM:-0.90}"
API_KEY="${VLLM_API_KEY:-}"

EXTRA_ARGS=()
if [[ -n "$API_KEY" ]]; then
    EXTRA_ARGS+=(--api-key "$API_KEY")
fi

echo "Launching vLLM: $MODEL on ${HOST}:${PORT}"
exec vllm serve "$MODEL" \
    --host "$HOST" \
    --port "$PORT" \
    --gpu-memory-utilization "$GPU_MEM" \
    "${EXTRA_ARGS[@]}" \
    "${@:2}"
