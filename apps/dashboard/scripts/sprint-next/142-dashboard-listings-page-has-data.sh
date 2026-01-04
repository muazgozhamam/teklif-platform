#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DASH_LOG="$ROOT/.tmp/dashboard.dev.log"

echo "==> ROOT=$ROOT"

# 1) Dashboard port: logdan veya probe ile bul
DASH_PORT=""
if [ -f "$DASH_LOG" ]; then
  DASH_PORT="$(rg -n "Local:\s+http://localhost:(\d+)" -or '$1' "$DASH_LOG" | tail -n 1 || true)"
fi

if [ -z "$DASH_PORT" ]; then
  for p in {3000..3010}; do
    code="$(curl -sS -o /dev/null -m 1 -w "%{http_code}" "http://localhost:$p/" 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
      DASH_PORT="$p"
      break
    fi
  done
fi

if [ -z "$DASH_PORT" ]; then
  echo "❌ Could not detect dashboard port."
  echo "   Tail log:"
  tail -n 80 "$DASH_LOG" || true
  exit 2
fi

DASH="http://localhost:$DASH_PORT"
echo "==> DASH=$DASH"

# 2) API'den son 3 listing id al
API="http://localhost:3001"
echo "==> API=$API"
IDS="$(curl -sS "$API/listings?limit=3" | python3 - <<'PY'
import json,sys
d=json.load(sys.stdin)
items=d.get("items") if isinstance(d,dict) else d
items=items or []
print("\n".join([it.get("id","") for it in items if isinstance(it,dict) and it.get("id")]))
PY
)"

echo "==> Latest listing IDs (up to 3):"
echo "$IDS" | sed 's/^/ - /'

# 3) /listings html çek ve ID var mı kontrol et
HTML="$(curl -sS "$DASH/listings")"
HIT="NO"
for id in $IDS; do
  if [ -n "$id" ] && printf "%s" "$HTML" | rg -q "$id"; then
    HIT="YES"
    echo "✅ Found listing id in HTML: $id"
    break
  fi
done

if [ "$HIT" = "NO" ]; then
  echo "⚠️  No listing IDs found in HTML."
  echo "   This usually means data is fetched client-side after render,"
  echo "   or page is still placeholder UI."
  echo
  echo "   Next: add request logging in dashboard proxy/api route and re-test."
fi

echo "==> Done."
