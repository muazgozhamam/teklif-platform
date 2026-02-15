#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CLOSING_PRICE="${CLOSING_PRICE:-1000000}"
CURRENCY="${CURRENCY:-TRY}"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "HATA: '$1' bulunamadı"; exit 2; }
}

need_bin jq

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

echo "==> BASE_URL=$BASE_URL"
echo "==> 1) Run broker approve -> listing flow to generate a deal"
FLOW_OUTPUT="$(BASE_URL="$BASE_URL" ./scripts/smoke-broker-approve-to-listing.sh)"
echo "$FLOW_OUTPUT"

DEAL_ID="$(echo "$FLOW_OUTPUT" | awk -F= '/^dealId=/{print $2}' | tail -n1 | tr -d '[:space:]')"
[ -n "$DEAL_ID" ] || { echo "HATA: dealId parse edilemedi"; exit 1; }
echo "OK dealId=$DEAL_ID"

echo "==> 2) Admin login"
ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "HATA: admin login başarısız"; exit 1; }
AUTH="Authorization: Bearer $ADMIN_TOKEN"

echo "==> 3) Mark deal WON (first call)"
WON1="$(curl -fsS -X POST "$BASE_URL/deals/$DEAL_ID/won" -H "$AUTH" -H "Content-Type: application/json" -d "{\"closingPrice\":$CLOSING_PRICE,\"currency\":\"$CURRENCY\"}")"
SNAP_ID_1="$(echo "$WON1" | jq -r '.snapshot.id // empty')"
[ -n "$SNAP_ID_1" ] || { echo "HATA: first won snapshot id yok"; echo "$WON1"; exit 1; }
echo "OK first snapshot id=$SNAP_ID_1"

echo "==> 4) Get snapshot + validate totals"
SNAP="$(curl -fsS "$BASE_URL/deals/$DEAL_ID/commission-snapshot" -H "$AUTH")"
echo "$SNAP" | jq -e '.dealId != null' >/dev/null || { echo "HATA: snapshot boş"; echo "$SNAP"; exit 1; }

CFG="$(curl -fsS "$BASE_URL/admin/commission-config" -H "$AUTH")"
BASE_RATE="$(echo "$CFG" | jq -r '.baseRate')"

export SNAP_JSON="$SNAP"
export CLOSING_PRICE_INPUT="$CLOSING_PRICE"
export BASE_RATE_INPUT="$BASE_RATE"
node <<'NODE'
const s = JSON.parse(process.env.SNAP_JSON || '{}');
const closingPrice = Number(process.env.CLOSING_PRICE_INPUT || '0');
const baseRate = Number(process.env.BASE_RATE_INPUT || '0');
const total = Number(s.totalCommission);
const h = Number(s.hunterAmount);
const b = Number(s.brokerAmount);
const c = Number(s.consultantAmount);
const p = Number(s.platformAmount);
const expected = closingPrice * baseRate;
const sum = h + b + c + p;
const eps = 1e-6;

function fail(msg) {
  console.error(`HATA: ${msg}`);
  process.exit(1);
}
if (!(closingPrice > 0)) fail('closingPrice <= 0');
if (!(baseRate > 0)) fail('baseRate <= 0');
if (Math.abs(total - expected) > eps) fail(`totalCommission mismatch total=${total} expected=${expected}`);
if (Math.abs(sum - total) > eps) fail(`split amounts sum mismatch sum=${sum} total=${total}`);
if (!s.rateUsedJson || !s.rateUsedJson.baseRate) fail('rateUsedJson/baseRate missing');
console.log(`OK totals total=${total} expected=${expected} sum=${sum}`);
NODE

echo "==> 5) Idempotency check (second WON call)"
WON2="$(curl -fsS -X POST "$BASE_URL/deals/$DEAL_ID/won" -H "$AUTH" -H "Content-Type: application/json" -d "{\"closingPrice\":$CLOSING_PRICE,\"currency\":\"$CURRENCY\"}")"
SNAP_ID_2="$(echo "$WON2" | jq -r '.snapshot.id // empty')"
[ -n "$SNAP_ID_2" ] || { echo "HATA: second won snapshot id yok"; echo "$WON2"; exit 1; }
[ "$SNAP_ID_1" = "$SNAP_ID_2" ] || { echo "HATA: idempotency fail: $SNAP_ID_1 != $SNAP_ID_2"; exit 1; }
echo "OK idempotent snapshot id=$SNAP_ID_2"

echo
echo "✅ SMOKE OK (commission won)"
