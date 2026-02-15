#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ATTEMPTS="${ATTEMPTS:-40}"

need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing binary: $1"; exit 2; }; }
need_bin curl

echo "==> smoke-rate-limit"
echo "BASE_URL=$BASE_URL"
echo "ATTEMPTS=$ATTEMPTS"

got_429=0
for i in $(seq 1 "$ATTEMPTS"); do
  code="$(curl -s -o /tmp/smoke-rate-limit.out -w "%{http_code}" -X POST "$BASE_URL/auth/login" -H 'Content-Type: application/json' -d '{"email":"admin@local.dev","password":"wrong-pass"}' || true)"
  if [ "$code" = "429" ]; then
    got_429=1
    echo "✅ Rate limit triggered at attempt=$i"
    break
  fi
  if [ "$code" != "401" ] && [ "$code" != "200" ]; then
    echo "❌ Unexpected status at attempt=$i: $code"
    cat /tmp/smoke-rate-limit.out || true
    exit 1
  fi
done

if [ "$got_429" -ne 1 ]; then
  echo "❌ No 429 received after $ATTEMPTS attempts"
  exit 1
fi

echo "✅ smoke-rate-limit OK"
