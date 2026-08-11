# 2024 Project Hub

> 🚀 **Quick Access**: [Open Local Dashboard](http://localhost:8080) (Ensure server is running first)
> 
> **To start the server**: Run `./start-dashboard.sh` or `start-dashboard.bat`

---

This repository contains two main projects:
1. **Free local Hermes**: Locked Ollama model `hermes` for **Cursor Desktop** and **Hermes Agent** (Nous) — $0, replaces paid Grok 4.5 High Fast.
2. **YouTube Video Production Pipeline**: A Mission Control hub for managing a three-channel video production pipeline.

---

# Free local Hermes (locked)

**Default model is locked to free local `hermes`** (backed by already-downloaded `openhermes`).  
This replaces paid **Grok 4.5 High Fast** for everyday Hermes work in Cursor Desktop **and** [Hermes Agent](https://docs.ollama.com/integrations/hermes).

Lock file: [`config/hermes.lock.json`](config/hermes.lock.json)

## Grok 4.5 High Fast cost (what we replace)

| Variant | Input | Output |
| --- | --- | --- |
| **Grok 4.5 Fast** (includes High Fast) | **$4 / M tokens** | **$18 / M tokens** |
| Grok 4.5 (base) | $2 / M tokens | $6 / M tokens |

Source: [Cursor Grok 4.5 docs](https://cursor.com/docs/models/grok-4-5).  
“High” effort does **not** change the per-token rate — it uses **more tokens** per task. Fast is the expensive rate tier.

**Locked Hermes cost: $0** (runs on your machine via Ollama).

## One command: lock free Hermes

```bash
./scripts/lock-hermes.sh
```

Diagnose / autofix anytime:

```bash
./scripts/hermes-doctor.sh          # diagnose
./scripts/hermes-doctor.sh --fix   # diagnose + autofix
```

This:
- Reuses your already-downloaded free model (`openhermes`)
- Creates/keeps the Cursor-safe alias `hermes`
- Writes the lock in `config/hermes.lock.json`
- Smoke-tests the local OpenAI-compatible endpoint

## Hermes Agent (Nous) — free local Ollama

Hermes Agent is separate from Cursor. Point it at **local** Ollama with provider **`custom`** (not `ollama-cloud`):

```bash
./scripts/lock-hermes.sh          # ensure free model alias exists
./scripts/hermes-use-ollama.sh    # writes ~/.hermes/config.yaml
hermes                            # or: ollama launch hermes
```

| Setting | Locked value |
| --- | --- |
| `model.provider` | `custom` |
| `model.base_url` | `http://127.0.0.1:11434/v1` |
| `model.default` | `hermes` |

Install Hermes Agent CLI if needed:

```bash
./scripts/install-hermes-cli.sh
# or:  ./scripts/hermes-doctor.sh --fix
# or:  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive
# or guided: ollama launch hermes
```

For slow CPU inference, `hermes-use-ollama.sh` sets `HERMES_API_TIMEOUT=1800` in `~/.hermes/.env`.

## Cursor Settings → Models (Desktop) — pin these

Cloud Agent tabs **cannot** leave Grok mid-run. Wire free Hermes in **Cursor Desktop**:

1. Open **Cursor Desktop** → **Settings** → **Models**
2. **OpenAI API Key:** `ollama`
3. **Override OpenAI Base URL:** `https://YOUR-TUNNEL/v1` (from `./scripts/expose-for-cursor.sh`)
4. **Add custom model:** `hermes`
5. In the chat model picker: turn **Auto OFF** and select **`hermes`**
6. Send: `Reply with exactly: hermes-ok`

Do **not** append `/chat/completions` — Cursor adds that path itself.

| Setting | Locked value |
| --- | --- |
| OpenAI API Key | `ollama` |
| Override OpenAI Base URL | `https://YOUR-TUNNEL/v1` |
| Add model | `hermes` |
| Auto | **OFF** |
| Selected model | **`hermes`** |

## Next steps to ensure everything is fixed

1. **Stop using Grok for Hermes work** — this Cloud Agent run is already on `cursor-grok-4.5-high-fast`; finish that tab, then switch.
2. On your machine: `./scripts/lock-hermes.sh`
3. Keep Ollama up: `ollama serve`
4. Expose HTTPS (Cloudflare preferred — free ngrok often blocks Cursor):
   ```bash
   ./scripts/expose-for-cursor.sh
   ```
5. Paste the printed `https://…/v1` into **Override OpenAI Base URL**
6. Add model `hermes`, **Auto OFF**, select `hermes`
7. Confirm with: `Reply with exactly: hermes-ok`
8. For future Cloud Agents: **do not** pick Grok 4.5 High Fast for Hermes — use Desktop + locked `hermes` (free)

Local free chat (no Cursor cloud billing):

```bash
./scripts/open-hermes.sh
```

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
| `hermes` | **Locked default** — free local alias (from `openhermes`) |
| `openhermes` | Free OpenHermes 2.5; source weights for `hermes` |
| `qwen2.5-coder:latest` | Coding-focused (optional) |
| `qwen359b` | Cursor-safe alias for Qwen3.5 9B |
| `qwen3.5:9b` | Same weights; `:` / `.` can break Cursor model names |
| `qwen3-vl:4b-instruct` | Vision |
| `llama3.1:8b` | General chat (can back Hermes via `MODEL_SOURCE=…`) |

Override Hermes source only if you intentionally want a different **free local** model:

```bash
MODEL_SOURCE=llama3.1:8b ./scripts/setup-hermes.sh
./scripts/lock-hermes.sh
```

## Verify the endpoint

```bash
./scripts/verify-hermes.sh
# or (defaults to locked hermes):
./scripts/verify-endpoint.sh
```

Overrides:

```bash
OLLAMA_BASE_URL='https://YOUR-TUNNEL/v1' \
OLLAMA_MODEL='hermes' \
OLLAMA_EXPECT='hermes-ok' \
./scripts/verify-endpoint.sh
```

## Notes

- Cursor cannot call `localhost` for custom OpenAI endpoints (requests go through Cursor’s backend), so a public HTTPS tunnel is required for Desktop.
- Prefer **cloudflared** over free **ngrok** (ngrok browser warning blocks Cursor).
- Keep the tunnel running while using the model in Cursor Desktop.
- Free tunnel URLs change when restarted — update Base URL / re-run expose so `hermes.lock.json` stays current.
- Cloud Agents cannot switch your desktop model picker and cannot use local Ollama.
- **Model Names:** If Cursor shows "Model not found", use `hermes` (no `:` / `.`).
