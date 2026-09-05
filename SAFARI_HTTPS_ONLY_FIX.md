# Safari HTTPS-Only Mode Fix Guide

## Problem

Safari displays: **"Safari can't open the page ... Navigation failed because the request was for an HTTP URL with HTTPS-Only enabled"**

This happens when:
- You're using Safari with **HTTPS-Only mode** enabled (the default in modern macOS)
- You try to open `http://localhost:8080` (HTTP, not HTTPS)
- Safari blocks HTTP connections when HTTPS-Only mode is active

## Root Cause

The dashboard server was running on plain HTTP (`http://localhost:8080`), but Safari's HTTPS-Only mode enforces secure connections for all URLs, including localhost.

## Solution 1: Use HTTPS Localhost (Recommended)

The updated `start-dashboard.sh` now supports HTTPS by default.

### Steps

1. **Start the server with HTTPS support:**
   ```bash
   ./start-dashboard.sh
   ```

2. **Expected output:**
   ```
   Creating self-signed certificate for localhost...
   ✓ Certificate created at ./.certs/localhost.crt
   ✓ HTTPS server running on https://localhost:8080
     (Click 'Trust' in your browser if prompted about the certificate)
   ```

3. **Open in browser:**
   - **Safari**: Navigate to `https://localhost:8080`
   - Your browser may show a certificate warning (normal for self-signed certificates)
   - Click "Show Details" → "Visit this website" to proceed
   - The certificate is trusted locally only

4. **Dashboard works!** HTTPS-Only mode will no longer block the connection.

### What the script does

- Generates a self-signed SSL certificate for localhost (done once, then reused)
- Starts a Python HTTPS server on port 8080
- Certificate is stored in `./.certs/` (automatically created)
- Future runs reuse the same certificate

---

## Solution 2: Disable Safari HTTPS-Only Mode (Temporary)

If you only want to use HTTP:

1. **Open Safari** → **Settings** (or **Preferences** on older macOS)
2. Go to **Privacy**
3. Uncheck **"Require HTTPS-Only"**
4. Run: `./start-dashboard.sh`
5. Open `http://localhost:8080`

**Note**: Re-enable HTTPS-Only mode after for security.

---

## Solution 3: Use a Port Redirect (Advanced)

If you want to keep HTTP working with HTTPS-Only enabled, set up a local proxy:

```bash
# macOS (using pfctl)
sudo pfctl -ef - << EOF
rdr pass inet proto tcp from any to 127.0.0.1 port 80 -> 127.0.0.1 port 8080
EOF

# Then open: http://localhost (port 80 will redirect to 8080)
```

Note: This requires `sudo` and additional setup.

---

## Solution 4: Expose via Public HTTPS Tunnel

Like the Ollama setup, you can expose your local dashboard over a public HTTPS tunnel:

```bash
# Install cloudflared
brew install cloudflared  # macOS
# or: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/ (other OS)

# Expose dashboard
cloudflared tunnel --url http://127.0.0.1:8080

# Copy the public HTTPS URL (e.g., https://abc123.trycloudflare.com)
# Open in Safari without any local issues
```

---

## Troubleshooting

### Certificate issues

If you get SSL errors after running the script:

1. **Delete the old certificate:**
   ```bash
   rm -rf ./.certs
   ```

2. **Restart the server:**
   ```bash
   ./start-dashboard.sh
   ```

3. **Clear Safari cache:**
   - Safari → Settings → Privacy → Manage Website Data
   - Search for "localhost"
   - Delete the entry

### Python SSL errors

If Python fails to wrap the socket with SSL:

- Make sure `openssl` is installed: `which openssl`
- On macOS: `brew install openssl`
- On Linux: `sudo apt-get install openssl`

---

## Summary Table

| Approach | Pros | Cons | Steps |
| --- | --- | --- | --- |
| **HTTPS Localhost** (Recommended) | Works with HTTPS-Only; simple; no config needed | Requires certificate (auto-generated) | Just run `./start-dashboard.sh` and use `https://localhost:8080` |
| **Disable HTTPS-Only** | Immediate; no SSL setup | Requires manual browser setting; less secure | Disable HTTPS-Only in Safari Settings, then open `http://localhost:8080` |
| **Port Redirect** | Transparent to apps | Requires sudo; OS-specific; complex | Set up pfctl rule (macOS) or firewall redirect (Linux) |
| **Public Tunnel** | Works from anywhere; no local cert issues | Requires internet; additional service (cloudflared/ngrok) | Install cloudflared; run tunnel; open public URL |

---

## Related Issues

This same HTTPS-Only mode issue affects:
- **Ollama tunnel**: The `expose-for-cursor.sh` already correctly uses HTTPS (via cloudflared/ngrok)
- **Any localhost HTTP service**: Dashboard, local dev servers, etc.

For more info on Safari HTTPS-Only:
https://support.apple.com/en-us/102068
