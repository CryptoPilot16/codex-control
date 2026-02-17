# Codex Control

Lightweight local tooling to approve Codex prompts from a push notification.

## Public-safe defaults
- No secrets are hardcoded in scripts.
- Configuration is read from environment variables.
- Copy `.env.example` to `.env` and set your own values.
- Do **not** commit `.env` to a public repo.

## Setup
```bash
cd /opt/codex-control
cp .env.example .env
# edit .env with your real values
```

## How to start
Run both services from `/opt/codex-control`:

```bash
cd /opt/codex-control
set -a; source .env; set +a
python3 approve_webhook.py
```

In a second shell:

```bash
cd /opt/codex-control
bash ./codex_watch.sh
```

## How to stop
Stop the two processes:

```bash
pkill -f approve_webhook.py
pkill -f codex_watch.sh
```

## Where logs are
- Watcher log file: `${CODEX_WATCH_LOG}` (default `/tmp/codex_watch.log`)
- Webhook logs: stdout/stderr of the shell where `approve_webhook.py` is running

## Where .env is
`/opt/codex-control/.env`

## What port it runs on
`approve_webhook.py` listens on `${APPROVE_HOST}:${APPROVE_PORT}`.
Defaults: `127.0.0.1:8787`.

## How to attach tmux
```bash
tmux attach -t codex
```

If your session name differs, use your configured `TMUX_SESSION` target.
