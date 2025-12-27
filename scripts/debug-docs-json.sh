#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3001}"
URL="$BASE_URL/docs-json"

echo "==> URL: $URL"
echo "==> 1) HEADERS + HTTP CODE"
HDR="$(mktemp)"
BODY="$(mktemp)"
trap 'rm -f "$HDR" "$BODY"' EXIT

HTTP_CODE="$(curl -sS -D "$HDR" -o "$BODY" -w "%{http_code}" "$URL" || true)"

echo "HTTP_CODE=$HTTP_CODE"
echo
echo "---- headers (first 30 lines) ----"
sed -n '1,30p' "$HDR" || true
echo "---------------------------------"
echo

BYTES="$(wc -c < "$BODY" | tr -d ' ')"
echo "BODY_BYTES=$BYTES"
echo
echo "---- body preview (first 300 chars) ----"
head -c 300 "$BODY" || true
echo
echo "---------------------------------------"
echo

if [ "$HTTP_CODE" != "200" ]; then
  echo "HATA: /docs-json 200 dönmedi."
  exit 2
fi

echo "==> 2) Parse OpenAPI from stdin and print requestBody schemas"

cat "$BODY" | node - <<'NODE'
const fs = require("fs");
const raw = fs.readFileSync(0, "utf8").trim();
const j = JSON.parse(raw);

function show(pathKey) {
  const obj = j.paths?.[pathKey];
  console.log("\n==============================");
  console.log("PATH:", pathKey);
  if (!obj) {
    console.log("YOK");
    return;
  }
  console.log("METHODS:", Object.keys(obj).join(", ").toUpperCase());
  for (const m of Object.keys(obj)) {
    console.log("\n==>", m.toUpperCase(), "requestBody:");
    console.dir(obj[m].requestBody, { depth: 12 });
  }
}

console.log("OPENAPI:", j.openapi, "TITLE:", j.info?.title);

// İlgili path’leri basalım
show("/leads/{id}/answer");
show("/leads/{id}/wizard/answer");
show("/leads/{id}/wizard/next-question");

// Bonus: /leads ile ilgili tüm path’leri listele
console.log("\n==> ALL /leads paths:");
Object.keys(j.paths||{}).filter(k=>k.includes("/leads")).forEach(k=>console.log(" -", k));
NODE

echo
echo "DONE."
