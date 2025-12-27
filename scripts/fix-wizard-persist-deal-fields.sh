#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
FILE="${FILE:-$ROOT/apps/api/src/leads/leads.service.ts}"

if [[ ! -f "$FILE" ]]; then
  echo "❌ leads.service.ts not found at: $FILE"
  echo "Kontrol:"
  echo "  ls -la $ROOT/apps/api/src/leads"
  exit 1
fi

python3 - "$FILE" <<'PY'
import re, sys
from pathlib import Path

file_path = sys.argv[1]
p = Path(file_path)
txt = p.read_text(encoding="utf-8")

marker = "WIZARD_PERSIST_DEAL_FIELDS"
if marker in txt:
    print("ℹ️ Patch already applied (marker found). No changes.")
    raise SystemExit(0)

m = re.search(r"\basync\s+wizardAnswer\s*\(", txt)
if not m:
    print("❌ Could not find 'async wizardAnswer(' in leads.service.ts")
    raise SystemExit(2)

# Find the opening brace '{' for the method body
i = m.start()
brace = txt.find("{", i)
if brace == -1:
    print("❌ Could not find method body '{' for wizardAnswer")
    raise SystemExit(3)

# Determine indentation inside method
line_start = txt.rfind("\n", 0, m.start()) + 1
base_indent = re.match(r"[ \t]*", txt[line_start:m.start()]).group(0)
inner = base_indent + "  "

# Best-effort prisma handle detection
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

insert = f"""
{inner}// {marker}: persist latest wizard answer into Deal table
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
{inner}      // keep as-is; adjust here if Deal.type is an enum
{inner}      data.type = answer;
{inner}      break;
{inner}    case 'rooms': {{
{inner}      // if Deal.rooms is Int, try parse; else keep string
{inner}      const n = Number(String(answer).replace(/[^0-9]/g, ''));
{inner}      data.rooms = Number.isFinite(n) && n > 0 ? n : answer;
{inner}      break;
{inner}    }}
{inner}    default:
{inner}      break;
{inner}  }}
{inner}  if (Object.keys(data).length) {{
{inner}    await {prisma_handle}.deal.update({{
{inner}      where: {{ leadId }},
{inner}      data,
{inner}    }});
{inner}  }}
{inner}}}
"""

new_txt = txt[:brace+1] + insert + txt[brace+1:]

bak = p.with_suffix(p.suffix + ".bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Patch applied.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- Prisma handle: {prisma_handle}")
PY
