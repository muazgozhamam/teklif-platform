#!/usr/bin/env bash
set -euo pipefail

FILE="$(pwd)/apps/api/src/leads/leads.service.ts"
[[ -f "$FILE" ]] || { echo "❌ Missing $FILE"; exit 1; }

python3 - "$FILE" <<'PY'
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 0) Signature must match what you printed
sig_pat = r"\basync\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*key\?\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*\{"
m = re.search(sig_pat, txt)
if not m:
    print("❌ wizardAnswer signature not as expected. Aborting to avoid breaking code.")
    m2 = re.search(r"\basync\s+wizardAnswer\s*\([^)]*\)\s*\{", txt)
    if m2: print("Found signature:", txt[m2.start():txt.find('{', m2.end())])
    raise SystemExit(2)

MARK = "WIZARD_DEAL_UPSERT_PERSIST_V1"
if MARK in txt:
    print("ℹ️ Patch already applied (marker exists).")
    raise SystemExit(0)

# locate method opening brace
brace = txt.find("{", m.end()-1)
if brace == -1:
    print("❌ Could not find wizardAnswer body brace.")
    raise SystemExit(3)

# indentation
line_start = txt.rfind("\n", 0, m.start()) + 1
base_indent = re.match(r"[ \t]*", txt[line_start:m.start()]).group(0)
inner = base_indent + "  "

# prisma handle detect
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

insert = f"""
{inner}// {MARK}
{inner}if (key && answer) {{
{inner}  const data: any = {{}};
{inner}  switch (key) {{
{inner}    case 'city': data.city = answer; break;
{inner}    case 'district': data.district = answer; break;
{inner}    case 'type': data.type = answer; break;
{inner}    case 'rooms': data.rooms = answer; break;
{inner}    default: break;
{inner}  }}
{inner}  if (Object.keys(data).length) {{
{inner}    await {prisma_handle}.deal.upsert({{
{inner}      where: {{ leadId }},
{inner}      update: data,
{inner}      create: {{
{inner}        leadId,
{inner}        status: 'OPEN',
{inner}        ...data,
{inner}      }},
{inner}    }});
{inner}  }}
{inner}}}
"""

new_txt = txt[:brace+1] + insert + txt[brace+1:]
bak = p.with_suffix(p.suffix + ".finalpersist.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Final wizard persist patch applied (deal.upsert).")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- Prisma handle: {prisma_handle}")
PY

echo
echo "==> Build check (no restart here)"
cd "$(pwd)/apps/api"
pnpm -s build
echo "✅ Build OK"
echo
echo "NEXT:"
echo "1) API restart (pnpm start:dev)"
echo "2) In repo root: bash scripts/wizard-and-match-doctor.sh"
