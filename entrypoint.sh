#!/usr/bin/env bash
set -euo pipefail

MAIN_SCRIPT="/home/lego/le-supermicro-ipmi.sh"
HEALTH_FILE="/tmp/last-run"
STOP=false
SECONDS_PER_DAY=86400

trap 'STOP=true' SIGTERM SIGINT

run_once() {
  echo "[entrypoint] Running once"
  exec "$MAIN_SCRIPT"
  date +%s > "$HEALTH_FILE"
}

print_interval() {
  local s="$1"
  local d=$((s / 86400))
  local h=$(( (s % 86400) / 3600 ))

  [[ $d -gt 0 ]] && printf "%dd " "$d"
  [[ $h -gt 0 ]] && printf "%dh" "$h"
}

parse_schedule() {
  if [[ "$SCHEDULE" =~ ^([1-7])d$ ]]; then
    days="${BASH_REMATCH[1]}"
    echo $(( days * SECONDS_PER_DAY ))
    return
  fi

  echo "[entrypoint] Invalid SCHEDULE: $SCHEDULE" >&2
  echo "[entrypoint] Allowed values: 1d .. 7d" >&2
  exit 1
}

sleep_loop() {
  local interval="$1"

  echo "[entrypoint] Running every $((interval / SECONDS_PER_DAY)) day(s)"

  while true; do
    "$MAIN_SCRIPT"
    date +%s > "$HEALTH_FILE"

    if $STOP; then
      echo "[entrypoint] Received shutdown signal, exiting"
      exit 0
    fi

    echo "[entrypoint] Sleeping for $(print_interval "$interval")"
    sleep "$interval" &
    wait $!
  done
}

if [[ -z "${SCHEDULE:-}" ]]; then
  run_once
else
  interval="$(parse_schedule)"
  sleep_loop "$interval"
fi
