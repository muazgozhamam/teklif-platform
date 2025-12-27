#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/offers/offers.service.ts"

if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE bulunamadı."
  exit 1
fi

echo "==> Disabling request existence check in OffersService.create()"

# "Request var mı?" bloğunu (findUnique + if(!req) throw ...) komple kaldırır
perl -0777 -i -pe '
s/\n\s*\/\/\s*Request var mı\?.*?\n\s*if\s*\(!req\)\s*throw\s*new\s*NotFoundException\([^\)]*\);\s*\n//s
' "$FILE"

echo "==> Done. Showing create() part (quick check):"
perl -ne 'print if $.>=1 && $.<=220' "$FILE" | sed -n '1,120p'

