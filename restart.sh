#!/usr/bin/env bash
set -e

pkill -f approve_webhook.py || true
pkill -f codex_watch.sh || true

cd /opt/codex-control
set -a; source .env; set +a

nohup python3 approve_webhook.py > /tmp/approve_webhook.log 2>&1 &
nohup bash ./codex_watch.sh >> /tmp/codex_watch.log 2>&1 &

sleep 1
ss -ltnp | grep 8787 || true
ps aux | grep codex_watch.sh | grep -v grep || true
echo "Restarted."
