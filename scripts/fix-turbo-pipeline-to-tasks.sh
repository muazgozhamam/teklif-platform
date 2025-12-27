#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FILE="$ROOT/turbo.json"

if [ ! -f "$FILE" ]; then
  echo "HATA: turbo.json bulunamadı: $FILE"
  exit 1
fi

echo "==> turbo.json patch: pipeline -> tasks"

node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/turbo.json';
const j = JSON.parse(fs.readFileSync(p,'utf8'));

if (j.pipeline && !j.tasks) {
  j.tasks = j.pipeline;
  delete j.pipeline;
  fs.writeFileSync(p, JSON.stringify(j, null, 2));
  console.log('OK: pipeline alanı tasks olarak değiştirildi');
} else if (j.tasks) {
  console.log('OK: zaten tasks var, dokunmadım');
} else {
  console.log('UYARI: pipeline/tasks bulunamadı, dosyayı elle kontrol et');
}
NODE

echo "==> Tamam. Şimdi tekrar:"
echo "pnpm dev"
