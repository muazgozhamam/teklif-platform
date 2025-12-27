#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/offers/offers.service.ts"

if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE bulunamadı."
  exit 1
fi

echo "==> Patching OffersService: ensure Lead.status is updated on ACCEPTED"

# 1) Eğer tx.lead.update zaten varsa dokunma
if grep -q "tx\.lead\.update" "$FILE"; then
  echo "==> tx.lead.update already exists in file. Will not duplicate."
else
  # 2) ACCEPTED akışında kesin bir noktaya ekle:
  # Transaction içinde "updateMany" ile diğer teklifleri REJECTED yaptıktan hemen sonra.
  # Aşağıdaki pattern: tx.offer.updateMany(... status: "REJECTED" ...) ; sonrasına lead update ekler.
  perl -0777 -i -pe '
    s/(await\s+tx\.offer\.updateMany\(\s*\{[\s\S]*?status\s*:\s*["'\'']REJECTED["'\''][\s\S]*?\}\s*\)\s*;\s*)/$1\n        await tx.lead.update({ where: { id: offer.requestId }, data: { status: "ACTIVE" } });\n/s
  ' "$FILE"
fi

# 3) Hâlâ eklenmediyse (pattern tutmadıysa) fallback:
# Transaction içinde accepted offer güncellendikten hemen sonra ekle.
if ! grep -q "tx\.lead\.update" "$FILE"; then
  perl -0777 -i -pe '
    s/(const\s+accepted\s*=\s*await\s+tx\.offer\.update\([\s\S]*?\);\s*)/$1\n        await tx.lead.update({ where: { id: offer.requestId }, data: { status: "ACTIVE" } });\n/s
  ' "$FILE"
fi

# 4) Son kontrol: eklenmiş mi?
if grep -q "tx\.lead\.update" "$FILE"; then
  echo "==> Patch OK: tx.lead.update inserted."
else
  echo "ERROR: Patch failed (could not find insertion point)."
  echo "Hızlı teşhis için aşağıdakileri çalıştırıp çıktıyı at:"
  echo "  grep -n \"updateMany\" -n $FILE | head -n 40"
  echo "  grep -n \"ACCEPTED\" -n $FILE | head -n 40"
  exit 1
fi

echo "==> Showing surrounding lines (first match):"
grep -n "tx\.lead\.update" -n "$FILE" | head -n 5

echo "==> Done. Restart API now."
