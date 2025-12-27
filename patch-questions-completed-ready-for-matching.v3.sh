#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SRC="$API_DIR/src"
SCHEMA="$API_DIR/prisma/schema.prisma"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -d "$API_DIR" ]] || die "apps/api yok. Repo kökünde çalıştır: ~/Desktop/teklif-platform"
[[ -d "$SRC" ]] || die "apps/api/src yok."
[[ -f "$SCHEMA" ]] || die "schema yok: $SCHEMA"

say "0) Hedef dosyaları bul"
CTRL="$(ls -1 "$SRC"/deals/deals.controller.ts 2>/dev/null || true)"
SVC="$(ls -1 "$SRC"/deals/deals.service.ts 2>/dev/null || true)"
[[ -f "$CTRL" ]] || die "DealsController bulunamadı: $SRC/deals/deals.controller.ts"
[[ -f "$SVC" ]]  || die "DealsService bulunamadı: $SRC/deals/deals.service.ts"

say "1) DealStatus enum READY_FOR_MATCHING var mı kontrol (yoksa ekle)"
python3 - <<'PY'
import re, pathlib, sys
p = pathlib.Path("apps/api/prisma/schema.prisma")
txt = p.read_text(encoding="utf-8")
m = re.search(r'(?ms)^\s*enum\s+DealStatus\s*\{\s*(.*?)^\s*\}\s*$', txt)
if not m:
    print("NO_ENUM_FOUND (skip)")
    sys.exit(0)
block = m.group(1)
if re.search(r'(?m)^\s*READY_FOR_MATCHING\s*$', block):
    print("ALREADY_PRESENT")
    sys.exit(0)
lines = block.splitlines()
out=[]
inserted=False
for line in lines:
    out.append(line)
    if (not inserted) and re.match(r'^\s*OPEN\s*$', line):
        out.append("  READY_FOR_MATCHING")
        inserted=True
if not inserted:
    out=["  READY_FOR_MATCHING"] + lines
new_txt = txt[:m.start(1)] + "\n".join(out) + txt[m.end(1):]
p.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "2) DealsService: ensure helper method ensureStatusReadyForMatching(id) ekle"

python3 - "$SVC" <<'PY'
import re, sys, pathlib
path = pathlib.Path(sys.argv[1])
txt = path.read_text(encoding="utf-8")

# Zaten eklendiyse çık
if "ensureStatusReadyForMatching" in txt:
    print("ALREADY_PRESENT")
    sys.exit(0)

# DealsService class bloğunu bul
m = re.search(r'(?s)export\s+class\s+DealsService\s*\{', txt)
if not m:
    print("NO_CLASS")
    sys.exit(2)

# Class içine (en sona yakın) method ekleyelim: son kapanan } öncesi
last = txt.rfind("}")
if last == -1 or last < m.start():
    print("NO_CLASS_END")
    sys.exit(2)

method = r'''
  /**
   * E2E / workflow safety: QUESTIONS_COMPLETED sonrası deal status'unu READY_FOR_MATCHING yap.
   * Not: prisma enum/migration durumuna göre DB tarafında enum değeri mevcut olmalı.
   */
  async ensureStatusReadyForMatching(dealId: string) {
    return this.prisma.deal.update({
      where: { id: dealId },
      data: { status: 'READY_FOR_MATCHING' as any },
    });
  }
'''

new_txt = txt[:last].rstrip() + "\n" + method + "\n}\n"
path.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "3) DealsController: advance handler sonrası QUESTIONS_COMPLETED hook ekle"

python3 - "$CTRL" <<'PY'
import re, sys, pathlib
path = pathlib.Path(sys.argv[1])
txt = path.read_text(encoding="utf-8")

# Zaten ekliyse çık
if "ensureStatusReadyForMatching" in txt and "QUESTIONS_COMPLETED" in txt:
    print("ALREADY_PRESENT")
    sys.exit(0)

