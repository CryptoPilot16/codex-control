#!/usr/bin/env bash
set -euo pipefail

PATTERN="codex_watch.sh"

if pgrep -f "$PATTERN" >/dev/null; then
  pkill -f "$PATTERN"
  echo "Notifications stopped."
else
  echo "Notifications already stopped."
fi
