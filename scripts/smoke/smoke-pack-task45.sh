#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
SMOKE_FLAG_MODE="${SMOKE_FLAG_MODE:-both}" # off|on|both
SMOKE_ALLOC_MODE="${SMOKE_ALLOC_MODE:-off}" # off|on
STAMP="$(date +%s)-$RANDOM"

BROKER_EMAIL="${BROKER_EMAIL:-smoke.task45.broker.${STAMP}@local.dev}"
HUNTER_EMAIL="${HUNTER_EMAIL:-smoke.task45.hunter.${STAMP}@local.dev}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-smoke.task45.consultant.${STAMP}@local.dev}"
TEST_PASSWORD="${TEST_PASSWORD:-Pass1234!}"
CLOSING_PRICE="${CLOSING_PRICE:-1000000}"
CURRENCY="${CURRENCY:-TRY}"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing binary: $1"; exit 2; }
}
need_bin jq
need_bin curl

fail() {
  echo "❌ $1"
  exit 1
}

ok() {
  echo "✅ $1"
}

warn() {
  echo "⚠️  $1"
}

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

admin_call() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  if [ -n "$body" ]; then
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $ADMIN_TOKEN"
  fi
}

create_user() {
  local email="$1"
  local role="$2"
  local out
  out="$(admin_call POST "/admin/users" "{\"email\":\"$email\",\"password\":\"$TEST_PASSWORD\",\"role\":\"$role\"}")" || return 1
  echo "$out" | jq -r '.id // empty'
}

assert_audit_sample() {
  local action="$1"
  local url="$2"
  local data
  data="$(curl -fsS "$url" -H "Authorization: Bearer $ADMIN_TOKEN")"

  echo "$data" | jq -e '.items | length > 0' >/dev/null || fail "Audit empty for action=$action"
  echo "$data" | jq -e '.items[0] | has("action") and has("canonicalAction") and has("entity") and has("canonicalEntity")' >/dev/null \
    || fail "Audit canonical fields missing for action=$action"

  local sample
  sample="$(echo "$data" | jq -c '.items[0]')"
  ok "Audit sample for $action: $sample"
}

assert_org_audit_sample() {
  local action="$1"
  local url="$2"
  local data
  data="$(curl -fsS "$url" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$data" | jq -e --arg a "$action" '.items | length > 0 and any(.[]; .action == $a and has("canonicalAction") and has("entity") and has("canonicalEntity"))' >/dev/null \
    || fail "Org audit verification failed for action=$action"
  ok "Org audit verified for $action"
}

create_won_snapshot() {
  local lead_json lead_id approve_json deal_id assign_json won_json
  lead_json="$(curl -fsS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{"initialText":"task45 snapshot flow"}')" || return 1
  lead_id="$(echo "$lead_json" | jq -r '.id // empty')"
  [ -n "$lead_id" ] || return 1

  approve_json="$(curl -fsS -X POST "$BASE_URL/broker/leads/$lead_id/approve" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{}')" || return 1
  deal_id="$(echo "$approve_json" | jq -r '.dealId // empty')"
  [ -n "$deal_id" ] || return 1

  assign_json="$(curl -fsS -X POST "$BASE_URL/deals/$deal_id/assign" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"consultantId\":\"$CONSULTANT_ID\"}")" || return 1
  echo "$assign_json" | jq -e --arg cid "$CONSULTANT_ID" '.consultantId == $cid' >/dev/null || return 1

  won_json="$(curl -fsS -X POST "$BASE_URL/deals/$deal_id/won" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"closingPrice\":$CLOSING_PRICE,\"currency\":\"$CURRENCY\"}")" || return 1
  echo "$won_json" | jq -e '.snapshot.id != null' >/dev/null || return 1

  echo "$won_json"
  [ -n "$deal_id" ] || return 1
  echo "$deal_id"
}

