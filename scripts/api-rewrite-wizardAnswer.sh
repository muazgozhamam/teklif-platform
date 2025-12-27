#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"
test -f "$FILE" || { echo "❌ Missing: $FILE"; exit 1; }

python3 - <<'PY'
import pathlib, re

p = pathlib.Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")

m = re.search(r"\n(\s*)async\s+wizardAnswer\s*\(\s*leadId\s*:\s*string\s*,\s*answer\?\s*:\s*string\s*\)\s*{", txt)
if not m:
    raise SystemExit("❌ async wizardAnswer(leadId: string, answer?: string) bulunamadı.")

indent = m.group(1)
start = m.start()

# Brace matching from the opening "{"
i = m.end() - 1
depth = 0
end = None
while i < len(txt):
    ch = txt[i]
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            end = i + 1
            break
    i += 1

if end is None:
    raise SystemExit("❌ wizardAnswer bloğu kapanışı bulunamadı (brace match fail).")

new_method = f"""
{indent}async wizardAnswer(leadId: string, answer?: string) {{
{indent}  if (!answer || !String(answer).trim()) {{
{indent}    return {{ ok: false, message: 'answer boş olamaz' }};
{indent}  }}

{indent}  // Deal'i garanti et (leadId unique => tek deal)
{indent}  const deal = await this.dealsService.ensureForLead(leadId);

{indent}  // Sıradaki alanı deal snapshot'ından hesapla
{indent}  const field =
{indent}    !deal.city ? 'city' :
{indent}    !deal.district ? 'district' :
{indent}    !deal.type ? 'type' :
{indent}    !deal.rooms ? 'rooms' :
{indent}    null;

{indent}  if (!field) {{
{indent}    // zaten tamam
{indent}    await this.markDealReadyForMatching(deal.id);
{indent}    const dealFinal = await this.prisma.deal.findUnique({{
{indent}      where: {{ id: deal.id }},
{indent}      include: {{ lead: true, consultant: true }},
{indent}    }});
{indent}    return {{ ok: true, done: true, dealId: deal.id, deal: dealFinal }};
{indent}  }}

{indent}  // Normalize + write
{indent}  const value = this.normalizeWizardValue(field, String(answer));
{indent}  const data: any = {{}};
{indent}  data[field] = (field === 'type') ? this.normalizeType(value) : value;

{indent}  // KRİTİK: this.prisma kullan (tek kaynak)
{indent}  const updated = await this.prisma.deal.update({{
{indent}    where: {{ id: deal.id }},
{indent}    data,
{indent}    include: {{ lead: true, consultant: true }},
{indent}  }});

{indent}  const done = this.isDealWizardDone(updated);

{indent}  if (done) {{
{indent}    await this.markDealReadyForMatching(deal.id);
{indent}    const dealFinal = await this.prisma.deal.findUnique({{
{indent}      where: {{ id: deal.id }},
{indent}      include: {{ lead: true, consultant: true }},
{indent}    }});
{indent}    return {{
{indent}      ok: true,
{indent}      done: true,
{indent}      filled: field,
{indent}      deal: dealFinal,
{indent}      next: null,
{indent}    }};
{indent}  }}

{indent}  return {{
{indent}    ok: true,
{indent}    done: false,
{indent}    filled: field,
{indent}    deal: updated,
{indent}    next: await this.wizardNextQuestion(leadId),
{indent}  }};
{indent}}}
"""

out = txt[:start] + "\n" + new_method.strip("\n") + "\n" + txt[end:]
p.write_text(out, encoding="utf-8")
print(f"✅ Rewrote wizardAnswer(): {p}")
PY

echo "✅ DONE"
echo "Şimdi API restart:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "Test:"
echo "  cd ~/Desktop/teklif-platform && bash scripts/wizard-and-match-doctor.sh"
