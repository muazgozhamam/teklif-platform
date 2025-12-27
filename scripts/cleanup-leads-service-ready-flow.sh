#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"

ts="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$ts"
echo "✅ Backup: $FILE.bak.$ts"

python3 - <<PY
from pathlib import Path
import re

path = Path("$FILE")
txt = path.read_text(encoding="utf-8")

def find_method_block(s: str, method_name: str):
    # finds "async methodName(...){...}" or "private methodName(...){...}"
    m = re.search(rf"\n\s*(?:public\s+|private\s+|protected\s+)?(?:async\s+)?{re.escape(method_name)}\s*\([^)]*\)\s*\{{", s)
    if not m:
        return None
    start = m.start()
    brace_start = s.find("{", m.end()-1)
    depth = 0
    for i in range(brace_start, len(s)):
        if s[i] == "{": depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                return (start, end)
    raise SystemExit(f"❌ Brace mismatch in {method_name}")

def replace_block(s: str, method_name: str, new_block: str):
    blk = find_method_block(s, method_name)
    if not blk:
        raise SystemExit(f"❌ Method not found: {method_name}")
    a,b = blk
    return s[:a] + "\n" + new_block.strip("\n") + "\n" + s[b:]

# 1) wizardNextQuestion: tek READY update + helper ile
wizard_next = r"""
  async wizardNextQuestion(leadId: string) {
    const deal = await this.dealsService.ensureForLead(leadId);

    const next =
      !deal.city ? { field: 'city', question: 'Hangi şehir?' } :
      !deal.district ? { field: 'district', question: 'Hangi ilçe?' } :
      !deal.type ? { field: 'type', question: 'Emlak türü nedir? (Satılık/Kiralık/Dükkan/Arsa vb.)' } :
      !deal.rooms ? { field: 'rooms', question: 'Kaç oda? (örn: 2+1, 3+1)' } :
      null;

    if (!next) {
      // Wizard tamamlandı: match'e hazır hale getir
      await this.markDealReadyForMatching(deal.id);
      return { done: true, dealId: deal.id };
    }

    return { done: false, dealId: deal.id, ...next };
  }
""".strip("\n")

txt = replace_block(txt, "wizardNextQuestion", wizard_next)

# 2) wizardAnswer: normalize + update + done hesapla + done ise helper + tek return
wizard_answer = r"""
  async wizardAnswer(leadId: string, answer?: string) {
    if (!answer || !String(answer).trim()) {
      return { ok: false, message: 'answer boş olamaz' };
    }

    const deal = await this.dealsService.ensureForLead(leadId);

    const field =
      !deal.city ? 'city' :
      !deal.district ? 'district' :
      !deal.type ? 'type' :
      !deal.rooms ? 'rooms' :
      null;

    if (!field) {
      // zaten tamam
      await this.markDealReadyForMatching(deal.id);
      const dealFinal = await this.prisma.deal.findUnique({
        where: { id: deal.id },
        include: { lead: true, consultant: true },
      });
      return { ok: true, done: true, dealId: deal.id, deal: dealFinal };
    }

    const value = this.normalizeWizardValue(field, String(answer));

    const data: any = {};
    data[field] = (field === 'type') ? this.normalizeType(value) : value;

    const updated = await this.dealsService['prisma'].deal.update({
      where: { id: deal.id },
      data,
      include: { lead: true, consultant: true },
    });

    const done = this.isDealWizardDone(updated);

    if (done) {
      await this.markDealReadyForMatching(deal.id);
      const dealFinal = await this.prisma.deal.findUnique({
        where: { id: deal.id },
        include: { lead: true, consultant: true },
      });

      return {
        ok: true,
        done: true,
        filled: field,
        deal: dealFinal,
        next: null,
      };
    }

    return {
      ok: true,
      done: false,
      filled: field,
      deal: updated,
      next: await this.wizardNextQuestion(leadId),
    };
  }
""".strip("\n")

txt = replace_block(txt, "wizardAnswer", wizard_answer)

# 3) isDealWizardDone: DUPLICATE temizliği
# Dosyada iki tane var: biri basit, biri (deal:any): boolean.
# Biz boolean signature'lı olanı BIRAKACAĞIZ; basit olanı sileceğiz.
pat = re.compile(r"\n\s*private\s+isDealWizardDone\s*\([^)]*\)\s*(?::\s*boolean\s*)?\{", re.M)
ms = list(pat.finditer(txt))
if len(ms) >= 2:
    # keep the one with ": boolean"
    keep_i = None
    for i,m in enumerate(ms):
        head = txt[m.start():m.start()+140]
        if re.search(r"\)\s*:\s*boolean\s*\{", head):
            keep_i = i
            break
    if keep_i is None:
        keep_i = 0

    def block_end(s: str, start_idx: int) -> int:
        i = s.find("{", start_idx)
        depth = 0
        for j in range(i, len(s)):
            c = s[j]
            if c == "{": depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return j+1
        return -1

    for i in sorted([i for i in range(len(ms)) if i != keep_i], reverse=True):
        a = ms[i].start()
        b = block_end(txt, a)
        if b == -1:
            raise SystemExit("❌ Brace mismatch while deleting duplicate isDealWizardDone")
        txt = txt[:a] + "\n" + txt[b:]

    # sanity
    ms2 = list(pat.finditer(txt))
    if len(ms2) != 1:
        raise SystemExit(f"❌ isDealWizardDone cleanup failed, found {len(ms2)}")
else:
    # 1 tane varsa dokunma
    pass

# 4) nextQuestion içinde gereksiz READY set ediliyorsa kaldırma (şimdilik olduğu gibi bırakmıyoruz, ama güvenli düzenliyoruz)
# Senin mevcut kod: COMPLETED olunca READY çekiyor. Bu OK.
# Sadece indentation/çift ensureForLead kalabalığını biraz toparlayalım: aynı davranış, daha temiz.
def clean_next_question_completed_block(s: str) -> str:
    # lead completed case: ensure deal + mark ready once
    return s

txt = clean_next_question_completed_block(txt)

path.write_text(txt, encoding="utf-8")
print("✅ LeadsService cleaned: wizardNextQuestion + wizardAnswer + isDealWizardDone dedup")
PY

echo
echo "==> Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"

echo
echo "Next test:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