assert_snapshot_off() {
  local deal_id="$1"
  local snapshot audit_json snapshot_id
  snapshot="$(curl -fsS "$BASE_URL/deals/$deal_id/commission-snapshot" -H "Authorization: Bearer $ADMIN_TOKEN")"
  snapshot_id="$(echo "$snapshot" | jq -r '.id // empty')"
  [ -n "$snapshot_id" ] || fail "Snapshot id missing (OFF mode)"
  LAST_SNAPSHOT_ID="$snapshot_id"

  echo "$snapshot" | jq -e '.networkMeta == null' >/dev/null || fail "Expected networkMeta to be null when flag OFF"

  audit_json="$(curl -fsS "$BASE_URL/admin/audit?action=COMMISSION_SNAPSHOT_NETWORK_CAPTURED&entityType=COMMISSION&entityId=$snapshot_id&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$audit_json" | jq -e '(.total // 0) == 0' >/dev/null || fail "Unexpected COMMISSION_SNAPSHOT_NETWORK_CAPTURED audit in OFF mode"
  ok "OFF mode verified: networkMeta null and no capture audit"
}

assert_snapshot_on() {
  local deal_id="$1"
  local snapshot snapshot_id audit_json
  snapshot="$(curl -fsS "$BASE_URL/deals/$deal_id/commission-snapshot" -H "Authorization: Bearer $ADMIN_TOKEN")"
  snapshot_id="$(echo "$snapshot" | jq -r '.id // empty')"
  [ -n "$snapshot_id" ] || fail "Snapshot id missing (ON mode)"
  LAST_SNAPSHOT_ID="$snapshot_id"

  echo "$snapshot" | jq -e '.networkMeta != null and (.networkMeta | has("path") and has("upline") and has("splitMap") and has("capturedAt") and has("splitTrace"))' >/dev/null \
    || fail "Expected networkMeta with path/upline/splitMap/splitTrace/capturedAt in ON mode"
  echo "$snapshot" | jq -e '.networkMeta.splitTrace | has("sourceUserId") and has("sourceUserRole") and has("effectiveSplitPercent") and has("defaultPercent") and has("resolvedAt")' >/dev/null \
    || fail "Expected splitTrace fields in ON mode"
  echo "$snapshot" | jq -e --arg oid "$OFFICE_ID" --arg rid "$REGION_ID" '.networkMeta.officeTrace.officeId == $oid and .networkMeta.officeTrace.regionId == $rid and (.networkMeta.officeTrace | has("overridePercent") and has("resolvedAt"))' >/dev/null \
    || fail "Expected officeTrace with officeId/regionId/overridePercent/resolvedAt in ON mode"

  audit_json="$(curl -fsS "$BASE_URL/admin/audit?action=COMMISSION_SNAPSHOT_NETWORK_CAPTURED&entityType=COMMISSION&entityId=$snapshot_id&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$audit_json" | jq -e '.items | length > 0 and any(.[]; .canonicalAction == "COMMISSION_SNAPSHOT_NETWORK_CAPTURED")' >/dev/null \
    || fail "Expected COMMISSION_SNAPSHOT_NETWORK_CAPTURED audit in ON mode"
  ok "ON mode verified: networkMeta captured + capture audit exists"
}

