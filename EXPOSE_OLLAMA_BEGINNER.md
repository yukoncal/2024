# Fix #1: Expose Ollama to Cursor (step-by-step, no programming)

This guide walks you through **security fix #1**: opening a **password-protected** tunnel so Cursor can reach Ollama on your computer—without leaving Ollama wide open on the internet.

You will copy and paste a few commands and fill in **your own** username, password, and tunnel address.

---

## What you are doing (in one sentence)

You run Ollama on your PC, use **ngrok** to create a private HTTPS link with a **login**, and paste that link into Cursor’s settings.

---

## Before you start

| You need | Why |
| --- | --- |
| **This repo** on your computer | The helper scripts live here |
| **Ollama** installed | Runs the AI model locally ([ollama.com/download](https://ollama.com/download)) |
| **ngrok** installed + free account | Creates the HTTPS tunnel ([ngrok.com/download](https://ngrok.com/download)) |
| **Cursor Desktop** | Where you change model settings |

---

## One-time setup

### 1. Install ngrok and connect your account

1. Download ngrok for your system and install it.
2. Sign up at [ngrok.com](https://ngrok.com).
3. In the ngrok dashboard, copy your **authtoken**.
4. In **Terminal** (Mac/Linux) or **PowerShell** (Windows), run (paste **your** token):

**Mac/Linux:**

```bash
ngrok config add-authtoken PASTE_YOUR_TOKEN_HERE
```

**Windows (PowerShell):**

```powershell
ngrok config add-authtoken PASTE_YOUR_TOKEN_HERE
```

### 2. Install the model (once per machine)

Open Terminal or PowerShell **in this repo folder** (the folder that contains `scripts`).

**Windows:**

```powershell
.\scripts\setup-qwen.ps1
```

**Mac/Linux:**

```bash
./scripts/setup-qwen.sh
```

Wait until it finishes without errors.

---

## Every time you want to use qwen25 in Cursor

Use **two windows**: one keeps the tunnel running; the other is for copy/paste helpers.

### Step A — Pick a tunnel login (you invent this)

This is **not** your ngrok account password. It is a **new** username and password **you make up** for the tunnel (like a Wi‑Fi password).

Examples:

- Username: `me`
- Password: `MyTunnel-2026-Secret`

**Rules:**

- Put them in the form `username:password` (one colon in the middle).
- Avoid `@`, `#`, and spaces in the password if you can (simpler copy/paste).

### Step B — Tell the script your tunnel login

**Windows (PowerShell)** — change the words in quotes to yours:

```powershell
$env:TUNNEL_AUTH = 'me:MyTunnel-2026-Secret'
```

**Mac/Linux:**

```bash
export TUNNEL_AUTH='me:MyTunnel-2026-Secret'
```

### Step C — Start the tunnel (leave this window open)

**Windows:**

```powershell
.\scripts\expose-for-cursor.ps1
```

**Mac/Linux:**

```bash
./scripts/expose-for-cursor.sh
```

You should see ngrok running and a line like **Forwarding** `https://something.ngrok-free.app` → …

**Do not close this window** while you use Cursor.

### Step D — Get the exact line for Cursor

Open a **second** Terminal/PowerShell in the same repo folder (with the **same** `TUNNEL_AUTH` still set).

**Windows:**

```powershell
$env:TUNNEL_AUTH = 'me:MyTunnel-2026-Secret'   # same as Step B
.\scripts\print-cursor-base-url.ps1
```

**Mac/Linux:**

```bash
export TUNNEL_AUTH='me:MyTunnel-2026-Secret'   # same as Step B
./scripts/print-cursor-base-url.sh
```

Copy the **whole** `https://…/v1` line it prints (it includes your tunnel login so Cursor can get through ngrok).

### Step E — Paste into Cursor

1. Open **Cursor** → **Settings** → **Models**.
2. Set:

| Setting | Value |
| --- | --- |
| **OpenAI API Key** | `ollama` (exactly this word) |
| **Override OpenAI Base URL** | Paste the full `https://…/v1` from Step D |
| **Add model** | `qwen25` |

3. In chat: turn **Auto** off, pick **`qwen25`**, send: `Reply with exactly: ollama-ok`

You should get back `ollama-ok`.

---

## Optional: test the tunnel before Cursor

With ngrok still running and `TUNNEL_AUTH` set:

**Mac/Linux:**

```bash
export OLLAMA_BASE_URL='https://me:MyTunnel-2026-Secret@YOUR-NGROK-HOST/v1'
./scripts/verify-endpoint.sh
```

Replace `YOUR-NGROK-HOST` with the host from ngrok (e.g. `abc123.ngrok-free.app`) and use the same user/password as in `TUNNEL_AUTH`.

Or run `./scripts/print-cursor-base-url.sh` and use its output:

```bash
export OLLAMA_BASE_URL='PASTE_OUTPUT_FROM_print-cursor-base-url'
./scripts/verify-endpoint.sh
```

---

## Troubleshooting

| Problem | What to try |
| --- | --- |
| Script says `TUNNEL_AUTH must be set` | Do Step B in the **same** window before running the expose script |
| `Ollama is not reachable` | Start Ollama (or re-run the setup script from one-time setup) |
| `ngrok is not installed` | Install ngrok and run `ngrok config add-authtoken …` |
| `print-cursor-base-url` fails | Start `expose-for-cursor` first and wait until ngrok shows **Forwarding** |
| Cursor errors but verify script passes | Make sure Base URL in Cursor matches **exactly** what `print-cursor-base-url` printed (including `/v1`) |
| Model not in list | Use `qwen25`, not `qwen2.5-coder:latest` |

---

## Safety reminders

- **Never share** your tunnel URL or `TUNNEL_AUTH`—anyone with them could use your Ollama while the tunnel is on.
- **Stop the tunnel** (close the expose window or Ctrl+C) when you are done.
- The word `ollama` as API key is **not** real security; the **tunnel password** (`TUNNEL_AUTH`) is what protects you on the internet.
