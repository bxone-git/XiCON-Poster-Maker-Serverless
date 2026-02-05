#!/bin/bash
set -e

echo "=== XiCON Poster Maker Startup ==="

# Verify Klein model exists (from base image via symlink)
KLEIN_PATH="/ComfyUI/models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors"
if [ ! -f "$KLEIN_PATH" ] && [ ! -L "$KLEIN_PATH" ]; then
    echo "ERROR: Klein model not found at $KLEIN_PATH"
    echo "Base image may be incorrect or symlink missing"
    exit 1
fi
echo "Klein model: OK (symlinked from base image)"

# Download CLIP model if not exists (PUBLIC URL, no auth needed)
CLIP_PATH="/ComfyUI/models/clip/qwen_3_8b_fp8mixed.safetensors"
if [ ! -f "$CLIP_PATH" ]; then
    echo "Downloading CLIP model (qwen_3_8b_fp8mixed.safetensors)..."
    wget -q --tries=3 --show-progress \
        "https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
        -O "$CLIP_PATH"
    echo "CLIP model downloaded successfully"
else
    echo "CLIP model already exists, skipping download"
fi

# Download VAE model if not exists (PUBLIC URL, no auth needed)
VAE_PATH="/ComfyUI/models/vae/flux2-vae.safetensors"
if [ ! -f "$VAE_PATH" ]; then
    echo "Downloading VAE model (flux2-vae.safetensors)..."
    wget -q --tries=3 --show-progress \
        "https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/vae/flux2-vae.safetensors" \
        -O "$VAE_PATH"
    echo "VAE model downloaded successfully"
else
    echo "VAE model already exists, skipping download"
fi

echo "All models ready!"

echo "Starting ComfyUI in the background..."
python /ComfyUI/main.py --listen --use-sage-attention &

echo "Waiting for ComfyUI to be ready..."
max_wait=120
wait_count=0
while [ $wait_count -lt $max_wait ]; do
    if curl -s http://127.0.0.1:8188/ > /dev/null 2>&1; then
        echo "ComfyUI is ready!"
        break
    fi
    echo "Waiting for ComfyUI... ($wait_count/$max_wait)"
    sleep 2
    wait_count=$((wait_count + 2))
done

if [ $wait_count -ge $max_wait ]; then
    echo "Error: ComfyUI failed to start within $max_wait seconds"
    exit 1
fi

echo "Starting the handler..."
exec python handler.py
