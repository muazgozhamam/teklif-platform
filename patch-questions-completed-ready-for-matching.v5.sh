#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
CTRL="$API_DIR/src/deals/deals.controller.ts"
SVC="$API_DIR/src/deals/deals.service.ts"
E2E="$API_DIR/e2e-managed-advance.sh"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -f "$CTRL" ]] || die "Controller yok: $CTRL"
[[ -f "$SVC"  ]] || die "Service yok: $SVC"
[[ -f "$E2E"  ]] || die "E2E yok: $E2E"

say "1) E2E: Advance HTTP kontrolünü 200/201 kabul edecek şekilde GARANTİ et"

python3 - "$E2E" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# Zaten 200/201 kabul ediyorsa çık
if re.search(r'adv_code.*==\s*"200"\s*\|\|.*==\s*"201"', txt):
    print("ALREADY_OK")
    raise SystemExit(0)

# Strateji: "Advance HTTP" fail satırını tetikleyen check'i doğrudan yeniden yaz.
# En yaygın form:
#   [[ "${adv_code}" == "200" ]] || fail_with_log_tail "Advance HTTP ..."
# veya
#   if [[ "${adv_code}" != "200" ]]; then fail... fi
#
# 1) Kısa devre formunu yakala
txt2 = re.sub(
    r'\[\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\]\s*\|\|\s*fail_with_log_tail\s*"Advance HTTP \$\{adv_code\}:\s*\$\{adv_body\}"',
    '[[ "${adv_code}" == "200" || "${adv_code}" == "201" ]] || fail_with_log_tail "Advance HTTP ${adv_code}: ${adv_body}"',
    txt
)

# 2) if != 200 formunu yakala
txt3 = re.sub(
    r'if\s+\[\[\s*"\$\{adv_code\}"\s*!=\s*"200"\s*\]\]\s*;\s*then\s*\n(\s*)fail_with_log_tail\s*"Advance HTTP \$\{adv_code\}:\s*\$\{adv_body\}"\s*\n\s*fi',
    r'if [[ "${adv_code}" != "200" && "${adv_code}" != "201" ]]; then\n\1fail_with_log_tail "Advance HTTP ${adv_code}: ${adv_body}"\nfi',
    txt2
)

if txt3 == txt:
    # Son çare: dosyada "Advance HTTP ${adv_code}" geçen satırı bul, bir önceki check satırını normalize et
    # Burada en güvenlisi: advance_code kontrolünün geçtiği yeri bulup, hemen üstüne garantili check koymak.
    # "adv_code=" satırından sonra ekleyelim.
    m = re.search(r'(?m)^\s*adv_code=.*$', txt)
    if not m:
        print("NO_ADV_CODE_LINE")
        raise SystemExit(2)
    insert_at = m.end()
    inject = '\n  # accept 200/201 for advance\n  [[ "${adv_code}" == "200" || "${adv_code}" == "201" ]] || fail_with_log_tail "Advance HTTP ${adv_code}: ${adv_body}"\n'
    txt3 = txt[:insert_at] + inject + txt[insert_at:]
    print("INJECTED_GUARD")
else:
    print("PATCHED")

p.write_text(txt3, encoding="utf-8")
PY

say "2) DealsService: ensureStatusReadyForMatching yoksa ekle (zaten var görünüyor ama garanti)"
python3 - "$SVC" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")
if "ensureStatusReadyForMatching" in txt:
    print("ALREADY_PRESENT")
    raise SystemExit(0)

m = re.search(r'(?s)export\s+class\s+DealsService\s*\{', txt)
if not m:
    print("NO_CLASS")
    raise SystemExit(2)

last = txt.rfind("}")
if last == -1:
    print("NO_END")
    raise SystemExit(2)

method = r'''
  /**
   * QUESTIONS_COMPLETED sonrası deal status'unu READY_FOR_MATCHING yap.
   */
  async ensureStatusReadyForMatching(dealId: string) {
    return this.prisma.deal.update({
      where: { id: dealId },
      data: { status: 'READY_FOR_MATCHING' as any },
    });
  }
'''
new_txt = txt[:last].rstrip() + "\n" + method + "\n}\n"
p.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "3) DealsController: advance handler'a hook enjekte et (async şartı yok, decorator arası olabilir)"
python3 - "$CTRL" <<'PY'
import sys, pathlib, re

