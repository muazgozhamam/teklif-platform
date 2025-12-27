#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
BASE_URL="${BASE_URL:-http://localhost:3001}"
LOG="$ROOT/.tmp-api-wizdbg.log"
AUTO_STOP="${AUTO_STOP:-1}" # AUTO_STOP=1 -> iş bitince API'yi kapatır

echo "==> 0) Free port 3001"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [[ -n "${PIDS}" ]]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

echo
echo "==> 1) Build API"
cd "$ROOT/apps/api"
pnpm -s build

echo
echo "==> 2) Start API (background) with logs: $LOG"
rm -f "$LOG"
PORT=3001 pnpm -s start:dev >"$LOG" 2>&1 &
API_PID=$!
echo "   - API_PID=$API_PID"

echo
echo "==> 3) Wait for /health"
for i in {1..60}; do
  if curl -sS "$BASE_URL/health" >/dev/null 2>&1; then
    echo "   ✅ API is up: $BASE_URL"
    break
  fi
  sleep 0.5
  if ! kill -0 "$API_PID" >/dev/null 2>&1; then
    echo "❌ API process exited early. Tail log:"
    tail -n 120 "$LOG" || true
    exit 1
  fi
  if [[ "$i" == "60" ]]; then
    echo "❌ API did not become healthy in time. Tail log:"
    tail -n 120 "$LOG" || true
    exit 1
  fi
done

echo
echo "==> 4) Run wizard+match doctor"
cd "$ROOT"
bash scripts/wizard-and-match-doctor.sh || true

echo
echo "==> 5) Extract WIZDBG logs"
echo "---- WIZDBG (last 200 lines around matches) ----"
# Show any debug lines; if none, show nearby lead route logs (still helpful)
if rg -n "WIZDBG_" "$LOG" >/dev/null 2>&1; then
  rg -n "WIZDBG_" "$LOG" || true
else
  echo "⚠️ No WIZDBG_ lines found in log."
  echo "Tail of log for context:"
  tail -n 120 "$LOG" || true
fi
echo "-----------------------------------------------"

if [[ "$AUTO_STOP" == "1" ]]; then
  echo
  echo "==> 6) Stop API (AUTO_STOP=1)"
  kill -9 "$API_PID" >/dev/null 2>&1 || true
  echo "✅ Stopped API_PID=$API_PID"
else
  echo
  echo "==> 6) Keeping API running (AUTO_STOP=0). PID=$API_PID, log=$LOG"
fi
