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

say "1) model User içine DealConsultant opposite field ekle (yoksa)"
python3 - "$SCHEMA" <<'PY'
import sys, pathlib, re

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")
orig = txt

# Zaten relation ekli mi?
if re.search(r'@relation\(\s*"\s*DealConsultant\s*"\s*\)', txt):
    # Dikkat: Deal tarafında zaten var; User tarafında var mı kontrol edelim
    # User model bloğunda arayacağız
    pass

# model User bloğunu bul
m = re.search(r'(?s)\bmodel\s+User\s*\{(.*?)\n\}', txt)
if not m:
    print("NO_MODEL_USER")
    raise SystemExit(2)

body = m.group(1)

# User içinde zaten var mı?
if re.search(r'(?m)^\s*\w+\s+Deal\[\]\s+@relation\(\s*"\s*DealConsultant\s*"\s*\)', body):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# Alan adı çakışmasın: consultantDeals yoksa onu kullan, varsa consultantDeals2
field_name = "consultantDeals"
if re.search(r'(?m)^\s*consultantDeals\b', body):
    field_name = "consultantDeals2"

inject = f"\n  {field_name} Deal[] @relation(\"DealConsultant\")\n"

new_body = body.rstrip() + inject
new_block = "model User {" + new_body + "\n}"

txt2 = txt[:m.start()] + new_block + txt[m.end():]
p.write_text(txt2, encoding="utf-8")
print(f"PATCHED ({field_name})")
PY

say "2) Prisma format + generate + db push + build"
cd "$API_DIR"
pnpm -s prisma format --schema prisma/schema.prisma
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s prisma db push --schema prisma/schema.prisma
pnpm -s build

say "✅ DONE"
echo
echo "Sonraki adım: API restart + /match tekrar deneme."
