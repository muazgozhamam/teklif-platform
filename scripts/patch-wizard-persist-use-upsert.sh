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

marker = "WIZARD_PERSIST_FINAL_V1"
if marker not in txt:
    print(f"❌ Marker not found: {marker}")
    raise SystemExit(2)

# Find wizardAnswer signature to infer param names
m = re.search(r"\basync\s+wizardAnswer\s*\(([^)]*)\)\s*\{", txt)
if not m:
    print("❌ Could not find async wizardAnswer(...) signature.")
    raise SystemExit(3)

sig = m.group(1)
params = re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*:", sig)
if len(params) < 3:
    print("❌ wizardAnswer signature params not parsed.")
    print("Signature:", sig)
    raise SystemExit(4)

lead_id, key_name, ans_name = params[0], params[1], params[2]

# Detect prisma handle (same heuristics)
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

# Replace only the persistence part inside the marker block: from "if (Object.keys(data).length)" to its closing braces.
block_pat = re.compile(
    r"(//\s+" + re.escape(marker) + r":.*?\n)([\s\S]*?)(?=\n\s*}\s*\n)",  # up to the end of outer if
    re.M
)
mb = block_pat.search(txt)
if not mb:
    print("❌ Could not locate marker block to patch.")
    raise SystemExit(5)

block_start = mb.start(2)
block_body = txt[block_start:mb.end(2)]

# Find the existing inner persistence stanza
persist_pat = re.compile(r"\n([ \t]*)if\s*\(\s*Object\.keys\(data\)\.length\s*\)\s*\{[\s\S]*?\n\1\}", re.M)
mp = persist_pat.search(block_body)
if not mp:
    print("❌ Could not find existing 'if (Object.keys(data).length) { ... }' stanza inside marker block.")
    raise SystemExit(6)

indent = mp.group(1)

replacement = f"""
{indent}if (Object.keys(data).length) {{
{indent}  // Deal wizard sırasında henüz oluşmamış olabilir; varsa update, yoksa create.
{indent}  await {prisma_handle}.deal.upsert({{
{indent}    where: {{ leadId: {lead_id} }},
{indent}    update: data,
{indent}    create: {{
{indent}      leadId: {lead_id},
{indent}      status: 'OPEN',
{indent}      ...data,
{indent}    }},
{indent}  }});
{indent}}}""".rstrip()

new_block_body = block_body[:mp.start()] + "\n" + replacement + block_body[mp.end():]
new_txt = txt[:block_start] + new_block_body + txt[mb.end(2):]

bak = p.with_suffix(p.suffix + ".upsertpatch.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Patched wizard persist to use deal.upsert() (create if missing).")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- wizardAnswer params: leadId={lead_id}, key={key_name}, answer={ans_name}")
print(f"- Prisma handle: {prisma_handle}")
PY
