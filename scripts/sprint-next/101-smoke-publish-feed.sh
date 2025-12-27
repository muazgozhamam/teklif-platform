#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }
need curl
need python3

http_post_json() {
  local url="$1" json="$2"
  curl -sS --connect-timeout 5 --max-time 20 \
    -H "Content-Type: application/json" \
    -X POST "$url" -d "$json"
}

http_get() {
  curl -sS --connect-timeout 5 --max-time 20 "$1"
}

json_get_id() {
python3 - <<'PY'
import json,sys
s=sys.stdin.read().strip()
obj=json.loads(s)
print(obj.get("id",""))
PY
}

echo "==> Smoke publish + feed @ $BASE_URL"

echo "==> 0) Health"
hc="$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/health")"
[ "$hc" = "200" ] || { echo "❌ health not 200: $hc"; exit 1; }
echo "✅ OK: API up"
echo

echo "==> 1) Create listing (should be DRAFT)"
json="$(python3 - <<'PY'
import json
print(json.dumps({"title":"SMOKE_PUBLISH","city":"Konya","district":"Meram","type":"SATILIK","rooms":"3+1"}))
PY
)"
resp="$(http_post_json "$BASE_URL/listings" "$json")"
id="$(printf "%s" "$resp" | json_get_id)"
[ -n "$id" ] || { echo "❌ Could not parse id"; echo "$resp"; exit 1; }
echo "✅ Created id=$id"
echo

echo "==> 2) Default feed: listing MUST NOT appear (because DRAFT)"
r1="$(http_get "$BASE_URL/listings?page=1&pageSize=50")"
python3 - <<PY
import json
obj=json.loads('''$r1''')
items=obj.get("items") or []
assert isinstance(items,list)
ids=[x.get("id") for x in items if isinstance(x,dict)]
assert "$id" not in ids, "DRAFT should not appear in default feed"
print("✅ OK: DRAFT not in default feed")
PY
echo

echo "==> 3) Publish listing"
pub_status="$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/listings/$id/publish")"
[ "$pub_status" = "200" -o "$pub_status" = "201" ] || { echo "❌ publish status not 200/201: $pub_status"; exit 1; }
echo "✅ OK: publish http=$pub_status"
echo

echo "==> 4) Default feed: listing MUST appear after publish"
r2="$(http_get "$BASE_URL/listings?page=1&pageSize=50")"
python3 - <<PY
import json
obj=json.loads('''$r2''')
items=obj.get("items") or []
ids=[x.get("id") for x in items if isinstance(x,dict)]
assert "$id" in ids, "PUBLISHED must appear in default feed"
print("✅ OK: PUBLISHED appears in default feed")
PY
echo

echo "✅ SMOKE PASSED (publish + feed)"
