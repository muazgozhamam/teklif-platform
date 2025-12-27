#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

CANDIDATES=(
  "/api-json"
  "/swagger-json"
  "/openapi.json"
  "/docs-json"
)

tmp="$(mktemp)"
found=""

for p in "${CANDIDATES[@]}"; do
  code="$(curl -sS -o "$tmp" -w "%{http_code}" "$BASE_URL$p" || true)"
  if [ "$code" = "200" ]; then
    # basit bir doğrulama: json objesi mi?
    if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));' "$tmp" >/dev/null 2>&1; then
      found="$p"
      break
    fi
  fi
done

if [ -z "$found" ]; then
  echo "HATA: OpenAPI JSON endpoint bulunamadı. Denenenler: ${CANDIDATES[*]}"
  echo "İpucu: tarayıcıdan /docs veya /swagger sayfan varsa onun ayarlarında JSON yolu yazıyor olabilir."
  exit 1
fi

echo "OK: OpenAPI endpoint = $found"
node <<'NODE' "$tmp"
const fs = require("fs");
const file = process.argv[1];
const doc = JSON.parse(fs.readFileSync(file, "utf8"));
const paths = doc.paths || {};

const keys = Object.keys(paths);
const target = keys.find(k => k.includes("/leads/") && k.includes("/answer"));
if (!target) {
  console.log("HATA: /leads/.../answer path bulunamadı.");
  console.log("Mevcut leads path'leri:");
  keys.filter(k => k.includes("/leads")).forEach(k => console.log(" -", k));
  process.exit(2);
}

console.log("\nFOUND PATH:", target);

const obj = paths[target];
const method =
  obj.put || obj.post || obj.patch || obj.get || obj.delete;

if (!method) {
  console.log("HATA: bu path altında method objesi yok");
  process.exit(3);
}

console.log("\n==> Methods:", Object.keys(obj).join(", ").toUpperCase());
console.log("\n==> requestBody:");
console.dir(method.requestBody, { depth: 20 });
console.log("\n==> parameters:");
console.dir(method.parameters || [], { depth: 20 });
NODE
