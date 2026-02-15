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

    if (dCity && cCity && dCity === cCity) s += 50;
    if (dDistrict && cDistrict && dDistrict === cDistrict) s += 30;

    const types = (c.types || []).map((x) => this.norm(x));
    const rooms = (c.rooms || []).map((x) => this.norm(x));

    if (dType && types.length && types.includes(dType)) s += 10;
    if (dRooms && rooms.length && rooms.includes(dRooms)) s += 10;

    return s;
  }

  private async loadByConsultant(consultantIds: string[]): Promise<Map<string, number>> {
    // Şemanda olmayan statusları kullanmıyoruz.
    // Eğer şemanda farklı “aktif” statuslar varsa sonradan script ile ekleriz.
    const ACTIVE_STATUSES = ['OPEN', 'READY_FOR_MATCHING', 'ASSIGNED'] as const;

    const m = new Map<string, number>();
    if (!consultantIds.length) {
      return m;
    }

    const rows = await this.prisma.deal.groupBy({
      by: ['consultantId'],
      where: {
        consultantId: { in: consultantIds },
        status: { in: [...ACTIVE_STATUSES] as any }, // Prisma enum farklarında TS takılmasın
      },
      _count: { _all: true },
    });

    for (const cid of consultantIds) m.set(cid, 0);
    for (const row of rows) {
      if (!row.consultantId) continue;
      m.set(row.consultantId, row._count?._all ?? 0);
    }
    return m;
  }

  async pickConsultantForDeal(dealId: string): Promise<{ consultantId: string; reason: any }> {
    const deal = await this.prisma.deal.findUnique({
      where: { id: dealId },
      select: { id: true, city: true, district: true, type: true, rooms: true },
    });
    if (!deal) throw new Error('Deal not found');

    let consultants: ConsultantLite[] = [];
    try {
      // consultant tablosu varsa
      // @ts-ignore
      consultants = await this.prisma.consultant.findMany({
        select: { id: true, city: true, district: true, types: true, rooms: true },
      });
    } catch {
      // consultant tablosu yoksa kırma: mevcut seed davranışı
      return {
        consultantId: 'consultant_seed_1',
        reason: { fallback: true, note: 'No consultant table; using consultant_seed_1' },
      };
    }

    if (!consultants.length) {
      return {
        consultantId: 'consultant_seed_1',
        reason: { fallback: true, note: 'No consultants found; using consultant_seed_1' },
      };
    }

    const loadMap = await this.loadByConsultant(consultants.map((c) => c.id));

    let best = consultants[0];
    let bestScore = -1;
    let bestLoad = Number.POSITIVE_INFINITY;

    for (const c of consultants) {
      const sc = this.score(deal, c);
      const ld = loadMap.get(c.id) ?? 0;

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
