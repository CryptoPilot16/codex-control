# Codex Control

Codex Control lets you approve Codex permission prompts from your Apple Watch ⌚ while Codex runs in `tmux`.
When Codex asks for command approval, the watcher sends a push notification and a one-tap Watch Shortcut can approve the prompt through a secure webhook.

## What This Does
When Codex shows a prompt like "Do you want me to run this command?", the system:
1. sends you a push notification immediately, and
2. lets you approve from your watch with a one-tap Shortcut that triggers approval on the server.

## Architecture
### Components
- **Codex (`tmux` session):** Codex runs inside a persistent `tmux` session so it keeps running if SSH disconnects.
- **Watcher (`codex_watch.sh`):** polling loop using `tmux capture-pane` to detect approval prompts and send Pushover alerts.
- **Webhook (`approve_webhook.py`):** local HTTP server receiving `/approve` actions and injecting keys into Codex via `tmux send-keys`.
- **Tailscale Serve (HTTPS bridge):** exposes the local webhook over your tailnet using your `*.ts.net` HTTPS URL without opening public ports.
- **Apple Watch Shortcut ("codex approve"):** watch action that performs a simple `GET` request to approve.
- **Pushover:** notification channel for reliable phone/watch alerts.

## Apple Watch Workflow
### Why two apps?
- **Pushover** = alerts (phone + watch notifications)
- **Shortcuts** = action (watch executes the approval request)

### Flow
1. Codex shows an approval prompt.
2. `codex_watch.sh` detects it and sends a Pushover notification.
3. You glance at your watch.
4. You run the `codex approve` Shortcut on the watch.
5. The Shortcut calls the Tailscale HTTPS endpoint.
6. `approve_webhook.py` validates the secret and injects approval into the Codex `tmux` session.
7. Codex continues running the command.

## Security Model
- Webhook stays local and is exposed to your devices via Tailscale HTTPS (tailnet-only).
- Approval requires a shared secret (`APPROVE_SECRET`).
- Secret can be sent as `?secret=...`, which works well for browser and Watch Shortcut flows.
- `X-Secret` header is also accepted for CLI and automation compatibility.
- No public port exposure is required.

## Why `tmux`
`tmux` keeps Codex persistent. You can close Termius/SSH and Codex keeps running. The webhook injects keys into the target `tmux` pane, so approvals still work when you are not actively connected.

## Requirements
- `python3`
- `tmux`
- `curl`
- Linux shell environment with access to `/tmp`

## Setup
```bash
cd /opt/codex-control
cp .env.example .env
```

Edit `.env` and set at minimum:
- `APPROVE_SECRET`
- `PUSHOVER_APP_TOKEN`
- `PUSHOVER_USER_KEY`

Never commit `.env`.

## Environment Variables
- `APPROVE_SECRET` (required): shared secret used by webhook auth.
- `PUSHOVER_APP_TOKEN` (required): Pushover application token.
- `PUSHOVER_USER_KEY` (required): destination Pushover user key.
- `TMUX_SESSION` (default `codex:0.0`): target pane/session for `tmux send-keys` and `capture-pane`.
- `APPROVE_HOST` (legacy): configured host value; current `approve_webhook.py` build binds to a fixed host instead.
- `APPROVE_PORT` (default `8787`): webhook bind port.
- `CODEX_WATCH_LOG` (default `/tmp/codex_watch.log`): watcher log path.
- `LAST_SENT_FILE` (default `/tmp/codex_approval_last_sent`): cooldown state file.
- `COOLDOWN_SECONDS` (default `30`): minimum time between push notifications.
- `APPROVE_URL` (optional): override destination link; secret query param is auto-added if missing.

## Network Binding (Current Behavior)
The current `approve_webhook.py` version binds to a fixed host configured in code and uses `${APPROVE_PORT}` for the port.
For public repos, avoid documenting private or internal host addresses; keep host-specific values in local-only changes.

## Run
### Option 1: Start each service manually
Terminal 1:
```bash
cd /opt/codex-control
set -a; source .env; set +a
python3 approve_webhook.py
```

Terminal 2:
```bash
cd /opt/codex-control
bash ./codex_watch.sh
```

### Option 2: Restart both services in background
```bash
cd /opt/codex-control
bash ./restart.sh
```

## Webhook Endpoints
All endpoints require the secret via either:
- `X-Secret: <APPROVE_SECRET>` header, or
- `?secret=<APPROVE_SECRET>` query parameter.

Supported paths:
- `/approve`: sends `y` + Enter.
- `/approve2`: sends `p` (and Enter on `GET`).
- `/deny`: sends `esc` on `GET`, sends `3` on `POST`.

`approve_webhook.py` currently listens on the fixed host configured in code and `${APPROVE_PORT}`.

## Stop
```bash
pkill -f approve_webhook.py
pkill -f codex_watch.sh
```

To stop notification polling only:
```bash
cd /opt/codex-control
bash ./stop.sh
```

## Logs and Checks
- Watcher log: `${CODEX_WATCH_LOG}` (default `/tmp/codex_watch.log`)
- Webhook log (if started with `restart.sh`): `/tmp/approve_webhook.log`

Quick checks:
```bash
ss -ltnp | grep 8787
ps aux | grep -E "approve_webhook.py|codex_watch.sh" | grep -v grep
```

## Tmux Attach
```bash
tmux attach -t codex
```

If your session target differs, use the value of `TMUX_SESSION`.

## Recent Updates (2026-02-17)
- `approve_webhook.py`: validates `?secret=` query parameter directly and still accepts `X-Secret` header for compatibility.
- `restart.sh`: explicitly sources `/opt/codex-control/.env` before starting services, avoiding dependence on caller working directory.
