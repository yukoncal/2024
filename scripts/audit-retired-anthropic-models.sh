#!/usr/bin/env bash
# Find retired Anthropic model IDs in Hermes config, env files, and this repo.
set -euo pipefail

PATTERN='claude-3-5-sonnet-20241022|claude-3-5-sonnet-20240620|claude-3-7-sonnet-20250219|claude-3-5-haiku-20241022'

echo "Searching for retired Anthropic model IDs..."
echo "Sonnet 3.5/3.7 → use claude-sonnet-4-6 (or anthropic/claude-sonnet-4.6 on OpenRouter)"
echo ""

FOUND=0
search_file() {
  local f="$1"
  if [[ -f "$f" ]] && grep -qE "$PATTERN" "$f" 2>/dev/null; then
    echo "  $f"
    grep -nE "$PATTERN" "$f" || true
    FOUND=1
  fi
}

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
search_file "$HERMES_HOME/config.yaml"
search_file "$HERMES_HOME/cli-config.yaml"

if [[ -d "$HERMES_HOME/profiles" ]]; then
  while IFS= read -r -d '' f; do
    search_file "$f"
  done < <(find "$HERMES_HOME/profiles" -name 'config.yaml' -print0 2>/dev/null || true)
fi

for f in .env .env.local; do
  search_file "$f"
done

if command -v rg >/dev/null 2>&1; then
  RG_GLOBS=(--glob '!.git' --glob '!README.md' --glob '!docs/ANTHROPIC_RETIRED_MODELS.md' --glob '!scripts/audit-retired-anthropic-models.sh')
  if rg -q "$PATTERN" . "${RG_GLOBS[@]}" 2>/dev/null; then
    echo "  (this repository)"
    rg -n "$PATTERN" . "${RG_GLOBS[@]}" 2>/dev/null || true
    FOUND=1
  fi
fi

if [[ "$FOUND" -eq 0 ]]; then
  echo "No retired model IDs in ~/.hermes or this repo."
  echo "Search Cursor Settings → Models and other machines in org MNC."
else
  echo ""
  echo "Update hits to claude-sonnet-4-6 (see docs/ANTHROPIC_RETIRED_MODELS.md)."
fi
