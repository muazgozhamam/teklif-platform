#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/apps/api/src/listings/listings.controller.ts"

echo "ROOT=$ROOT"
echo "FILE=$FILE"
test -f "$FILE" || { echo "❌ listings.controller.ts yok"; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$ts"
echo "✅ Backup: $FILE.bak.$ts"

python3 - <<'PY'
from pathlib import Path
import re, os

p = Path(os.environ["FILE"])
txt = p.read_text(encoding="utf-8")

# 1) import { CreateListingDto, UpdateListingDto } from './listings.dto';
#    -> import * as ListingDto from './listings.dto';
txt2 = re.sub(
    r"^import\s+\{\s*CreateListingDto\s*,\s*UpdateListingDto\s*\}\s+from\s+(['\"]\./listings\.dto['\"]);\s*$",
    r"import * as ListingDto from \1;",
    txt,
    flags=re.M
)

# Eğer import satırı farklı formatta ise daha gevşek yakala
if txt2 == txt:
    txt2 = re.sub(
        r"^import\s+\{[^}]*CreateListingDto[^}]*UpdateListingDto[^}]*\}\s+from\s+(['\"]\./listings\.dto['\"]);\s*$",
        r"import * as ListingDto from \1;",
        txt,
        flags=re.M
    )

txt = txt2

# 2) Parametre tip kullanımını namespace'e çevir
# @Body() dto: CreateListingDto  -> ListingDto.CreateListingDto
txt = re.sub(r"(\bdto\s*:\s*)CreateListingDto\b", r"\1ListingDto.CreateListingDto", txt)
txt = re.sub(r"(\bdto\s*:\s*)UpdateListingDto\b", r"\1ListingDto.UpdateListingDto", txt)

# Ek güvenlik: dosyada artık çıplak CreateListingDto geçmesin (import harici)
# (import satırı kalktıysa zaten)
p.write_text(txt, encoding="utf-8")
print("✅ TS1272 fix applied (namespace import + usages updated)")
PY

echo "DONE."
