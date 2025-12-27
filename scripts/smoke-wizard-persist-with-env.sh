#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
LOG="$ROOT/.tmp-wizpersist.log"
PORT="${PORT:-3001}"
BASE_URL="${BASE_URL:-http://localhost:${PORT}}"

pick_db_url() {
  if [[ -f "$API_DIR/.env" ]]; then
    awk -F= '/^DATABASE_URL=/{sub(/^DATABASE_URL=/,""); print; exit}' "$API_DIR/.env"
    return 0
  fi
  if [[ -f "$ROOT/.env" ]]; then
    awk -F= '/^DATABASE_URL=/{sub(/^DATABASE_URL=/,""); print; exit}' "$ROOT/.env"
    return 0
  fi
  echo ""
}

DB_URL="$(pick_db_url | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
if [[ -z "${DB_URL}" ]]; then
  echo "❌ DATABASE_URL not found in $API_DIR/.env or $ROOT/.env"
  exit 2
fi

echo "==> 1) Free port $PORT"
PIDS="$(lsof -nP -t -iTCP:${PORT} -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

echo
echo "==> 2) Start API from dist with DATABASE_URL -> $LOG"
rm -f "$LOG"
DATABASE_URL="$DB_URL" PORT="$PORT" node "$API_DIR/dist/src/main.js" >"$LOG" 2>&1 &
API_PID=$!
echo "API_PID=$API_PID"

echo
echo "==> 3) Wait health"
ok=0
for i in {1..60}; do
  if curl -sS "$BASE_URL/health" >/dev/null 2>&1; then
    ok=1
    echo "OK: health"
    break
  fi
  sleep 0.2
done

if [[ "$ok" != "1" ]]; then
  echo "❌ API didn't become healthy. Last 120 log lines:"
  tail -n 120 "$LOG" || true
  kill -9 "$API_PID" || true
  exit 3
fi

echo
echo "==> 4) Run doctor"
BASE_URL="$BASE_URL" bash scripts/wizard-and-match-doctor.sh || true

echo
echo "==> 5) Stop API"
kill -9 "$API_PID" || true

echo
echo "==> 6) Show WIZPERS logs"
rg -n "WIZPERS_" "$LOG" || echo "WIZPERS yok"
echo
echo "==> DONE (log: $LOG)"
