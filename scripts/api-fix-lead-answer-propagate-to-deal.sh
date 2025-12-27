#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
FILE="$ROOT/apps/api/src/leads/leads.service.ts"

if [[ ! -f "$FILE" ]]; then
  echo "❌ Bulunamadı: $FILE"
  echo "   leads.service.ts yolu farklıysa söyle; scripti ona göre güncellerim."
  exit 1
fi

python3 - <<'PY' "$FILE"
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# 1) class içine helper ekle (varsa ekleme)
helper = r"""
  private async applyAnswerToDeal(leadId: string, key: string, answer: string) {
    // Lead'e bağlı tek bir deal var varsayımı
    const data: any = {};
    if (key === 'city') data.city = answer;
    else if (key === 'district') data.district = answer;
    else if (key === 'type') data.type = answer;
    else if (key === 'rooms') data.rooms = answer;
    else return;

    await this.prisma.deal.updateMany({
      where: { leadId },
      data,
    });
  }
"""

if "applyAnswerToDeal(" not in txt:
  # LeadsService class başlangıcından sonra eklemeye çalış
  m = re.search(r"(export\s+class\s+LeadsService\s*\{)", txt)
  if not m:
    raise SystemExit("❌ LeadsService class bulunamadı (export class LeadsService { )")
  insert_at = m.end()
  txt = txt[:insert_at] + helper + txt[insert_at:]

# 2) /answer metodu içinde DTO alanlarını normalize et ve applyAnswerToDeal çağır
# Çeşitli imzalar olabilir: dto.key/dto.answer veya dto.field/dto.value
# Bu yüzden method gövdesine "key/answer" normalize snippet'i en başa ekleyeceğiz.
normalize_snippet = r"""
    const key = (dto as any).key ?? (dto as any).field;
    const answer = (dto as any).answer ?? (dto as any).value;
    if (!key) throw new Error('key is required');
    if (answer === undefined || answer === null) throw new Error('answer is required');
"""

# async answer(leadId: string, dto: ...) { ... } bloğunu bul
m = re.search(r"async\s+answer\s*\(\s*leadId\s*:\s*string\s*,\s*dto\s*:[^)]+\)\s*\{", txt)
if not m:
  raise SystemExit("❌ async answer(leadId: string, dto: ...) metodu bulunamadı.")

# method gövdesinin hemen içine normalize ekle (zaten ekliyse ekleme)
start = m.end()
if "const key = (dto as any).key" not in txt[start:start+400]:
  txt = txt[:start] + normalize_snippet + txt[start:]

# applyAnswerToDeal çağrısı yoksa, method içinde lead answer kaydı sonrası ekle
# En risksiz: method içinde ilk "await this.prisma.lead" ya da "await this.prisma.leadAnswer" sonrası ekle
if "applyAnswerToDeal(leadId" not in txt:
  # leadAnswer create/findUnique vb. bir await'ten sonra ekle
  anchor = re.search(r"(await\s+this\.prisma\.(leadAnswer|lead)\.[a-zA-Z]+\([^\)]*\)\s*;?)", txt[start:])
  if not anchor:
    # daha basit: method içinde ilk await satırından sonra
    anchor = re.search(r"(await\s+[^\n;]+;)", txt[start:])
  if not anchor:
    raise SystemExit("❌ answer() içinde anchor bulunamadı; dosya beklenenden farklı.")
  a0 = start + anchor.end()
  txt = txt[:a0] + "\n    await this.applyAnswerToDeal(leadId, key, String(answer));\n" + txt[a0:]

# 3) answer() metodunda dto.key/dto.answer kullanılan yerleri key/answer'a çevir (varsa)
txt = re.sub(r"\bdto\.key\b", "key", txt)
txt = re.sub(r"\bdto\.answer\b", "answer", txt)
txt = re.sub(r"\bdto\.field\b", "key", txt)
txt = re.sub(r"\bdto\.value\b", "answer", txt)

p.write_text(txt, encoding="utf-8")
print(f"✅ Patched: {p}")
PY

echo
echo "✅ DONE."
echo "Şimdi API tarafını restart etmen gerekebilir:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Test:"
echo "  bash scripts/wizard-and-match-doctor.sh"