assert_allocations_on() {
  local list_json alloc_id approved_json approved_state audit_json
  list_json="$(curl -fsS "$BASE_URL/admin/allocations?snapshotId=$LAST_SNAPSHOT_ID&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$list_json" | jq -e '.items | length >= 1' >/dev/null || fail "Expected at least one allocation row"
  alloc_id="$(echo "$list_json" | jq -r '.items[0].id // empty')"
  [ -n "$alloc_id" ] || fail "Allocation id missing"

  approved_json="$(curl -fsS -X POST "$BASE_URL/admin/allocations/$alloc_id/approve" -H "Authorization: Bearer $ADMIN_TOKEN")"
  approved_state="$(echo "$approved_json" | jq -r '.state // empty')"
  [ "$approved_state" = "APPROVED" ] || fail "Allocation approve failed"

  audit_json="$(curl -fsS "$BASE_URL/admin/audit?action=COMMISSION_ALLOCATED&entityType=COMMISSION&entityId=$LAST_SNAPSHOT_ID&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$audit_json" | jq -e '.items | length > 0 and any(.[]; has("action") and has("canonicalAction") and has("entity") and has("canonicalEntity"))' >/dev/null \
    || fail "Expected COMMISSION_ALLOCATED audit with canonical fields"
  audit_json="$(curl -fsS "$BASE_URL/admin/audit?action=COMMISSION_ALLOCATION_APPROVED&entityType=COMMISSION&entityId=$LAST_SNAPSHOT_ID&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$audit_json" | jq -e '.items | length > 0 and any(.[]; has("action") and has("canonicalAction") and has("entity") and has("canonicalEntity"))' >/dev/null \
    || fail "Expected COMMISSION_ALLOCATION_APPROVED audit with canonical fields"

  local csv_out
  csv_out="$(curl -fsS "$BASE_URL/admin/allocations/export.csv?snapshotId=$LAST_SNAPSHOT_ID&state=APPROVED" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$csv_out" | head -n 1 | grep -q '^id,snapshotId,dealId,beneficiaryUserId,beneficiaryEmail,role,percent,amount,state,createdAt,exportedAt,exportBatchId$' \
    || fail "Allocation CSV header mismatch"

  local mark_json
  mark_json="$(curl -fsS -X POST "$BASE_URL/admin/allocations/export/mark" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"allocationIds\":[\"$alloc_id\"],\"exportBatchId\":\"smoke-batch-$STAMP\"}")"
  echo "$mark_json" | jq -e '.newlyMarked >= 1' >/dev/null || fail "Allocation export mark failed"

  local mark_json_second
  mark_json_second="$(curl -fsS -X POST "$BASE_URL/admin/allocations/export/mark" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"allocationIds\":[\"$alloc_id\"],\"exportBatchId\":\"smoke-batch-$STAMP\"}")"
  echo "$mark_json_second" | jq -e '.newlyMarked == 0 and .alreadyExported >= 1' >/dev/null || fail "Allocation export mark idempotency failed"

  audit_json="$(curl -fsS "$BASE_URL/admin/audit?action=COMMISSION_ALLOCATION_EXPORTED&entityType=COMMISSION&entityId=$LAST_SNAPSHOT_ID&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$audit_json" | jq -e '.items | length > 0 and any(.[]; has("action") and has("canonicalAction") and has("entity") and has("canonicalEntity"))' >/dev/null \
    || fail "Expected COMMISSION_ALLOCATION_EXPORTED audit with canonical fields"

  local integrity_json
  integrity_json="$(curl -fsS "$BASE_URL/admin/allocations/integrity/$LAST_SNAPSHOT_ID" -H "Authorization: Bearer $ADMIN_TOKEN")"
  echo "$integrity_json" | jq -e '.ok == true and .checks.mathOk == true and .checks.allocationVsConsultantOk == true and .checks.exportBatchIntegrityOk == true' >/dev/null \
    || fail "Allocation integrity invariant check failed"
  ok "Allocation mode ON verified: list + approve + audit"
}

echo "==> TASK 4.5 unified smoke"
echo "BASE_URL=$BASE_URL"
echo "SMOKE_FLAG_MODE=$SMOKE_FLAG_MODE"
echo "SMOKE_ALLOC_MODE=$SMOKE_ALLOC_MODE"

echo "==> A) Auth"
ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD" || true)"
[ -n "$ADMIN_TOKEN" ] || fail "Admin login failed ($ADMIN_EMAIL)"
ok "Admin token acquired"

