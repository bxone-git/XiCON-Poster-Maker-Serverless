#!/bin/bash
# Klein 모델 다운로드 스크립트
# 실행 전 HuggingFace CLI 로그인 필요: huggingface-cli login

set -e

MODELS_DIR="./models/diffusion_models"
mkdir -p "$MODELS_DIR"

echo "Downloading Flux.2 Klein 9B FP8 model..."
echo "This requires HuggingFace authentication (gated model)"

# huggingface-cli를 사용하여 다운로드 (토큰 자동 사용)
huggingface-cli download \
    black-forest-labs/FLUX.2-klein-base-9b-fp8 \
    flux-2-klein-base-9b-fp8.safetensors \
    --local-dir "$MODELS_DIR" \
    --local-dir-use-symlinks False

echo "Download complete: $MODELS_DIR/flux-2-klein-base-9b-fp8.safetensors"