# advance route methodunu yakala (çoğu projede @Post(':id/advance') bulunur)
# Strateji: @Post(':id/advance') ile başlayan method bloğunu bulup, method içinde advance çağrısından sonra if ekle
pm = re.search(r"(?s)@Post\(\s*['\"]:id/advance['\"]\s*\)\s*.*?\n\s*(async\s+\w+\s*\(.*?\)\s*\{.*?\n\s*\})", txt)
if not pm:
    print("NO_ADVANCE_HANDLER")
    sys.exit(2)

method_block = pm.group(1)

# id parametresi genelde @Param('id') id: string olur. event de body.dto.event olur.
# Biz method içinde dönen değişkeni yakalayalım: genelde `const res = await this.dealsService.advance(...)` veya `return this.dealsService.advance(...)`
# Eğer direkt return ise, önce result'a alıp sonra return edeceğiz.

# 1) Direkt return pattern
ret = re.search(r"(?s)\n(\s*)return\s+await\s+this\.dealsService\.advance\((.*?)\);\s*\n", method_block)
if ret:
    indent = ret.group(1)
    args = ret.group(2)

    # event erişimi: body?.event veya dto.event; method signature'da body param ismini bulalım
    # Basitçe method_block içinde ".event" geçen ilk body değişkenini bul:
    evm = re.search(r"\b(\w+)\.event\b", method_block)
    body_var = evm.group(1) if evm else "body"

    # id değişkeni: "id" genelde var; yoksa @Param('id') ile gelen değişkeni yakalamaya çalış
    idm = re.search(r"\bParam\(\s*['\"]id['\"]\s*\)\s*(\w+)\s*:\s*string", method_block)
    id_var = idm.group(1) if idm else "id"

    injected = (
        f"\n{indent}const result = await this.dealsService.advance({args});\n"
        f"{indent}if ({body_var}.event === 'QUESTIONS_COMPLETED') {{\n"
        f"{indent}  await this.dealsService.ensureStatusReadyForMatching({id_var});\n"
        f"{indent}  return this.dealsService.getById ? await this.dealsService.getById({id_var}) : result;\n"
        f"{indent}}}\n"
        f"{indent}return result;\n"
    )

    method_block2 = method_block[:ret.start()] + injected + method_block[ret.end():]
    txt2 = txt[:pm.start(1)] + method_block2 + txt[pm.end(1):]
    path.write_text(txt2, encoding="utf-8")
    print("PATCHED_RETURN_AWAIT")
    sys.exit(0)

# 2) const result = await ... pattern
call = re.search(r"(?s)\n(\s*)const\s+(\w+)\s*=\s*await\s+this\.dealsService\.advance\((.*?)\);\s*\n", method_block)
if call:
    indent = call.group(1)
    resvar = call.group(2)
    # body var
    evm = re.search(r"\b(\w+)\.event\b", method_block)
    body_var = evm.group(1) if evm else "body"
    idm = re.search(r"\bParam\(\s*['\"]id['\"]\s*\)\s*(\w+)\s*:\s*string", method_block)
    id_var = idm.group(1) if idm else "id"

    # injection point: call satırının hemen sonrası
    inject_point = call.end()
    hook = (
        f"{indent}if ({body_var}.event === 'QUESTIONS_COMPLETED') {{\n"
        f"{indent}  await this.dealsService.ensureStatusReadyForMatching({id_var});\n"
        f"{indent}}}\n"
    )
    method_block2 = method_block[:inject_point] + hook + method_block[inject_point:]
    txt2 = txt[:pm.start(1)] + method_block2 + txt[pm.end(1):]
    path.write_text(txt2, encoding="utf-8")
    print("PATCHED_CONST_RESULT")
    sys.exit(0)

print("NO_PATCH_PATTERN_MATCH")
sys.exit(2)
PY

say "4) Prisma generate + build"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build

say "✅ DONE"
echo
echo "Run E2E:"
echo "  cd $API_DIR"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./e2e-managed-advance.sh"
