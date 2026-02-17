# Codex Control

Local approval bridge for Codex sessions running in `tmux`.  
It watches your Codex pane for approval prompts, sends a Pushover notification, and accepts approval/deny actions through a local webhook.

## Components
- `codex_watch.sh`: polls a tmux pane and sends push notifications when approval text appears.
- `approve_webhook.py`: local HTTP server that converts webhook actions into tmux key presses.
- `restart.sh`: convenience script to stop both services and start them again with `.env`.
- `stop.sh`: helper script to stop notification polling (`codex_watch.sh`) only.
- `.env.example`: template for required and optional configuration.

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
- `APPROVE_HOST` (default `127.0.0.1`): webhook bind host.
- `APPROVE_PORT` (default `8787`): webhook bind port.
- `CODEX_WATCH_LOG` (default `/tmp/codex_watch.log`): watcher log path.
- `LAST_SENT_FILE` (default `/tmp/codex_approval_last_sent`): cooldown state file.
- `COOLDOWN_SECONDS` (default `30`): minimum time between push notifications.
- `APPROVE_URL` (optional): override destination link; secret query param is auto-added if missing.

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

`approve_webhook.py` listens on `${APPROVE_HOST}:${APPROVE_PORT}` (default `127.0.0.1:8787`).

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
