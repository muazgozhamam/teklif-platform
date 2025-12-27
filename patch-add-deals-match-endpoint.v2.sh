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

say "1) DealsController class bloğuna @Post(':id/match') ekle (yoksa)"
python3 - "$CTRL" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
src = p.read_text(encoding="utf-8")

if re.search(r'@Post\(\s*[\'"]\:id\/match[\'"]\s*\)', src):
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# class DealsController başlangıcını bul (export olsa da olmasa da)
m = re.search(r'\bclass\s+DealsController\b', src)
if not m:
    print("NO_CLASS_DECL: DealsController")
    raise SystemExit(2)

# class body'si için ilk "{" bul
i = src.find("{", m.end())
if i == -1:
    print("NO_OPEN_BRACE_AFTER_CLASS")
    raise SystemExit(3)

# Brace counting ile class kapanışını bul
depth = 0
end = None
for j in range(i, len(src)):
    ch = src[j]
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            end = j
            break

if end is None:
    print("NO_MATCHING_CLOSING_BRACE")
    raise SystemExit(4)

inject = """

  @Post(':id/match')
  match(@Param('id') id: string) {
    return this.deals.matchDeal(id);
  }
"""

new_src = src[:end] + inject + src[end:]
p.write_text(new_src, encoding="utf-8")
print("PATCHED")
PY

say "2) Build"
cd "$API_DIR"
pnpm -s build

say "✅ DONE"
echo
echo "Kontrol:"
echo "  cd $API_DIR && grep -n \":id/match\" -n src/deals/deals.controller.ts"
