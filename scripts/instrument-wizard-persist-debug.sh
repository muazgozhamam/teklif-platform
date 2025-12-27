#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
FILE="${FILE:-$ROOT/apps/api/src/leads/leads.service.ts}"

if [[ ! -f "$FILE" ]]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

python3 - "$FILE" <<'PY'
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

marker = "WIZARD_PERSIST_DEAL_FIELDS_V3"
dbg = "WIZARD_PERSIST_DEBUG"

if dbg in txt:
    print("ℹ️ Debug already instrumented. Skipping.")
    raise SystemExit(0)

# Find the V3 block start
start = txt.find(f"// {marker}:")
if start == -1:
    print("❌ V3 marker block not found. (Expected to already have V3 applied)")
    raise SystemExit(2)

# Find a safe insertion point: right after "if (key && answer) {"
m = re.search(r"//\s+" + re.escape(marker) + r".*?\n([ \t]*)if\s*\(\s*key\s*&&\s*answer\s*\)\s*\{", txt, flags=re.S)
if not m:
    print("❌ Could not locate 'if (key && answer)' inside V3 block.")
    raise SystemExit(3)

indent = m.group(1) + "  "  # inside if-block
insert_pos = m.end()

debug_lines = f"""
{indent}// {dbg}: begin
{indent}try {{
{indent}  // eslint-disable-next-line no-console
{indent}  console.log('WIZDBG_IN', {{ leadId, key, answer }});
{indent}}} catch (e) {{}}
{indent}// {dbg}: end
"""

new_txt = txt[:insert_pos] + debug_lines + txt[insert_pos:]

# Now also instrument the updateMany call result
# Replace: await this.prisma.deal.updateMany({ ... });
# with: const res = await ...; console.log(...res.count...); const after=await findFirst; console.log(after);
# We'll do a targeted replace inside the V3 block only (nearest occurrence after start).
sub = new_txt[start:start+4000]  # local window
m2 = re.search(r"await\s+(this\.[A-Za-z0-9_]+)\.deal\.updateMany\s*\(\s*\{", sub)
if not m2:
    print("❌ Could not find updateMany call in V3 block window.")
    p.write_text(new_txt, encoding="utf-8")
    print("✅ WIZDBG_IN inserted, but updateMany instrumentation not applied.")
    raise SystemExit(0)

handle = m2.group(1)

# Find exact statement end ';' after that match in the full text
global_pos = start + m2.start()
stmt_start = start + m2.start()
semi = new_txt.find(");", stmt_start)
if semi == -1:
    print("❌ Could not find end of updateMany statement.")
    p.write_text(new_txt, encoding="utf-8")
    raise SystemExit(4)

stmt_end = semi + 2

# Extract indentation for that line
line_start = new_txt.rfind("\n", 0, stmt_start) + 1
stmt_indent = re.match(r"[ \t]*", new_txt[line_start:stmt_start]).group(0)

replacement = f"""{stmt_indent}const __wizRes = await {handle}.deal.updateMany({{
{stmt_indent}  where: {{ leadId }},
{stmt_indent}  data,
{stmt_indent}}});
{stmt_indent}// eslint-disable-next-line no-console
{stmt_indent}console.log('WIZDBG_UPD', {{ leadId, key, answer, updated: __wizRes.count }});
{stmt_indent}const __after = await {handle}.deal.findFirst({{
{stmt_indent}  where: {{ leadId }},
{stmt_indent}  select: {{ id: true, status: true, city: true, district: true, type: true, rooms: true }},
{stmt_indent}}});
{stmt_indent}// eslint-disable-next-line no-console
{stmt_indent}console.log('WIZDBG_AFTER', __after);
"""

new_txt2 = new_txt[:stmt_start] + replacement + new_txt[stmt_end:]

bak = p.with_suffix(p.suffix + ".wizdbg.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt2, encoding="utf-8")

print("✅ Wizard persist debug instrumentation applied.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
PY
