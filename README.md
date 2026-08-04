# Qwen3.5 9B for Cursor

Run **Qwen3.5 9B** locally with [Ollama](https://ollama.com) and use it as a custom model in Cursor.

> Cursor builds prompts on its servers, then calls your OpenAI-compatible endpoint from the cloud. That means `http://localhost:11434` does **not** work as the Base URL — you need a **public HTTPS** tunnel (Cloudflare Tunnel or ngrok).

## Requirements

- [Ollama](https://ollama.com) installed
- ~7GB disk for the model, ~16GB RAM recommended (or ~8GB VRAM)
- Cursor **Pro** or higher (custom / named BYOK models)
- A public HTTPS tunnel to your machine (`cloudflared` or `ngrok`)

## 1. Install the model

```bash
chmod +x scripts/*.sh
./scripts/setup-qwen.sh
```

This will:

1. Pull `qwen3.5:9b`
2. Create a Cursor-safe alias `qwen359b` (avoids `:` / `.` name validation issues)

Manual equivalent:

```bash
ollama pull qwen3.5:9b
ollama create qwen359b -f ollama/Modelfile
```

## 2. Verify locally

```bash
./scripts/verify-qwen.sh
```

You should see a chat completion response containing content from `qwen359b`.

## 3. Expose Ollama to Cursor

```bash
./scripts/expose-for-cursor.sh
```

Copy the HTTPS URL it prints (for example `https://abc123.trycloudflare.com`).

Your Cursor Base URL must be that host **plus** `/v1`:

```text
https://abc123.trycloudflare.com/v1
```

Do not append `/chat/completions` — Cursor adds that.

## 4. Configure Cursor

1. Open **Cursor Settings → Models**
2. Under **OpenAI**:
   - **API Key**: `ollama` (any non-empty string; Ollama ignores auth)
   - Enable **Override OpenAI Base URL**
   - Base URL: `https://YOUR-TUNNEL-HOST/v1`
3. **Add model** → `qwen359b`
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

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Verify works, Cursor chat fails | Base URL must be public HTTPS, not localhost |
| `AI Model Not Found` / mangled name | Use alias `qwen359b`, not `qwen3.5:9b` |
| `404` on chat completions | Base URL should end at `/v1` only |
| Free plan / named models unavailable | Upgrade to Pro+ |
| Weak Agent tool use | Expected for a 9B local model; fine for chat/edit, limited for heavy Agent |

## Notes

- Tab completion still uses Cursor’s built-in models; custom endpoints apply to chat models.
- Traffic still routes through Cursor’s backend for prompt assembly — this is not fully offline.
- Keep the tunnel running while you use the model in Cursor.
