#!/usr/bin/env bash
set -euo pipefail

FILE="e2e-managed-advance.sh"
[[ -f "$FILE" ]] || { echo "❌ $FILE yok."; exit 1; }

cp -f "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 - "$FILE" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
lines = p.read_text(encoding="utf-8").splitlines(True)

# "==> 7) Assert status ==" satırını bul
idx = None
for i,l in enumerate(lines):
    if "Assert status ==" in l:
        idx = i
        break

if idx is None:
    print("NO_ASSERT_BLOCK")
    raise SystemExit(2)

# Assert bloğunun hemen öncesine DEAL_JSON fetch enjekte et (zaten varsa ekleme)
inject = (
    '\n'
    '  # Assert için dealı tekrar çek (DEAL_JSON unbound olmasın)\n'
    '  DEAL_JSON="$(curl -fsS "$BASE/deals/by-lead/$LEAD_ID")"\n'
)

# idx’den geriye doğru bakıp yakınlarda DEAL_JSON assignment var mı kontrol et
window = "".join(lines[max(0, idx-20):idx])
if 'DEAL_JSON="$(curl' in window:
    print("ALREADY_HAS_DEAL_JSON_NEAR_ASSERT")
    raise SystemExit(0)

# "==> 7) Assert" echo satırından hemen önce inject
lines.insert(idx, inject)

p.write_text("".join(lines), encoding="utf-8")
print("PATCHED")
PY

echo "✅ PATCHED: $FILE (Assert öncesi DEAL_JSON fetch eklendi)"
echo "Run:"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./$FILE"
