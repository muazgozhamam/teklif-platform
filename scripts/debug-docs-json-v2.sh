#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3001}"
URL="$BASE_URL/docs-json"

echo "==> URL: $URL"
HDR="$(mktemp)"
BODY="$(mktemp)"
trap 'rm -f "$HDR" "$BODY"' EXIT

HTTP_CODE="$(curl -sS -D "$HDR" -o "$BODY" -w "%{http_code}" "$URL" || true)"
echo "HTTP_CODE=$HTTP_CODE"
echo
sed -n '1,20p' "$HDR" || true
echo

BYTES="$(wc -c < "$BODY" | tr -d ' ')"
echo "BODY_BYTES=$BYTES"
echo "BODY_PREVIEW:"
head -c 200 "$BODY" || true
echo
echo

if [ "$HTTP_CODE" != "200" ]; then
  echo "HATA: /docs-json 200 dönmedi."
  exit 2
fi

node -e '
const fs = require("fs");
const bodyPath = process.argv[1];
const raw = fs.readFileSync(bodyPath, "utf8");
if (!raw || raw.trim().length < 10) {
  console.error("HATA: docs-json body boş/çok kısa");
  process.exit(3);
}
const j = JSON.parse(raw);

function show(pathKey) {
  const obj = j.paths?.[pathKey];
  console.log("\n==============================");
  console.log("PATH:", pathKey);
  if (!obj) { console.log("YOK"); return; }
  console.log("METHODS:", Object.keys(obj).join(", ").toUpperCase());
  for (const m of Object.keys(obj)) {
    console.log("\n==>", m.toUpperCase(), "requestBody:");
    console.dir(obj[m].requestBody, { depth: 12 });
    console.log("\n==>", m.toUpperCase(), "parameters:");
    console.dir(obj[m].parameters || [], { depth: 6 });
  }
}

console.log("OPENAPI:", j.openapi, "TITLE:", j.info?.title);

show("/leads/{id}/answer");
show("/leads/{id}/wizard/answer");
show("/leads/{id}/wizard/next-question");

console.log("\n==> ALL /leads paths:");
Object.keys(j.paths || {}).filter(k => k.includes("/leads")).forEach(k => console.log(" -", k));
' "$BODY"

echo
echo "DONE."
