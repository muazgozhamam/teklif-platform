#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
FILE="${FILE:-$ROOT/apps/api/src/leads/leads.service.ts}"

if [[ ! -f "$FILE" ]]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

# pick a reasonable backup (newest/most specific first)
CANDIDATES=(
  "$FILE.autofix3.bak"
  "$FILE.wizdbg.bak"
  "$FILE.v3vars.bak"
  "$FILE.v3.bak"
  "$FILE.v2.bak"
  "$FILE.bak"
)

RESTORE_FROM=""
for f in "${CANDIDATES[@]}"; do
  if [[ -f "$f" ]]; then
    RESTORE_FROM="$f"
    break
  fi
done

if [[ -z "$RESTORE_FROM" ]]; then
  echo "❌ No backup found to restore from."
  echo "Looked for:"
  printf "  - %s\n" "${CANDIDATES[@]}"
  exit 2
fi

echo "==> Restoring leads.service.ts from: $RESTORE_FROM"
cp -f "$RESTORE_FROM" "$FILE"

python3 - "$FILE" <<'PY'
import re, sys
from pathlib import Path

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 1) Remove all previously injected blocks by known markers (safe cleanup)
markers = [
    "WIZARD_PERSIST_DEAL_FIELDS_V3",
    "WIZARD_PERSIST_FROM_CONTROLLER_V1",
    "WIZARD_PERSIST_FROM_CONTROLLER_V2",
    "WIZARD_PERSIST_FROM_CONTROLLER_V3",
    "WIZARD_PERSIST_DEBUG",
    "WIZDBG_",
]

# Remove comment-led blocks starting with any of these markers
for mk in markers:
    # remove blocks that start with "// <marker" until a blank line OR until next non-indented code boundary
    txt = re.sub(rf"\n[ \t]*//\s*{re.escape(mk)}.*?(?=\n[ \t]*\S)", "\n", txt, flags=re.S)

# Also remove any orphaned WIZDBG console logs if they remained
txt = re.sub(r"\n[ \t]*console\.log\('WIZDBG_[^']*'.*?\);\s*", "\n", txt)

# 2) Locate wizardAnswer method and extract param names
m = re.search(r"\basync\s+wizardAnswer\s*\(([^)]*)\)\s*\{", txt)
if not m:
    print("❌ Could not find async wizardAnswer(...) in leads.service.ts")
    raise SystemExit(3)

sig = m.group(1)
# capture param identifiers (the name before ':')
params = re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*:", sig)
if len(params) < 3:
    print("❌ wizardAnswer signature does not look like (leadId: ..., key: ..., answer: ...)")
    print("Signature:", sig)
    raise SystemExit(4)

lead_id, key_name, ans_name = params[0], params[1], params[2]

# 3) Find opening brace and indentation
brace = txt.find("{", m.end()-1)
if brace == -1:
    print("❌ Could not find method opening brace.")
    raise SystemExit(5)

line_start = txt.rfind("\n", 0, m.start()) + 1
base_indent = re.match(r"[ \t]*", txt[line_start:m.start()]).group(0)
inner = base_indent + "  "

# Prisma handle detect
prisma_handle = "this.prisma"
if "this.prismaService." in txt and "this.prisma." not in txt:
    prisma_handle = "this.prismaService"
elif "this.db." in txt and "this.prisma." not in txt and "this.prismaService." not in txt:
    prisma_handle = "this.db"

FINAL = "WIZARD_PERSIST_FINAL_V1"
if FINAL in txt:
    print("ℹ️ Final marker already present; skipping insert.")
    p.write_text(txt, encoding="utf-8")
    raise SystemExit(0)

insert = f"""
{inner}// {FINAL}: persist wizard answers into Deal table
{inner}if ({key_name} && {ans_name}) {{
{inner}  const data: any = {{}};
{inner}  switch ({key_name}) {{
{inner}    case 'city': data.city = {ans_name}; break;
{inner}    case 'district': data.district = {ans_name}; break;
{inner}    case 'type': data.type = {ans_name}; break;
{inner}    case 'rooms': data.rooms = {ans_name}; break; // keep raw like "2+1"
{inner}    default: break;
{inner}  }}
{inner}  if (Object.keys(data).length) {{
{inner}    await {prisma_handle}.deal.updateMany({{
{inner}      where: {{ leadId: {lead_id} }},
{inner}      data,
{inner}    }});
{inner}  }}
{inner}}}
"""

new_txt = txt[:brace+1] + insert + txt[brace+1:]

bak = p.with_suffix(p.suffix + ".finalpatch.bak")
bak.write_text(txt, encoding="utf-8")
p.write_text(new_txt, encoding="utf-8")

print("✅ Restored + cleaned + FINAL patch applied.")
print(f"- Updated: {p}")
print(f"- Backup:  {bak}")
print(f"- wizardAnswer params: leadId={lead_id}, key={key_name}, answer={ans_name}")
print(f"- Prisma handle: {prisma_handle}")
PY
