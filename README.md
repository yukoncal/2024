# Connect Ollama to Cursor

Your Ollama OpenAI-compatible API is live at:

```text
https://brought-passage-trapeze.ngrok-free.dev/v1
```

Verified: Ollama chat completions working (`qwen2.5-coder:latest` → `ollama-ok`).

## Cursor Settings → Models (Desktop)

Cloud Agent tabs keep showing the hosted Cursor model (e.g. Grok). Wire Ollama in **Cursor Desktop**:

1. Open **Cursor Desktop** → **Settings** → **Models**
2. **OpenAI API Key:** `ollama` (any non-empty string)
3. **Override OpenAI Base URL:** `https://brought-passage-trapeze.ngrok-free.dev/v1`
4. **Add custom model:** `qwen2.5-coder:latest` (or `qwen359b`)
5. In the chat model picker, turn **Auto** off and select that model
6. Send: `Reply with exactly: ollama-ok`

Do **not** append `/chat/completions` — Cursor adds that path itself.

| Setting | Value |
| --- | --- |
| OpenAI API Key | `ollama` |
| Override OpenAI Base URL | `https://brought-passage-trapeze.ngrok-free.dev/v1` |
| Add model | `qwen2.5-coder:latest` |

## Available models

| Model id | Notes |
| --- | --- |
| `qwen2.5-coder:latest` | Coding-focused (default smoke-test target) |
| `qwen359b` | Cursor-safe alias for Qwen3.5 9B |
| `qwen3.5:9b` | Same weights; `:` / `.` can break Cursor model names |
| `qwen3-vl:4b-instruct` | Vision |
| `llama3.1:8b` | General chat |

## Verify the endpoint

```bash
./scripts/verify-endpoint.sh
```

Overrides:

```bash
OLLAMA_BASE_URL='https://brought-passage-trapeze.ngrok-free.dev/v1' \
OLLAMA_MODEL='qwen2.5-coder:latest' \
./scripts/verify-endpoint.sh
```

The script lists `/v1/models`, runs one `/v1/chat/completions`, and exits non-zero unless the assistant reply is exactly `ollama-ok`.

## Notes

- Cursor cannot call `localhost` for custom OpenAI endpoints (requests go through Cursor’s backend), so this public HTTPS tunnel is required.
- Keep the ngrok tunnel running while using the model.
- Free ngrok URLs change when the tunnel restarts — update the Base URL if the host changes.
- Cloud Agents cannot switch your desktop model picker; configure this in **Cursor desktop**.
