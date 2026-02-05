# Building XiCON Poster Maker Serverless

This project uses the **Flux.2 Klein (9B)** model, which is a gated model hosted by Black Forest Labs on Hugging Face.

## ⚠️ Important: Authentication Required

To build this Docker image, you **MUST** provide a Hugging Face Access Token. The token must have:
1.  **Read access** to gated repositories.
2.  Been used to **accept the license agreement** on the [FLUX.2-klein-base-9b-fp8 model page](https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8).

## How to Build

Use the `--build-arg` flag to pass your token during the build process.

```bash
# Replace hf_... with your actual token
docker build --build-arg HF_TOKEN=hf_your_token_here -t xicon-poster-maker .
```

## Troubleshooting

### 403 Forbidden Error
If you see a `403 Forbidden` error during the `wget` step for `flux-2-klein-base-9b-fp8.safetensors`:
1.  Verify your token is valid.
2.  Go to [https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8](https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8) and ensure you have clicked **"Agree and access repository"**.

### 401 Unauthorized Error
This indicates the token is missing or invalid. Check that you included `--build-arg HF_TOKEN=...` in your command.
