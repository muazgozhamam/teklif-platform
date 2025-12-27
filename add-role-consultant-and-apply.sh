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

say "1) enum Role içine CONSULTANT ekle (yoksa)"
python3 - "$SCHEMA" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")
orig = txt

# enum Role bloğunu yakala
m = re.search(r'(?s)\benum\s+Role\s*\{(.*?)\n\}', txt)
if not m:
    print("NO_ENUM_ROLE")
    raise SystemExit(2)

body = m.group(1)

if re.search(r'(?m)^\s*CONSULTANT\s*$', body):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# Basitçe kapanıştan önce ekle (indent 2 boşluk)
new_body = body.rstrip() + "\n  CONSULTANT\n"
new_block = "enum Role {" + new_body + "\n}"

txt2 = txt[:m.start()] + new_block + txt[m.end():]
p.write_text(txt2, encoding="utf-8")
print("PATCHED")
PY

say "2) Prisma generate + db push + build"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s prisma db push --schema prisma/schema.prisma
pnpm -s build

say "✅ DONE"
echo
echo "Şimdi match tekrar denenecek. (API dist ise restart şart.)"
