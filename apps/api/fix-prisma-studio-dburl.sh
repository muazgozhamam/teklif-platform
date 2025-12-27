#!/usr/bin/env bash
set -euo pipefail

# FAIL-FAST: doğru kökte miyiz?
[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin. Şuradan çalıştır: cd ~/Desktop/teklif-platform/apps/api"; exit 1; }
[ -f "prisma.config.ts" ] || { echo "HATA: prisma.config.ts bulunamadı (apps/api içinde olmalı)."; exit 1; }

echo "==> 1) apps/api/.env kontrol"
if [ ! -f ".env" ]; then
  cat > .env <<'ENV'
# Local development (EDIT THIS)
DATABASE_URL="postgresql://USER:PASSWORD@localhost:5432/teklif_platform?schema=public"
ENV
  echo "   - .env oluşturuldu (DATABASE_URL placeholder). Lütfen USER/PASSWORD/DB adını düzelt."
else
  echo "   - .env mevcut"
fi

echo "==> 2) prisma.config.ts patch (dotenv + DATABASE_URL fail-fast)"
node - <<'NODE'
const fs = require("fs");

const p = "prisma.config.ts";
let txt = fs.readFileSync(p, "utf8");

const sentinel = "/* AUTO-ENV-BOOTSTRAP */";

if (!txt.includes(sentinel)) {
  // En üste env bootstrap ekleyelim
  const bootstrap = `import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";

${sentinel}
// __dirname için (ESM uyumlu)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Önce apps/api/.env
dotenv.config({ path: path.resolve(__dirname, ".env") });
// Sonra repo root .env (apps/api -> ../../)
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

// Fail-fast: DATABASE_URL şart
if (!process.env.DATABASE_URL) {
  throw new Error(
    "DATABASE_URL bulunamadı. apps/api/.env içine DATABASE_URL ekle veya repo root .env'yi ayarla."
  );
}

`;

  // Eğer dosya import ile başlıyorsa, en başa ekleriz.
  // Yoksa yine en başa ekleriz.
  txt = bootstrap + "\n" + txt;
}

// datasource.url yoksa eklemeye çalışalım.
// Prisma config formatını bilmeden agresif overwrite yapmıyoruz.
// Sadece iki güvenli durum:
// 1) datasource: { ... } var ama url yok -> url: process.env.DATABASE_URL ekle
// 2) datasource hiç yok -> export default içine datasource ekle (minimal ekleme)

function ensureDatasourceUrl(code) {
  // Case 1: datasource var, url yok
  if (code.match(/datasource\s*:\s*\{[\s\S]*?\}/m) && !code.match(/datasource\s*:\s*\{[\s\S]*?url\s*:/m)) {
    return code.replace(/datasource\s*:\s*\{([\s\S]*?)\}/m, (m, inner) => {
      return `datasource: {\n    url: process.env.DATABASE_URL,\n${inner.replace(/^\s*/gm, "    ")}\n  }`;
    });
  }

  // Case 2: export default { ... } var, datasource yok
  if (code.match(/export\s+default\s+\{[\s\S]*?\}\s*;?\s*$/m) && !code.match(/datasource\s*:/m)) {
    return code.replace(/export\s+default\s+\{([\s\S]*?)\}\s*;?\s*$/m, (m, inner) => {
      // schema property varsa altına datasource ekleyelim, yoksa en üste
      if (inner.includes("schema")) {
        return `export default {${inner.replace(/schema\s*:\s*[^,\n]+,?/m, (sm) => {
          const hasComma = sm.trim().endsWith(",");
          return `${sm}${hasComma ? "" : ","}\n  datasource: { url: process.env.DATABASE_URL },`;
        })}\n};`;
      }
      return `export default {\n  datasource: { url: process.env.DATABASE_URL },${inner}\n};`;
    });
  }

  return code;
}

const next = ensureDatasourceUrl(txt);
fs.writeFileSync(p, next, "utf8");
console.log("==> prisma.config.ts patched.");
NODE

echo "==> 3) Prisma Studio başlatma denemesi"
echo "   Not: DATABASE_URL placeholder ise yine bağlanamaz; ama artık hata mesajı net olacak."
pnpm -s prisma studio --config ./prisma.config.ts || {
  echo
  echo "==> Studio açılamadı."
  echo "Muhtemel sebep: DATABASE_URL placeholder veya Postgres çalışmıyor."
  echo "DÜZELT: apps/api/.env içindeki DATABASE_URL'yi gerçek değerlerle güncelle."
  exit 1
}

