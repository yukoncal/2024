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

## Troubleshoot "Local models not showing"

If you've completed setup but models still don't appear in Cursor's model picker:

```bash
./scripts/troubleshoot-cursor-models.sh
```

This script checks:
- ✓ Ollama is installed and running
- ✓ Models are aliased with Cursor-safe names (no "." or ":")
- ✓ Tunnel tool (cloudflared or ngrok) is available
- ✓ Correct Cursor Desktop settings for API key, base URL, and model name

### Quick checklist if models aren't showing

1. **Is Ollama running?**
   ```bash
   curl http://127.0.0.1:11434/api/tags
   ```
   If this fails, run: `ollama serve`

2. **Is the tunnel running?**
   Keep `./scripts/expose-for-cursor.sh` running in another terminal while chatting.

3. **Are Cursor settings correct?**
   - Settings → Models
   - **API Key**: `ollama` (not your OpenAI key)
   - **Base URL**: `https://YOUR-TUNNEL/v1` (copy from tunnel output, add `/v1`)
   - **Model name**: `qwen25` (no dots, no colons)
   - Turn **Auto** OFF in the chat model picker

4. **Is the model aliased correctly in Ollama?**
   ```bash
   ollama list
   ```
   You should see `qwen25` (not `qwen2.5-coder:latest`).

### Common error messages

| Error | Cause | Fix |
| --- | --- | --- |
| "The model you chose is not available" | Model name has "." or ":" | Use alias like `qwen25` instead |
| "Connection refused" or "Timeout" | Tunnel not running or URL wrong | Keep `./scripts/expose-for-cursor.sh` running; verify URL in Cursor Settings |
| Ollama not reachable at localhost:11434 | Ollama daemon not running | Run `ollama serve` |
| Model appears but doesn't respond | Settings are wrong | Check API key (`ollama`), base URL (ends in `/v1`), and model name (`qwen25`) |

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
