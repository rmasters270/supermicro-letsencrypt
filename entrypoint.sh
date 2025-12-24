#!/usr/bin/env bash
set -euo pipefail

MAIN_SCRIPT="/home/lego/le-supermicro-ipmi.sh"

trap 'STOP=true' SIGTERM SIGINT

echo "[entrypoint] First run"
"$MAIN_SCRIPT"

# Only use force update on first run
export FORCE_UPDATE="false"

if [ -n "${SCHEDULE:-}" ]; then
  echo "[entrypoint] Running with cron schedule: $SCHEDULE"
  CRON_FILE="$(mktemp)"
  echo "$SCHEDULE $MAIN_SCRIPT" > "$CRON_FILE"
  exec /usr/local/bin/supercronic -debug "$CRON_FILE"
fi
