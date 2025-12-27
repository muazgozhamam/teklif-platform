#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
CTRL="$API_DIR/src/deals/deals.controller.ts"
E2E="$API_DIR/e2e-managed-advance.sh"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$CTRL" ]] || die "Controller yok: $CTRL"
[[ -f "$E2E"  ]] || die "E2E yok: $E2E"
[[ -d "$API_DIR" ]] || die "API dir yok: $API_DIR"

say "1) E2E: Advance HTTP check'i 200/201 kabul edecek şekilde düzelt (global)"
python3 - "$E2E" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 1) En yaygın pattern: [[ "${adv_code}" == "200" ]]
txt2 = re.sub(
    r'\[\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\]',
    '[[ "${adv_code}" == "200" || "${adv_code}" == "201" ]]',
    txt
)

# 2) Bazı scriptlerde: [[ "${adv_code}" != "200" ]]
txt3 = re.sub(
    r'\[\[\s*"\$\{adv_code\}"\s*!=\s*"200"\s*\]\]',
    '[[ "${adv_code}" != "200" && "${adv_code}" != "201" ]]',
    txt2
)

p.write_text(txt3, encoding="utf-8")
print("PATCHED")
PY
say "   - Patched: $E2E"

say "2) DealsController: advance() içine QUESTIONS_COMPLETED hook ekle (advanceDeal sonrası status update)"

python3 - "$CTRL" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
src = p.read_text(encoding="utf-8")

# Zaten patchliyse çık
if "ensureStatusReadyForMatching" in src and "QUESTIONS_COMPLETED" in src:
    print("ALREADY_PRESENT")
    raise SystemExit(0)

# advance methodunu yakala (tam senin koduna göre)
pattern = r"""@Post\(':id/advance'\)\s*
\s*advance\(\s*@Param\('id'\)\s*id:\s*string,\s*@Body\(\)\s*body:\s*\{\s*event:\s*DealEvent\s*\}\s*\)\s*\{\s*
\s*return\s+this\.deals\.advanceDeal\(id,\s*body\.event\);\s*
\s*\}\s*"""

m = re.search(pattern, src, flags=re.M | re.S)
if not m:
    print("NO_MATCH_ADVANCE_METHOD")
    raise SystemExit(2)

replacement = """@Post(':id/advance')
  async advance(@Param('id') id: string, @Body() body: { event: DealEvent }) {
    const result = await this.deals.advanceDeal(id, body.event);

    if ((body.event as any) === 'QUESTIONS_COMPLETED') {
      // DealsService içinde daha önce eklediğimiz helper
      return this.deals.ensureStatusReadyForMatching(id);
    }

    return result;
  }"""

src2 = src[:m.start()] + replacement + src[m.end():]
p.write_text(src2, encoding="utf-8")
print("PATCHED_CONTROLLER")
PY

say "3) Build"
cd "$API_DIR"
pnpm -s build

say "✅ DONE"
echo
echo "Run E2E:"
echo "  cd $API_DIR"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./e2e-managed-advance.sh"
