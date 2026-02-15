#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}
need_cmd curl
need_cmd jq

auth_login() {
  local email="$1"
  local password="$2"
  curl -fsS -X POST "$BASE_URL/auth/login" \
    -H 'content-type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}"
}

echo "==> smoke-background-jobs"
echo "BASE_URL=$BASE_URL"

curl -fsS "$BASE_URL/health" | jq -e '.ok == true' >/dev/null

echo "==> 1) Create won snapshot baseline"
FLOW_OUT="$(BASE_URL="$BASE_URL" ./scripts/smoke-commission-won.sh)"
DEAL_ID="$(echo "$FLOW_OUT" | awk -F= '/^OK dealId=/{print $2}' | tail -n1 | tr -d '[:space:]')"
[ -n "$DEAL_ID" ] || { echo "❌ dealId parse failed"; exit 1; }

echo "==> 2) Admin login"
ADMIN_LOGIN="$(auth_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
ADMIN_TOKEN="$(echo "$ADMIN_LOGIN" | jq -r '.access_token // .accessToken // empty')"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }
AUTH="authorization: Bearer $ADMIN_TOKEN"

echo "==> 3) Resolve snapshot id"
SNAP="$(curl -fsS "$BASE_URL/deals/$DEAL_ID/commission-snapshot" -H "$AUTH")"
SNAP_ID="$(echo "$SNAP" | jq -r '.id // empty')"
[ -n "$SNAP_ID" ] || { echo "❌ snapshot id missing"; exit 1; }

KEY="job-smoke-$SNAP_ID"

echo "==> 4) Trigger job first time"
RUN1="$(curl -fsS -X POST "$BASE_URL/admin/jobs/allocation-integrity" -H "$AUTH" -H 'content-type: application/json' -d "{\"snapshotId\":\"$SNAP_ID\",\"idempotencyKey\":\"$KEY\"}")"
echo "$RUN1" | jq -e '.run.status == "SUCCEEDED"' >/dev/null
RUN_ID_1="$(echo "$RUN1" | jq -r '.run.id')"

echo "==> 5) Trigger job second time (idempotent reuse)"
RUN2="$(curl -fsS -X POST "$BASE_URL/admin/jobs/allocation-integrity" -H "$AUTH" -H 'content-type: application/json' -d "{\"snapshotId\":\"$SNAP_ID\",\"idempotencyKey\":\"$KEY\"}")"
echo "$RUN2" | jq -e '.reused == true' >/dev/null
RUN_ID_2="$(echo "$RUN2" | jq -r '.run.id')"
[ "$RUN_ID_1" = "$RUN_ID_2" ] || { echo "❌ idempotency mismatch"; exit 1; }

echo "==> 6) List runs endpoint"
LIST="$(curl -fsS "$BASE_URL/admin/jobs/runs?jobName=ALLOCATION_INTEGRITY_CHECK_V1&take=5&skip=0" -H "$AUTH")"
echo "$LIST" | jq -e '.items | length >= 1' >/dev/null

echo "✅ smoke-background-jobs OK"
