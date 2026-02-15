#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
MODE="${MODE:-off}" # off|on|both
AUTO_SEED_ADMIN="${AUTO_SEED_ADMIN:-1}" # 1|0
SMOKE_ALLOC_MODE="${SMOKE_ALLOC_MODE:-off}" # off|on
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
API_LOG="$TMP_DIR/api-dev.log"
PID_FILE="$TMP_DIR/api-dev.pid"
VERIFY_SCRIPT="$ROOT_DIR/scripts/smoke/run-api-verification.sh"

mkdir -p "$TMP_DIR"

pass() { echo "✅ $1"; }
warn() { echo "⚠️  $1"; }
fail() { echo "❌ $1"; exit 1; }

case "$MODE" in
  off|on|both) ;;
  *) fail "Invalid MODE=$MODE (expected off|on|both)" ;;
esac

case "$AUTO_SEED_ADMIN" in
  0|1) ;;
  *) fail "Invalid AUTO_SEED_ADMIN=$AUTO_SEED_ADMIN (expected 0|1)" ;;
esac

if [ ! -x "$VERIFY_SCRIPT" ]; then
  fail "Missing executable verify script: $VERIFY_SCRIPT"
fi

# Best-effort stop by pid file, then by port, then fallback pattern.
stop_existing_api() {
  local had=0

  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      had=1
    fi
    rm -f "$PID_FILE"
  fi

  local port_pids
  port_pids="$(lsof -ti tcp:3001 2>/dev/null || true)"
  if [ -n "$port_pids" ]; then
    echo "$port_pids" | xargs kill 2>/dev/null || true
    had=1
  fi

  if [ "$had" -eq 0 ]; then
    pkill -f "apps/api" 2>/dev/null || true
  fi

  sleep 1
}

start_api() {
  : > "$API_LOG"

  (
    cd "$ROOT_DIR"
    if [ "${NETWORK_COMMISSIONS_ENABLED:-}" != "" ]; then
      NETWORK_COMMISSIONS_ENABLED="$NETWORK_COMMISSIONS_ENABLED" COMMISSION_ALLOCATION_ENABLED="${COMMISSION_ALLOCATION_ENABLED:-}" pnpm -C apps/api dev >>"$API_LOG" 2>&1
    else
      COMMISSION_ALLOCATION_ENABLED="${COMMISSION_ALLOCATION_ENABLED:-}" pnpm -C apps/api dev >>"$API_LOG" 2>&1
    fi
  ) &
  local pid=$!
  echo "$pid" > "$PID_FILE"

  # Quick crash detection and fallback to start:dev
  sleep 2
  if ! kill -0 "$pid" 2>/dev/null; then
    (
      cd "$ROOT_DIR"
      if [ "${NETWORK_COMMISSIONS_ENABLED:-}" != "" ]; then
        NETWORK_COMMISSIONS_ENABLED="$NETWORK_COMMISSIONS_ENABLED" COMMISSION_ALLOCATION_ENABLED="${COMMISSION_ALLOCATION_ENABLED:-}" pnpm -C apps/api start:dev >>"$API_LOG" 2>&1
      else
        COMMISSION_ALLOCATION_ENABLED="${COMMISSION_ALLOCATION_ENABLED:-}" pnpm -C apps/api start:dev >>"$API_LOG" 2>&1
      fi
    ) &
    pid=$!
    echo "$pid" > "$PID_FILE"
    sleep 2
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "----- Last 120 lines: $API_LOG -----"
      tail -n 120 "$API_LOG" || true
      fail "API failed to start with pnpm -C apps/api dev and fallback start:dev"
    fi
  fi
}

check_health_once() {
  local path="$1"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL$path" || true)"

  case "$path" in
    /stats/me)
      [ "$code" = "200" ] || [ "$code" = "401" ] || [ "$code" = "403" ]
      ;;
    *)
      [ "$code" = "200" ]
      ;;
  esac
}

