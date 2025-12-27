#!/usr/bin/env bash
set -euo pipefail

FILE="e2e-managed-advance.sh"

[[ -f "$FILE" ]] || { echo "❌ $FILE yok. apps/api içinde çalıştır."; exit 1; }

cp -f "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 - "$FILE" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

orig = txt

# 1) En yaygın iki kontrol formunu yakala ve genişlet:
#    a) if [[ "${adv_code}" != "200" ]]; then ...
txt = re.sub(
    r'(\bif\s+\[\[\s*"\$\{adv_code\}"\s*!=\s*"200"\s*\]\]\s*;\s*then\b)',
    'if [[ "${adv_code}" != "200" && "${adv_code}" != "201" ]]; then',
    txt
)

#    b) if [[ "${adv_code}" == "200" ]]; then ... else fail ...
txt = re.sub(
    r'(\bif\s+\[\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\]\s*;\s*then\b)',
    'if [[ "${adv_code}" == "200" || "${adv_code}" == "201" ]]; then',
    txt
)

# 2) Bazı varyantlar: if [ "$adv_code" != "200" ]; then ...
txt = re.sub(
    r'(\bif\s+\[\s*"\$\{adv_code\}"\s*!=\s*"200"\s*\]\s*;\s*then\b)',
    'if [ "${adv_code}" != "200" ] && [ "${adv_code}" != "201" ]; then',
    txt
)
txt = re.sub(
    r'(\bif\s+\[\s*"\$\{adv_code\}"\s*==\s*"200"\s*\]\s*;\s*then\b)',
    'if [ "${adv_code}" = "200" ] || [ "${adv_code}" = "201" ]; then',
    txt
)

if txt == orig:
    print("NO_CHANGE_FOUND (adv_code condition bulunamadı)")
    raise SystemExit(2)

p.write_text(txt, encoding="utf-8")
print("PATCHED_OK")
PY

echo "✅ PATCHED: $FILE (201 artık OK)"
echo "Run:"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./$FILE"