echo "==> B) Create test actors"
BROKER_ID="$(create_user "$BROKER_EMAIL" "BROKER" || true)"
HUNTER_ID="$(create_user "$HUNTER_EMAIL" "HUNTER" || true)"
CONSULTANT_ID="$(create_user "$CONSULTANT_EMAIL" "CONSULTANT" || true)"
[ -n "$BROKER_ID" ] || fail "Broker create failed"
[ -n "$HUNTER_ID" ] || fail "Hunter create failed"
[ -n "$CONSULTANT_ID" ] || fail "Consultant create failed"
ok "Chosen IDs broker=$BROKER_ID hunter=$HUNTER_ID consultant=$CONSULTANT_ID"

echo "==> C) Network ops"
SET_PARENT="$(admin_call POST "/admin/network/parent" "{\"childId\":\"$HUNTER_ID\",\"parentId\":\"$BROKER_ID\"}")"
echo "$SET_PARENT" | jq -e --arg p "$BROKER_ID" '.parentId == $p' >/dev/null || fail "Set parent failed"

PATH_JSON="$(admin_call GET "/admin/network/$HUNTER_ID/path")"
UPLINE_JSON="$(admin_call GET "/admin/network/$HUNTER_ID/upline?maxDepth=10")"
echo "$PATH_JSON" | jq -e --arg h "$HUNTER_ID" --arg b "$BROKER_ID" '. | length >= 2 and .[0].id == $h and .[1].id == $b' >/dev/null || fail "Path chain invalid"
echo "$UPLINE_JSON" | jq -e --arg b "$BROKER_ID" '. | length >= 1 and .[0].id == $b' >/dev/null || fail "Upline order invalid"
ok "Network path/upline verified"

echo "==> D) Commission split ops"
SPLIT_SET="$(admin_call POST "/admin/network/commission-split" '{"role":"BROKER","percent":15.5}')"
echo "$SPLIT_SET" | jq -e '.percent == 15.5' >/dev/null || fail "Set commission split failed"
SPLIT_MAP="$(admin_call GET "/admin/network/commission-split")"
echo "$SPLIT_MAP" | jq -e '.BROKER == 15.5' >/dev/null || fail "Split map validation failed"
ok "Commission split verified"

echo "==> D2) Region + office foundation ops"
REGION_JSON="$(admin_call POST "/admin/org/regions" "{\"city\":\"Istanbul\",\"district\":\"Task45-$STAMP\"}")"
REGION_ID="$(echo "$REGION_JSON" | jq -r '.id // empty')"
[ -n "$REGION_ID" ] || fail "Region create failed"
OFFICE_JSON="$(admin_call POST "/admin/org/offices" "{\"name\":\"Task45 Office $STAMP\",\"regionId\":\"$REGION_ID\",\"brokerId\":\"$BROKER_ID\",\"overridePercent\":12.5}")"
OFFICE_ID="$(echo "$OFFICE_JSON" | jq -r '.id // empty')"
[ -n "$OFFICE_ID" ] || fail "Office create failed"
ASSIGN_OFFICE_JSON="$(admin_call POST "/admin/org/users/office" "{\"userId\":\"$CONSULTANT_ID\",\"officeId\":\"$OFFICE_ID\"}")"
echo "$ASSIGN_OFFICE_JSON" | jq -e --arg oid "$OFFICE_ID" '.officeId == $oid' >/dev/null || fail "Assign user office failed"
OFFICE_USERS_JSON="$(admin_call GET "/admin/org/offices/$OFFICE_ID/users")"
echo "$OFFICE_USERS_JSON" | jq -e --arg uid "$CONSULTANT_ID" 'any(.[]; .id == $uid and .officeId != null)' >/dev/null || fail "Office users endpoint failed"
REGION_OFFICES_JSON="$(admin_call GET "/admin/org/regions/$REGION_ID/offices")"
echo "$REGION_OFFICES_JSON" | jq -e --arg oid "$OFFICE_ID" 'any(.[]; .id == $oid)' >/dev/null || fail "Region offices endpoint failed"
ok "Region/office ops verified regionId=$REGION_ID officeId=$OFFICE_ID"

