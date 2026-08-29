#!/usr/bin/env bash
# Comprehensive troubleshooting guide for local Ollama models not showing in Cursor.
# This script diagnoses each step of the setup process and suggests fixes.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_URL="http://127.0.0.1:${OLLAMA_PORT}"
ERRORS=()
WARNINGS=()

print_header() {
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
  ERRORS+=("$1")
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
  WARNINGS+=("$1")
}

check_ollama_installed() {
  print_header "Step 1: Check Ollama Installation"
  
  if command -v ollama >/dev/null 2>&1; then
    local version
    version=$(ollama --version 2>/dev/null || echo "unknown")
    print_success "Ollama is installed: $version"
  else
    print_error "Ollama is not installed"
    cat <<'EOF'

Install Ollama:
  macOS/Linux:  curl -fsSL https://ollama.com/install.sh | sh
  Windows:      https://ollama.com/download

Then re-run this script.
EOF
    return 1
  fi
  return 0
}

check_ollama_running() {
  print_header "Step 2: Check Ollama Daemon"
  
  if curl -fsS "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
    print_success "Ollama daemon is running at ${OLLAMA_URL}"
    return 0
  else
    print_warning "Ollama daemon is NOT running at ${OLLAMA_URL}"
    echo "Attempting to start Ollama..."
    
    if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled ollama >/dev/null 2>&1; then
      print_warning "Starting via systemctl..."
      if sudo systemctl start ollama 2>/dev/null; then
        sleep 2
        if curl -fsS "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
          print_success "Ollama started successfully"
          return 0
        fi
      fi
    fi
    
    if ! curl -fsS "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
      print_warning "Starting Ollama in background..."
      nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
      local start_time
      start_time=$(date +%s)
      while [ $(($(date +%s) - start_time)) -lt 30 ]; do
        if curl -fsS "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
          print_success "Ollama daemon started"
          return 0
        fi
        sleep 1
      done
    fi
    
    print_error "Could not start Ollama daemon"
    echo "Manual fix: ollama serve"
    return 1
  fi
}

check_models_available() {
  print_header "Step 3: Check Available Models in Ollama"
  
  local models
  models=$(curl -fsS "${OLLAMA_URL}/api/tags" 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || true)
  
  if [ -z "$models" ]; then
    print_warning "No models are installed in Ollama"
    echo "Install a model with: ./scripts/setup-qwen.sh"
    return 1
  fi
  
  print_success "Models found:"
  echo "$models" | while read -r model; do
    echo "  - $model"
  done
  
  # Check for Cursor-safe models
  if echo "$models" | grep -q "qwen25\|qwen25-7b-coder\|hermes"; then
    print_success "Found a Cursor-safe model alias"
    return 0
  else
    print_warning "No Cursor-safe model alias found"
    echo "Create one with: ./scripts/setup-qwen.sh"
    return 1
  fi
}

check_tunnel_required() {
  print_header "Step 4: Understand Tunnel Requirement"
  
  cat <<'EOF'
Cursor Cloud routes all requests through its backend servers. Direct 
http://localhost:11434 connections are NOT possible. You need a public 
HTTPS tunnel that Cursor's backend can reach.

Two options:
  1. Cloudflare Tunnel (recommended): ./scripts/expose-for-cursor.sh
  2. ngrok:                          ./scripts/expose-for-cursor.sh

EOF
}

check_tunnel_tools() {
  print_header "Step 5: Check Tunnel Tools"
  
  local has_tunnel=0
  
  if command -v cloudflared >/dev/null 2>&1; then
    print_success "cloudflared is installed (recommended)"
    has_tunnel=1
  else
    print_warning "cloudflared is NOT installed"
  fi
  
  if command -v ngrok >/dev/null 2>&1; then
    print_success "ngrok is installed"
    has_tunnel=1
  else
    print_warning "ngrok is NOT installed"
  fi
  
  if [ "$has_tunnel" -eq 0 ]; then
    print_error "Neither cloudflared nor ngrok is installed"
    cat <<'EOF'

Install one:
  Cloudflare Tunnel (macOS):  brew install cloudflared
  Cloudflare Tunnel (Linux):  https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
  ngrok:                      https://ngrok.com/download

Then run: ./scripts/expose-for-cursor.sh
EOF
    return 1
  fi
  
  return 0
}

