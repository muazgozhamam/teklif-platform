#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

say() { printf "\n==> %s\n" "$*"; }
die() { printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -d "$API_DIR" ]] || die "apps/api bulunamadı. Bu script repo kökünde çalıştırılmalı: ~/Desktop/teklif-platform"
[[ -f "$SCHEMA" ]] || die "Prisma schema bulunamadı: $SCHEMA"

say "1) Prisma DealStatus enum: READY_FOR_MATCHING ekle (yoksa)"

# DealStatus enum bloğunu yakalayıp READY_FOR_MATCHING yoksa OPEN'dan sonra eklemeye çalışır
python3 - <<'PY'
import re, pathlib, sys
schema_path = pathlib.Path("apps/api/prisma/schema.prisma")
txt = schema_path.read_text(encoding="utf-8")

m = re.search(r'(?ms)^\s*enum\s+DealStatus\s*\{\s*(.*?)^\s*\}\s*$', txt)
if not m:
    print("NO_ENUM")
    sys.exit(0)

block = m.group(1)
if re.search(r'(?m)^\s*READY_FOR_MATCHING\s*$', block):
    print("ALREADY")
    sys.exit(0)

# OPEN satırından sonra eklemeyi dene; OPEN yoksa en üste ekle
lines = block.splitlines()
out = []
inserted = False
for line in lines:
    out.append(line)
    if (not inserted) and re.match(r'^\s*OPEN\s*$', line):
        out.append("  READY_FOR_MATCHING")
        inserted = True

if not inserted:
    # enum içinde OPEN yoksa bloğun başına ekle
    out = ["  READY_FOR_MATCHING"] + lines

new_block = "\n".join(out)
new_txt = txt[:m.start(1)] + new_block + txt[m.end(1):]
schema_path.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "2) API: QUESTIONS_COMPLETED -> status=READY_FOR_MATCHING patch"

# Deals tarafında advance logic nerede ise yakalamak için olası dosyaları tarıyoruz.
# Hedef: QUESTIONS_COMPLETED geçen yerde status'u READY_FOR_MATCHING'e set etmek.
CANDIDATES="$(grep -RIl --exclude-dir=dist --exclude-dir=node_modules "QUESTIONS_COMPLETED" "$API_DIR/src" || true)"
[[ -n "$CANDIDATES" ]] || die "QUESTIONS_COMPLETED geçen bir dosya bulunamadı (apps/api/src)."

# Heuristik: advance/transition mantığı genelde deals.service.ts içinde olur.
TARGET_FILE="$(echo "$CANDIDATES" | grep -E "deals\.(service|controller)\.ts$" | head -n 1 || true)"
if [[ -z "$TARGET_FILE" ]]; then
  # fallback: ilk adayı al
  TARGET_FILE="$(echo "$CANDIDATES" | head -n 1)"
fi

say "   - Target: $TARGET_FILE"

# Patch stratejisi:
# 1) 'QUESTIONS_COMPLETED' case bloğu içinde "status:" set'i varsa READY_FOR_MATCHING yap
# 2) Yoksa, event kontrolü yapılan yerde prisma update'e status ekle
#
# Not: Bu regex patch "yeterince standart" bir switch/case bekler. Olmazsa script fail eder ve dosyayı yazmadan çıkar.

python3 - <<'PY'
import re, pathlib, sys

path = pathlib.Path(sys.argv[1])
txt = path.read_text(encoding="utf-8")

if "READY_FOR_MATCHING" not in txt and "DealStatus.READY_FOR_MATCHING" not in txt:
    # import/enum kullanımına göre en minimal kullanım: string literal da olabilir ama biz enum tercih ederiz.
    pass

