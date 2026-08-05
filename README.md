# Connect Ollama to Cursor

Your Ollama OpenAI-compatible API is live at:

```text
https://brought-passage-trapeze.ngrok-free.dev/v1
```

Verified: Ollama **0.32.4**, chat completions working.

## Cursor Settings → Models

| Setting | Value |
| --- | --- |
| OpenAI API Key | `ollama` |
| Override OpenAI Base URL | `https://brought-passage-trapeze.ngrok-free.dev/v1` |
| Add model | `qwen359b` |

Then in Chat / Agent: turn **Auto** off and select **qwen359b**.

Do **not** append `/chat/completions` — Cursor adds that path itself.

## Available models

| Model id | Notes |
| --- | --- |
| `qwen359b` | Cursor-safe alias for Qwen3.5 9B (recommended) |
| `qwen3.5:9b` | Same weights; `:` / `.` can break Cursor model names |
| `qwen2.5-coder:latest` | Coding-focused |
| `qwen3-vl:4b-instruct` | Vision |
| `llama3.1:8b` | General chat |

## Verify the endpoint

```bash
./scripts/verify-endpoint.sh
```

Or manually:

```bash
curl -sS "https://brought-passage-trapeze.ngrok-free.dev/v1/models" \
  -H "ngrok-skip-browser-warning: true"
```

## Notes

- Cursor cannot call `localhost` for custom OpenAI endpoints (requests go through Cursor’s backend), so this public HTTPS tunnel is required.
- Keep the ngrok tunnel running while using the model.
- Free ngrok URLs change when the tunnel restarts — update the Base URL if the host changes.
- Cloud Agents cannot switch your desktop model picker; configure this in **Cursor desktop**.
