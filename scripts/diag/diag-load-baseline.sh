#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CONCURRENCY="${CONCURRENCY:-5}"
REQUESTS_PER_ENDPOINT="${REQUESTS_PER_ENDPOINT:-40}"

HEALTH_P95_BUDGET_MS="${HEALTH_P95_BUDGET_MS:-150}"
STATS_P95_BUDGET_MS="${STATS_P95_BUDGET_MS:-500}"
ADMIN_USERS_P95_BUDGET_MS="${ADMIN_USERS_P95_BUDGET_MS:-700}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

need_cmd curl
need_cmd jq
need_cmd awk
need_cmd sort
need_cmd xargs

echo "==> diag-load-baseline"
echo "BASE_URL=$BASE_URL"
echo "CONCURRENCY=$CONCURRENCY REQUESTS_PER_ENDPOINT=$REQUESTS_PER_ENDPOINT"

curl -fsS "$BASE_URL/health" | jq -e '.ok == true' >/dev/null || {
  echo "❌ Health check failed at $BASE_URL/health"
  exit 1
}

auth_json="$(curl -fsS -X POST "$BASE_URL/auth/login" -H 'content-type: application/json' -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")"
ADMIN_TOKEN="$(echo "$auth_json" | jq -r '.access_token // .accessToken // empty')"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }

run_probe() {
  local label="$1"
  local url="$2"
  local auth_mode="$3"
  local outfile="$4"

  rm -f "$outfile"
  seq "$REQUESTS_PER_ENDPOINT" | xargs -I{} -P "$CONCURRENCY" bash -c '
    url="$1"
    auth_mode="$2"
    token="$3"
    if [ "$auth_mode" = "bearer" ]; then
      ms=$(curl -sS -o /dev/null -w "%{time_total}" -H "authorization: Bearer $token" "$url" | awk "{ printf \"%.3f\\n\", \$1 * 1000 }")
    else
      ms=$(curl -sS -o /dev/null -w "%{time_total}" "$url" | awk "{ printf \"%.3f\\n\", \$1 * 1000 }")
    fi
    echo "$ms"
  ' _ "$url" "$auth_mode" "$ADMIN_TOKEN" >> "$outfile"

  local count
  count=$(wc -l < "$outfile" | tr -d ' ')
  if [ "$count" -lt 1 ]; then
    echo "❌ $label no samples"
    return 1
  fi

  local sorted
  sorted="$(mktemp)"
  sort -n "$outfile" > "$sorted"

  local p50_index p95_index p50 p95 max
  p50_index=$(( (count * 50 + 99) / 100 ))
  p95_index=$(( (count * 95 + 99) / 100 ))
  [ "$p50_index" -lt 1 ] && p50_index=1
  [ "$p95_index" -lt 1 ] && p95_index=1

  p50=$(awk -v n="$p50_index" 'NR==n {print; exit}' "$sorted")
  p95=$(awk -v n="$p95_index" 'NR==n {print; exit}' "$sorted")
  max=$(awk 'END {print}' "$sorted")

  rm -f "$sorted"

  echo "$label samples=$count p50_ms=$p50 p95_ms=$p95 max_ms=$max"
  printf '%s\n' "$p95"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

p95_health="$(run_probe "GET /health" "$BASE_URL/health" "none" "$tmpdir/health.txt" | tee "$tmpdir/health.log" | tail -n1)"
p95_stats="$(run_probe "GET /stats/me" "$BASE_URL/stats/me" "bearer" "$tmpdir/stats.txt" | tee "$tmpdir/stats.log" | tail -n1)"
p95_admin_users="$(run_probe "GET /admin/users/paged" "$BASE_URL/admin/users/paged?take=20&skip=0" "bearer" "$tmpdir/admin_users.txt" | tee "$tmpdir/admin_users.log" | tail -n1)"

fail=0

check_budget() {
  local label="$1"
  local p95="$2"
  local budget="$3"

  if awk -v p="$p95" -v b="$budget" 'BEGIN { exit !(p <= b) }'; then
    echo "✅ $label budget OK (p95=${p95}ms <= ${budget}ms)"
  else
    echo "❌ $label budget FAIL (p95=${p95}ms > ${budget}ms)"
    fail=1
  fi
}

check_budget "GET /health" "$p95_health" "$HEALTH_P95_BUDGET_MS"
check_budget "GET /stats/me" "$p95_stats" "$STATS_P95_BUDGET_MS"
check_budget "GET /admin/users/paged" "$p95_admin_users" "$ADMIN_USERS_P95_BUDGET_MS"

echo
if [ "$fail" -ne 0 ]; then
  echo "❌ diag-load-baseline FAILED"
  exit 1
fi

echo "✅ diag-load-baseline OK"