COMM_OFFICE_JSON="$(curl -sS "$BASE_URL/admin/commissions?officeId=$OFFICE_ID&take=5" -H "Authorization: Bearer $ADMIN_TOKEN" || true)"
if echo "$COMM_OFFICE_JSON" | jq -e 'has("items") and has("total")' >/dev/null 2>&1; then
  ok "Admin commissions office filter endpoint reachable"
else
  warn "Admin commissions office filter check skipped or unavailable"
fi

echo "==> E) Audit canonical fields"
assert_audit_sample "NETWORK_PARENT_SET" "$BASE_URL/admin/audit?action=NETWORK_PARENT_SET&entityType=USER&entityId=$HUNTER_ID&take=20"
assert_audit_sample "COMMISSION_SPLIT_CONFIG_SET" "$BASE_URL/admin/audit?action=COMMISSION_SPLIT_CONFIG_SET&entityType=COMMISSION_CONFIG&take=20"
assert_org_audit_sample "REGION_CREATED" "$BASE_URL/admin/audit?action=REGION_CREATED&entityType=REGION&entityId=$REGION_ID&take=20"
assert_org_audit_sample "OFFICE_CREATED" "$BASE_URL/admin/audit?action=OFFICE_CREATED&entityType=OFFICE&entityId=$OFFICE_ID&take=20"
assert_org_audit_sample "USER_OFFICE_ASSIGNED" "$BASE_URL/admin/audit?action=USER_OFFICE_ASSIGNED&entityType=USER&entityId=$CONSULTANT_ID&take=20"

case "$SMOKE_FLAG_MODE" in
  off)
    echo "==> F) Snapshot networkMeta OFF mode"
    DEAL_ID="$(create_won_snapshot | tail -n1)" || fail "Could not create WON snapshot for OFF mode"
    ok "OFF flow dealId=$DEAL_ID"
    assert_snapshot_off "$DEAL_ID"
    ;;
  on)
    echo "==> F) Snapshot networkMeta ON mode"
    DEAL_ID="$(create_won_snapshot | tail -n1)" || fail "Could not create WON snapshot for ON mode"
    ok "ON flow dealId=$DEAL_ID"
    assert_snapshot_on "$DEAL_ID"
    if [ "$SMOKE_ALLOC_MODE" = "on" ]; then
      assert_allocations_on
    fi
    ;;
  both)
    echo "==> F) Snapshot networkMeta BOTH mode (OFF assertions + ON instruction)"
    DEAL_ID="$(create_won_snapshot | tail -n1)" || fail "Could not create WON snapshot for BOTH mode"
    ok "BOTH(off-phase) flow dealId=$DEAL_ID"
    assert_snapshot_off "$DEAL_ID"
    echo
    warn "Now restart API with NETWORK_COMMISSIONS_ENABLED=1 and rerun:"
    echo "SMOKE_FLAG_MODE=on BASE_URL=$BASE_URL ./scripts/smoke/smoke-pack-task45.sh"
    ;;
  *)
    fail "Invalid SMOKE_FLAG_MODE: $SMOKE_FLAG_MODE (expected off|on|both)"
    ;;
esac

if [ -n "${DATABASE_URL:-}" ] && [ -x "./scripts/diag/diag-query-plans.sh" ]; then
  echo "==> G) Optional query-plan diag"
  if ! DATABASE_URL="$DATABASE_URL" ./scripts/diag/diag-query-plans.sh; then
    warn "diag-query-plans failed; continuing"
  else
    ok "diag-query-plans completed"
  fi
else
  warn "Skipping diag-query-plans (DATABASE_URL missing or script not executable)"
fi

echo
echo "✅ SMOKE PACK OK (task45)"
