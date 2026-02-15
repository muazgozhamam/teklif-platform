#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/Desktop/teklif-platform}"
API_BASE="${API_BASE:-http://localhost:3001}"
USER_ID="${USER_ID:-cmk0380hs0000a3lwug4f5b2k}"
DEAL_ID="${1:-}"

if [ -z "$DEAL_ID" ]; then
  echo "❌ Usage: bash scripts/diag-claim-not-moving.sh <DEAL_ID>"
  echo "   Optional env: API_BASE, USER_ID, ROOT"
  exit 1
fi

echo "==> ROOT=$ROOT"
echo "==> API_BASE=$API_BASE"
echo "==> USER_ID=$USER_ID"
echo "==> DEAL_ID=$DEAL_ID"
echo

curl_json () {
  # args: method url header_userid(true/false)
  local method="$1"; shift
  local url="$1"; shift
  local with_uid="${1:-false}"; shift || true

  if [ "$with_uid" = "true" ]; then
    curl -sS -D /tmp/hdr.$$ -X "$method" "$url" -H "x-user-id: $USER_ID" "$@"
  else
    curl -sS -D /tmp/hdr.$$ -X "$method" "$url" "$@"
  fi
}

show_status () {
  awk 'BEGIN{RS="\r\n"} NR==1{print $0}' /tmp/hdr.$$ | sed 's/\r$//'
}

summarize_deal () {
  python3 - <<'PY'
import json,sys
raw=sys.stdin.read().strip()
if not raw:
  print("(empty body)")
  raise SystemExit(0)
try:
  d=json.loads(raw)
except Exception as e:
  print("Non-JSON body:", raw[:500])
  raise SystemExit(0)

keys=["id","status","consultantId","listingId","linkedListingId","createdAt","updatedAt"]
out={k:d.get(k) for k in keys if k in d}
print(json.dumps(out, indent=2, ensure_ascii=False))
PY
}

contains_id () {
  local id="$1"
  python3 - <<PY
import json,sys
id="$id"
raw=sys.stdin.read().strip()
try:
  arr=json.loads(raw) if raw else []
except:
  print("Non-JSON"); raise SystemExit(0)
if isinstance(arr, dict) and "items" in arr: arr=arr["items"]
found=False
if isinstance(arr, list):
  found=any(isinstance(x,dict) and str(x.get("id",""))==id for x in arr)
print("FOUND" if found else "NOT_FOUND")
PY
}

echo "==> 1) BEFORE: GET /deals/:id"
before="$(curl_json GET "$API_BASE/deals/$DEAL_ID" false || true)"
echo " - HTTP: $(show_status)"
echo "$before" | summarize_deal
echo

echo "==> 2) POST /deals/:id/assign-to-me"
resp="$(curl_json POST "$API_BASE/deals/$DEAL_ID/assign-to-me" true || true)"
echo " - HTTP: $(show_status)"
# body bazen boş olabilir; yine de yazdır
if [ -n "${resp:-}" ]; then
  echo "$resp" | head -c 1200; echo
else
  echo "(empty body)"
fi
echo

echo "==> 3) AFTER: GET /deals/:id"
after="$(curl_json GET "$API_BASE/deals/$DEAL_ID" false || true)"
echo " - HTTP: $(show_status)"
echo "$after" | summarize_deal
echo

echo "==> 4) Check lists: pending + mine (first 50)"
pending="$(curl_json GET "$API_BASE/deals/inbox/pending?take=50&skip=0" false || true)"
echo " - pending contains DEAL?  $(echo "$pending" | contains_id "$DEAL_ID")"
mine="$(curl_json GET "$API_BASE/deals/inbox/mine?take=50&skip=0" true || true)"
echo " - mine contains DEAL?     $(echo "$mine" | contains_id "$DEAL_ID")"
echo
echo "✅ DIAG DONE."
