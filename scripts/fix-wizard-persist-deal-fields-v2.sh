#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
FILE="${FILE:-$ROOT/apps/api/src/leads/leads.service.ts}"

if [[ ! -f "$FILE" ]]; then
  echo "❌ leads.service.ts not found at: $FILE"
  exit 1
fi

python3 - "$FILE" <<'PY'
import re, sys
from pathlib import Path

file_path = sys.argv[1]
p = Path(file_path)
txt = p.read_text(encoding="utf-8")

marker = "WIZARD_PERSIST_DEAL_FIELDS"
if marker not in txt:
    print("❌ Marker not found. First patch must exist to apply v2.")
    print("Marker:", marker)
    raise SystemExit(2)

# Find wizardAnswer signature and help infer the lead id param name (usually 'id' or 'leadId')
m = re.search(r"\basync\s+wizardAnswer\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)", txt)
lead_param = "id"
if m:
    lead_param = m.group(1)

# Replace the entire marker block with a safer V2 block.
# We replace from the marker comment line up to the matching closing brace of that inserted block.
# We search a conservative pattern: marker line -> up to the next blank line after the block.
pattern = re.compile(
    r"^[ \t]*//\s+" + re.escape(marker) + r":.*?\n(?:(?:.|\n)*?)^[ \t]*}\n",
    re.MULTILINE
)

m2 = pattern.search(txt)
if not m2:
    # fallback: replace from marker line until first occurrence of a line that starts with the same indent and is blank after it
    # but keep it simple: try a wider match ending with the exact closing '}}}\n' from the original insert
    pattern2 = re.compile(
        r"^[ \t]*//\s+" + re.escape(marker) + r":.*?\n(?:(?:.|\n)*?)^[ \t]*}\}\}\n",
        re.MULTILINE
    )
    m2 = pattern2.search(txt)
    if not m2:
        print("❌ Could not locate the inserted marker block to replace.")
        raise SystemExit(3)

# Determine indentation from marker line
marker_line_start = txt.rfind("\n", 0, m2.start()) + 1
indent = re.match(r"[ \t]*", txt[marker_line_start:m2.start()]).group(0)

# Detect prisma handle (same as v1 logic)
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

# V2 block: find deal first, then update by id
replacement = f"""{indent}// {marker}: persist latest wizard answer into Deal table (v2: find by leadId, update by deal.id)
{indent}if (key && answer) {{
{indent}  const data: any = {{}};
{indent}  switch (key) {{
{indent}    case 'city':
{indent}      data.city = answer;
{indent}      break;
{indent}    case 'district':
{indent}      data.district = answer;
{indent}      break;
{indent}    case 'type':
{indent}      data.type = answer;
{indent}      break;
{indent}    case 'rooms':
{indent}      // keep raw (e.g., "2+1") unless your schema is Int
{indent}      data.rooms = answer;
{indent}      break;
{indent}    default:
{indent}      break;
{indent}  }}
{indent}  if (Object.keys(data).length) {{
{indent}    const deal = await {prisma_handle}.deal.findFirst({{
{indent}      where: {{ leadId: {lead_param} }},
{indent}      select: {{ id: true }},
{indent}    }});
{indent}    if (deal) {{
{indent}      await {prisma_handle}.deal.update({{
{indent}        where: {{ id: deal.id }},
{indent}        data,
{indent}      }});
{indent}    }}
{indent}  }}
{indent}}}
"""

new_txt = txt[:m2.start()] + replacement + txt[m2.end():]

bak = p.with_suffix(p.suffix + ".v2.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ V2 patch applied (marker block replaced).")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- Prisma handle: {prisma_handle}")
print(f"- leadId param inferred as: {lead_param}")
PY
