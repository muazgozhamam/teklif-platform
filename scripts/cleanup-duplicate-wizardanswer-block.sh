#!/usr/bin/env bash
set -euo pipefail

FILE="$(pwd)/apps/api/src/leads/leads.service.ts"
[[ -f "$FILE" ]] || { echo "❌ Missing $FILE"; exit 1; }

python3 - "$FILE" <<'PY'
import sys, re
from pathlib import Path

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 1) locate wizardAnswer method
m = re.search(r"\basync\s+wizardAnswer\s*\(", txt)
if not m:
    print("❌ wizardAnswer not found"); raise SystemExit(2)

# find method body start "{"
brace_open = txt.find("{", m.end())
if brace_open == -1:
    print("❌ wizardAnswer body brace not found"); raise SystemExit(3)

# brace-match to get full method body range
i = brace_open + 1
depth = 1
while i < len(txt) and depth > 0:
    ch = txt[i]
    if ch == "{": depth += 1
    elif ch == "}": depth -= 1
    i += 1
brace_close = i  # position after closing brace

method = txt[brace_open:brace_close]

# 2) ensure WIZPERS marker exists
if "WIZPERS_IN" not in method:
    print("❌ WIZPERS markers not found inside wizardAnswer. Aborting."); raise SystemExit(4)

# 3) find the point right after WIZPERS_SKIP_EMPTY log (end of first block)
anchor = method.find("WIZPERS_SKIP_EMPTY")
if anchor == -1:
    print("❌ Could not find WIZPERS_SKIP_EMPTY anchor. Aborting."); raise SystemExit(5)

# move to end of that line
line_end = method.find("\n", anchor)
if line_end == -1:
    line_end = len(method)

rest = method[line_end+1:]

# 4) find the duplicate second "if (key && answer)" in the remaining part
dup_start = re.search(r"^\s*if\s*\(\s*key\s*&&\s*answer\s*\)\s*\{", rest, flags=re.M)
if not dup_start:
    print("ℹ️ No duplicate second if(key&&answer) found. Nothing to do.")
    raise SystemExit(0)

start_idx = line_end + 1 + dup_start.start()

# Now remove that duplicate block ONLY (brace-match from its "{")
# Find the first "{" of that if
dup_brace = method.find("{", start_idx)
if dup_brace == -1:
    print("❌ Duplicate block brace not found"); raise SystemExit(6)

j = dup_brace + 1
d = 1
while j < len(method) and d > 0:
    ch = method[j]
    if ch == "{": d += 1
    elif ch == "}": d -= 1
    j += 1
dup_end = j  # after the closing brace of that if-block

new_method = method[:start_idx] + method[dup_end:]

new_txt = txt[:brace_open] + new_method + txt[brace_close:]

bak = p.with_suffix(p.suffix + ".dedupe.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Removed duplicate wizardAnswer persist block.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
PY

echo
echo "==> Build (apps/api)"
cd "$(pwd)/apps/api"
pnpm -s build
echo "✅ Build OK"
