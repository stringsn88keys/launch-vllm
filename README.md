# launch-vllm

Scripts for building and running [vLLM](https://github.com/vllm-project/vllm) on Windows
(GPU inference server, OpenAI-compatible API), plus a small CUDA runtime shim for driver/toolkit
mismatches.

- `vllm-windows/` — vLLM checkout with a Windows build script.
- `cuda-shim/bin/` — drop-in `cudart64_13.dll` shim (gitignored; build/copy it yourself, see below).
- `launch.ps1` / `launch.sh` — start the server.

## 1. Build vLLM

Requires: Visual Studio 2022 with "Desktop development with C++", CUDA Toolkit, an NVIDIA GPU/driver,
and [`uv`](https://docs.astral.sh/uv/). The build script checks for all of these and tells you what's missing.

```powershell
cd vllm-windows
.\build_windows.ps1                      # full build (compiles CUDA kernels), default
.\build_windows.ps1 -BuildMode editable  # editable install, kernels compiled once
.\build_windows.ps1 -MaxJobs 4           # limit parallel compile jobs (less RAM)
```

This creates `vllm-windows/.venv` with vLLM installed. First build takes a while (compiles CUDA kernels).

If `vllm._C` fails to load with a missing `cudart64_13.dll`, copy/build a matching shim into
`cuda-shim/bin/cudart64_13.dll` and make sure that folder is on `PATH` before launching (see `launch.ps1`
line adding `torch\lib` to `PATH` for the pattern — add `cuda-shim/bin` the same way if you need it).

## 2. Set your Hugging Face token

Models are pulled from the Hugging Face Hub on first run and cached locally (`~/.cache/huggingface`).
Gated/private models need a token. Not sure which model fits your GPU? Use llmfit to check a model
against your hardware before downloading it.

```bash
cp .env.example .env
# edit .env, set HF_TOKEN=hf_...
```

- `launch.ps1` loads `.env` automatically.
- `launch.sh` does not — export it yourself first: `set -a; source .env; set +a`.

To pre-download a model instead of waiting on first request:

```bash
vllm-windows/.venv/Scripts/huggingface-cli download <org/model>
```

## 3. Launch the server

PowerShell (Windows):

```powershell
.\launch.ps1                                              # default model, 0.0.0.0:8000
.\launch.ps1 -Model "org/some-model" -Port 8001 -ApiKey "secret"
.\launch.ps1 -GpuMemoryUtilization 80 -ExtraArgs "--max-model-len 8192"
```

Bash (Linux/WSL, if using a Linux build of vLLM instead of the Windows one):

```bash
./launch.sh "org/some-model"
VLLM_PORT=8001 VLLM_API_KEY=secret ./launch.sh
```

Both scripts start a standard OpenAI-compatible vLLM server. Once running, check it's up:

```bash
curl http://localhost:8000/v1/models
```

## 4. Connect from agents / clients

Point any OpenAI-compatible client at `http://<host>:<port>/v1`. If you launched with `-ApiKey`/`VLLM_API_KEY`,
pass it as the bearer token; otherwise any placeholder string works.

**curl**

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer secret" \
  -d '{"model": "org/some-model", "messages": [{"role": "user", "content": "hi"}]}'
```

**OpenAI Python SDK**

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8000/v1", api_key="secret")
resp = client.chat.completions.create(
    model="org/some-model",
    messages=[{"role": "user", "content": "hi"}],
)
```

**Claude Agent SDK / other agent frameworks** — most support a custom OpenAI-compatible base URL;
set it to `http://<host>:8000/v1` and supply the same API key.

**GitHub Copilot / VS Code** — Command Palette → `Chat: Manage Language Models` → `OpenAI Compatible`
→ paste base URL (`http://localhost:8000/v1`), API key, and model ID → `Add Model`. Shows up in the
Copilot Chat model picker. (VS Code Insiders as of writing.)

**OpenAI Codex CLI** — add a custom provider in `~/.codex/config.toml`:

```toml
model = "org/some-model"
model_provider = "vllm"

[model_providers.vllm]
name = "local vLLM"
base_url = "http://localhost:8000/v1"
wire_api = "chat"       # vLLM speaks Chat Completions, not the Responses API
env_key = "VLLM_API_KEY"
```

```bash
export VLLM_API_KEY=secret   # any value works if you didn't launch with -ApiKey
```

**Aider**

```bash
export OPENAI_API_BASE=http://localhost:8000/v1
export OPENAI_API_KEY=secret
aider --model openai/org/some-model   # openai/ prefix required
```

**opencode** — add a custom provider to `opencode.json`:

```json
{
  "provider": {
    "vllm": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "local vLLM",
      "options": { "baseURL": "http://localhost:8000/v1" },
      "models": { "org/some-model": {} }
    }
  }
}
```

**Claude Code / Claude Desktop** — Claude Code always runs on Claude itself (Anthropic API / Bedrock /
Vertex / Claude Platform on AWS); there's no setting to swap its backend for an OpenAI-compatible
endpoint. To let Claude call your local model as a *tool* instead, bridge it through MCP
([`@felores/multichat-mcp-server`](https://github.com/felores/multichat-mcp-server)) in `.mcp.json`:

```json
{
  "mcpServers": {
    "local-vllm": {
      "command": "npx",
      "args": ["-y", "@felores/multichat-mcp-server"],
      "env": {
        "AI_CHAT_NAME": "Local vLLM",
        "AI_CHAT_BASE_URL": "http://localhost:8000/v1",
        "AI_CHAT_KEY": "secret",
        "AI_CHAT_MODEL": "org/some-model"
      }
    }
  }
}
```
