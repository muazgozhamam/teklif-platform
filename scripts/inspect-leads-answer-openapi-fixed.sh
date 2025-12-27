#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3001}"

curl -sS "$BASE_URL/docs-json" | node - <<'NODE'
const fs = require('fs');
const j = JSON.parse(fs.readFileSync(0,'utf8'));
const p = '/leads/{id}/answer';
const obj = j.paths?.[p];
console.log('PATH:', p);
if (!obj) { console.log('HATA: path yok'); process.exit(1); }

console.log('\nMETHODS:', Object.keys(obj).join(', ').toUpperCase());
for (const m of Object.keys(obj)) {
  console.log('\n==>', m.toUpperCase(), 'requestBody:');
  console.dir(obj[m].requestBody, { depth: 12 });
}
NODE
