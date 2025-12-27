#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "prisma.config.ts" ] || { echo "HATA: prisma.config.ts yok."; exit 1; }

echo "==> prisma.config.ts içinde dotenv 'quiet' yapılıyor (log susturma) + tekrar garanti"

node - <<'NODE'
const fs = require("fs");
const p = "prisma.config.ts";
let t = fs.readFileSync(p, "utf8");

// dotenv.config({ path: ..., }) -> dotenv.config({ path: ..., quiet: true })
t = t.replace(/dotenv\.config\(\{\s*path:\s*([^,}]+)\s*\}\)/g, "dotenv.config({ path: $1, quiet: true })");
t = t.replace(/dotenv\.config\(\{\s*path:\s*([^,}]+)\s*,\s*quiet:\s*true\s*\}\)/g, "dotenv.config({ path: $1, quiet: true })");

// Eğer hiç quiet yoksa ama config satırları farklıysa elle ekleyelim (basit kontrol)
t = t.replace(/dotenv\.config\(\{\s*path:\s*path\.resolve\(__dirname,\s*"\.env"\)\s*\}\);/g,
              'dotenv.config({ path: path.resolve(__dirname, ".env"), quiet: true });');
t = t.replace(/dotenv\.config\(\{\s*path:\s*path\.resolve\(__dirname,\s*"\.\.\/\.\.\/\.env"\)\s*\}\);/g,
              'dotenv.config({ path: path.resolve(__dirname, "../../.env"), quiet: true });');

fs.writeFileSync(p, t, "utf8");
console.log("==> prisma.config.ts hardened.");
NODE

echo "==> DONE"
echo "Test:"
echo "  pnpm -s prisma studio --config ./prisma.config.ts"
