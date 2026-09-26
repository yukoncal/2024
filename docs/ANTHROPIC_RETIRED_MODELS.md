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

From a clone of this repo:

```bash
./scripts/audit-retired-anthropic-models.sh          # report only
./scripts/audit-retired-anthropic-models.sh --fix    # rewrite Hermes config in place (.bak kept)
```

Without a clone (downloads the same script to `~/hermes-fix`):

```bash
mkdir -p ~/hermes-fix && cd ~/hermes-fix
curl -fsSLO https://raw.githubusercontent.com/yukoncal/2024/main/scripts/audit-retired-anthropic-models.sh
chmod +x audit-retired-anthropic-models.sh
./audit-retired-anthropic-models.sh --fix
```

The script checks `~/.hermes` and `~/.config/hermes` (`config.yaml`, `cli-config.yaml`, `profiles/*/config.yaml`), plus `.env` files in the current directory. Set `HERMES_HOME` if your Hermes data lives elsewhere.

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

## 4. Hermes Agent code fix (patch included)

Config alone fixes today's failures; the code fix prevents any future config or script from sending a retired ID. The patch lives in this repo because the automation that produced it cannot push to `yukoncal/hermes-agent`.

```bash
git clone https://github.com/yukoncal/hermes-agent.git
cd hermes-agent
git checkout -b fix-retired-claude-models
git am /path/to/2024/patches/hermes-agent-retired-claude-models.patch
PYTHONPATH=. python3 -m pytest tests/agent/test_retired_anthropic_models.py -q
git push -u origin fix-retired-claude-models
```

What the patch does:

- `agent/retired_anthropic_models.py` — table of retired IDs → supported replacements.
- `agent/anthropic_adapter.py` — rewrites retired IDs on requests to `api.anthropic.com` (third-party Anthropic-compatible endpoints are left untouched) and logs a warning.
- `hermes_cli/model_normalize.py` — same rewrite during provider/model normalization, so aggregator slugs are covered.
- `scripts/audit-retired-anthropic-models.sh` — audit with `--fix`.
- Tests plus a docs page.
