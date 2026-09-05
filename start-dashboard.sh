#!/usr/bin/env bash
set -e

# Dashboard starter with HTTPS-Only mode support for Safari

PORT="${DASHBOARD_PORT:-8080}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/.certs"

echo "========================================"
echo "YouTube Mission Control Dashboard"
echo "========================================"
echo ""

# Function to create self-signed certificate for localhost
create_certificate() {
  mkdir -p "$CERT_DIR"
  
  if [ ! -f "$CERT_DIR/localhost.key" ] || [ ! -f "$CERT_DIR/localhost.crt" ]; then
    echo "Creating self-signed certificate for localhost..."
    openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/localhost.key" -out "$CERT_DIR/localhost.crt" -days 365 -nodes \
      -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null || {
      echo "Failed to create certificate. Make sure openssl is installed."
      return 1
    }
    echo "✓ Certificate created at $CERT_DIR/localhost.crt"
  fi
}

# Function to detect SSL support and start server
start_https_server() {
  if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not installed."
    return 1
  fi

  # Try to start HTTPS server with Python
  if python3 << PYTHON_SCRIPT
import http.server
import ssl
import os
import sys

port = 8080
cert_dir = "$CERT_DIR"
cert_file = os.path.join(cert_dir, "localhost.crt")
key_file = os.path.join(cert_dir, "localhost.key")

if not os.path.exists(cert_file) or not os.path.exists(key_file):
    print("ERROR: Certificate files not found", file=sys.stderr)
    sys.exit(1)

try:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert_file, key_file)
    
    handler = http.server.SimpleHTTPRequestHandler
    httpd = http.server.HTTPServer(('127.0.0.1', port), handler)
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    
    print(f"✓ HTTPS server running on https://localhost:{port}")
    print("  (Click 'Trust' in your browser if prompted about the certificate)")
    httpd.serve_forever()
except Exception as e:
    print(f"ERROR: Failed to start HTTPS server: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
  then
    return 0
  else
    return 1
  fi
}

# Function to start HTTP server (fallback)
start_http_server() {
  echo ""
  echo "⚠ WARNING: Running on HTTP (localhost:8080)"
  echo "If using Safari with HTTPS-Only mode enabled, this will be blocked."
  echo "To fix: See SAFARI_HTTPS_ONLY_FIX.md or disable HTTPS-Only mode in Safari."
  echo ""
  cd "$SCRIPT_DIR"
  python3 -m http.server $PORT
}

# Main flow
echo "Starting server on port $PORT..."
echo ""

# Try HTTPS first
if create_certificate; then
  echo "Attempting to start HTTPS server..."
  cd "$SCRIPT_DIR"
  if start_https_server; then
    exit 0
  fi
fi

# Fallback to HTTP
echo "Starting HTTP server (fallback)..."
start_http_server
