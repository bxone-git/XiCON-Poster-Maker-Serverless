FROM blendx/xicon-poster-maker-base:klein-9b-fp8 as runtime

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

# Install SageAttention (Fix for SM89 kernel issue on L40/Ada GPUs)
RUN pip install "sageattention>=2.0.0" --no-cache-dir

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    cd ComfyUI-KJNodes && \
    pip install -r requirements.txt

# Create model directories
RUN mkdir -p /ComfyUI/models/diffusion_models /ComfyUI/models/vae /ComfyUI/models/clip

# Symlink Klein model from base image
RUN ln -sf /models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors \
    /ComfyUI/models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors

# CLIP and VAE are downloaded at runtime (public URLs, no auth needed)
# See entrypoint.sh for download logic

COPY . .

# Copy workflow JSON
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