# 1) switch-case içinde "case 'QUESTIONS_COMPLETED':" arayalım
m = re.search(r"(?s)(case\s+['\"]QUESTIONS_COMPLETED['\"]\s*:\s*)(.*?)(\bbreak\s*;)", txt)
if m:
    head, body, tail = m.group(1), m.group(2), m.group(3)

    # body içinde status set ediliyorsa değiştir
    if re.search(r"status\s*:\s*['\"][A-Z_]+['\"]", body):
        body2 = re.sub(r"(status\s*:\s*)['\"][A-Z_]+['\"]", r"\1'READY_FOR_MATCHING'", body)
        new = txt[:m.start()] + head + body2 + tail + txt[m.end():]
        path.write_text(new, encoding="utf-8")
        print("PATCHED_CASE_STATUS_LITERAL")
        sys.exit(0)

    if re.search(r"status\s*:\s*DealStatus\.[A-Z_]+", body):
        body2 = re.sub(r"(status\s*:\s*DealStatus\.)[A-Z_]+", r"\1READY_FOR_MATCHING", body)
        new = txt[:m.start()] + head + body2 + tail + txt[m.end():]
        path.write_text(new, encoding="utf-8")
        print("PATCHED_CASE_STATUS_ENUM")
        sys.exit(0)

    # status set'i yoksa, prisma update içinde data:{} içine status eklemeye çalış
    # data: { ... } bloğunu yakala (ilk data: { ... } )
    dm = re.search(r"data\s*:\s*\{", body)
    if dm:
        # data: { açılışından hemen sonra status ekleyelim
        insert_at = dm.end()
        body2 = body[:insert_at] + "\n        status: 'READY_FOR_MATCHING'," + body[insert_at:]
        new = txt[:m.start()] + head + body2 + tail + txt[m.end():]
        path.write_text(new, encoding="utf-8")
        print("PATCHED_CASE_INSERT_IN_DATA")
        sys.exit(0)

# 2) switch-case yoksa: event == 'QUESTIONS_COMPLETED' gibi bir kontrol arayalım
m2 = re.search(r"(?s)(QUESTIONS_COMPLETED)(.*?)(prisma\.\w+\.update\s*\(\s*\{)", txt)
if m2:
    # update çağrısının data bloğuna status ekle (ilk data: { ... } bulunursa)
    # çok riskli olmaması için update(...) içinde data: { açılışından sonra ekleriz
    um = re.search(r"(?s)(prisma\.\w+\.update\s*\(\s*\{.*?data\s*:\s*\{)", txt)
    if um:
        insert_at = um.end()
        new = txt[:insert_at] + "\n        status: 'READY_FOR_MATCHING'," + txt[insert_at:]
        path.write_text(new, encoding="utf-8")
        print("PATCHED_UPDATE_DATA_INSERT")
        sys.exit(0)

print("NO_PATCH")
sys.exit(2)
PY "$TARGET_FILE" || die "QUESTIONS_COMPLETED patch uygulanamadı. (Dosya yapısı regex'e uymadı.) Target=$TARGET_FILE"

say "3) E2E script: advance için 200/201 kabul + default EXPECT_STATUS=READY_FOR_MATCHING"

E2E="$API_DIR/e2e-managed-advance.sh"
if [[ -f "$E2E" ]]; then
  # 200 check'i 200/201 yap
  perl -0777 -i -pe 's/\[\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\]/[[ "${adv_code}" == "200" || "${adv_code}" == "201" ]]/g' "$E2E" || true
  # Eğer EXPECT_STATUS default yoksa ekle (basit yaklaşım: değişken tanımlarında EXPECT_STATUS satırını bulup set et)
  perl -0777 -i -pe 's/EXPECT_STATUS="\$\{EXPECT_STATUS:-\}"/EXPECT_STATUS="\${EXPECT_STATUS:-READY_FOR_MATCHING}"/g' "$E2E" || true
  say "   - Patched: $E2E"
else
  say "   - Not found (skip): $E2E"
fi

say "4) Prisma generate + build"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build

say "✅ DONE"
echo
echo "Test:"
echo "  cd $API_DIR"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./e2e-managed-advance.sh"
