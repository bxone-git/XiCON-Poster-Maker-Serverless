# XiCON Poster Maker - Network Volume Version
# Models are loaded from /runpod-volume (Network Volume: XiCON)
# Tag: blendx/xicon-poster-maker:netvolume

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

# Install SageAttention (Fix for SM89 kernel issue on L40/Ada GPUs)
RUN pip install "sageattention>=2.0.0" --no-cache-dir

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    cd ComfyUI-KJNodes && \
    pip install -r requirements.txt

# Create model directories (will be symlinked to network volume at runtime)
RUN mkdir -p /ComfyUI/models/diffusion_models /ComfyUI/models/vae /ComfyUI/models/text_encoders

# NO MODEL DOWNLOADS - Models will be loaded from Network Volume

COPY . .

# Copy workflow JSON
RUN if [ -f /XiCON_Poster_Maker_I2I_api.json ]; then \
        echo "Workflow JSON found"; \
    fi

# Copy config.ini for ComfyUI-Manager
RUN mkdir -p /ComfyUI/user/default/ComfyUI-Manager
RUN if [ -f /config.ini ]; then \
        cp /config.ini /ComfyUI/user/default/ComfyUI-Manager/config.ini; \
    fi

RUN chmod +x /entrypoint.sh
RUN chmod +x /setup_netvolume.sh 2>/dev/null || true

CMD ["/entrypoint.sh"]
