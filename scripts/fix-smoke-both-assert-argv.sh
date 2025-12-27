#!/usr/bin/env bash
set -euo pipefail

FILE="scripts/smoke-both-answer-endpoints.sh"
[[ -f "$FILE" ]] || { echo "❌ Missing $FILE"; exit 1; }

python3 - "$FILE" <<'PY'
import sys
from pathlib import Path

p = Path(sys.argv[1])
lines = p.read_text(encoding="utf-8").splitlines(True)

# Assert bloğunu hedefle: "==> 5) Assert fields are set" satırından başla,
# bir sonraki 'echo' "✅ DONE" bloğuna kadar değiştir.
start = None
end = None

for i, ln in enumerate(lines):
    if '==> 5) Assert fields are set (basic)' in ln:
        start = i
        break

if start is None:
    raise SystemExit("❌ Could not find assert header (step 5) in smoke script.")

# end: ilk kez "echo" ve "✅ DONE" geçen bölgeye kadar (sondaki DONE'u koruyacağız)
for j in range(start, len(lines)):
    if 'echo "✅ DONE"' in lines[j]:
        # bu satır kalsın diye buradan ÖNCE bitecek şekilde ayarla
        end = j
        break

if end is None:
    raise SystemExit("❌ Could not find the final DONE echo to anchor replacement.")

new_block = """echo
echo "==> 5) Assert fields are set (basic)"
# NOTE: "node -" kullanınca process.argv[1] '-' olur. Dosya argümanı process.argv[2]'dedir.
node - "$TMP_DEAL_JSON" <<'NODE'
const fs = require("fs");

// node - <file>  => argv[1] = "-", argv[2] = "<file>"
// node <file>    => argv[1] = "<file>"
const path = (process.argv[2] && process.argv[2] !== "-") ? process.argv[2] : process.argv[1];

const raw = fs.readFileSync(path, "utf8");
const deal = JSON.parse(raw);

const ok =
  deal.city === "Konya" &&
  deal.district === "Meram" &&
  deal.type === "SATILIK" &&
  deal.rooms === "2+1";

if (!ok) {
  console.error("❌ FAIL: Deal fields not fully persisted");
  console.error("Got:", deal);
  process.exit(1);
}
console.log("✅ PASS: Deal fields persisted via BOTH endpoints");
NODE

echo
""".splitlines(True)

bak = p.with_suffix(p.suffix + ".argvfix.bak")
bak.write_text("".join(lines), encoding="utf-8")

patched = "".join(lines[:start]) + "".join(new_block) + "".join(lines[end:])
p.write_text(patched, encoding="utf-8")

print("✅ Patched assert block to handle node '-' argv correctly.")
print(f"- Updated: {p}")
print(f"- Backup : {bak}")
PY

chmod +x "$FILE"
echo "✅ OK"