print_cursor_settings_guide() {
  print_header "Step 6: Cursor Desktop Configuration"
  
  cat <<'EOF'
After establishing a tunnel with ./scripts/expose-for-cursor.sh:

1. Get the tunnel URL (should look like https://xxx.trycloudflare.com)
2. In Cursor Desktop:
   - Click settings icon (bottom-left)
   - Go to "Models"
   - Under "Manually add OpenAI API":

   OpenAI API Key:        ollama
   Override OpenAI Base URL: https://YOUR-TUNNEL-URL/v1
   
3. Under "Add custom model", add exactly: qwen25
   (Do NOT use: qwen2.5-coder:latest or qwen2.5-coder:7b)

4. In the chat model picker:
   - Turn OFF "Auto" (top-right toggle)
   - Select "qwen25"
   - Send: Reply with exactly: ollama-ok
   
Expected response: "ollama-ok"

EOF
}

print_verification_commands() {
  print_header "Step 7: Manual Verification Commands"
  
  cat <<'EOF'
Test Ollama locally:
  curl http://127.0.0.1:11434/api/tags

Test model inference locally:
  MODEL_ALIAS=qwen25 ./scripts/verify-qwen.sh

Test through tunnel (replace URL with your tunnel):
  OLLAMA_BASE_URL='https://YOUR-TUNNEL/v1' \
  OLLAMA_MODEL='qwen25' \
  ./scripts/verify-endpoint.sh

EOF
}

print_common_issues() {
  print_header "Common Issues & Fixes"
  
  cat <<'EOF'
Issue: "The model you chose is not available"
  Cause: Cursor rejects model names with "." or ":"
  Fix:   Use the alias "qwen25" instead of "qwen2.5-coder:latest"

Issue: Timeout waiting for response from Cursor
  Cause: Tunnel is not running or tunnel URL is wrong
  Fix:   Keep ./scripts/expose-for-cursor.sh running in another terminal
         Double-check the tunnel URL in Cursor Settings

Issue: Model appears but doesn't respond
  Cause: API key, base URL, or model name is incorrect
  Fix:   Verify in Cursor Settings:
         - API Key: exactly "ollama" (not your OpenAI key)
         - Base URL: https://YOUR-TUNNEL/v1 (with /v1 at the end)
         - Model: exactly "qwen25" (no dots or colons)

Issue: "Connection refused" or "Network error"
  Cause: Tunnel is not running or models aren't aliased correctly
  Fix:   1. Check: curl http://127.0.0.1:11434/api/tags
         2. Keep: ./scripts/expose-for-cursor.sh running
         3. Verify model alias exists: ollama list

EOF
}

print_summary() {
  print_header "Troubleshooting Summary"
  
  if [ "${#ERRORS[@]}" -eq 0 ] && [ "${#WARNINGS[@]}" -eq 0 ]; then
    print_success "All checks passed! Your setup appears correct."
    echo "Next: Run ./scripts/expose-for-cursor.sh and configure Cursor Desktop"
    return 0
  fi
  
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo -e "${RED}Errors (must fix):${NC}"
    for error in "${ERRORS[@]}"; do
      echo "  - $error"
    done
    echo
  fi
  
  if [ "${#WARNINGS[@]}" -gt 0 ]; then
    echo -e "${YELLOW}Warnings (may need attention):${NC}"
    for warning in "${WARNINGS[@]}"; do
      echo "  - $warning"
    done
    echo
  fi
  
  return 1
}

main() {
  echo -e "\n${BLUE}Cursor Local Models Troubleshooting${NC}"
  echo "======================================"
  echo "This will check each step of the Ollama → Cursor setup."
  echo
  
  check_ollama_installed || exit 1
  check_ollama_running || print_warning "Ollama daemon issue"
  check_models_available || print_warning "No models installed"
  check_tunnel_required
  check_tunnel_tools || print_warning "Tunnel tools missing"
  
  print_cursor_settings_guide
  print_verification_commands
  print_common_issues
  print_summary
}

main "$@"
