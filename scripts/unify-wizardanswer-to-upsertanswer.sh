#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"
[[ -f "$FILE" ]] || { echo "❌ Missing $FILE"; exit 1; }

python3 - <<'PY'
import re
from pathlib import Path

p = Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")

MARK="WIZ_TO_UPSERT_UNIFY_V1"
if MARK in txt:
    print("ℹ️ Already unified (marker exists).")
    raise SystemExit(0)

# find wizardAnswer method
m = re.search(r"\basync\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*key\?\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*\{", txt)
if not m:
    print("❌ wizardAnswer signature not found (expected leadId,key?,answer?).")
    raise SystemExit(2)

brace_open = txt.find("{", m.end()-1)
i = brace_open+1
depth=1
while i < len(txt) and depth>0:
    if txt[i] == "{": depth += 1
    elif txt[i] == "}": depth -= 1
    i += 1
brace_close = i

method = txt[m.start():brace_close]

# indent
line_start = txt.rfind("\n", 0, m.start()) + 1
base_indent = re.match(r"[ \t]*", txt[line_start:m.start()]).group(0)
inner = base_indent + "  "

new_method = (
    f"{txt[m.start():brace_open+1]}\n"
    f"{inner}// {MARK}\n"
    f"{inner}// Single source of truth: reuse upsertAnswer persist logic\n"
    f"{inner}return this.upsertAnswer(leadId, key as any, answer as any);\n"
    f"{base_indent}}}\n"
)

new_txt = txt[:m.start()] + new_method + txt[brace_close:]
bak = p.with_suffix(p.suffix + ".wizunify.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ wizardAnswer now delegates to upsertAnswer.")
print(f"- Updated: {p}")
print(f"- Backup : {bak}")
PY

echo "==> Build"
pnpm -s -C apps/api build
echo "✅ Build OK"
