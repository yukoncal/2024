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

## Fix qwen2.5 in Cursor (do this)

`qwen2.5-coder:latest` **does not work** in Cursor (`.` and `:` are rejected → “The model you chose is not available”).

Use the safe name **`qwen25`** instead.

### On your PC (PowerShell or Terminal in this repo)

```powershell
.\scripts\setup-qwen.ps1
.\scripts\expose-for-cursor.ps1
```

macOS/Linux:

```bash
./scripts/setup-qwen.sh
./scripts/expose-for-cursor.sh
```

Copy the HTTPS URL the tunnel prints, then add `/v1`.

### Paste into Cursor Desktop → Settings → Models

| Setting | Exact value |
| --- | --- |
| OpenAI API Key | `ollama` |
| Override OpenAI Base URL | `https://YOUR-TUNNEL/v1` |
| Add model | `qwen25` |

Then:

1. Turn **Auto** off in the chat model picker  
2. Select **`qwen25`** (not `qwen2.5-coder:latest`)  
3. Send: `Reply with exactly: ollama-ok`

Do **not** use these names in Cursor: `qwen2.5-coder:latest`, `qwen2.5-coder:7b`, `qwen25:latest`.

Prefer **cloudflared** over free ngrok. Keep the tunnel running while you chat.

---

## Available models

| Model id | Notes |
| --- | --- |
| `qwen25` | **Use this in Cursor** — alias for Qwen2.5-Coder 7B |
| `qwen25-7b-coder` | Same weights, longer alias |
| `qwen2.5-coder:7b` | Ollama name only — do not use in Cursor |
| `qwen2.5-coder:latest` | Breaks Cursor model picker |
| `qwen359b` | Optional Qwen3.5 9B (`MODEL_SOURCE=qwen3.5:9b MODEL_ALIAS=qwen359b ./scripts/setup-qwen.sh`) |

## Verify

```bash
MODEL_ALIAS=qwen25 ./scripts/verify-qwen.sh
```

```bash
OLLAMA_BASE_URL='https://YOUR-TUNNEL/v1' \
OLLAMA_MODEL='qwen25' \
./scripts/verify-endpoint.sh
```

## YouTube Video Production Pipeline

A static site hub for managing production across three channels: **Drone Technology**, **Military Bases**, and **Family**.

- **Hub**: `index.html`
- **Dashboard**: `mission-control.html`
- **Phases**: `phases/` (9 phases with checklists and scoring)

```bash
python3 -m http.server 8080
```

## Notes

- Cursor cannot call `localhost` for custom OpenAI endpoints — you need a public HTTPS tunnel.
- Cloud Agents cannot change your desktop model picker; set **`qwen25`** in **Cursor Desktop**.
