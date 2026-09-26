#!/usr/bin/env bash
# Find (and optionally rewrite) retired Anthropic model IDs in Hermes config.
#
#   ./scripts/audit-retired-anthropic-models.sh          # report only
#   ./scripts/audit-retired-anthropic-models.sh --fix     # rewrite in place (.bak kept)
set -euo pipefail

FIX=0
[[ "${1:-}" == "--fix" ]] && FIX=1

PATTERN='claude-3-5-sonnet-20241022|claude-3-5-sonnet-20240620|claude-3-7-sonnet-20250219|claude-3-5-haiku-20241022'

echo "Retired Anthropic model IDs → replacements:"
echo "  claude-3-5-sonnet-20241022 / -20240620 / claude-3-7-sonnet-20250219 → claude-sonnet-4-6"
echo "  claude-3-5-haiku-20241022 → claude-haiku-4-5-20251001"
echo ""

FOUND=0

rewrite_file() {
  local f="$1"
  cp "$f" "$f.bak"
  sed -i.tmp \
    -e 's|anthropic/claude-3-5-sonnet-20241022|anthropic/claude-sonnet-4.6|g' \
    -e 's|anthropic/claude-3-5-sonnet-20240620|anthropic/claude-sonnet-4.6|g' \
    -e 's|anthropic/claude-3-7-sonnet-20250219|anthropic/claude-sonnet-4.6|g' \
    -e 's|anthropic/claude-3-5-haiku-20241022|anthropic/claude-haiku-4.5|g' \
    -e 's|claude-3-5-sonnet-20241022|claude-sonnet-4-6|g' \
    -e 's|claude-3-5-sonnet-20240620|claude-sonnet-4-6|g' \
    -e 's|claude-3-7-sonnet-20250219|claude-sonnet-4-6|g' \
    -e 's|claude-3-5-haiku-20241022|claude-haiku-4-5-20251001|g' \
    "$f"
  rm -f "$f.tmp"
  echo "    rewritten (backup: $f.bak)"
}

search_file() {
  local f="$1"
  if [[ -f "$f" ]] && grep -qE "$PATTERN" "$f" 2>/dev/null; then
    echo "  $f"
    grep -nE "$PATTERN" "$f" || true
    FOUND=1
    if [[ "$FIX" -eq 1 ]]; then
      rewrite_file "$f"
    fi
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

for f in .env .env.local cli-config.yaml; do
  search_file "$f"
done

# Report-only scan of the current repo (never rewritten by --fix). The docs,
# this script, and the Hermes patch all name the retired IDs on purpose.
REPO_EXCLUDES=(
  --glob '!.git'
  --glob '!patches/*'
  --glob '!docs/ANTHROPIC_RETIRED_MODELS.md'
  --glob '!scripts/audit-retired-anthropic-models.sh'
  --glob '!README.md'
)
if command -v rg >/dev/null 2>&1 && rg -q "$PATTERN" . "${REPO_EXCLUDES[@]}" 2>/dev/null; then
  echo "  (this repository — review manually)"
  rg -n "$PATTERN" . "${REPO_EXCLUDES[@]}" 2>/dev/null || true
  FOUND=1
fi

if [[ "$FOUND" -eq 0 ]]; then
  echo "No retired model IDs found in Hermes config paths."
  echo ""
  echo "Set the active model explicitly if needed:"
  echo "  hermes config set model.default claude-sonnet-4-6     # provider: anthropic"
  echo "  hermes config set model.default anthropic/claude-sonnet-4.6   # OpenRouter"
elif [[ "$FIX" -eq 1 ]]; then
  echo ""
  echo "Done. Restart Hermes (CLI session, gateway, cron) to pick up the change."
else
  echo ""
  echo "Re-run with --fix to rewrite these in place, or edit manually."
fi
