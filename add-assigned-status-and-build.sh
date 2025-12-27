#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$SCHEMA" ]] || die "schema.prisma yok: $SCHEMA"

say "0) Backup schema"
cp -f "$SCHEMA" "$SCHEMA.bak.$(date +%Y%m%d-%H%M%S)"

say "1) DealStatus enum: ASSIGNED ekle (yoksa)"
python3 - "$SCHEMA" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r'(?s)\benum\s+DealStatus\s*\{(.*?)\n\}', txt)
if not m:
    print("NO_ENUM_DealStatus")
    raise SystemExit(2)

inside = m.group(1)
if re.search(r'(?m)^\s*ASSIGNED\s*$', inside):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

lines = inside.splitlines()
out = []
inserted = False
for line in lines:
    out.append(line)
    if (not inserted) and re.search(r'^\s*READY_FOR_MATCHING\s*$', line):
        out.append("  ASSIGNED")
        inserted = True
if not inserted:
    out.append("  ASSIGNED")

new_inside = "\n".join(out)
new_txt = txt[:m.start()] + f"enum DealStatus {{\n{new_inside}\n}}" + txt[m.end():]
p.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "2) prisma generate"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma

say "3) prisma db push"
pnpm -s prisma db push --schema prisma/schema.prisma

say "4) build"
pnpm -s build

say "✅ DONE"
echo
echo "Next: API match endpoint patch + E2E"
