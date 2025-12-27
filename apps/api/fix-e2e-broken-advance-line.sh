#!/usr/bin/env bash
set -euo pipefail

FILE="e2e-managed-advance.sh"
[[ -f "$FILE" ]] || { echo "❌ $FILE yok."; exit 1; }

cp -f "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 - "$FILE" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1])
lines = p.read_text(encoding="utf-8").splitlines(True)

out = []
removed = 0

for l in lines:
    # Tam olarak senin gördüğün bozuk satır paterni:
    if re.search(r'^\s*\[\[\s*""\s*==\s*"200"\s*\|\|\s*""\s*==\s*"201"\s*\]\]\s*\|\|\s*fail_with_log_tail\s*', l):
        removed += 1
        continue
    # Daha genel: [[ "" == "200" ... ]] şeklinde bir şey enjekte olduysa
    if re.search(r'^\s*\[\[\s*""\s*==\s*".*?"\s*(\|\|\s*""\s*==\s*".*?")?\s*\]\]\s*\|\|\s*fail_with_log_tail\s*', l):
        removed += 1
        continue
    out.append(l)

p.write_text("".join(out), encoding="utf-8")
print(f"REMOVED={removed}")
PY

echo "✅ Patched. Şimdi kontrol:"
echo "  grep -n \"Advance HTTP\" e2e-managed-advance.sh"
echo
echo "Run:"
echo "  EXPECT_STATUS=READY_FOR_MATCHING ./e2e-managed-advance.sh"
