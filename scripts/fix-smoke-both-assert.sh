#!/usr/bin/env bash
set -euo pipefail

F="scripts/smoke-both-answer-endpoints.sh"
[[ -f "$F" ]] || { echo "❌ Missing $F"; exit 1; }

python3 - <<'PY'
from pathlib import Path

p = Path("scripts/smoke-both-answer-endpoints.sh")
lines = p.read_text(encoding="utf-8").splitlines(True)  # keep \n

# Find start: the echo line that prints the assert header
start = None
for i, ln in enumerate(lines):
    if '==> 5) Assert fields are set (basic)' in ln:
        # Usually it's like: echo "==> 5) Assert ..."
        # Ensure we start at that echo line (or the previous "echo" line if present)
        start = i
        # if previous line is just `echo\n`, include it too for clean output
        if i > 0 and lines[i-1].strip() == "echo":
            start = i-1
        break

if start is None:
    raise SystemExit("❌ Could not find the assert header line (==> 5) in script.")

# Find end: after the line that prints ✅ DONE (include preceding echo if present)
end = None
for j in range(start, len(lines)):
    if 'echo "✅ DONE"' in lines[j] or "echo '✅ DONE'" in lines[j]:
        end = j + 1
        # include the previous `echo` if it's a blank echo
        if j > 0 and lines[j-1].strip() == "echo":
            start = min(start, j-1)  # already ok, but safe
        break

if end is None:
    raise SystemExit('❌ Could not find the "✅ DONE" line after the assert header.')

new_assert = """echo
echo "==> 5) Assert fields are set (basic)"
TMP_DEAL_JSON=".tmp-smoke-deal.json"
printf "%s" "$DEAL_JSON" > "$TMP_DEAL_JSON"

node - <<'NODE' "$TMP_DEAL_JSON"
const fs = require("fs");
const file = process.argv[1];
const raw = fs.readFileSync(file, "utf8").trim();
const deal = JSON.parse(raw);

const ok =
  deal.city === "Konya" &&
  deal.district === "Meram" &&
  deal.type === "SATILIK" &&
  deal.rooms === "2+1";

if (!ok) {
  console.error("❌ FAIL: Deal fields not fully persisted");
  console.error(deal);
  process.exit(1);
}
console.log("✅ PASS: Deal fields persisted via BOTH endpoints");
NODE

rm -f "$TMP_DEAL_JSON" || true

echo
echo "✅ DONE"
"""

bak = p.with_suffix(p.suffix + ".assertfix.bak")
bak.write_text("".join(lines), encoding="utf-8")

patched = "".join(lines[:start]) + new_assert + "".join(lines[end:])
p.write_text(patched, encoding="utf-8")

print("✅ Patched assert block (line-based).")
print(f"- Updated: {p}")
print(f"- Backup : {bak}")
print(f"- Replaced lines: {start+1}..{end}")
PY

chmod +x scripts/smoke-both-answer-endpoints.sh
echo "✅ OK"
