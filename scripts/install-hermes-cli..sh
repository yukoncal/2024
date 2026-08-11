#!/usr/bin/env bash
# Typo shim: correct name is install-hermes-cli.sh (one dot before sh).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "note: use ./scripts/install-hermes-cli.sh (one dot before sh)" >&2
exec "${DIR}/install-hermes-cli.sh" "$@"
