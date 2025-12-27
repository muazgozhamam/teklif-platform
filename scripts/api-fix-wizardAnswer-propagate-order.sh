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

# 1) Propagate bloğunu yakala
m_block = re.search(
  r"\n\s*// --- propagate wizard answer -> deal fields ---\n.*?\n\s*// --- end propagate ---\n",
  txt,
  flags=re.DOTALL
)
if not m_block:
  raise SystemExit("❌ Propagate bloğu bulunamadı. (Marker yok)")

block = m_block.group(0)

# 2) Bloğu şimdiki yerinden kaldır
txt2 = txt[:m_block.start()] + "\n" + txt[m_block.end():]

# 3) wizardAnswer içindeki 'const field' satırını bul ve hemen sonrasına ekle
# Önce wizardAnswer bloğunu tespit et (başlangıç)
m_wiz = re.search(r"async\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*\{", txt2)
if not m_wiz:
  raise SystemExit("❌ wizardAnswer metodu bulunamadı.")

# Basit brace matching ile wizardAnswer bloğu sınırlarını bul
start = m_wiz.start()
i = m_wiz.end()
depth = 1
while i < len(txt2) and depth > 0:
  ch = txt2[i]
  if ch == '{': depth += 1
  elif ch == '}': depth -= 1
  i += 1
wiz_end = i  # after closing brace
wiz_body = txt2[m_wiz.end():wiz_end-1]

# wizardAnswer içinde const field = ...; satırını bul
m_field = re.search(r"\n(\s*)const\s+field\s*=\s*.*?;\s*\n", wiz_body, flags=re.DOTALL)
if not m_field:
  raise SystemExit("❌ wizardAnswer içinde 'const field = ...;' bulunamadı.")

indent = m_field.group(1)
# bloğun indentini field ile hizala (mevcut block zaten 4 space gibi; ama garanti olsun)
block_fixed = re.sub(r"\n(\s*)", lambda mm: "\n" + (indent if mm.group(1) != "" else ""), block.strip("\n"))
block_fixed = "\n" + indent + block_fixed.replace("\n", "\n" + indent) + "\n"

# insert position: field satırının hemen sonrası
insert_pos_in_wiz = m_field.end()
wiz_body2 = wiz_body[:insert_pos_in_wiz] + block_fixed + wiz_body[insert_pos_in_wiz:]

# Dosyayı birleştir
out = txt2[:m_wiz.end()] + wiz_body2 + txt2[wiz_end-1:]

p.write_text(out, encoding="utf-8")
print(f"✅ Fixed order: {p}")
PY

echo
echo "✅ DONE."
echo "Şimdi TypeScript watch otomatik toparlamalı."
echo "Eğer çalışmıyorsa API restart:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Test:"
echo "  cd ~/Desktop/teklif-platform && bash scripts/wizard-and-match-doctor.sh"
