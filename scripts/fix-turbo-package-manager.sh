#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
PKG="$ROOT/package.json"

if [ ! -f "$PKG" ]; then
  echo "HATA: root package.json bulunamadı: $PKG"
  exit 1
fi

echo "==> Root package.json: packageManager ekleniyor (pnpm)"

node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/package.json';
const j = JSON.parse(fs.readFileSync(p,'utf8'));
if (!j.packageManager) {
  // Versiyon belirlemek için pnpm -v çıktısını al
  const { execSync } = require('child_process');
  let v = '9.0.0';
  try { v = execSync('pnpm -v').toString().trim(); } catch {}
  j.packageManager = `pnpm@${v}`;
  fs.writeFileSync(p, JSON.stringify(j, null, 2));
  console.log('OK: packageManager eklendi ->', j.packageManager);
} else {
  console.log('OK: packageManager zaten var ->', j.packageManager);
}
NODE

echo "==> Tamam. Şimdi tekrar dev:"
echo "pnpm dev"
