# XiCON Poster Maker - RunPod Serverless

Creates magazine-style posters with typography overlay and transparent envelope packaging using Flux 2 Klein 9B. Two-stage I2I pipeline.

**GitHub**: https://github.com/bxone-git/XiCON-Poster-Maker-Serverless

---

## 빌드 및 배포 가이드

### Step 1: RunPod Hub 접속

1. https://www.runpod.io/console/serverless 접속
2. 로그인 (계정: wlsdml1114)

### Step 2: GitHub 연동 및 빌드

1. **"New Template"** 클릭
2. **"Build from GitHub"** 선택
3. GitHub 계정 연동 (bxone-git)
4. 저장소 선택: `bxone-git/XiCON-Poster-Maker-Serverless`
5. **"Build"** 클릭

### Step 3: 빌드 대기

- 빌드 시간: **약 15-20분** (모델 다운로드 포함)
- 빌드 로그에서 진행 상황 확인 가능
- 성공 시 "Build complete" 메시지 표시

### Step 4: 엔드포인트 생성

1. 빌드 완료 후 **"Deploy"** 클릭
2. GPU 선택: **ADA_24** 또는 **ADA_32_PRO**
3. Worker 설정:
   - Min Workers: 0 (비용 절감)
   - Max Workers: 1-3 (트래픽에 따라)
4. **"Create Endpoint"** 클릭

### Step 5: 테스트

```bash
curl -X POST "https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "image_url": "https://example.com/input.jpg",
      "prompt_stage1": "magazine cover with typography overlay",
      "prompt_stage2": "transparent envelope packaging"
    }
  }'
```

---

## 주요 특징

- **Two-stage I2I Pipeline**: Typography overlay → Envelope packaging
- **Flux 2 Klein 9B**: Efficient 9B parameter model with FP8 quantization
- **Flexible Output**: Get stage1, final, or both outputs
- **High Resolution**: Default 1024x1472 portrait format

---

## API 사용법

### 필수 파라미터

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_url` / `image_base64` / `image_path` | string | Input image (required) |

### 선택 파라미터

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt_stage1` | string | (magazine prompt) | Stage 1: Typography overlay |
| `prompt_stage2` | string | (envelope prompt) | Stage 2: Envelope packaging |
| `steps` | int | 20 | Denoising steps |
| `cfg` | float | 5.0 | CFG scale |
| `seed` | int | 0 | Random seed (0=random) |
| `width` | int | 1024 | Output width |
| `height` | int | 1472 | Output height |
| `output_stage` | string | "final" | "stage1", "final", or "both" |

### 최소 요청 예시

```json
{
  "input": {
    "image_url": "https://example.com/input.jpg"
  }
}
```

### 전체 파라미터 요청 예시

```json
{
  "input": {
    "image_url": "https://example.com/input.jpg",
    "prompt_stage1": "magazine cover, bold typography, minimalist design",
    "prompt_stage2": "transparent envelope, professional packaging",
    "steps": 20,
    "cfg": 5.0,
    "seed": 12345,
    "width": 1024,
    "height": 1472,
    "output_stage": "both"
  }
}
```

### 응답 형식

**output_stage="final" (default)**
```json
{
  "image": "<base64-encoded-image>"
}
```

**output_stage="stage1"**
```json
{
  "image": "<base64-encoded-image>"
}
```

**output_stage="both"**
```json
{
  "images": {
    "stage1": "<base64-encoded-image>",
    "final": "<base64-encoded-image>"
  }
}
```

---

## 기술 사양

| 항목 | 값 |
|------|-----|
| Base Image | `wlsdml1114/multitalk-base:1.7` |
| CUDA | 12.8 |
| GPU | ADA_24, ADA_32_PRO |
| Container Disk | 40GB |
| Default Resolution | 1024x1472 (Portrait) |
| Default Steps | 20 |
| Default CFG | 5.0 |

## 모델 목록 (Docker에 포함)

| Model | File | Size |
|-------|------|------|
| UNET | `flux-2-klein-base-9b-fp8.safetensors` | 9.57 GB |
| CLIP | `qwen_3_8b_fp8mixed.safetensors` | 8.66 GB |
| VAE | `flux2-vae.safetensors` | 336 MB |

---

## 워크플로우 노드 ID 매핑

### Stage 1 (Typography Overlay)

| Node ID | Class | Parameter | Description |
|---------|-------|-----------|-------------|
| 51 | LoadImage | `image` | Input image |
| 1 | INTConstant | `value` | Width (1024) |
| 2 | INTConstant | `value` | Height (1472) |
| 52 | ImageScale | `width`, `height` | Resize to target |
| 16 | FLUXTextEncodeClip | `text` | prompt_stage1 |
| 20 | INTConstant | `value` | seed |
| 7 | FLUXSamplerConfig | `steps`, `cfg` | Stage 1 sampling config |
| 8 | FLUXSamplerOptions | - | Stage 1 sampler |
| 10 | Img2ImgFlux2WithLatent | - | Stage 1 I2I |

### Stage 2 (Envelope Packaging)

| Node ID | Class | Parameter | Description |
|---------|-------|-----------|-------------|
| 24 | ImageScale | `width`, `height` | Resize stage1 output |
| 23 | FLUXTextEncodeClip | `text` | prompt_stage2 |
| 29 | INTConstant | `value` | seed |
| 17 | FLUXSamplerConfig | `steps`, `cfg` | Stage 2 sampling config |
| 18 | FLUXSamplerOptions | - | Stage 2 sampler |
| 19 | Img2ImgFlux2WithLatent | - | Stage 2 I2I (final) |

### Output Nodes

| Node ID | Class | Parameter | Description |
|---------|-------|-----------|-------------|
| 15 | SaveImage | - | Stage 1 output |
| 26 | SaveImage | - | Final output |

---

## 트러블슈팅

### 빌드 실패: 모델 다운로드 오류
- Hugging Face 토큰이 유효한지 확인
- 네트워크 연결 상태 확인

### 이미지 출력 없음
- `XiCON_Poster_Maker_api.json`에서 SaveImage 노드 확인
- `save_output: true` 설정 확인

### 메모리 부족 오류
- GPU 메모리가 충분한지 확인 (최소 24GB 권장)
- 해상도를 낮춰서 시도

### ComfyUI 시작 실패
- entrypoint.sh의 실행 권한 확인
- 로그에서 구체적인 오류 메시지 확인

---

## 로컬 개발

```bash
# Docker 빌드
cd XiCON-Poster-Maker-Serverless
docker build -t xicon-poster-maker:latest .

# 로컬 테스트
docker run --gpus all -p 8188:8188 xicon-poster-maker:latest
```

---

## GitHub 업데이트 방법

```bash
cd /path/to/XiCON-Poster-Maker-Serverless

# 변경사항 커밋
git add .
git commit -m "Update: description"

# bxone-git에 push
git push bxone main
```

RunPod Hub에서 자동으로 새 빌드가 트리거됩니다.

---

*XiCON Poster Maker - Powered by Flux 2 Klein 9B & ComfyUI*


[![Runpod](https://api.runpod.io/badge/bxone-git/XiCON-Poster-Maker-Serverless)](https://console.runpod.io/hub/bxone-git/XiCON-Poster-Maker-Serverless)
