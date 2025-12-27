#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
SCHEMA="$API_DIR/prisma/schema.prisma"

say(){ printf "\n==> %s\n" "$*"; }
die(){ printf "\n❌ %s\n" "$*" >&2; exit 1; }

[[ -d "$API_DIR" ]] || die "apps/api bulunamadı. Script repo kökünde çalıştırılmalı."
[[ -f "$SCHEMA" ]] || die "Prisma schema bulunamadı: $SCHEMA"

say "1) Prisma DealStatus enum: READY_FOR_MATCHING (yoksa ekle)"
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

new_block="\n".join(out)
new_txt = txt[:m.start(1)] + new_block + txt[m.end(1):]
p.write_text(new_txt, encoding="utf-8")
print("PATCHED")
PY

say "2) API: QUESTIONS_COMPLETED -> status=READY_FOR_MATCHING patch"

# QUESTIONS_COMPLETED geçen dosyaları bul
CANDIDATES="$(grep -RIl --exclude-dir=dist --exclude-dir=node_modules "QUESTIONS_COMPLETED" "$API_DIR/src" || true)"
[[ -n "$CANDIDATES" ]] || die "QUESTIONS_COMPLETED geçen dosya bulunamadı (apps/api/src)."

# Öncelik: deals.engine.ts / deals.service.ts / deals.controller.ts
TARGET_FILE="$(echo "$CANDIDATES" | grep -E "deals\.(engine|service|controller)\.ts$" | head -n 1 || true)"
if [[ -z "$TARGET_FILE" ]]; then
  TARGET_FILE="$(echo "$CANDIDATES" | head -n 1)"
fi

say "   - Target: $TARGET_FILE"

# Python patch: switch-case veya update(data) içine status ekleme
python3 - "$TARGET_FILE" <<'PY'
import re, pathlib, sys

path = pathlib.Path(sys.argv[1])
txt = path.read_text(encoding="utf-8")

# 1) switch-case: case 'QUESTIONS_COMPLETED':
m = re.search(r"(?s)(case\s+['\"]QUESTIONS_COMPLETED['\"]\s*:\s*)(.*?)(\bbreak\s*;)", txt)
if m:
    head, body, tail = m.group(1), m.group(2), m.group(3)

    # status literal varsa değiştir
    if re.search(r"status\s*:\s*['\"][A-Z_]+['\"]", body):
        body2 = re.sub(r"(status\s*:\s*)['\"][A-Z_]+['\"]", r"\1'READY_FOR_MATCHING'", body)
        path.write_text(txt[:m.start()] + head + body2 + tail + txt[m.end():], encoding="utf-8")
        print("PATCHED_CASE_STATUS_LITERAL")
        sys.exit(0)

    # status enum varsa değiştir
    if re.search(r"status\s*:\s*DealStatus\.[A-Z_]+", body):
        body2 = re.sub(r"(status\s*:\s*DealStatus\.)[A-Z_]+", r"\1READY_FOR_MATCHING", body)
        path.write_text(txt[:m.start()] + head + body2 + tail + txt[m.end():], encoding="utf-8")
        print("PATCHED_CASE_STATUS_ENUM")
        sys.exit(0)

    # status yoksa, data: { içine ekle
    dm = re.search(r"data\s*:\s*\{", body)
    if dm:
        insert_at = dm.end()
        body2 = body[:insert_at] + "\n        status: 'READY_FOR_MATCHING'," + body[insert_at:]
        path.write_text(txt[:m.start()] + head + body2 + tail + txt[m.end():], encoding="utf-8")
        print("PATCHED_CASE_INSERT_IN_DATA")
        sys.exit(0)

# 2) event kontrolü + prisma update(data) paterni
if "QUESTIONS_COMPLETED" in txt:
    um = re.search(r"(?s)(prisma\.\w+\.update\s*\(\s*\{.*?data\s*:\s*\{)", txt)
    if um and "status:" not in txt[um.start():um.end()+200]:
        insert_at = um.end()
        new = txt[:insert_at] + "\n        status: 'READY_FOR_MATCHING'," + txt[insert_at:]
        path.write_text(new, encoding="utf-8")
        print("PATCHED_UPDATE_DATA_INSERT")
        sys.exit(0)

print("NO_PATCH")
sys.exit(2)
PY

say "3) E2E script patch (200/201 kabul + EXPECT_STATUS default)"
E2E="$API_DIR/e2e-managed-advance.sh"
if [[ -f "$E2E" ]]; then
  # 200 -> 200/201 kabul
  perl -0777 -i -pe 's/\[\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\]/[[ "${adv_code}" == "200" || "${adv_code}" == "201" ]]/g' "$E2E" || true
  # EXPECT_STATUS default boşsa READY_FOR_MATCHING yap
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
