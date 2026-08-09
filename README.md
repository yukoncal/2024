# 2024 Project Hub

> 🚀 **Quick Access**: [Open Local Dashboard](http://localhost:8080) (Ensure server is running first)
> 
> **To start the server**: Run `./start-dashboard.sh` or `start-dashboard.bat`

---

This repository contains two main projects:
1. **Ollama to Cursor Connection**: Scripts and docs to use local models (like Qwen2.5-Coder 7B) in Cursor Desktop.
2. **YouTube Video Production Pipeline**: A Mission Control hub for managing a three-channel video production pipeline.

---

# Connect Ollama to Cursor

## Fix: "The model you chose is not available"

Cursor rejects custom model names that contain `:` or `.`.  
`qwen2.5-coder:latest` will fail. Use the Cursor-safe alias **`qwen25-7b-coder`** instead.

Also, free ngrok tunnels go offline when the process stops. Prefer **cloudflared**, and always paste a **live** tunnel URL into Cursor settings.

## 1. Install the model (local machine)

```bash
chmod +x scripts/*.sh
./scripts/setup-qwen.sh
```

This pulls `qwen2.5-coder:7b` and creates the alias `qwen25-7b-coder`.

Windows (PowerShell):

```powershell
.\scripts\setup-qwen.ps1
```

## 2. Expose Ollama over public HTTPS

Cursor’s backend cannot call `localhost`. Start a tunnel:

```bash
./scripts/expose-for-cursor.sh
```

Copy the printed HTTPS host and append `/v1`, for example:

```text
https://YOUR-SUBDOMAIN.trycloudflare.com/v1
```

Prefer **cloudflared** over free ngrok (ngrok’s browser interstitial breaks Cursor).

## 3. Cursor Settings → Models (Desktop)

1. Open **Cursor Desktop** → **Settings** → **Models**
2. **OpenAI API Key:** `ollama` (any non-empty string)
3. **Override OpenAI Base URL:** your live tunnel URL ending in `/v1`
4. **Add custom model:** `qwen25-7b-coder` (no `:` and no `.` — even though `ollama list` shows `qwen25-7b-coder:latest`)
5. In the chat model picker, turn **Auto** off and select **`qwen25-7b-coder`**
6. Send: `Reply with exactly: ollama-ok`

Do **not** append `/chat/completions` — Cursor adds that path itself.  
Do **not** select `qwen2.5-coder:latest`, `qwen2.5-coder:7b`, or `qwen25-7b-coder:latest` in the picker.

| Setting | Value |
| --- | --- |
| OpenAI API Key | `ollama` |
| Override OpenAI Base URL | `https://YOUR-TUNNEL/v1` |
| Add model | `qwen25-7b-coder` |

## YouTube Video Production Pipeline

A static site hub for managing production across three channels: **Drone Technology**, **Military Bases**, and **Family**.

- **Hub**: `index.html`
- **Dashboard**: `mission-control.html`
- **Phases**: `phases/` (9 phases with checklists and scoring)

To view the pipeline hub:
```bash
python3 -m http.server 8080
```

## Available models

| Model id | Notes |
| --- | --- |
| `qwen25-7b-coder` | **Recommended** Cursor-safe alias for Qwen2.5-Coder 7B |
| `qwen2.5-coder:7b` | Same weights; do not use this name in Cursor |
| `qwen2.5-coder:latest` | Same family; Cursor rejects `:` / `.` in the picker |
| `qwen359b` | Cursor-safe alias for Qwen3.5 9B (`MODEL_SOURCE=qwen3.5:9b MODEL_ALIAS=qwen359b ./scripts/setup-qwen.sh`) |
| `qwen3.5:9b` | Same weights; `:` / `.` can break Cursor model names |
| `qwen3-vl:4b-instruct` | Vision |
| `llama3.1:8b` | General chat |

## Verify the endpoint

Local:

```bash
MODEL_ALIAS=qwen25-7b-coder ./scripts/verify-qwen.sh
```

Public tunnel (after `expose-for-cursor.sh`):

```bash
OLLAMA_BASE_URL='https://YOUR-TUNNEL/v1' \
OLLAMA_MODEL='qwen25-7b-coder' \
./scripts/verify-endpoint.sh
```

The script lists `/v1/models`, runs one `/v1/chat/completions`, and exits non-zero unless the assistant reply is exactly `ollama-ok`.

## Notes

- Cursor cannot call `localhost` for custom OpenAI endpoints (requests go through Cursor’s backend), so a public HTTPS tunnel is required.
- Prefer **cloudflared**. Free **ngrok** often fails because Cursor does not send `ngrok-skip-browser-warning`.
- Keep the tunnel running while using the model. When it restarts, update the Base URL in Cursor.
- Cloud Agents cannot switch your desktop model picker; configure this in **Cursor desktop**.
- If Cursor shows **"The model you chose is not available"** or **"Model not found"**, switch to a name without `:` or `.` — use `qwen25-7b-coder`.
