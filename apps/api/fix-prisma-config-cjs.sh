#!/usr/bin/env bash
set -euo pipefail

# FAIL-FAST: doğru kökte miyiz?
[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin. cd ~/Desktop/teklif-platform/apps/api"; exit 1; }
[ -f "prisma.config.ts" ] || { echo "HATA: prisma.config.ts bulunamadı."; exit 1; }

echo "==> prisma.config.ts: import.meta/url/fileURLToPath kaldırılıyor, __dirname ile CJS uyumlu hale getiriliyor"

node - <<'NODE'
const fs = require("fs");
const p = "prisma.config.ts";
let t = fs.readFileSync(p, "utf8");

// 1) fileURLToPath importunu kaldır
t = t.replace(/^\s*import\s+\{\s*fileURLToPath\s*\}\s+from\s+["']node:url["'];\s*\n/gm, "");

// 2) import.meta.url kullanan satırları kaldır
t = t.replace(/^\s*const\s+__filename\s*=\s*fileURLToPath\(import\.meta\.url\);\s*\n/gm, "");
t = t.replace(/^\s*const\s+__dirname\s*=\s*path\.dirname\(__filename\);\s*\n/gm, "");

// 3) Eğer __dirname artık tanımsız kalırsa (çok nadir), dotenv path resolve için güvenli fallback ekle
// Bizim senaryoda CJS + TS -> __dirname var, ama yine de fail-safe ekliyoruz.
if (t.includes("path.resolve(__dirname") && !t.includes("const __dirname =")) {
  // AUTO-ENV-BOOTSTRAP bloğuna yakın bir yere eklemeye çalış
  // "__dirname" zaten runtime'da var; burada sadece TS lint/derleme için gerekirse tanımlı gösteriyoruz.
  // Ama CommonJS'te const __dirname yeniden declare edilemez; o yüzden sadece yoksa ekle.
  // Bu nedenle eklemiyoruz. (CJS'te __dirname global)
}

// 4) node:url importu boş kalmışsa temizle (güvenli)
t = t.replace(/^\s*import\s+path\s+from\s+["']node:path["'];\s*\n\n/m, (m) => m); // no-op

fs.writeFileSync(p, t, "utf8");
console.log("==> prisma.config.ts patched (CJS compatible).");
NODE

echo "==> DONE"
echo
echo "Şimdi DEV server'ı yeniden başlat:"
echo "  pnpm start:dev"
echo
echo "NOT: pnpm start:dev terminali BLOKLAR (açık kalır). Kapatmak için Ctrl+C."
