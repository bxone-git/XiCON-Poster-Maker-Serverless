FROM wlsdml1114/multitalk-base:1.7 as runtime

RUN pip install -U "huggingface_hub[hf_transfer]"
RUN pip install runpod websocket-client

WORKDIR /

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd /ComfyUI && pip install -r requirements.txt

# Clone custom nodes
RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    cd ComfyUI-KJNodes && \
    pip install -r requirements.txt

# Create model directories
RUN mkdir -p /ComfyUI/models/diffusion_models /ComfyUI/models/vae /ComfyUI/models/clip

# Download UNET (9.57 GB) - VERIFIED URL, NO HF TOKEN REQUIRED
RUN wget -q "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/flux-2-klein-base-9b-fp8.safetensors" \
    -O /ComfyUI/models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors

# Download CLIP (8.66 GB) - VERIFIED URL, NO HF TOKEN REQUIRED
RUN wget -q "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
    -O /ComfyUI/models/clip/qwen_3_8b_fp8mixed.safetensors

# Download VAE (336 MB) - VERIFIED URL, NO HF TOKEN REQUIRED
RUN wget -q "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/vae/flux2-vae.safetensors" \
    -O /ComfyUI/models/vae/flux2-vae.safetensors

COPY . .

# Copy workflow JSON (assuming it will be named XiCON_Poster_Maker_I2I_api.json)
# Note: This file needs to be created in the project root
RUN if [ -f /XiCON_Poster_Maker_I2I_api.json ]; then \
        echo "Workflow JSON found and copied"; \
    else \
        echo "WARNING: XiCON_Poster_Maker_I2I_api.json not found - needs to be created"; \
    fi

# Copy config.ini for ComfyUI-Manager
RUN mkdir -p /ComfyUI/user/default/ComfyUI-Manager
RUN if [ -f /config.ini ]; then \
        cp /config.ini /ComfyUI/user/default/ComfyUI-Manager/config.ini; \
        echo "config.ini copied"; \
    else \
        echo "WARNING: config.ini not found - needs to be created"; \
    fi

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
