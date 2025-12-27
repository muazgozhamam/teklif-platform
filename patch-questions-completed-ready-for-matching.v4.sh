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
[[ -f "$E2E"  ]] || die "E2E script yok: $E2E"

say "1) E2E: Advance için 200/201 kabul et"
perl -0777 -i -pe 's/\[\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\]/[[ "${adv_code}" == "200" || "${adv_code}" == "201" ]]/g' "$E2E" || true
say "   - Patched: $E2E"

say "2) DealsService: ensureStatusReadyForMatching yoksa ekle"
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

say "3) DealsController: @Post(...advance...) handlerına hook ekle (regex yerine blok-parsing)"

python3 - "$CTRL" <<'PY'
import sys, pathlib, re

p = pathlib.Path(sys.argv[1])
src = p.read_text(encoding="utf-8")

# Zaten patch'liyse çık
if "ensureStatusReadyForMatching" in src and "QUESTIONS_COMPLETED" in src:
    print("ALREADY_PRESENT")
    raise SystemExit(0)

lines = src.splitlines(True)

# 1) @Post(...) içinde advance geçen decorator'u bul
post_idx = None
for i, line in enumerate(lines):
    if "@Post" in line and "advance" in line:
        post_idx = i
        break
if post_idx is None:
    print("NO_POST_ADVANCE_DECORATOR")
    raise SystemExit(2)

# 2) Decorator'dan sonra gelen ilk method başlangıcını bul (async ... {)
method_start = None
for i in range(post_idx, min(post_idx+40, len(lines))):
    if re.search(r'\basync\b', lines[i]) and "{" in lines[i]:
        method_start = i
        break
if method_start is None:
    print("NO_METHOD_START_AFTER_DECORATOR")
    raise SystemExit(2)

# 3) method bloğunu brace matching ile çıkar
buf = []
brace = 0
started = False
end_idx = None
for i in range(method_start, len(lines)):
    buf.append(lines[i])
    for ch in lines[i]:
        if ch == "{":
            brace += 1
            started = True
        elif ch == "}":
            brace -= 1
    if started and brace == 0:
        end_idx = i
        break
if end_idx is None:
    print("NO_METHOD_END")
    raise SystemExit(2)

method = "".join(buf)

# 4) id var: @Param('id') xxx: string
idm = re.search(r"@Param\(\s*['\"]id['\"]\s*\)\s*(\w+)\s*:\s*string", method)
id_var = idm.group(1) if idm else "id"

# 5) body var: @Body() xxx
bm = re.search(r"@Body\(\s*\)\s*(\w+)", method)
body_var = bm.group(1) if bm else None
if body_var is None:
    # fallback: method içinde ".event" geçen ilk değişkeni yakala
    em = re.search(r"\b(\w+)\.event\b", method)
    body_var = em.group(1) if em else "body"

# 6) dealsService.advance çağrısını bul
# a) return await this.dealsService.advance(...)
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
    # b) const result = await this.dealsService.advance(...)
    mcall = re.search(r"(?s)\n(\s*)const\s+(\w+)\s*=\s*await\s+this\.dealsService\.advance\((.*?)\);\s*\n", method)
    if not mcall:
        print("NO_ADVANCE_CALL_PATTERN")
        raise SystemExit(2)
    indent = mcall.group(1)
    resvar = mcall.group(2)
    inject_at = mcall.end()
    hook = (
        f"{indent}if ({body_var}.event === 'QUESTIONS_COMPLETED') {{\n"
        f"{indent}  await this.dealsService.ensureStatusReadyForMatching({id_var});\n"
        f"{indent}}}\n"
    )
    method2 = method[:inject_at] + hook + method[inject_at:]

# 7) dosyaya yaz
new_lines = lines[:method_start] + [method2] + lines[end_idx+1:]
p.write_text("".join(new_lines), encoding="utf-8")
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
