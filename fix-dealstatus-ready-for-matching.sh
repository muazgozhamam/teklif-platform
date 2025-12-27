#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$SCHEMA" ]] || die "schema.prisma yok: $SCHEMA"

say "1) schema.prisma: DealStatus enum'a READY_FOR_MATCHING ekle (yoksa)"
python3 - "$SCHEMA" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r'(?s)\benum\s+DealStatus\s*\{(.*?)\n\}', txt)
if not m:
    print("NO_ENUM_DealStatus")
    raise SystemExit(2)

block = m.group(0)
inside = m.group(1)

if re.search(r'(?m)^\s*READY_FOR_MATCHING\s*$', inside):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# Basit kural: OPEN satırının altına ekle; yoksa bloğun sonuna ekle
lines = inside.splitlines()
out_lines = []
inserted = False
for line in lines:
    out_lines.append(line)
    if not inserted and re.search(r'^\s*OPEN\s*$', line):
        out_lines.append("  READY_FOR_MATCHING")
        inserted = True

if not inserted:
    out_lines.append("  READY_FOR_MATCHING")

new_inside = "\n".join(out_lines)
new_block = re.sub(r'(?s)\benum\s+DealStatus\s*\{.*?\n\}', f"enum DealStatus {{\n{new_inside}\n}}", block)

txt2 = txt[:m.start()] + new_block + txt[m.end():]
p.write_text(txt2, encoding="utf-8")
print("PATCHED")
PY

say "2) Prisma generate"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma

say "3) DB'ye uygula (dev ortamı): prisma db push"
# migrate yerine db push: hızlı ve dev için uygun
pnpm -s prisma db push --schema prisma/schema.prisma

say "4) Build"
pnpm -s build

say "✅ DONE"
echo
echo "Test:"
echo "  cd $API_DIR"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./e2e-managed-advance.sh"