wait_for_health() {
  local max_wait=60
  local elapsed=0
  local paths=("/health" "/_health" "/stats/me")
  local pid_dead_streak=0

  while [ "$elapsed" -lt "$max_wait" ]; do
    local p
    for p in "${paths[@]}"; do
      if check_health_once "$p"; then
        pass "API health ready at $BASE_URL$p"
        return 0
      fi
    done

    if [ -f "$PID_FILE" ]; then
      local pid
      pid="$(cat "$PID_FILE" 2>/dev/null || true)"
      if [ -n "${pid:-}" ] && ! kill -0 "$pid" 2>/dev/null; then
        pid_dead_streak=$((pid_dead_streak + 1))
      else
        pid_dead_streak=0
      fi
      if [ "$pid_dead_streak" -ge 5 ]; then
        # Some pnpm/nest start modes can re-parent the real node process.
        # Fail only if health is still unreachable after repeated dead-pid checks.
        echo "----- Last 120 lines: $API_LOG -----"
        tail -n 120 "$API_LOG" || true
        fail "API process appears dead and health is still unreachable"
      fi
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  echo "----- Last 120 lines: $API_LOG -----"
  tail -n 120 "$API_LOG" || true
  fail "Health check timeout after ${max_wait}s"
}

cleanup_started_api() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    fi
    rm -f "$PID_FILE"
  fi
}

run_verify() {
  local verify_mode="$1"
  (
    cd "$ROOT_DIR"
    if [ -n "${DATABASE_URL:-}" ]; then
      BASE_URL="$BASE_URL" MODE="$verify_mode" DATABASE_URL="$DATABASE_URL" SMOKE_ALLOC_MODE="$SMOKE_ALLOC_MODE" "$VERIFY_SCRIPT"
    else
      BASE_URL="$BASE_URL" MODE="$verify_mode" SMOKE_ALLOC_MODE="$SMOKE_ALLOC_MODE" "$VERIFY_SCRIPT"
    fi
  )
}

seed_admin_user() {
  if [ "$AUTO_SEED_ADMIN" = "0" ]; then
    warn "AUTO_SEED_ADMIN=0, skipping db:seed"
    return 0
  fi

  echo "==> Seeding admin/demo users (pnpm -C apps/api db:seed)"
  (
    cd "$ROOT_DIR"
    pnpm -C apps/api db:seed >>"$API_LOG" 2>&1
  ) || {
    echo "----- Last 120 lines: $API_LOG -----"
    tail -n 120 "$API_LOG" || true
    fail "db:seed failed"
  }
  pass "db:seed completed"
}

main() {
  echo "==> restart-and-verify"
  echo "BASE_URL=$BASE_URL"
  echo "MODE=$MODE"
  echo "AUTO_SEED_ADMIN=$AUTO_SEED_ADMIN"
  echo "SMOKE_ALLOC_MODE=$SMOKE_ALLOC_MODE"
  echo "LOG=$API_LOG"

  local hard_fail=0

  trap 'cleanup_started_api' EXIT

  if [ "$MODE" = "off" ]; then
    stop_existing_api
    NETWORK_COMMISSIONS_ENABLED="" start_api
    wait_for_health
    seed_admin_user
    run_verify off || hard_fail=1
  elif [ "$MODE" = "on" ]; then
    stop_existing_api
    NETWORK_COMMISSIONS_ENABLED=1 start_api
    wait_for_health
    seed_admin_user
    run_verify on || hard_fail=1
  else
    stop_existing_api
    NETWORK_COMMISSIONS_ENABLED="" start_api
    wait_for_health
    seed_admin_user
    run_verify off || hard_fail=1

    cleanup_started_api

    stop_existing_api
    NETWORK_COMMISSIONS_ENABLED=1 start_api
    wait_for_health
    seed_admin_user
    run_verify on || hard_fail=1
  fi

  echo
  echo "===== SUMMARY ====="
  if [ "$hard_fail" -eq 0 ]; then
    pass "Restart + verification completed"
    pass "Log file: $API_LOG"
  else
    warn "Verification failed. Log file kept at: $API_LOG"
    fail "Restart + verification failed"
  fi
}

main "$@"
