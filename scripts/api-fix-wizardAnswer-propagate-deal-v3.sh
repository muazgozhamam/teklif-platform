#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"

python3 - <<'PY'
import re, pathlib

p = pathlib.Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")

# wizardAnswer metodunu bul
m = re.search(r"async\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*\{", txt)
if not m:
    raise SystemExit("❌ wizardAnswer metodu bulunamadı")

# brace match
i = m.end()
depth = 1
while i < len(txt) and depth > 0:
    if txt[i] == '{': depth += 1
    elif txt[i] == '}': depth -= 1
    i += 1

method_start = m.end()
method_end = i - 1
body = txt[method_start:method_end]

# Eski propagate bloğunu temizle
body = re.sub(
    r"\n\s*// --- propagate wizard answer.*?// --- end propagate ---\n",
    "\n",
    body,
    flags=re.DOTALL
)

# leadAnswer create / upsert satırını bul
ma = re.search(r"(await\s+this\.prisma\.leadAnswer\.[A-Za-z0-9_]+\([^\)]*\)\s*;?)", body)
if not ma:
    raise SystemExit("❌ prisma.leadAnswer.* bulunamadı")

# indent bul
line_start = body.rfind("\n", 0, ma.start()) + 1
indent = re.match(r"\s*", body[line_start:]).group(0)

snippet = """
{indent}// --- propagate wizard answer -> deal fields (DB source) ---
{indent}const __last = await this.prisma.leadAnswer.findFirst({{
{indent}  where: {{ leadId }},
{indent}  orderBy: {{ createdAt: 'desc' }},
{indent}  select: {{ key: true }},
{indent}});
{indent}const __k = (__last?.key || '');

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
""".format(indent=indent)

insert_pos = ma.end()
body = body[:insert_pos] + snippet + body[insert_pos:]

out = txt[:method_start] + body + txt[method_end:]
p.write_text(out, encoding="utf-8")

print("✅ wizardAnswer propagate FIXED:", p)
PY

echo "✅ DONE"
echo "Şimdi API restart:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Sonra test:"
echo "  cd ~/Desktop/teklif-platform && bash scripts/wizard-and-match-doctor.sh"
