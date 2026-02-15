#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing binary: $1"; exit 2; }; }
need_bin curl
need_bin jq

echo "==> smoke-audit-integrity"
echo "BASE_URL=$BASE_URL"

login_json="$(curl -fsS -X POST "$BASE_URL/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")"
token="$(echo "$login_json" | jq -r '.access_token // empty')"
[ -n "$token" ] || { echo "❌ admin login failed"; exit 1; }

# Trigger one auditable action to ensure recent hash-chain entries exist
stamp="$(date +%s)"
email="smoke.audit.integrity.$stamp@local.dev"
create_json="$(curl -fsS -X POST "$BASE_URL/admin/users" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"Pass1234!\",\"role\":\"HUNTER\"}")"
uid="$(echo "$create_json" | jq -r '.id // empty')"
[ -n "$uid" ] || { echo "❌ unable to create user for audit trigger"; echo "$create_json"; exit 1; }

integrity_json="$(curl -fsS "$BASE_URL/admin/audit/integrity?take=2000" -H "Authorization: Bearer $token")"
echo "$integrity_json" | jq -e '.ok == true' >/dev/null || { echo "❌ audit integrity failed"; echo "$integrity_json"; exit 1; }

echo "$integrity_json" | jq -e '.checkedRows >= 1' >/dev/null || { echo "❌ integrity checkedRows is zero"; echo "$integrity_json"; exit 1; }

echo "✅ smoke-audit-integrity OK"
