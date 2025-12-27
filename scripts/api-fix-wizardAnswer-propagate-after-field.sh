#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"
if [[ ! -f "$FILE" ]]; then
  echo "❌ Bulunamadı: $FILE"
  exit 1
fi

python3 - <<'PY' "$FILE"
import re, pathlib, sys

p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

m = re.search(r"async\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*\{", txt)
if not m:
  raise SystemExit("❌ wizardAnswer metodu bulunamadı.")

# brace match
i = m.end()
depth = 1
while i < len(txt) and depth > 0:
  if txt[i] == '{': depth += 1
  elif txt[i] == '}': depth -= 1
  i += 1

method_start = m.end()
method_end = i-1
body = txt[method_start:method_end]

# eski propagate bloklarını temizle
body = re.sub(r"\n\s*// --- propagate wizard answer.*?// --- end propagate ---\n", "\n", body, flags=re.DOTALL)

# field/key satırını bul
mf = re.search(r"\n(\s*)const\s+(field|key)\s*=\s*.*?;\s*\n", body, flags=re.DOTALL)
if not mf:
  raise SystemExit("❌ wizardAnswer içinde 'const field = ...;' veya 'const key = ...;' bulunamadı.")

indent = mf.group(1)
varname = mf.group(2)  # field veya key

snippet = """
{indent}// --- propagate wizard answer -> deal fields (from {var}) ---
{indent}const __k = ({var} || '').toString();

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
""".format(indent=indent, var=varname)

insert_pos = mf.end()
body2 = body[:insert_pos] + snippet + body[insert_pos:]

out = txt[:method_start] + body2 + txt[method_end:]
p.write_text(out, encoding="utf-8")

print("✅ Patched:", p, "(after const %s)" % varname)
PY

echo
echo "✅ DONE."
echo "API restart et:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Test:"
echo "  cd ~/Desktop/teklif-platform && bash scripts/wizard-and-match-doctor.sh"
