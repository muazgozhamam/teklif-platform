#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> smoke-validation-strict"
echo "BASE_URL=$BASE_URL"

tmp="$(mktemp)"
code="$(curl -sS -o "$tmp" -w "%{http_code}" -X POST "$BASE_URL/auth/login" -H 'Content-Type: application/json' -d '{"email":"admin@local.dev","password":"admin123","extra":"x"}' || true)"
body="$(cat "$tmp")"
rm -f "$tmp"

if [ "$code" = "400" ]; then
  echo "$body" | grep -qi 'should not exist' || {
    echo "❌ got 400 but strict validation message not found"
    echo "$body"
    exit 1
  }
  echo "✅ strict validation active (unknown field rejected)"
  echo "✅ smoke-validation-strict OK"
  exit 0
fi

if [ "$code" = "200" ] || [ "$code" = "401" ]; then
  echo "⚠️ strict validation appears disabled (status=$code)."
  echo "ℹ️ enable with: VALIDATION_STRICT_ENABLED=1"
  exit 0
fi

echo "❌ unexpected status: $code"
echo "$body"
exit 1
