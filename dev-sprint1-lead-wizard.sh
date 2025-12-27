#!/usr/bin/env bash
set -euo pipefail

say() { printf "\n==> %s\n" "$*"; }
die() { echo "❌ $*" >&2; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/apps/api"
BASE_URL="${BASE_URL:-http://localhost:3001}"

command -v node >/dev/null 2>&1 || die "node yok"
command -v pnpm >/dev/null 2>&1 || die "pnpm yok"
command -v curl >/dev/null 2>&1 || die "curl yok"

say "0) Health kontrol"
curl -sS "$BASE_URL/health" >/dev/null || die "API ayakta değil. (pnpm start:dev açık mı?)"
echo "✅ health OK"

say "1) Prisma generate"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma >/dev/null
echo "✅ prisma generate OK"
cd "$ROOT_DIR"

say "2) DB seed + smoke test (senin çalışan script)"
./dev-seed-and-smoke-test.sh

echo
say "3) Wizard Sprint-1 için sıradaki adım"
cat <<'EOF'

Şu an seed+match tarafı çalışıyor. Sprint-1 (Lead Wizard) için bir sonraki adım:
- Lead'e soru-cevap akışı (next-question / answer) endpointleri
- Deal'e alanların adım adım yazılması (city/district/type/rooms)
- Wizard bitince status READY_FOR_MATCH

Bunları ekleyen ayrı bir script yazacağım; ama önce repo'da şu dosyaları net tespit etmem lazım:
1) LeadsController dosya yolu
2) LeadsService dosya yolu
3) DealsService içinde "ensureForLead" benzeri fonksiyon var mı

Bunun için şu komutların çıktısını gönder:
  cd ~/Desktop/teklif-platform/apps/api
  rg -n "class\\s+LeadsController" src
  rg -n "class\\s+LeadsService" src
  rg -n "class\\s+DealsService" src
  rg -n "ensureForLead|byLead|createDeal|upsert\\(" src/deals -S

EOF
