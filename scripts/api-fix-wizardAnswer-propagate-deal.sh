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

# 1) wizardAnswer metodunu bul
m = re.search(r"async\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*\{", txt)
if not m:
  raise SystemExit("❌ wizardAnswer(leadId: string, answer?: string) metodu bulunamadı.")

# Basit brace matching ile method bloğunu çıkar
start = m.start()
i = m.end()
# find first '{' already at end of match? match ends at '{' so depth=1
depth = 1
while i < len(txt) and depth > 0:
  ch = txt[i]
  if ch == '{': depth += 1
  elif ch == '}': depth -= 1
  i += 1
method_block = txt[m.end():i-1]  # inside braces

# 2) "currentKey" veya "key" benzeri değişkeni yakala (wizard hangi alanı soruyor?)
# olası isimler: key, currentKey, nextKey, step.key...
# Öncelikle method içinde kullanılan en belirgin key değişkenini bulalım.
key_var = None
for cand in ["currentKey", "key", "nextKey", "stepKey", "field"]:
  if re.search(rf"\b{cand}\b", method_block):
    key_var = cand
    break

# Eğer doğrudan değişken yoksa, wizard next objesinden gelen ".key" kullanımı var mı?
if not key_var and ".key" in method_block:
  # fallback: answer kaydından önce kullanılan bir const yakala: const X = ...key
  mm = re.search(r"const\s+([A-Za-z0-9_]+)\s*=\s*[^;\n]*\.key\b", method_block)
  if mm:
    key_var = mm.group(1)

if not key_var:
  # son fallback: methodun içinde "city/district/type/rooms" switch'i yoksa biz ekleyeceğiz ama key'i nereden alacağız?
  # En güvenlisi: "next" objesi oluşturulurken kullanılan key'yi bulmak için 'key:' alanını arayalım.
  mm = re.search(r"key\s*:\s*'?(city|district|type|rooms)'?", method_block)
  if mm:
    # hard: ama burada sabit string var; gerçek key değişkeni yok
    key_var = "key"
    method_block = "const key = undefined as any;\n" + method_block
  else:
    raise SystemExit("❌ wizardAnswer içinde key değişkenini tespit edemedim (beklenenden farklı).")

# 3) Deal propagate helper (method içi inline, en az risk)
propagate_snippet = f"""
    // --- propagate wizard answer -> deal fields ---
    const __data: any = {{}};
    if ({key_var} === 'city') __data.city = answer;
    else if ({key_var} === 'district') __data.district = answer;
    else if ({key_var} === 'type') __data.type = answer;
    else if ({key_var} === 'rooms') __data.rooms = answer;

    if (Object.keys(__data).length) {{
      await this.prisma.deal.updateMany({{
        where: {{ leadId }},
        data: __data,
      }});
    }}
    // --- end propagate ---
"""

# 4) Snippet’i nereye koyacağız?
# En mantıklısı: answer DB'ye yazıldıktan hemen sonra.
# leadAnswer create/upsert varsa onun arkasına ekle; yoksa lead update arkasına.
insert_at = None
# method_block içinde prisma.leadAnswer.* await bul
ma = re.search(r"(await\s+this\.prisma\.leadAnswer\.[A-Za-z0-9_]+\([^\)]*\)\s*;?)", method_block)
if ma:
  insert_at = ma.end()
else:
  # lead update var mı?
  mb = re.search(r"(await\s+this\.prisma\.lead\.update\([^\)]*\)\s*;?)", method_block)
  if mb:
    insert_at = mb.end()

if insert_at is None:
  # hiçbiri yoksa, answer doğrulamasından sonra ekle
  mc = re.search(r"if\s*\(\s*!answer\s*\)\s*[^;]*;", method_block)
  insert_at = mc.end() if mc else 0

# Eğer snippet zaten eklenmişse tekrar ekleme
if "propagate wizard answer -> deal fields" not in method_block:
  method_block = method_block[:insert_at] + propagate_snippet + method_block[insert_at:]

# 5) Eski method bloğunu dosyada replace et
new_txt = txt[:m.end()] + method_block + txt[i-1:]  # keep closing brace

p.write_text(new_txt, encoding="utf-8")
print(f"✅ Patched: {p}")
print(f"✅ wizardAnswer key var detected: {key_var}")
PY

echo
echo "✅ DONE."
echo "Şimdi API'yi restart et:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Sonra test:"
echo "  cd ~/Desktop/teklif-platform && bash scripts/wizard-and-match-doctor.sh"
