#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
MODE="${MODE:-off}" # off|on|both
HEALTH_PATH="${HEALTH_PATH:-}"
SMOKE_ALLOC_MODE="${SMOKE_ALLOC_MODE:-off}" # off|on

if [ ! -x "./scripts/smoke/smoke-pack-task45.sh" ]; then
  echo "❌ Missing executable: ./scripts/smoke/smoke-pack-task45.sh"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "❌ Missing binary: curl"
  exit 1
fi

pass() { echo "✅ $1"; }
warn() { echo "⚠️  $1"; }
fail() { echo "❌ $1"; exit 1; }

case "$MODE" in
  off|on|both) ;;
  *) fail "Invalid MODE=$MODE (expected off|on|both)" ;;
esac

check_health_path() {
  local path="$1"
  local tmp status
  tmp="$(mktemp)"
  status="$(curl -sS -o "$tmp" -w "%{http_code}" "$BASE_URL$path" || true)"

  if [ "$path" = "/stats/me" ]; then
    # /stats/me is auth-protected in many environments; 401/403 still proves API is reachable.
    if [ "$status" = "200" ] || [ "$status" = "401" ] || [ "$status" = "403" ]; then
      rm -f "$tmp"
      return 0
    fi
  else
    if [ "$status" = "200" ]; then
      rm -f "$tmp"
      return 0
    fi
  fi

  LAST_HEALTH_STATUS="$status"
  LAST_HEALTH_BODY="$(head -c 240 "$tmp" | tr '\n' ' ')"
  rm -f "$tmp"
  return 1
}

LAST_HEALTH_STATUS=""
LAST_HEALTH_BODY=""

HEALTH_CANDIDATES=()
if [ -n "$HEALTH_PATH" ]; then
  HEALTH_CANDIDATES+=("$HEALTH_PATH")
else
  HEALTH_CANDIDATES+=("/health" "/_health" "/stats/me")
fi

echo "==> API verification"
echo "BASE_URL=$BASE_URL"
echo "MODE=$MODE"
echo "SMOKE_ALLOC_MODE=$SMOKE_ALLOC_MODE"

HEALTH_OK=0
for p in "${HEALTH_CANDIDATES[@]}"; do
  if check_health_path "$p"; then
    HEALTH_OK=1
    pass "Health OK ($BASE_URL$p)"
    break
  fi
done

if [ "$HEALTH_OK" -ne 1 ]; then
  fail "Health check failed. Last status=$LAST_HEALTH_STATUS body='${LAST_HEALTH_BODY:-<empty>}'"
fi

SMOKE_OFF_OK=0
SMOKE_ON_OK=0
DIAG_NOTE="⚠️  Diag skipped (DATABASE_URL not set)"
if [ -n "${DATABASE_URL:-}" ]; then
  DIAG_NOTE="✅ Diag passed/attempted via smoke pack (see output)"
fi

run_smoke() {
  local flag_mode="$1"
  echo "==> Running smoke-pack (SMOKE_FLAG_MODE=$flag_mode)"
  if [ -n "${DATABASE_URL:-}" ]; then
    BASE_URL="$BASE_URL" DATABASE_URL="$DATABASE_URL" SMOKE_FLAG_MODE="$flag_mode" SMOKE_ALLOC_MODE="$SMOKE_ALLOC_MODE" ./scripts/smoke/smoke-pack-task45.sh
  else
    BASE_URL="$BASE_URL" SMOKE_FLAG_MODE="$flag_mode" SMOKE_ALLOC_MODE="$SMOKE_ALLOC_MODE" ./scripts/smoke/smoke-pack-task45.sh
  fi
}

case "$MODE" in
  off)
    run_smoke off || fail "Smoke OFF failed"
    SMOKE_OFF_OK=1
    ;;
  on)
    run_smoke on || fail "Smoke ON failed"
    SMOKE_ON_OK=1
    ;;
  both)
    # smoke-pack in both mode executes OFF checks and prints ON rerun instruction by design.
    run_smoke both || fail "Smoke BOTH failed"
    SMOKE_OFF_OK=1
    warn "Smoke ON not executed in MODE=both by design. Restart API with NETWORK_COMMISSIONS_ENABLED=1 and rerun MODE=on."
    ;;
esac

echo
echo "===== SUMMARY ====="
pass "Health OK"
if [ "$SMOKE_OFF_OK" -eq 1 ]; then
  pass "Smoke OFF OK"
fi
if [ "$SMOKE_ON_OK" -eq 1 ]; then
  pass "Smoke ON OK"
elif [ "$MODE" = "both" ]; then
  warn "Smoke ON pending (run MODE=on after restarting API with NETWORK_COMMISSIONS_ENABLED=1)"
fi
echo "$DIAG_NOTE"

echo
echo "✅ API verification completed"
