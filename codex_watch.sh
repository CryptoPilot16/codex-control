#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

: "${PUSHOVER_APP_TOKEN:?Missing PUSHOVER_APP_TOKEN}"
: "${PUSHOVER_USER_KEY:?Missing PUSHOVER_USER_KEY}"
: "${APPROVE_SECRET:?Missing APPROVE_SECRET}"

TMUX_SESSION="${TMUX_SESSION:-codex:0.0}"
APPROVE_PORT="${APPROVE_PORT:-8787}"
APPROVE_HOST="${APPROVE_HOST:-127.0.0.1}"
APPROVE_URL="${APPROVE_URL:-http://${APPROVE_HOST}:${APPROVE_PORT}/approve}"
LOG_FILE="${CODEX_WATCH_LOG:-/tmp/codex_watch.log}"

# Ensure approval link carries secret for webhook auth.
if [[ "$APPROVE_URL" != *"secret="* ]]; then
  if [[ "$APPROVE_URL" == *"?"* ]]; then
    APPROVE_URL="${APPROVE_URL}&secret=${APPROVE_SECRET}"
  else
    APPROVE_URL="${APPROVE_URL}?secret=${APPROVE_SECRET}"
  fi
fi

# Prevent spamming every 2 seconds.
LAST_SENT_FILE="${LAST_SENT_FILE:-/tmp/codex_approval_last_sent}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-30}"

now_ts() { date +%s; }

should_send() {
  if [[ -f "$LAST_SENT_FILE" ]]; then
    local last
    last=$(cat "$LAST_SENT_FILE" || echo 0)
    (( $(now_ts) - last >= COOLDOWN_SECONDS ))
  else
    return 0
  fi
}

send_push() {
  local resp
  resp=$(curl -s \
    -F "token=$PUSHOVER_APP_TOKEN" \
    -F "user=$PUSHOVER_USER_KEY" \
    -F "title=Codex Approval Needed" \
    -F "message=Tap Approve to continue" \
    -F "url=$APPROVE_URL" \
    -F "url_title=Approve" \
    https://api.pushover.net/1/messages.json)

  echo "$(date) pushover_resp=$resp" >> "$LOG_FILE"
}

IN_PROMPT=0

while true; do
  pane="$(tmux capture-pane -pt "$TMUX_SESSION" -S -200 2>/dev/null || true)"

  if echo "$pane" | grep -Eq "Would you like to run|Press enter to confirm|Yes, proceed"; then
    if [[ "$IN_PROMPT" -eq 0 ]]; then
      if should_send; then
        echo "$(date) detected approval prompt" >> "$LOG_FILE"
        send_push || echo "$(date) send_push failed" >> "$LOG_FILE"
        now_ts > "$LAST_SENT_FILE"
      fi
      IN_PROMPT=1
    fi
  else
    IN_PROMPT=0
  fi

  sleep 2
done
