#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1"; exit 1; }; }
need curl
need python3

HTTP_BODY=""
HTTP_STATUS=""

http_post_json() {
  local url="$1"
  local json="$2"
  local raw body status

  raw="$(curl -sS --connect-timeout 5 --max-time 20 \
    -H 'Content-Type: application/json' \
    -X POST "$url" \
    -d "$json" \
    -w $'\n__HTTP_STATUS:%{http_code}\n')"

  body="${raw%$'\n__HTTP_STATUS:'*}"
  status="${raw##*$'\n__HTTP_STATUS:'}"
  status="${status//$'\n'/}"; status="${status//$'\r'/}"

  HTTP_BODY="$body"
  HTTP_STATUS="$status"
}

http_get() {
  local url="$1"
  curl -sS --connect-timeout 5 --max-time 20 "$url"
}

json_get_id() {
  # stdin -> parse JSON -> print id
  python3 -c 'import sys,json; obj=json.loads(sys.stdin.read() or "{}"); print(obj.get("id",""))'
}

mk_json() {
  local title="$1" city="$2" district="$3" typ="$4" rooms="$5"
  python3 - <<PY
import json
print(json.dumps({
  "title": "$title",
  "city": "$city",
  "district": "$district",
  "type": "$typ",
  "rooms": "$rooms"
}))
PY
}

create_listing() {
  local city="$1" district="$2" typ="$3" rooms="$4" title="$5"
  local json id

  json="$(mk_json "$title" "$city" "$district" "$typ" "$rooms")"
  echo "   -> POST /listings title=$title"
  http_post_json "$BASE_URL/listings" "$json"

  if [ "$HTTP_STATUS" != "201" ] && [ "$HTTP_STATUS" != "200" ]; then
    echo "❌ Create listing failed. HTTP=$HTTP_STATUS"
    echo "---- BODY ----"
    printf "%s\n" "$HTTP_BODY"
    exit 1
  fi

  id="$(printf "%s" "$HTTP_BODY" | json_get_id)"
  if [ -z "$id" ]; then
    echo "❌ Create listing: could not parse id from JSON"
    echo "---- BODY ----"
    printf "%s\n" "$HTTP_BODY"
    exit 1
  fi

  echo "   ✅ created id=$id"
  printf "%s" "$id"
}

echo "==> Pagination smoke @ $BASE_URL"

echo "==> 0) Health"
hc="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/health")"
[ "$hc" = "200" ] || { echo "❌ Health not OK. HTTP=$hc"; exit 1; }
echo "✅ OK: API up"
echo

echo "==> 1) Create fixtures"
P1="$(create_listing Konya Meram SATILIK '3+1' P1)"
P2="$(create_listing Konya Meram SATILIK '3+1' P2)"
echo

echo "==> 2) GET /listings page=1 pageSize=1 and page=2 pageSize=1"
r1="$(http_get "$BASE_URL/listings?page=1&pageSize=1")"
r2="$(http_get "$BASE_URL/listings?page=2&pageSize=1")"

python3 - <<PY
import json
a=json.loads('''$r1''')["items"]
b=json.loads('''$r2''')["items"]
assert isinstance(a,list) and isinstance(b,list), "items must be arrays"
assert len(a)==1 and len(b)==1, "expected 1 item per page"
ida=a[0].get("id"); idb=b[0].get("id")
assert ida and idb, "missing id in items"
assert ida!=idb, "page 1 and page 2 should differ when pageSize=1"
print("✅ OK: pagination pages differ:", ida, idb)
PY

echo
echo "✅ PAGINATION SMOKE PASSED"