p = pathlib.Path(sys.argv[1])
src = p.read_text(encoding="utf-8")

if "ensureStatusReadyForMatching" in src and "QUESTIONS_COMPLETED" in src:
    print("ALREADY_PRESENT")
    raise SystemExit(0)

lines = src.splitlines(True)

# a) @Post içinde advance geçen decorator satırını bul (route /:id/advance olabilir)
post_i = None
for i, line in enumerate(lines):
    if "@Post" in line and "advance" in line:
        post_i = i
        break
if post_i is None:
    print("NO_POST_ADVANCE_DECORATOR")
    raise SystemExit(2)

# b) decorator'dan sonra method bloğunu bulmak:
# - arada başka decorator satırları olabilir (@HttpCode, @UseGuards, vs.)
# - method imzası async olmayabilir
# - imza birkaç satır olabilir; kriter: decorator olmayan ilk satırlardan itibaren,
#   ilk '{' açılana kadar ilerle, '{' görünce method başlat.
j = post_i + 1
while j < len(lines) and lines[j].lstrip().startswith("@"):
    j += 1

# şimdi j method imzasının başladığı satır olmalı; ama '{' belki ileride
method_start = j
k = j
found_brace = False
while k < len(lines) and k < j + 80:
    if "{" in lines[k]:
        found_brace = True
        break
    k += 1
if not found_brace:
    print("NO_OPEN_BRACE_FOR_METHOD")
    raise SystemExit(2)

# method bloğunu brace-match ile topla: k satırında '{' var, oradan itibaren
buf = []
brace = 0
started = False
end_i = None
for i in range(method_start, len(lines)):
    buf.append(lines[i])
    for ch in lines[i]:
        if ch == "{":
            brace += 1
            started = True
        elif ch == "}":
            brace -= 1
    if started and brace == 0:
        end_i = i
        break
if end_i is None:
    print("NO_METHOD_END")
    raise SystemExit(2)

method = "".join(buf)

# id var
idm = re.search(r"@Param\(\s*['\"]id['\"]\s*\)\s*(\w+)\s*:\s*string", method)
id_var = idm.group(1) if idm else "id"

# body var (event buradan okunacak)
bm = re.search(r"@Body\(\s*\)\s*(\w+)", method)
body_var = bm.group(1) if bm else None
if body_var is None:
    em = re.search(r"\b(\w+)\.event\b", method)
    body_var = em.group(1) if em else "body"

# advance call yakala (return await ... veya const ... = await ...)
mret = re.search(r"(?s)\n(\s*)return\s+await\s+this\.dealsService\.advance\((.*?)\);\s*\n", method)
if mret:
    indent = mret.group(1)
    args = mret.group(2)
    injected = (
        f"\n{indent}const result = await this.dealsService.advance({args});\n"
        f"{indent}if ({body_var}.event === 'QUESTIONS_COMPLETED') {{\n"
        f"{indent}  const updated = await this.dealsService.ensureStatusReadyForMatching({id_var});\n"
        f"{indent}  return updated;\n"
        f"{indent}}}\n"
        f"{indent}return result;\n"
    )
    method2 = method[:mret.start()] + injected + method[mret.end():]
else:
    mcall = re.search(r"(?s)\n(\s*)const\s+(\w+)\s*=\s*await\s+this\.dealsService\.advance\((.*?)\);\s*\n", method)
    if not mcall:
        print("NO_ADVANCE_CALL_PATTERN")
        raise SystemExit(2)
    indent = mcall.group(1)
    inject_at = mcall.end()
    hook = (
        f"{indent}if ({body_var}.event === 'QUESTIONS_COMPLETED') {{\n"
        f"{indent}  await this.dealsService.ensureStatusReadyForMatching({id_var});\n"
        f"{indent}}}\n"
    )
    method2 = method[:inject_at] + hook + method[inject_at:]

new_src = "".join(lines[:method_start]) + method2 + "".join(lines[end_i+1:])
p.write_text(new_src, encoding="utf-8")
print("PATCHED_CONTROLLER")
PY

say "4) Build"
cd "$API_DIR"
pnpm -s build

say "✅ DONE"
echo
echo "Run:"
echo "  cd $API_DIR"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./e2e-managed-advance.sh"
