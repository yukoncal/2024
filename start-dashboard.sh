#!/usr/bin/env bash
echo "Starting YouTube Mission Control Dashboard..."
echo "Open http://localhost:8080 in your browser."
echo ""

# Try to open browser
if command -v open > /dev/null; then
  open http://localhost:8080
elif command -v xdg-open > /dev/null; then
  xdg-open http://localhost:8080
fi

python3 -m http.server 8080
