#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
FILE="$ROOT/apps/api/src/leads/leads.service.ts"

if [[ ! -f "$FILE" ]]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

python3 - "$FILE" <<'PY'
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

MARK = "DEAL_UPSERT_ON_WIZARD_ANSWER_V1"
if MARK in txt:
    print("ℹ️ Patch already applied (marker exists).")
    raise SystemExit(0)

m = re.search(r"\basync\s+wizardAnswer\s*\(([^)]*)\)\s*\{", txt)
if not m:
    print("❌ Could not find async wizardAnswer(...) in leads.service.ts")
    raise SystemExit(2)

sig = m.group(1)
params = re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*:", sig)
if len(params) < 3:
    print("❌ Could not parse (leadId, key, answer) param names from wizardAnswer signature.")
    print("Signature:", sig)
    raise SystemExit(3)

lead_id, key_name, ans_name = params[0], params[1], params[2]

brace = txt.find("{", m.end()-1)
if brace == -1:
    print("❌ Could not find opening brace for wizardAnswer.")
    raise SystemExit(4)

line_start = txt.rfind("\n", 0, m.start()) + 1
base_indent = re.match(r"[ \t]*", txt[line_start:m.start()]).group(0)
inner = base_indent + "  "

# Prisma handle detect
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

insert = f"""
{inner}// {MARK}: wizard answer geldiği anda Deal yoksa create et, varsa update et
{inner}if ({key_name} && {ans_name}) {{
{inner}  const data: any = {{}};
{inner}  switch ({key_name}) {{
{inner}    case 'city': data.city = {ans_name}; break;
{inner}    case 'district': data.district = {ans_name}; break;
{inner}    case 'type': data.type = {ans_name}; break;
{inner}    case 'rooms': data.rooms = {ans_name}; break;
{inner}    default: break;
{inner}  }}
{inner}  if (Object.keys(data).length) {{
{inner}    await {prisma_handle}.deal.upsert({{
{inner}      where: {{ leadId: {lead_id} }},
{inner}      update: data,
{inner}      create: {{
{inner}        leadId: {lead_id},
{inner}        status: 'OPEN',
{inner}        ...data,
{inner}      }},
{inner}    }});
{inner}  }}
{inner}}}
"""

new_txt = txt[:brace+1] + insert + txt[brace+1:]

bak = p.with_suffix(p.suffix + ".upsertv1.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Upsert patch inserted into wizardAnswer.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- wizardAnswer params: leadId={lead_id}, key={key_name}, answer={ans_name}")
print(f"- Prisma handle: {prisma_handle}")
PY
