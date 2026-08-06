#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the 2024 repository.
#
# The repository currently ships only documentation, so there is nothing to
# install yet. This script auto-detects the most common project manifests and
# installs their dependencies when they appear, so the environment stays ready
# as the project grows. Each step is guarded, so running it on the current
# (manifest-free) tree is a safe no-op, and re-running it is idempotent.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

installed_something=0

# Build the pip flags once. On distros that enforce PEP 668
# (an EXTERNALLY-MANAGED marker in the stdlib), a plain `pip install --user`
# is refused, so add --break-system-packages when the marker is present. This
# keeps the bootstrap working whether or not the base image enforces PEP 668.
pip_user_args=(--user)
if compgen -G "/usr/lib/python3*/EXTERNALLY-MANAGED" >/dev/null 2>&1; then
  pip_user_args+=(--break-system-packages)
fi

# Node.js
if [ -f package.json ]; then
  installed_something=1
  echo "==> Detected package.json; installing Node dependencies"
  if [ -f package-lock.json ]; then
    npm ci
  else
    npm install
  fi
fi

# Python
if [ -f requirements.txt ]; then
  installed_something=1
  echo "==> Detected requirements.txt; installing Python dependencies"
  python3 -m pip install "${pip_user_args[@]}" -r requirements.txt
fi
if [ -f pyproject.toml ]; then
  installed_something=1
  echo "==> Detected pyproject.toml; installing project"
  python3 -m pip install "${pip_user_args[@]}" -e .
fi

# Go
if [ -f go.mod ]; then
  installed_something=1
  echo "==> Detected go.mod; downloading modules"
  go mod download
fi

# Rust
if [ -f Cargo.toml ]; then
  installed_something=1
  echo "==> Detected Cargo.toml; fetching crates"
  cargo fetch
fi

if [ "$installed_something" -eq 0 ]; then
  echo "==> No recognized project manifest found; nothing to install."
  echo "    (Add a package.json, requirements.txt, pyproject.toml, go.mod, or"
  echo "     Cargo.toml and this bootstrap will install dependencies on the next run.)"
fi

echo "==> Bootstrap complete."
