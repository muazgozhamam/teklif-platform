#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"

SVC="$API_DIR/src/deals/matching.service.ts"

echo "==> 1) matching.service.ts yaz"
cat > "$SVC" <<'TS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type DealLite = {
  id: string;
  city: string | null;
  district: string | null;
  type: string | null;
  rooms: string | null;
};

type ConsultantLite = {
  id: string;
  city?: string | null;
  district?: string | null;
  types?: string[] | null;
  rooms?: string[] | null;
};

/**
 * Matching V2:
 * - Kriter skoru: city/district/type/rooms
 * - Tie-break: aktif iş yükü düşük olan
 */
@Injectable()
export class MatchingService {
  constructor(private prisma: PrismaService) {}

  private norm(s?: string | null): string {
    return (s || '').trim().toLowerCase();
  }

  private score(deal: DealLite, c: ConsultantLite): number {
    let s = 0;

    const dCity = this.norm(deal.city);
    const dDistrict = this.norm(deal.district);
    const dType = this.norm(deal.type);
    const dRooms = this.norm(deal.rooms);

    const cCity = this.norm(c.city || null);
    const cDistrict = this.norm(c.district || null);

    // city match ağırlığı yüksek
    if (dCity && cCity && dCity === cCity) s += 50;

    // district
    if (dDistrict && cDistrict && dDistrict === cDistrict) s += 30;

    // type / rooms: consultant tablosunda yoksa seed kullanıyor olabilir.
    // Bu yüzden esnek: consultant'ı ayrıca "consultantPreferences" gibi ayrı bir tabloya taşımadık.
    // Eğer consultant üzerinde types/rooms yoksa puan eklemeyiz (0).
    const types = (c.types || []).map((x) => this.norm(x));
    const rooms = (c.rooms || []).map((x) => this.norm(x));

    if (dType && types.length && types.includes(dType)) s += 10;
    if (dRooms && rooms.length && rooms.includes(dRooms)) s += 10;

    return s;
  }

  private async loadByConsultant(): Promise<Map<string, number>> {
    // aktif sayılacak statuslar (senin akışa uygun)
    const active = await this.prisma.deal.groupBy({
      by: ['consultantId'],
      where: {
        consultantId: { not: null },
        status: { in: ['OPEN', 'ASKING', 'READY_FOR_MATCHING', 'ASSIGNED'] },
      },
      _count: { _all: true },
    });

    const m = new Map<string, number>();
    for (const row of active) {
      if (row.consultantId) m.set(row.consultantId, row._count._all);
    }
    return m;
  }

  async pickConsultantForDeal(dealId: string): Promise<{ consultantId: string; reason: any }> {
    const deal = await this.prisma.deal.findUnique({
      where: { id: dealId },
      select: { id: true, city: true, district: true, type: true, rooms: true },
    });
    if (!deal) throw new Error('Deal not found');

    // consultant modeli projeye göre değişebilir. En güvenlisi: Consultant tablosu varsa çek.
    // Eğer yoksa, mevcut seed consultant'lar user tablosunda olabilir.
    // Burada önce consultant tablosunu deneriz; hata olursa seed fallback.
    let consultants: ConsultantLite[] = [];
    try {
      // @ts-ignore
      consultants = await this.prisma.consultant.findMany({ select: { id: true, city: true, district: true, types: true, rooms: true } });
    } catch {
      // fallback: mevcut seed’lere dokunmadan, mevcut yaklaşımı koru
      return {
        consultantId: 'consultant_seed_1',
        reason: { fallback: true, note: 'No consultant table; using seed consultant_seed_1' },
      };
    }

    if (!consultants.length) {
      return {
        consultantId: 'consultant_seed_1',
        reason: { fallback: true, note: 'No consultants found; using seed consultant_seed_1' },
      };
    }

    const loadMap = await this.loadByConsultant();

    let best = consultants[0];
    let bestScore = -1;
    let bestLoad = Number.POSITIVE_INFINITY;

    for (const c of consultants) {
      const sc = this.score(deal, c);
      const ld = loadMap.get(c.id) ?? 0;

      // önce skor, sonra düşük load
      if (sc > bestScore || (sc === bestScore && ld < bestLoad)) {
        best = c;
        bestScore = sc;
        bestLoad = ld;
      }
    }

    return {
      consultantId: best.id,
      reason: {
        bestScore,
        bestLoad,
        deal,
        picked: best,
        loads: Object.fromEntries(loadMap.entries()),
      },
    };
  }
}
TS

echo "==> 2) DealsModule içine MatchingService ekle"
MOD="$API_DIR/src/deals/deals.module.ts"
python3 - <<'PY' "$MOD"
from pathlib import Path
import sys, re
p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

if "MatchingService" not in txt:
  # import ekle
  txt = re.sub(r"(from '\.\/deals\.service';\n)", r"\1import { MatchingService } from './matching.service';\n", txt)
  # providers içine ekle
  txt = re.sub(r"providers:\s*\[([^\]]*)\]", lambda m: f"providers: [{m.group(1).strip()}, MatchingService]", txt)
p.write_text(txt, encoding="utf-8")
print("✅ patched", p)
PY

echo "==> 3) DealsService match mantığını MatchingService ile bağla"
SVC2="$API_DIR/src/deals/deals.service.ts"
python3 - <<'PY' "$SVC2"
from pathlib import Path
import sys, re
p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

# import ekle
if "MatchingService" not in txt:
  txt = re.sub(r"(from '\.\./prisma/prisma\.service';\n)", r"\1import { MatchingService } from './matching.service';\n", txt)

# constructor'a inject
if "private matching" not in txt:
  txt = re.sub(
    r"constructor\(\s*private prisma: PrismaService\s*\)",
    "constructor(private prisma: PrismaService, private matching: MatchingService)",
    txt
  )

# matchDeal veya benzeri method içinde consultant seçimini değiştir.
# consultant_seed_1 hardcode'u varsa replace edelim.
txt = txt.replace("const consultantId = 'consultant_seed_1';", "const pick = await this.matching.pickConsultantForDeal(id);\n    const consultantId = pick.consultantId;")

# match update dönüşüne reason eklemek istersek controller'a dokunmadan loglayabiliriz.
if "pickConsultantForDeal" in txt and "console.log" not in txt:
  pass

p.write_text(txt, encoding="utf-8")
print("✅ patched", p)
PY

echo
echo "✅ DONE."
echo "Şimdi API restart etmen gerekiyor:"
echo "  cd $API_DIR && pnpm start:dev"
