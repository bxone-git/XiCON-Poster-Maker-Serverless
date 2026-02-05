# XiCON Poster Maker - Build Guide

## Prerequisites

1. HuggingFace CLI 설치 및 로그인
   ```bash
   pip install huggingface_hub
   huggingface-cli login
   ```

2. [FLUX.2-klein-base-9b-fp8](https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8) 모델 라이선스 동의

## Recommended: Docker Hub + RunPod Serverless

RunPod Hub는 빌드 시크릿을 지원하지 않으므로, **Docker Hub 직접 배포**를 권장합니다.

### Step 1: Download Klein Model (Local)

Klein 모델은 Gated Model이므로 로컬에서 사전 다운로드 필요:

```bash
chmod +x download_models.sh
./download_models.sh
```

이 스크립트는 `models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors` (9.57GB)를 다운로드합니다.

### Step 2: Build Docker Image

```bash
docker build --platform linux/amd64 -t blendx/xicon-poster-maker:latest .
```

**Note**: Klein 모델이 이미지에 포함되므로 빌드에 시간이 걸릴 수 있습니다.

### Step 3: Push to Docker Hub

```bash
docker push blendx/xicon-poster-maker:latest
```

### Step 4: Deploy on RunPod Serverless

1. RunPod Serverless → New Endpoint
2. Container Image: `blendx/xicon-poster-maker:latest`
3. GPU: Ada 24GB 이상

## Model Information

| Model | Size | Source | Auth |
|-------|------|--------|------|
| Klein UNET | 9.57 GB | Docker Image (COPY) | N/A |
| CLIP (Qwen) | 8.66 GB | Runtime Download | Public |
| VAE | 336 MB | Runtime Download | Public |

## Cold Start Time

- First run (CLIP/VAE download): ~3-5 minutes
- Subsequent runs (warm worker): ~30 seconds

## Alternative: Git LFS for Hub Auto-Build

If you want RunPod Hub auto-build:

1. Install Git LFS: `git lfs install`
2. Track models: `git lfs track "*.safetensors"`
3. Commit models/ directory
4. Push to GitHub → Hub auto-builds

**Note**: This incurs GitHub LFS storage costs for ~10GB file.
