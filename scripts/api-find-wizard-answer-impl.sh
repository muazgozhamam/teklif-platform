#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
echo "==> Repo: $ROOT"
echo

echo "==> 1) LeadsController içindeki answer route'larını bul"
grep -RIn --include='*.ts' "Mapped {/leads" apps/api/src 2>/dev/null || true
echo

echo "==> 2) Controller route: /leads/:id/answer implementasyonunu bul"
grep -RIn --include='*.ts' -E "(/:id/answer|leads/:id/answer|@Post\\(':id/answer'\\)|@Put\\(':id/answer'\\))" apps/api/src/leads || true
echo

echo "==> 3) Wizard answer route: /leads/:id/wizard/answer implementasyonunu bul"
grep -RIn --include='*.ts' -E "wizard/answer|@Post\\(':id/wizard/answer'\\)" apps/api/src/leads || true
echo

echo "==> 4) Service çağrısı iz sür: '.answer(' ve 'wizard' keyword'leri"
grep -RIn --include='*.ts' -E "\.answer\\(|wizard.*answer|answer.*wizard" apps/api/src/leads || true
echo

echo "==> 5) Prisma update noktaları (deal.update / deal.updateMany) - lead answer sonrası ilişki kurmak için"
grep -RIn --include='*.ts' -E "prisma\.deal\.(update|updateMany)" apps/api/src/leads apps/api/src/deals 2>/dev/null || true
echo
echo "✅ DONE. Çıktıda geçen dosya yollarını buraya yapıştır."
