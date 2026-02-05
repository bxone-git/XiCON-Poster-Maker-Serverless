#!/bin/bash
set -e

echo "=== XiCON Poster Maker Startup ==="

# ==========================================
# Network Volume Setup
# ==========================================
NETVOLUME="/runpod-volume"

if [ -d "$NETVOLUME" ] && [ -d "$NETVOLUME/models" ]; then
    echo "Network Volume found at $NETVOLUME"
    echo "Creating symlinks to ComfyUI models directory..."

    # Remove existing directories (if any)
    rm -rf /ComfyUI/models/diffusion_models
    rm -rf /ComfyUI/models/text_encoders
    rm -rf /ComfyUI/models/vae

    # Create parent directory if needed
    mkdir -p /ComfyUI/models

    # Create symlinks
    ln -sf $NETVOLUME/models/diffusion_models /ComfyUI/models/diffusion_models
    ln -sf $NETVOLUME/models/text_encoders /ComfyUI/models/text_encoders
    ln -sf $NETVOLUME/models/vae /ComfyUI/models/vae

    echo "Symlinks created successfully!"
else
    echo "WARNING: Network Volume not found at $NETVOLUME"
    echo "Using models from container (if available)"
fi

# ==========================================
# Model Verification
# ==========================================
echo ""
echo "Verifying models..."

# Verify Klein model
KLEIN_PATH="/ComfyUI/models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors"
if [ -f "$KLEIN_PATH" ] || [ -L "$KLEIN_PATH" ]; then
    echo "  Klein model: OK"
else
    echo "  ERROR: Klein model not found at $KLEIN_PATH"
    echo "  Run setup_netvolume.sh first to download models"
    exit 1
fi

# Verify Text Encoder model
TEXT_ENC_PATH="/ComfyUI/models/text_encoders/qwen_3_8b_fp8mixed.safetensors"
if [ -f "$TEXT_ENC_PATH" ] || [ -L "$TEXT_ENC_PATH" ]; then
    echo "  Text Encoder model: OK"
else
    echo "  ERROR: Text Encoder model not found at $TEXT_ENC_PATH"
    echo "  Run setup_netvolume.sh first to download models"
    exit 1
fi

# Verify VAE model
VAE_PATH="/ComfyUI/models/vae/flux2-vae.safetensors"
if [ -f "$VAE_PATH" ] || [ -L "$VAE_PATH" ]; then
    echo "  VAE model: OK"
else
    echo "  ERROR: VAE model not found at $VAE_PATH"
    echo "  Run setup_netvolume.sh first to download models"
    exit 1
fi

echo ""
echo "All models ready!"

# ==========================================
# Start ComfyUI
# ==========================================
echo ""
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

echo ""
echo "Starting the handler..."
exec python handler.py
