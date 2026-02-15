#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-consultant1@test.com}"
CONSULTANT_PASSWORD="${CONSULTANT_PASSWORD:-pass123}"
BROKER_EMAIL="${BROKER_EMAIL:-broker.stats@local.dev}"
BROKER_PASSWORD="${BROKER_PASSWORD:-pass123}"

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

admin_call() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  if [ -n "$body" ]; then
    curl -fsS -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "$body"
  else
    curl -fsS -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $ADMIN_TOKEN"
  fi
}

find_user_id_by_email() {
  local email="$1"
  admin_call GET "/admin/users?take=200&q=$(printf '%s' "$email" | sed 's/@/%40/g')" \
    | jq -r --arg email "$email" '.[] | select(.email == $email) | .id' \
    | head -n1
}

ensure_broker_user() {
  local tok
  tok="$(login_token "$BROKER_EMAIL" "$BROKER_PASSWORD" || true)"
  if [ -n "$tok" ]; then
    echo "$tok"
    return 0
  fi

  local user_id
  user_id="$(find_user_id_by_email "$BROKER_EMAIL")"
  if [ -z "$user_id" ]; then
    user_id="$(admin_call POST "/admin/users" "{\"email\":\"$BROKER_EMAIL\",\"password\":\"$BROKER_PASSWORD\",\"role\":\"BROKER\"}" | jq -r '.id // empty')"
  fi
  [ -n "$user_id" ] || { echo "HATA: broker user oluşturulamadı"; exit 1; }
  admin_call PATCH "/admin/users/$user_id" "{\"role\":\"BROKER\",\"isActive\":true}" >/dev/null
  admin_call POST "/admin/users/$user_id/set-password" "{\"password\":\"$BROKER_PASSWORD\"}" >/dev/null

  tok="$(login_token "$BROKER_EMAIL" "$BROKER_PASSWORD" || true)"
  [ -n "$tok" ] || { echo "HATA: broker login başarısız"; exit 1; }
  echo "$tok"
}

echo "==> BASE_URL=$BASE_URL"
echo "==> 1) Create won snapshot flow"
FLOW_OUTPUT="$(BASE_URL="$BASE_URL" ./scripts/smoke-commission-won.sh)"
echo "$FLOW_OUTPUT"
DEAL_ID="$(echo "$FLOW_OUTPUT" | awk -F= '/^OK dealId=/{print $2}' | tail -n1 | tr -d '[:space:]')"
[ -n "$DEAL_ID" ] || DEAL_ID="$(echo "$FLOW_OUTPUT" | awk -F= '/^dealId=/{print $2}' | tail -n1 | tr -d '[:space:]')"
[ -n "$DEAL_ID" ] || { echo "HATA: dealId parse edilemedi"; exit 1; }
echo "OK dealId=$DEAL_ID"

echo "==> 2) Admin/Consultant login"
ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
CONSULTANT_TOKEN="$(login_token "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "HATA: admin login başarısız"; exit 1; }
[ -n "$CONSULTANT_TOKEN" ] || { echo "HATA: consultant login başarısız"; exit 1; }
BROKER_TOKEN="$(ensure_broker_user)"

echo "==> 3) Consultant /me/commissions assertions"
ME_JSON="$(curl -fsS "$BASE_URL/me/commissions?take=50&skip=0" -H "Authorization: Bearer $CONSULTANT_TOKEN")"
echo "$ME_JSON" | jq -e '.total >= 1' >/dev/null || { echo "HATA: /me total < 1"; exit 1; }
echo "$ME_JSON" | jq -e --arg id "$DEAL_ID" '.items | any(.dealId == $id)' >/dev/null || { echo "HATA: /me items deal bulunamadı"; exit 1; }
echo "OK /me commissions contains deal"

echo "==> 4) Admin /admin/commissions search assertions"
ADMIN_JSON="$(curl -fsS "$BASE_URL/admin/commissions?take=20&skip=0&q=$DEAL_ID" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$ADMIN_JSON" | jq -e '.total >= 1' >/dev/null || { echo "HATA: admin total < 1"; exit 1; }
echo "$ADMIN_JSON" | jq -e --arg id "$DEAL_ID" '.items | any(.dealId == $id)' >/dev/null || { echo "HATA: admin items deal bulunamadı"; exit 1; }
echo "OK /admin/commissions contains deal"

echo "==> 5) Broker /broker/commissions assertions"
BROKER_JSON="$(curl -fsS "$BASE_URL/broker/commissions?take=50&skip=0" -H "Authorization: Bearer $BROKER_TOKEN")"
echo "$BROKER_JSON" | jq -e '.total >= 1' >/dev/null || { echo "HATA: broker total < 1"; exit 1; }
echo "$BROKER_JSON" | jq -e --arg id "$DEAL_ID" '.items | any(.dealId == $id)' >/dev/null || { echo "HATA: broker items deal bulunamadı"; exit 1; }
echo "OK /broker/commissions contains deal"

echo "==> 6) Pagination sanity"
PAGE_JSON="$(curl -fsS "$BASE_URL/admin/commissions?take=1&skip=0" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$PAGE_JSON" | jq -e '.items | length == 1' >/dev/null || { echo "HATA: take=1 items length != 1"; exit 1; }
echo "$PAGE_JSON" | jq -e '.total >= 1' >/dev/null || { echo "HATA: take=1 total < 1"; exit 1; }
echo "OK pagination sanity"

echo
echo "✅ SMOKE OK (commission reports)"
