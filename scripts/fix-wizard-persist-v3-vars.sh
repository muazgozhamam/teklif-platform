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

marker = "WIZARD_PERSIST_FROM_CONTROLLER_V3"
if marker not in txt:
    print(f"❌ Marker not found: {marker}")
    raise SystemExit(2)

# 1) Find wizardAnswer signature and extract first 3 param names
m = re.search(r"\basync\s+wizardAnswer\s*\(([^)]*)\)\s*\{", txt)
if not m:
    print("❌ Could not find async wizardAnswer(...) signature.")
    raise SystemExit(3)

sig = m.group(1)
# get param identifiers before ':'
names = re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*:", sig)
if len(names) < 1:
    print("❌ Could not parse parameter names from wizardAnswer signature.")
    print("Signature:", sig)
    raise SystemExit(4)

lead_id = names[0]
key_name = names[1] if len(names) >= 2 else "key"
ans_name = names[2] if len(names) >= 3 else "answer"

# 2) Replace the entire marker block safely
# We replace from marker comment line to the end of the injected if-block (the next line that starts with same indent and closes it)
block_pat = re.compile(
    r"^[ \t]*//\s+" + re.escape(marker) + r":.*?\n(?:(?:.|\n)*?)^[ \t]*}\n",
    re.MULTILINE
)
mm = block_pat.search(txt)
if not mm:
    # fallback: replace until a blank line after the block
    mm = re.search(r"^[ \t]*//\s+" + re.escape(marker) + r":.*?\n(?:(?:.|\n)*?)\n", txt, flags=re.M|re.S)
    if not mm:
        print("❌ Could not locate marker block region to replace.")
        raise SystemExit(5)

# indent from marker line
marker_line_start = txt.rfind("\n", 0, mm.start()) + 1
indent = re.match(r"[ \t]*", txt[marker_line_start:mm.start()]).group(0)

# prisma handle detect
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

replacement = f"""{indent}// {marker}: persist wizard answers into Deal (fixed vars)
{indent}const __wizKey = {key_name};
{indent}const __wizAnswer = {ans_name};
{indent}if (__wizKey && __wizAnswer) {{
{indent}  const data: any = {{}};
{indent}  switch (__wizKey) {{
{indent}    case 'city': data.city = __wizAnswer; break;
{indent}    case 'district': data.district = __wizAnswer; break;
{indent}    case 'type': data.type = __wizAnswer; break;
{indent}    case 'rooms': data.rooms = __wizAnswer; break;
{indent}    default: break;
{indent}  }}
{indent}  if (Object.keys(data).length) {{
{indent}    await {prisma_handle}.deal.updateMany({{
{indent}      where: {{ leadId: {lead_id} }},
{indent}      data,
{indent}    }});
{indent}  }}
{indent}}}
"""

new_txt = txt[:mm.start()] + replacement + txt[mm.end():]

bak = p.with_suffix(p.suffix + ".v3vars.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ V3 marker block vars fixed.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- wizardAnswer params: leadId={lead_id}, key={key_name}, answer={ans_name}")
print(f"- Prisma handle: {prisma_handle}")
PY
