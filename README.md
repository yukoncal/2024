# 2024 Project Hub

> 🚀 **Quick Access**: [Open Local Dashboard](http://localhost:8080) (Ensure server is running first)
> 
> **To start the server**: Run `./start-dashboard.sh` or `start-dashboard.bat`

---

This repository contains two main projects:
1. **Ollama to Cursor / Hermes**: Scripts and docs to run local models (Qwen, Hermes 3, Llama) via Ollama.
2. **YouTube Video Production Pipeline**: A Mission Control hub for managing a three-channel video production pipeline.

---

# Change to Ollama

Use local Ollama instead of cloud models (Grok, OpenRouter, etc.).

## Hermes Desktop / Hermes Agent

Local Ollama is a **Custom Endpoint** (not the hosted `ollama-cloud` provider):

```bash
./scripts/hermes-use-ollama.sh
```

Windows (PowerShell):

```powershell
.\scripts\hermes-use-ollama.ps1
```

That writes `~/.hermes/config.yaml`:

| Setting | Value |
| --- | --- |
| `model.provider` | `custom` |
| `model.base_url` | `http://127.0.0.1:11434/v1` |
| `model.default` | `qwen2.5-coder:latest` |

Then restart Hermes Desktop and pick that model. Overrides:

```bash
OLLAMA_MODEL=hermes3:8b ./scripts/hermes-use-ollama.sh
OLLAMA_MODEL=llama3.1:8b PULL=0 ./scripts/hermes-use-ollama.sh
```

Do **not** set `provider: ollama` for a local daemon — that targets Ollama Cloud. Use `provider: custom` + the `/v1` base URL.

## Cursor Desktop

Cloud Agent tabs keep showing the hosted Cursor model (e.g. Grok). Wire Ollama in **Cursor Desktop**:

1. Start Ollama and expose it over public HTTPS (Cursor cannot call `localhost`):

```bash
./scripts/setup-qwen.sh          # optional: pull + Cursor-safe alias
./scripts/expose-for-cursor.sh   # prefer cloudflared over free ngrok
```

2. Open **Cursor Desktop** → **Settings** → **Models**
3. **OpenAI API Key:** `ollama` (any non-empty string)
4. **Override OpenAI Base URL:** `https://YOUR-TUNNEL-HOST/v1`
5. **Add custom model:** `qwen2.5-coder:latest` (or `qwen359b` / `hermes3:8b`)
6. In the chat model picker, turn **Auto** off and select that model
7. Send: `Reply with exactly: ollama-ok`

Do **not** append `/chat/completions` — Cursor adds that path itself.

| Setting | Value |
| --- | --- |
| OpenAI API Key | `ollama` |
| Override OpenAI Base URL | `https://YOUR-TUNNEL-HOST/v1` |
| Add model | `qwen2.5-coder:latest` |

Free tunnel URLs change when restarted — always paste the URL from the current `expose-for-cursor` session.

## YouTube Video Production Pipeline

A static site hub for managing production across three channels: **Drone Technology**, **Military Bases**, and **Family**.

- **Hub**: `index.html`
- **Dashboard**: `mission-control.html`
- **Phases**: `phases/` (9 phases with checklists and scoring)

To view the pipeline hub:
```bash
python3 -m http.server 8080
```

## Available models (~8GB VRAM / 16GB RAM)

| Model id | Notes |
| --- | --- |
| `qwen2.5-coder:latest` | Coding-focused (default smoke-test / Hermes target) |
| `hermes3:8b` | Strong Hermes / tool-use pick for 8GB VRAM |
| `llama3.1:8b` | General chat; reliable fallback |
| `qwen359b` | Cursor-safe alias for Qwen3.5 9B |
| `qwen3.5:9b` | Same weights; `:` / `.` can break Cursor model names |
| `qwen3-vl:4b-instruct` | Vision |

## Verify the endpoint

Local daemon:

```bash
./scripts/verify-endpoint.sh
```

Public tunnel (for Cursor):

```bash
OLLAMA_BASE_URL='https://YOUR-TUNNEL-HOST/v1' \
OLLAMA_MODEL='qwen2.5-coder:latest' \
./scripts/verify-endpoint.sh
```

The script lists `/v1/models`, runs one `/v1/chat/completions`, and exits non-zero unless the assistant reply is exactly `ollama-ok`.

## Notes

- Cursor cannot call `localhost` for custom OpenAI endpoints (requests go through Cursor’s backend), so a public HTTPS tunnel is required for **Cursor Desktop**. Hermes on the same machine can use `http://127.0.0.1:11434/v1` directly.
- Prefer **cloudflared** (`./scripts/expose-for-cursor.sh`). Free **ngrok** browser-warning pages break Cursor because Cursor’s backend does not send `ngrok-skip-browser-warning`.
- Keep the tunnel running while using the model in Cursor.
- Cloud Agents cannot switch your desktop model picker; configure Ollama in **Cursor desktop** or **Hermes**.
- **Model Names:** If Cursor shows "Model not found", use a name without `:` or `.` (e.g. alias `qwen359b` instead of `qwen3.5:9b`).
