#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
FILE="${FILE:-$ROOT/apps/api/src/leads/leads.service.ts}"

if [[ ! -f "$FILE" ]]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

# Prefer the newest backup we created
BKP_V2="$FILE.v2.bak"
BKP_V1="$FILE.bak"

if [[ -f "$BKP_V2" ]]; then
  echo "==> Restoring from: $BKP_V2"
  cp -f "$BKP_V2" "$FILE"
elif [[ -f "$BKP_V1" ]]; then
  echo "==> Restoring from: $BKP_V1"
  cp -f "$BKP_V1" "$FILE"
else
  echo "❌ No backup found. Expected one of:"
  echo "  - $BKP_V2"
  echo "  - $BKP_V1"
  exit 2
fi

python3 - "$FILE" <<'PY'
import re, sys
from pathlib import Path

file_path = sys.argv[1]
p = Path(file_path)
txt = p.read_text(encoding="utf-8")

# Remove any previous broken injected blocks if they exist (v1/v2 marker)
txt = re.sub(r"\n[ \t]*//\s+WIZARD_PERSIST_DEAL_FIELDS:.*?(?=\n[ \t]*\S)", "\n", txt, flags=re.S)
txt = re.sub(r"\n[ \t]*//\s+WIZARD_PERSIST_DEAL_FIELDS:.*", "\n", txt)

marker = "WIZARD_PERSIST_DEAL_FIELDS_V3"
if marker in txt:
    print("ℹ️ V3 marker already exists, skipping patch.")
    p.write_text(txt, encoding="utf-8")
    raise SystemExit(0)

# Find wizardAnswer method
m = re.search(r"\basync\s+wizardAnswer\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)", txt)
if not m:
    print("❌ Could not find async wizardAnswer(...)")
    raise SystemExit(3)

lead_param = m.group(1)

# Find opening brace of the method body
brace = txt.find("{", m.start())
if brace == -1:
    print("❌ Could not find opening '{' for wizardAnswer")
    raise SystemExit(4)

# Determine indentation inside method
line_start = txt.rfind("\n", 0, m.start()) + 1
base_indent = re.match(r"[ \t]*", txt[line_start:m.start()]).group(0)
inner = base_indent + "  "

# Detect prisma handle
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

# Safe persist block: use updateMany by leadId (no uniqueness assumption)
# Also: keep rooms as raw string (e.g., "2+1")
insert = f"""
{inner}// {marker}: persist latest wizard answer into Deal table (safe insert)
{inner}if (key && answer) {{
{inner}  const data: any = {{}};
{inner}  switch (key) {{
{inner}    case 'city':
{inner}      data.city = answer;
{inner}      break;
{inner}    case 'district':
{inner}      data.district = answer;
{inner}      break;
{inner}    case 'type':
{inner}      data.type = answer;
{inner}      break;
{inner}    case 'rooms':
{inner}      data.rooms = answer;
{inner}      break;
{inner}    default:
{inner}      break;
{inner}  }}
{inner}  if (Object.keys(data).length) {{
{inner}    await {prisma_handle}.deal.updateMany({{
{inner}      where: {{ leadId: {lead_param} }},
{inner}      data,
{inner}    }});
{inner}  }}
{inner}}}
"""

new_txt = txt[:brace+1] + insert + txt[brace+1:]

bak = p.with_suffix(p.suffix + ".v3.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Restored + V3 patch applied.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- Prisma handle: {prisma_handle}")
print(f"- leadId param: {lead_param}")
PY
