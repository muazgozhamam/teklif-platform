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

# 0) LeadsService var mı?
m_cls = re.search(r"export\s+class\s+LeadsService\s*\{", txt)
if not m_cls:
  raise SystemExit("❌ LeadsService class bulunamadı (export class LeadsService {)")

# 1) helper ekle (yoksa)
helper = """
  private async applyAnswerToDeal(leadId: string, key: string, answer: string) {
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
  insert_at = m_cls.end()
  txt = txt[:insert_at] + helper + txt[insert_at:]

# 2) “lead answer yazan” metodu bul:
#   - leadId paramı olacak
#   - içeride leadAnswer veya /answer DTO mapping bulunacak
method_headers = list(re.finditer(
  r"async\s+([A-Za-z0-9_]+)\s*\(\s*leadId\s*:\s*string\s*,\s*([A-Za-z0-9_]+)\s*:\s*[^)]+\)\s*\{",
  txt
))

def find_method_body_span(start_idx: int):
  # Basit brace matching
  i = start_idx
  depth = 0
  while i < len(txt) and txt[i] != '{':
    i += 1
  if i >= len(txt): return None
  depth = 1
  i += 1
  while i < len(txt) and depth > 0:
    ch = txt[i]
    if ch == '{':
      depth += 1
    elif ch == '}':
      depth -= 1
    i += 1
  return (start_idx, i)  # end is after closing brace

candidates = []
for mh in method_headers:
  span = find_method_body_span(mh.start())
  if not span: 
    continue
  body = txt[mh.end():span[1]]
  score = 0
  if "leadAnswer" in body: score += 5
  if "/answer" in body: score += 2
  if ".answer" in mh.group(1).lower(): score += 1
  if "dto.key" in body or "dto.field" in body or ".key" in body and "required" in body: score += 2
  if "wizard" in body.lower(): score += 1
  candidates.append((score, mh, span, body))

if not candidates:
  # Alternatif: leadId paramı olmayan ama leadAnswer geçen metodu yakala (fallback)
  fallback = re.search(r"async\s+([A-Za-z0-9_]+)\s*\([^)]*\)\s*\{", txt)
  if not fallback:
    raise SystemExit("❌ Hiç async method bulunamadı; dosya beklenenden farklı.")
  raise SystemExit("❌ leadId alan async method bulunamadı. (Beklenenden farklı imza)")

candidates.sort(key=lambda x: x[0], reverse=True)
score, mh, span, body = candidates[0]
method_name = mh.group(1)
dto_name = mh.group(2)

if score < 3:
  raise SystemExit(f"❌ Uygun answer metodu bulunamadı (bulunan en iyi: {method_name}, score={score}).")

# 3) Bu metodun içine normalize snippet ekle (yoksa)
normalize = f"""
    const key = ({dto_name} as any).key ?? ({dto_name} as any).field;
    const answer = ({dto_name} as any).answer ?? ({dto_name} as any).value;
    if (!key) throw new Error('key is required');
    if (answer === undefined || answer === null) throw new Error('answer is required');
"""

# method gövdesinin başına ekle
method_start = mh.end()
already = "const key =" in txt[method_start:method_start+300]
if not already:
  txt = txt[:method_start] + normalize + txt[method_start:]

# 4) answer kaydından sonra applyAnswerToDeal ekle (yoksa)
# Metodun güncel body’sini tekrar al
span2 = find_method_body_span(mh.start())
body2 = txt[mh.end():span2[1]]

if "applyAnswerToDeal(leadId" not in body2:
  # leadAnswer create/update vb. satırını bul
  anchor = re.search(r"(await\s+this\.prisma\.leadAnswer\.[A-Za-z0-9_]+\([^\)]*\)\s*;?)", body2)
  if not anchor:
    # lead update veya leadAnswer upsert olmayabilir; en azından ilk await'ten sonra ekle
    anchor = re.search(r"(await\s+[^\n;]+;)", body2)

  if not anchor:
    # hiç await yoksa, normalize sonrası ekle
    insert_pos = mh.end() + normalize.count("\n") + 1
  else:
    insert_pos = mh.end() + anchor.end()

  txt = txt[:insert_pos] + "\n    await this.applyAnswerToDeal(leadId, key, String(answer));\n" + txt[insert_pos:]

# 5) Bu metod içinde dto.key/field/answer/value kullanımlarını normalize değişkenlere çevir (güvenli)
txt = re.sub(rf"\b{re.escape(dto_name)}\.key\b", "key", txt)
txt = re.sub(rf"\b{re.escape(dto_name)}\.field\b", "key", txt)
txt = re.sub(rf"\b{re.escape(dto_name)}\.answer\b", "answer", txt)
txt = re.sub(rf"\b{re.escape(dto_name)}\.value\b", "answer", txt)

p.write_text(txt, encoding="utf-8")
print(f"✅ Patched: {p}")
print(f"✅ Target method: {method_name}(leadId, {dto_name}) (score={score})")
PY

echo
echo "✅ DONE."
echo "API'yi restart et:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Sonra test:"
echo "  cd ~/Desktop/teklif-platform && bash scripts/wizard-and-match-doctor.sh"
