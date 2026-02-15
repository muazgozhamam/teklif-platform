#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"

API_PORT="${API_PORT:-3001}"
DASHBOARD_PORT="${DASHBOARD_PORT:-3000}"
WAIT_SECONDS="${WAIT_SECONDS:-60}"

API_BASE_URL="${API_BASE_URL:-http://localhost:${API_PORT}}"
DASHBOARD_BASE_URL="${DASHBOARD_BASE_URL:-http://localhost:${DASHBOARD_PORT}}"

API_LOG="$TMP_DIR/api-dev.log"
DASHBOARD_LOG="$TMP_DIR/dashboard-dev.log"
API_PID_FILE="$TMP_DIR/api-dev.pid"
DASHBOARD_PID_FILE="$TMP_DIR/dashboard-dev.pid"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ Missing command: $1"
    exit 1
  }
}

stop_pid_file() {
  local file="$1"
  if [ -f "$file" ]; then
    local pid
    pid="$(cat "$file" 2>/dev/null || true)"
    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 0.5
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$file"
  fi
}

kill_port() {
  local port="$1"
  local pids
  pids="$(lsof -ti tcp:"$port" 2>/dev/null || true)"
  if [ -n "${pids:-}" ]; then
    echo "⚠️  Port $port occupied -> stopping $pids"
    kill $pids 2>/dev/null || true
    sleep 0.5
    kill -9 $pids 2>/dev/null || true
  fi
}

wait_for_url() {
  local url="$1"
  local label="$2"
  local i=0
  while [ "$i" -lt "$WAIT_SECONDS" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "✅ $label ready: $url"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

need_cmd pnpm
need_cmd curl
need_cmd lsof

mkdir -p "$TMP_DIR"

echo "==> dev-up"
echo "ROOT_DIR=$ROOT_DIR"
echo "API_BASE_URL=$API_BASE_URL"
echo "DASHBOARD_BASE_URL=$DASHBOARD_BASE_URL"

# best-effort cleanup
stop_pid_file "$API_PID_FILE"
stop_pid_file "$DASHBOARD_PID_FILE"
kill_port "$API_PORT"
kill_port "$DASHBOARD_PORT"

echo "==> starting API (apps/api start:dev)"
(
  cd "$ROOT_DIR"
  nohup env PORT="$API_PORT" pnpm -C apps/api start:dev >"$API_LOG" 2>&1 &
  echo $! >"$API_PID_FILE"
)

if ! wait_for_url "$API_BASE_URL/health" "API"; then
  echo "❌ API failed to start"
  echo "---- API log (last 120 lines) ----"
  tail -n 120 "$API_LOG" || true
  exit 1
fi

echo "==> starting Dashboard (apps/dashboard dev)"
(
  cd "$ROOT_DIR"
  nohup pnpm -C apps/dashboard dev --port "$DASHBOARD_PORT" >"$DASHBOARD_LOG" 2>&1 &
  echo $! >"$DASHBOARD_PID_FILE"
)

if ! wait_for_url "$DASHBOARD_BASE_URL/login" "Dashboard"; then
  echo "❌ Dashboard failed to start"
  echo "---- Dashboard log (last 120 lines) ----"
  tail -n 120 "$DASHBOARD_LOG" || true
  exit 1
fi

echo
echo "✅ Dev environment is ready"
echo "   API:       $API_BASE_URL/health"
echo "   Dashboard: $DASHBOARD_BASE_URL/login"
echo "   API log:   $API_LOG"
echo "   UI log:    $DASHBOARD_LOG"
echo "   API pid:   $(cat "$API_PID_FILE")"
echo "   UI pid:    $(cat "$DASHBOARD_PID_FILE")"
