#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
CTRL="$API_DIR/src/deals/deals.controller.ts"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$CTRL" ]] || die "Controller yok: $CTRL"

say "0) Backup"
cp -f "$CTRL" "$CTRL.bak.$(date +%Y%m%d-%H%M%S)"

say "1) DealsController içine @Post(':id/match') ekle (yoksa)"
python3 - "$CTRL" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

if re.search(r'@Post\(\s*[\'"]\:id\/match[\'"]\s*\)', txt):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# DealsController class'ını bul
m = re.search(r'(?s)export\s+class\s+DealsController\s*\{.*?\n\}', txt)
if not m:
    print("NO_DEALS_CONTROLLER_CLASS")
    raise SystemExit(2)

# class kapanışından hemen önce inject
end = m.end()
class_block = txt[m.start():m.end()]

# Son kapanış '}' indexi
last_brace = class_block.rfind("}")
if last_brace == -1:
    print("NO_CLASS_CLOSING_BRACE")
    raise SystemExit(3)

inject = """

  @Post(':id/match')
  match(@Param('id') id: string) {
    return this.deals.matchDeal(id);
  }
"""

new_class_block = class_block[:last_brace] + inject + "\n" + class_block[last_brace:]
new_txt = txt[:m.start()] + new_class_block + txt[m.end():]

p.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "2) Prisma generate + db push + build"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s prisma db push --schema prisma/schema.prisma
pnpm -s build

say "✅ DONE"
echo
echo "Şimdi API'yi çalıştırıp gerçek DEAL_ID ile test edeceğiz."
