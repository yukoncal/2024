# Fix: retired Claude 3.5 Sonnet (`claude-3-5-sonnet-20241022`)

Anthropic **retired** `claude-3-5-sonnet-20241022` on **2025-10-28**. Any client still sending that model ID gets `not_found_error` (those calls do not appear on the Usage page).

If you received a notice about API key **`anthropic-hermes`**, something in your stack (usually **Hermes Agent** with provider `anthropic`) is still using the old ID.

## Use this model instead

| Retired | Replacement (Anthropic API) |
| --- | --- |
| `claude-3-5-sonnet-20241022` | **`claude-sonnet-4-6`** |
| `claude-3-5-sonnet-20240620` | **`claude-sonnet-4-6`** |
| `claude-3-7-sonnet-20250219` | **`claude-sonnet-4-6`** |

OpenRouter / Nous slug: **`anthropic/claude-sonnet-4.6`**

Official table: [Anthropic model deprecations](https://platform.claude.com/docs/en/about-claude/model-deprecations)

## 1. Find where the old ID is set

From this repo:

```bash
./scripts/audit-retired-anthropic-models.sh
rg 'claude-3-5-sonnet-20241022' ~ .
```

Typical locations:

- `~/.hermes/config.yaml` → `model.default`
- Hermes profile dirs under `~/.hermes/profiles/*/config.yaml`
- **Cursor Desktop** → Settings → Models (custom model name)
- CI env vars (`ANTHROPIC_MODEL`, job YAML)

## 2. Update Hermes (most common for `anthropic-hermes`)

Direct Anthropic API:

```bash
hermes config set model.default claude-sonnet-4-6
hermes config set model.provider anthropic
```

OpenRouter:

```bash
hermes config set model.default anthropic/claude-sonnet-4.6
hermes config set model.provider openrouter
```

Restart any long-running Hermes process (CLI session, gateway, cron) after changing config.

## 3. Verify

```bash
curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-6","max_tokens":16,"messages":[{"role":"user","content":"ping"}]}'
```

You should get a normal response, not `not_found_error`.

## Hermes Agent code fix

The **[yukoncal/hermes-agent](https://github.com/yukoncal/hermes-agent)** repo includes an auto-upgrade for known retired IDs at request time (branch `cursor/fix-retired-claude-35-sonnet-b7c0`). Merge or cherry-pick that change so old configs stop hitting the API with retired names. Updating `model.default` is still recommended.
