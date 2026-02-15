#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
TEST_EMAIL="${TEST_EMAIL:-smoke.admin.user.$(date +%s)@local.dev}"
TEST_PASSWORD="${TEST_PASSWORD:-Pass1234!}"

json_get() {
  local expr="$1"
  node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync(0,'utf8'));const v=(function(){try{return $expr}catch{return ''}})();process.stdout.write(v===undefined||v===null?'':String(v));"
}

login_token() {
  local email="$1"
  local password="$2"
  local out
  out="$(curl -sS -X POST "$BASE_URL/auth/login" -H "Content-Type: application/json" -d "{\"email\":\"$email\",\"password\":\"$password\"}")" || return 1
  echo "$out" | json_get "j.access_token || j.accessToken || ''"
}

status_code() {
  node -e "const fs=require('fs');const s=fs.readFileSync(0,'utf8');const m=s.match(/HTTP\\/[^\\s]+\\s+([0-9]{3})/g);const c=(m&&m.length)?(m[m.length-1].match(/([0-9]{3})/)||[])[1]:'';process.stdout.write(c);"
}

echo "==> BASE_URL=$BASE_URL"

echo "==> 1) Admin login"
ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "HATA: admin login token yok"; exit 1; }
ADMIN_AUTH="Authorization: Bearer $ADMIN_TOKEN"
echo "OK admin=$ADMIN_EMAIL"

echo "==> 2) Admin users list"
USERS_JSON="$(curl -fsS -H "$ADMIN_AUTH" "$BASE_URL/admin/users?take=20")"
COUNT="$(echo "$USERS_JSON" | node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync(0,'utf8'));process.stdout.write(String(Array.isArray(j)?j.length:0));")"
echo "OK users.count=$COUNT"

echo "==> 3) Create test user"
CREATE_JSON="$(curl -fsS -X POST "$BASE_URL/admin/users" -H "$ADMIN_AUTH" -H "Content-Type: application/json" -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"role\":\"USER\"}")"
USER_ID="$(echo "$CREATE_JSON" | json_get "j.id || ''")"
[ -n "$USER_ID" ] || { echo "HATA: create user id yok"; echo "$CREATE_JSON"; exit 2; }
echo "OK userId=$USER_ID email=$TEST_EMAIL"

echo "==> 4) Patch role -> CONSULTANT and isActive=true"
PATCH_JSON="$(curl -fsS -X PATCH "$BASE_URL/admin/users/$USER_ID" -H "$ADMIN_AUTH" -H "Content-Type: application/json" -d '{"role":"CONSULTANT","isActive":true}')"
PATCH_ROLE="$(echo "$PATCH_JSON" | json_get "j.role || ''")"
PATCH_ACTIVE="$(echo "$PATCH_JSON" | json_get "j.isActive")"
[ "$PATCH_ROLE" = "CONSULTANT" ] || { echo "HATA: role CONSULTANT olmadı"; echo "$PATCH_JSON"; exit 3; }
[ "$PATCH_ACTIVE" = "true" ] || { echo "HATA: isActive true olmadı"; echo "$PATCH_JSON"; exit 3; }
echo "OK patched role=$PATCH_ROLE isActive=$PATCH_ACTIVE"

echo "==> 5) Test user login + consultant protected route allow"
TEST_TOKEN="$(login_token "$TEST_EMAIL" "$TEST_PASSWORD")"
[ -n "$TEST_TOKEN" ] || { echo "HATA: test user login başarısız"; exit 4; }
TEST_AUTH="Authorization: Bearer $TEST_TOKEN"
ALLOW_CODE="$(curl -sS -i -H "$TEST_AUTH" "$BASE_URL/deals/inbox/pending?take=5&skip=0" | status_code)"
[ "$ALLOW_CODE" = "200" ] || { echo "HATA: consultant route allow bekleniyordu, code=$ALLOW_CODE"; exit 4; }
echo "OK protected allow code=$ALLOW_CODE"

echo "==> 6) Patch role -> HUNTER and verify deny on consultant route"
curl -fsS -X PATCH "$BASE_URL/admin/users/$USER_ID" -H "$ADMIN_AUTH" -H "Content-Type: application/json" -d '{"role":"HUNTER"}' >/dev/null
TEST_TOKEN_2="$(login_token "$TEST_EMAIL" "$TEST_PASSWORD")"
[ -n "$TEST_TOKEN_2" ] || { echo "HATA: role change sonrası login başarısız"; exit 5; }
DENY_CODE="$(curl -sS -i -H "Authorization: Bearer $TEST_TOKEN_2" "$BASE_URL/deals/inbox/pending?take=5&skip=0" | status_code)"
[ "$DENY_CODE" = "403" ] || { echo "HATA: consultant route deny bekleniyordu, code=$DENY_CODE"; exit 5; }
echo "OK protected deny code=$DENY_CODE"

echo "==> 7) Patch isActive=false and verify login denied"
curl -fsS -X PATCH "$BASE_URL/admin/users/$USER_ID" -H "$ADMIN_AUTH" -H "Content-Type: application/json" -d '{"isActive":false}' >/dev/null
LOGIN_INACTIVE_CODE="$(curl -sS -i -X POST "$BASE_URL/auth/login" -H "Content-Type: application/json" -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" | status_code)"
[ "$LOGIN_INACTIVE_CODE" = "401" ] || { echo "HATA: inactive login deny bekleniyordu, code=$LOGIN_INACTIVE_CODE"; exit 6; }
echo "OK inactive login denied code=$LOGIN_INACTIVE_CODE"

echo
echo "✅ SMOKE OK (admin users)"
echo "testUserId=$USER_ID"
echo "testEmail=$TEST_EMAIL"
