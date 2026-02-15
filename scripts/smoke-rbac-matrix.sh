#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
STAMP="$(date +%s)-$RANDOM"
TEST_PASSWORD="${TEST_PASSWORD:-Pass1234!}"

BROKER_EMAIL="rbac.broker.${STAMP}@local.dev"
HUNTER_EMAIL="rbac.hunter.${STAMP}@local.dev"
CONSULTANT_EMAIL="rbac.consultant.${STAMP}@local.dev"

need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing binary: $1"; exit 2; }; }
need_bin curl
need_bin jq

fail() { echo "❌ $1"; exit 1; }
ok() { echo "✅ $1"; }

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // empty'
}

expect_status() {
  local method="$1"
  local path="$2"
  local expected="$3"
  local token="${4:-}"
  local body="${5:-}"

  local tmp code
  tmp="$(mktemp)"
  if [ -n "$token" ]; then
    if [ -n "$body" ]; then
      code="$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$body" || true)"
    else
      code="$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $token" || true)"
    fi
  else
    if [ -n "$body" ]; then
      code="$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" "$BASE_URL$path" -H 'Content-Type: application/json' -d "$body" || true)"
    else
      code="$(curl -sS -o "$tmp" -w "%{http_code}" -X "$method" "$BASE_URL$path" || true)"
    fi
  fi

  if [ "$code" != "$expected" ]; then
    echo "--- response body ---"
    cat "$tmp" || true
    rm -f "$tmp"
    fail "$method $path expected=$expected got=$code"
  fi
  rm -f "$tmp"
  ok "$method $path -> $code"
}

echo "==> smoke-rbac-matrix"
echo "BASE_URL=$BASE_URL"

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || fail "admin login failed"
ok "Admin login ok"

create_user() {
  local email="$1"
  local role="$2"
  curl -fsS -X POST "$BASE_URL/admin/users" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$TEST_PASSWORD\",\"role\":\"$role\"}" \
    | jq -r '.id // empty'
}

BROKER_ID="$(create_user "$BROKER_EMAIL" "BROKER")"
HUNTER_ID="$(create_user "$HUNTER_EMAIL" "HUNTER")"
CONSULTANT_ID="$(create_user "$CONSULTANT_EMAIL" "CONSULTANT")"
[ -n "$BROKER_ID" ] || fail "broker create failed"
[ -n "$HUNTER_ID" ] || fail "hunter create failed"
[ -n "$CONSULTANT_ID" ] || fail "consultant create failed"
ok "Test users created"

BROKER_TOKEN="$(login_token "$BROKER_EMAIL" "$TEST_PASSWORD")"
HUNTER_TOKEN="$(login_token "$HUNTER_EMAIL" "$TEST_PASSWORD")"
CONSULTANT_TOKEN="$(login_token "$CONSULTANT_EMAIL" "$TEST_PASSWORD")"
[ -n "$BROKER_TOKEN" ] || fail "broker login failed"
[ -n "$HUNTER_TOKEN" ] || fail "hunter login failed"
[ -n "$CONSULTANT_TOKEN" ] || fail "consultant login failed"
ok "Role logins ok"

expect_status GET "/admin/users" 401
expect_status GET "/admin/users" 200 "$ADMIN_TOKEN"
expect_status GET "/admin/users" 403 "$CONSULTANT_TOKEN"
expect_status GET "/admin/audit" 403 "$BROKER_TOKEN"
expect_status GET "/admin/audit" 200 "$ADMIN_TOKEN"
expect_status GET "/broker/leads/pending" 200 "$BROKER_TOKEN"
expect_status GET "/broker/leads/pending" 403 "$HUNTER_TOKEN"
expect_status GET "/deals/inbox/mine" 200 "$CONSULTANT_TOKEN"
expect_status GET "/deals/inbox/mine" 403 "$HUNTER_TOKEN"
expect_status POST "/admin/network/parent" 403 "$CONSULTANT_TOKEN" '{"childId":"x","parentId":"y"}'
expect_status GET "/stats/me" 200 "$HUNTER_TOKEN"

echo "✅ smoke-rbac-matrix OK"
