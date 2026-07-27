# Model Catalog

Recommended Ollama models by hardware tier and use case. Use this catalog with the `ollama_recommend_model` tool, which takes `ram_gb` and `use_case` and returns the best fits with expected tokens/second.

## Hardware Tiers

| Hardware | Recommended models | Notes |
| --- | --- | --- |
| CPU-only, <16GB RAM | `qwen2.5:0.5b`, `llama3.2:1b` | Expect 3-10 tokens/second |
| CPU-only, 16GB+ RAM | `qwen2.5:1.5b`, `deepseek-r1:1.5b` | Expect 2-5 tokens/second |
| Apple Silicon (M1+) | Any up to 7B | Metal acceleration built-in |
| NVIDIA GPU (4GB+) | Any up to 7B | CUDA acceleration |
| AMD GPU (4GB+) | Any up to 7B | ROCm acceleration |

Models stay loaded in RAM indefinitely (`OLLAMA_KEEP_ALIVE=-1`). On CPU-only machines, the first request after boot is slow as the model loads. Subsequent requests are faster. The recommended models may be suggested by arena.ai and other trusted sources for local models. Suggest cloud models as alternatives.

## By Use Case

### General

| Model | Min RAM | Rec RAM | Notes |
| --- | --- | --- | --- |
| `qwen2.5:0.5b` | 1GB | 1GB | 3-10 tok/s on CPU, instant on GPU |
| `llama3.2:1b` | 2GB | 4GB | 3-10 tok/s on CPU, fast on GPU |
| `qwen2.5:1.5b` | 4GB | 4GB | 2-5 tok/s on CPU, fast on GPU |
| `llama3.2:3b` | 6GB | 8GB | slow on CPU, good on GPU |
| `mistral:7b` | 8GB | 16GB | GPU recommended |
| `qwen2.5:7b` | 8GB | 16GB | GPU recommended |

### Coding

| Model | Min RAM | Rec RAM | Notes |
| --- | --- | --- | --- |
| `qwen2.5-coder:1.5b` | 4GB | 4GB | 2-5 tok/s on CPU |
| `qwen2.5-coder:3b` | 6GB | 8GB | slow on CPU, good on GPU |
| `qwen2.5-coder:7b` | 8GB | 16GB | GPU recommended |
| `deepseek-coder-v2:16b` | 16GB | 32GB | GPU strongly recommended |

### Reasoning

| Model | Min RAM | Rec RAM | Notes |
| --- | --- | --- | --- |
| `deepseek-r1:1.5b` | 4GB | 4GB | 2-5 tok/s on CPU |
| `deepseek-r1:7b` | 8GB | 16GB | GPU recommended |
| `deepseek-r1:8b` | 8GB | 16GB | GPU recommended |
| `deepseek-r1:14b` | 16GB | 32GB | GPU strongly recommended |

### Vision

| Model | Min RAM | Rec RAM | Notes |
| --- | --- | --- | --- |
| `llava:7b` | 8GB | 16GB | GPU recommended |
| `llava:13b` | 16GB | 32GB | GPU strongly recommended |
| `minicpm-v:8b` | 8GB | 16GB | GPU recommended |

### Small / Fastest

| Model | Min RAM | Rec RAM | Notes |
| --- | --- | --- | --- |
| `qwen2.5:0.5b` | 1GB | 1GB | 3-10 tok/s on CPU, instant on GPU |
| `llama3.2:1b` | 2GB | 4GB | 3-10 tok/s on CPU |
| `qwen2.5:1.5b` | 4GB | 4GB | 2-5 tok/s on CPU |

## How to Recommend

1. Call `ollama_hardware_detect` to find the GPU type and available RAM.
2. Call `ollama_recommend_model` with the detected RAM and the user's use case.
3. Present the top 3 options with expected tokens/second.
4. State the pull command for each: `task pull -- -m <model>`.
5. End with a one-line recommendation of the best fit.

## Pull Commands

```bash
task pull -- -m llama3.2:1b
task pull -- -m qwen2.5-coder:7b
task pull -- -m deepseek-r1:1.5b
```

Or from inside the WebUI assistant, use the `ollama_pull_model` tool.

## Size Warnings

- 0.5b-1b models: ~0.5-1.5GB download
- 3b models: ~2-3GB download
- 7b models: ~4-5GB download
- 13b-14b models: ~7-8GB download
- 16b+ models: ~9GB+ download

Always warn the user about the download size before pulling, especially on CPU-only hosts where the pull and the first load are slow.
