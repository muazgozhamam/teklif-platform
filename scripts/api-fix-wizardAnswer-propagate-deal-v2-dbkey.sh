#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"
if [[ ! -f "$FILE" ]]; then
  echo "❌ Bulunamadı: $FILE"
  exit 1
fi

python3 - <<'PY' "$FILE"
import sys, re, pathlib

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 1) wizardAnswer method body locate
m = re.search(r"async\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*\{", txt)
if not m:
  raise SystemExit("❌ wizardAnswer metodu bulunamadı.")

# brace match
i = m.end()
depth = 1
while i < len(txt) and depth > 0:
  ch = txt[i]
  if ch == '{': depth += 1
  elif ch == '}': depth -= 1
  i += 1
method_start = m.end()
method_end = i-1
body = txt[method_start:method_end]

# 2) remove old propagate block if exists
body2 = re.sub(
  r"\n\s*// --- propagate wizard answer -> deal fields ---\n.*?\n\s*// --- end propagate ---\n",
  "\n",
  body,
  flags=re.DOTALL
)

# 3) find a safe anchor: after leadAnswer create/upsert
# we will insert right after the FIRST await this.prisma.leadAnswer.*
ma = re.search(r"(await\s+this\.prisma\.leadAnswer\.[A-Za-z0-9_]+\([^\)]*\)\s*;?)", body2)
if not ma:
  raise SystemExit("❌ wizardAnswer içinde prisma.leadAnswer.* (create/upsert) bulunamadı. Bu fix DB key’e dayanıyor.")

# detect indentation from that line
# find line start
line_start = body2.rfind("\n", 0, ma.start()) + 1
indent = re.match(r"\s*", body2[line_start:]).group(0)

snippet = f"""
{indent}// --- propagate wizard answer -> deal fields (DB key source) ---
{indent}const __last = await this.prisma.leadAnswer.findFirst({{
{indent}  where: {{ leadId }},
{indent}  orderBy: {{ createdAt: 'desc' }},
{indent}  select: {{ key: true }},
{indent}});
{indent}const __k = (__last?.key || '').toString();

{indent}const __data: any = {{}};
{indent}if (__k === 'city') __data.city = answer;
{indent}else if (__k === 'district') __data.district = answer;
{indent}else if (__k === 'type') __data.type = answer;
{indent}else if (__k === 'rooms') __data.rooms = answer;

{indent}if (Object.keys(__data).length) {{
{indent}  await this.prisma.deal.updateMany({{
{indent}    where: {{ leadId }},
{indent}    data: __data,
{indent}  }});
{indent}}
{indent}// --- end propagate ---
"""

insert_pos = ma.end()
body3 = body2[:insert_pos] + snippet + body2[insert_pos:]

out = txt[:method_start] + body3 + txt[method_end:]
p.write_text(out, encoding="utf-8")
print(f"✅ Patched v2 (db key): {p}")
PY

echo
echo "✅ DONE."
echo "API restart et:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Test:"
echo "  cd ~/Desktop/teklif-platform && bash scripts/wizard-and-match-doctor.sh"
