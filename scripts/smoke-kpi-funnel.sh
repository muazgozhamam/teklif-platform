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

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

echo "==> smoke-kpi-funnel"
echo "BASE_URL=$BASE_URL"

curl -fsS "$BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }

KPI_JSON="$(curl -fsS "$BASE_URL/admin/kpi/funnel" -H "Authorization: Bearer $ADMIN_TOKEN")"

echo "$KPI_JSON" | jq -e 'has("filters") and has("counts") and has("conversion")' >/dev/null || { echo "❌ KPI shape invalid"; exit 1; }
echo "$KPI_JSON" | jq -e '.counts | has("leadsTotal") and has("leadsApproved") and has("dealsTotal") and has("listingsTotal") and has("dealsWon")' >/dev/null || { echo "❌ KPI counts keys invalid"; exit 1; }
echo "$KPI_JSON" | jq -e '.conversion | has("leadToApprovedPct") and has("approvedToDealPct") and has("dealToListingPct") and has("listingToWonPct") and has("leadToWonPct")' >/dev/null || { echo "❌ KPI conversion keys invalid"; exit 1; }

echo "$KPI_JSON" | jq -e '.conversion.leadToApprovedPct|numbers' >/dev/null || { echo "❌ conversion not numeric"; exit 1; }

echo "✅ smoke-kpi-funnel OK"
