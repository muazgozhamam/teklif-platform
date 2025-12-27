#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$SCHEMA" ]] || die "schema.prisma yok: $SCHEMA"

say "0) Backup"
cp -f "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"

say "1) schema.prisma: 'LOST}' (ve benzeri) düzelt"
python3 - "$SCHEMA" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# Enum value ile '}' aynı satıra yapışmışsa ayır:
# örn: "  LOST}" -> "  LOST\n}"
def fix_inline_brace(s: str) -> str:
    # satır sonundaki } yapışıklığını düzelt
    return re.sub(r'(?m)^(\s*[A-Z0-9_]+)\s*\}\s*$', r'\1\n}', s)

txt2 = fix_inline_brace(txt)

if txt2 == txt:
    print("NO_CHANGE")
else:
    p.write_text(txt2, encoding="utf-8")
    print("PATCHED")
PY

say "2) Prisma generate (schema valid mi kontrol)"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma

say "3) DB'ye uygula (dev): prisma db push"
pnpm -s prisma db push --schema prisma/schema.prisma

say "4) Build"
pnpm -s build

say "✅ DONE"
echo
echo "Test:"
echo "  cd $API_DIR"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./e2e-managed-advance.sh"
