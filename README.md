# Connect Qwen3.5 9B to Cursor

Use **Qwen3.5 9B** locally via [Ollama](https://ollama.com), then wire it into Cursor as a custom model.

> **Important:** Cursor builds prompts on its servers, then calls your endpoint from the cloud.  
> `http://localhost:11434` will **not** work as the Base URL. You need a **public HTTPS** tunnel.

This Cloud Agent **cannot** flip the model picker in your Cursor desktop app. Run the steps below on your Windows PC, then select `qwen359b` in Cursor.

## Requirements

- Windows (PowerShell) — or macOS/Linux (bash scripts also included)
- [Ollama](https://ollama.com/download) installed
- ~7GB disk, ~16GB RAM recommended (or ~8GB VRAM)
- Cursor **Pro** or higher (custom / named BYOK models)
- A public HTTPS tunnel: [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) or [ngrok](https://ngrok.com/download)

## Connect in 4 steps (Windows)

Open PowerShell in this repo folder, then:

### 1. Install the model

```powershell
.\scripts\setup-qwen.ps1
```

This pulls `qwen3.5:9b` (~6.6GB) and creates a Cursor-safe alias `qwen359b` (avoids `:` / `.` name issues).

### 2. Verify locally

```powershell
.\scripts\verify-qwen.ps1
```

You should see a chat completion response from `qwen359b`.

### 3. Expose Ollama to Cursor

```powershell
.\scripts\expose-for-cursor.ps1
```

Copy the HTTPS URL it prints, for example `https://abc123.trycloudflare.com`.  
Your Cursor Base URL is that host **plus** `/v1`:

```text
https://abc123.trycloudflare.com/v1
```

Do **not** append `/chat/completions` — Cursor adds that. Keep this window open while you use the model.

### 4. Configure Cursor desktop

1. Open **Cursor Settings → Models**
2. Under **OpenAI / API Keys**:
   - **API Key**: `ollama` (any non-empty string; Ollama ignores auth)
   - Enable **Override OpenAI Base URL**
   - Base URL: `https://YOUR-TUNNEL-HOST/v1`
3. **Add model** → type exactly: `qwen359b`
4. Toggle the model **on**
5. In Chat / Agent, open the model picker, turn **Auto** off, select **qwen359b**

## Quick reference

| Setting | Value |
| --- | --- |
| Real Ollama model | `qwen3.5:9b` |
| Cursor model name | `qwen359b` |
| Local OpenAI API | `http://127.0.0.1:11434/v1` |
| Cursor Base URL | `https://YOUR-TUNNEL/v1` |
| API key in Cursor | `ollama` |

## macOS / Linux

```bash
chmod +x scripts/*.sh
./scripts/setup-qwen.sh
./scripts/verify-qwen.sh
./scripts/expose-for-cursor.sh
```

Then use the same Cursor Settings values as above.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Verify works, Cursor chat fails | Base URL must be public HTTPS, not localhost |
| `AI Model Not Found` / mangled name | Use alias `qwen359b`, not `qwen3.5:9b` |
| `404` on chat completions | Base URL should end at `/v1` only |
| Free plan / named models unavailable | Upgrade to Pro+ |
| Tunnel script exits immediately | Install cloudflared: `winget install --id Cloudflare.cloudflared` |
| Weak Agent tool use | Expected for a 9B local model; fine for chat/edit |

## Notes

- Tab completion still uses Cursor’s built-in models; custom endpoints apply to chat models.
- Traffic still routes through Cursor’s backend for prompt assembly — this is not fully offline.
- Keep the tunnel running while you use the model in Cursor.
- Cloud Agents cannot run as Qwen3.5 9B; this connection is for **Cursor desktop** only.
