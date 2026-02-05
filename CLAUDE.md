# CLAUDE.md

RunPod Serverless 패키지 개발 가이드

## 프로젝트 개요

XiCON Poster Maker - Flux 2 Klein 9B 기반 2단계 I2I 파이프라인
- Stage 1: 매거진 커버 + 타이포그래피 오버레이
- Stage 2: 투명 봉투 패키징

## 필수 파일 구조

```
├── .runpod/
│   ├── hub.json      # RunPod Hub 설정 (필수)
│   └── tests.json    # 테스트 설정 (Hub 배포 시 필수)
├── Dockerfile        # 컨테이너 빌드
├── entrypoint.sh     # 시작 스크립트
├── handler.py        # RunPod 핸들러
├── *.json            # ComfyUI 워크플로우
└── README.md         # 문서
```

---

## 중요 지침 (꼭 유념할 것)

### 1. hub.json과 tests.json 설정 일치

**반드시 두 파일의 설정이 일치해야 함:**

```json
// hub.json
"gpuIds": "ADA_24,ADA_32_PRO",
"allowedCudaVersions": ["12.8"]

// tests.json - 반드시 일치!
"gpuTypeId": "ADA_24",
"allowedCudaVersions": ["12.8"]
```

❌ **불일치 시**: 테스트가 무한 대기 상태로 빠짐 (로그 없음)

### 2. CUDA 버전 호환성

| 배포 방식 | CUDA 12.8 | CUDA 12.7 | 비고 |
|-----------|-----------|-----------|------|
| RunPod Hub | ❌ 드라이버 미지원 | ✅ | Hub 사용 시 12.7 필수 |
| RunPod Serverless 직접 | ✅ | ✅ | RTX 5090은 12.8 필수 |

### 3. GPU 아키텍처별 요구사항

| GPU | 아키텍처 | 최소 CUDA |
|-----|----------|-----------|
| RTX 4090 | Ada Lovelace | 12.0+ |
| RTX 5090 | Blackwell | **12.8+** |

**RTX 5090 사용 시**: RunPod Hub 불가 → Serverless 직접 배포 필요

### 4. tests.json 필수 (Hub 배포)

RunPod Hub는 `tests.json`이 **mandatory**:
- 빈 배열 `"tests": []`도 가능하지만 권장하지 않음
- timeout 충분히 설정 (모델 로딩 시간 고려: 600000ms+)

### 5. GitHub Webhook 미감지 시

Push가 감지 안 될 경우 빈 커밋으로 트리거:
```bash
git commit --allow-empty -m "Trigger rebuild" && git push
```

### 6. Network Volume 방식 (현재 사용)

**모델은 Network Volume "XiCON"에서 로드:**

```
/runpod-volume/
├── models/
│   ├── diffusion_models/
│   │   └── flux-2-klein-base-9b-fp8.safetensors  (~9GB, Gated)
│   ├── text_encoders/                            # ⚠️ clip/ 아님!
│   │   └── qwen_3_8b_fp8mixed.safetensors        (~8GB)
│   └── vae/
│       └── flux2-vae.safetensors                 (~300MB)
```

**⚠️ 중요: ComfyUI CLIPLoader는 `text_encoders/` 디렉토리를 사용 (clip/ 아님)**

**최초 모델 설정 (Network Volume에서 1회 실행):**
```bash
./setup_netvolume.sh
```

**빌드 명령어:**
```bash
docker build --platform linux/amd64 -t blendx/xicon-poster-maker:netvolume .
docker push blendx/xicon-poster-maker:netvolume
```

### 7. handler.py 필수 구조

```python
import runpod  # 필수

def handler(job):
    job_input = job.get("input", {})
    # 처리 로직
    return {"image": base64_result}  # 또는 {"error": "..."}

runpod.serverless.start({"handler": handler})  # 필수
```

### 8. 노드 ID 매핑 검증

handler.py에서 주입하는 노드 ID가 워크플로우 JSON과 일치하는지 반드시 확인:
```python
# handler.py
prompt["2"]["inputs"]["image"] = image_path  # LoadImage

# workflow.json에서 노드 "2"가 LoadImage인지 확인!
```

---

## 배포 방식 비교

| 항목 | RunPod Hub | Serverless 직접 |
|------|------------|-----------------|
| GitHub 연동 | 자동 빌드 | 수동 Docker 빌드 |
| CUDA 12.8 | ❌ | ✅ |
| RTX 5090 | ❌ | ✅ |
| tests.json | 필수 | 불필요 |
| 빌드 시간 | Hub에서 처리 | 로컬/CI에서 처리 |

---

## 빌드 & 배포 명령어

### 방법 1: RunPod Hub 자동 배포 (권장)

**사전 조건**: Base 이미지가 Docker Hub에 존재해야 함

```bash
# Git push만으로 Hub에서 자동 빌드/배포
git add .
git commit -m "Update for Hub deployment"
git push origin main
```

### 방법 2: Base 이미지 빌드 (최초 1회 또는 Klein 모델 업데이트 시)

```bash
# 1. Klein 모델 다운로드 (HuggingFace 인증 필요)
huggingface-cli login
./download_models.sh

# 2. Base 이미지 빌드
docker build --platform linux/amd64 -f Dockerfile.base -t blendx/xicon-poster-maker-base:klein-9b-fp8 .

# 3. Docker Hub에 Push
docker push blendx/xicon-poster-maker-base:klein-9b-fp8
```

### 방법 3: 직접 Docker 배포 (Hub 대신)

```bash
docker build --platform linux/amd64 -t blendx/xicon-poster-maker:latest .
docker push blendx/xicon-poster-maker:latest
# RunPod Serverless에서 직접 이미지 지정
```

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| 테스트 무한 대기 | hub.json/tests.json 불일치 | 설정 동기화 |
| CUDA 오류 | 드라이버 미지원 | CUDA 버전 다운그레이드 |
| 빌드 미트리거 | Webhook 미감지 | 빈 커밋 push |
| 403 Forbidden (모델) | HF 라이선스 미동의 | `huggingface-cli login` 후 모델 페이지에서 "Agree and access" 클릭 |
| 모델 다운로드 실패 | 로컬 다운로드 누락 | `./download_models.sh` 실행 후 재빌드 |

자세한 빌드 가이드: [README_BUILD.md](./README_BUILD.md)
