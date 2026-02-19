import {
  BadRequestException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ListingStatus, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateListingDto,
  ListListingsQuery,
  UpdateListingDto,
  UpdateSahibindenDto,
  UpsertListingAttributesDto,
} from './listings.dto';

type AuthUser = { sub: string; role: Role | string };

const DEFAULT_TAKE = 24;
const MAX_TAKE = 100;
const TRY_CURRENCY = 'TRY';
const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT_PER_WINDOW = 120;

const rateBucket = new Map<string, { count: number; resetAt: number }>();

@Injectable()
export class ListingsService {
  constructor(private readonly prisma: PrismaService) {}

  private parseDecimal(value: string | number | null | undefined, fieldName: string) {
    if (value === null || value === undefined || value === '') return null;
    const normalized =
      typeof value === 'number'
        ? String(value)
        : String(value).trim().replace(/\./g, '').replace(',', '.');
    const num = Number(normalized);
    if (!Number.isFinite(num)) throw new BadRequestException(`${fieldName} geçersiz`);
    if (num <= 0) throw new BadRequestException(`${fieldName} pozitif olmalı`);
    return new Prisma.Decimal(normalized);
  }

  private parseTakeSkip(query: ListListingsQuery) {
    const takeNum = Number(query.take || DEFAULT_TAKE);
    const skipNum = Number(query.skip || 0);
    const take = Number.isFinite(takeNum) ? Math.min(Math.max(takeNum, 1), MAX_TAKE) : DEFAULT_TAKE;
    const skip = Number.isFinite(skipNum) ? Math.max(skipNum, 0) : 0;
    return { take, skip };
  }

  private parseBBox(raw?: string) {
    if (!raw) return null;
    const parts = String(raw)
      .split(',')
      .map((x) => Number(x.trim()));
    if (parts.length !== 4 || parts.some((x) => !Number.isFinite(x))) {
      throw new BadRequestException('bbox formatı geçersiz, latMin,lngMin,latMax,lngMax beklenir');
    }
    const [latMin, lngMin, latMax, lngMax] = parts;
    if (latMin > latMax || lngMin > lngMax) {
      throw new BadRequestException('bbox aralığı geçersiz');
    }
    return { latMin, lngMin, latMax, lngMax };
  }

  private enforcePublicRateLimit(ipOrKey: string) {
    const key = ipOrKey || 'unknown';
    const now = Date.now();
    const existing = rateBucket.get(key);
    if (!existing || existing.resetAt <= now) {
      rateBucket.set(key, { count: 1, resetAt: now + RATE_WINDOW_MS });
      return;
    }
    if (existing.count >= RATE_LIMIT_PER_WINDOW) {
      throw new HttpException(
        'Çok fazla istek gönderildi. Lütfen kısa süre sonra tekrar deneyin.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    existing.count += 1;
    rateBucket.set(key, existing);
  }

  private isAdmin(user: AuthUser) {
    return String(user.role || '').toUpperCase() === 'ADMIN';
  }

  private resolveOwnerId(row: {
    createdById?: string | null;
    consultantId?: string | null;
    userId?: string | null;
  }) {
    return row.createdById || row.consultantId || row.userId || null;
  }

  private assertCanMutate(user: AuthUser, row: { createdById?: string | null; consultantId?: string | null; userId?: string | null }) {
    if (this.isAdmin(user)) return;
    const ownerId = this.resolveOwnerId(row);
    if (!ownerId || ownerId !== user.sub) {
      throw new ForbiddenException('Bu ilanı düzenleme yetkiniz yok');
    }
  }

  private async writeAudit(actorUserId: string, action: string, listingId: string, meta?: Record<string, unknown>) {
    try {
      await (this.prisma as any).commissionAuditEvent.create({
        data: {
          action: 'SNAPSHOT_CREATED',
          entityType: 'SYSTEM',
          entityId: listingId,
          actorUserId,
          payloadJson: { domain: 'LISTING', action, ...(meta || {}) },
        },
      });
    } catch {
      // Audit tablosu stage/prod drift nedeniyle yok olabilir; listing akışını bloklamayız.
    }
  }

  private applyPrivacyForPublic<T extends { privacyMode?: string | null; lat?: number | null; lng?: number | null }>(
    row: T,
  ) {
    if (!row) return row;
    if (row.privacyMode === 'HIDDEN') {
      return { ...row, lat: null, lng: null };
    }
    if (row.privacyMode === 'APPROXIMATE') {
      const lat = typeof row.lat === 'number' ? Number(row.lat.toFixed(3)) : row.lat;
      const lng = typeof row.lng === 'number' ? Number(row.lng.toFixed(3)) : row.lng;
      return { ...row, lat, lng };
    }
    return row;
  }

  private async resolveLeafCategoryFromDto(dto: Pick<CreateListingDto, 'categoryLeafId' | 'categoryLeafPathKey' | 'categoryPathKey'>) {
    const leafPathKey = dto.categoryLeafPathKey || dto.categoryPathKey || null;

    let leaf:
      | {
          id: string;
          pathKey: string;
          _count?: { children?: number };
        }
      | null = null;

    if (dto.categoryLeafId) {
      leaf = await (this.prisma as any).categoryNode.findUnique({
        where: { id: dto.categoryLeafId },
        select: { id: true, pathKey: true, _count: { select: { children: true } } },
      });
    } else if (leafPathKey) {
      leaf = await (this.prisma as any).categoryNode.findUnique({
        where: { pathKey: leafPathKey },
        select: { id: true, pathKey: true, _count: { select: { children: true } } },
      });
    }

    if (!leaf) return null;
    const childCount = Number(leaf._count?.children || 0);
    if (childCount > 0) {
      throw new BadRequestException('Kategori leaf olmalı; parent kategori seçilemez');
    }
    return leaf;
  }

  async getPublicCategoriesTree() {
    const rows = await (this.prisma as any).categoryNode.findMany({
      where: { isActive: true },
      orderBy: [{ depth: 'asc' }, { order: 'asc' }, { name: 'asc' }],
      include: { _count: { select: { children: true } } },
    });

    const byId = new Map<string, any>();
    for (const row of rows) {
      byId.set(row.id, {
        id: row.id,
        pathKey: row.pathKey,
        name: row.name,
        slug: row.slug,
        depth: row.depth,
        order: row.order,
        isActive: row.isActive,
        isLeaf: Number(row._count?.children || 0) === 0,
        children: [],
      });
    }

    const roots: any[] = [];
    for (const row of rows) {
      const node = byId.get(row.id);
      if (row.parentId && byId.has(row.parentId)) {
        byId.get(row.parentId).children.push(node);
      } else {
        roots.push(node);
      }
    }
    return roots;
  }

  async getPublicCategoryLeaves() {
    const rows = await (this.prisma as any).categoryNode.findMany({
      where: {
        isActive: true,
        children: { none: {} },
      },
      orderBy: [{ depth: 'asc' }, { order: 'asc' }, { name: 'asc' }],
      select: { id: true, pathKey: true, name: true, slug: true, depth: true, order: true },
    });
    return rows.map((row: any) => ({ ...row, isLeaf: true }));
  }

  private async ensurePublishRequirements(listingId: string) {
    const listing = await this.prisma.listing.findUnique({
      where: { id: listingId },
      include: {
        listingAttributes: true,
      },
    });
    if (!listing) throw new NotFoundException('Listing not found');

    if (!listing.title?.trim()) throw new BadRequestException('Publish için başlık zorunlu');
    if (!listing.description?.trim()) throw new BadRequestException('Publish için açıklama zorunlu');
    if (!listing.city?.trim() || !listing.district?.trim() || !listing.neighborhood?.trim()) {
      throw new BadRequestException('Publish için şehir/ilçe/mahalle zorunlu');
    }
    if (listing.lat === null || listing.lat === undefined || listing.lng === null || listing.lng === undefined) {
      throw new BadRequestException('Map pin zorunlu: lat/lng olmadan yayınlanamaz');
    }

    const hasPrice = Boolean(listing.priceAmount) || listing.price !== null;
    if (!hasPrice) {
      throw new BadRequestException('Publish için fiyat zorunlu');
    }

    if (listing.categoryLeafId) {
      const requiredDefs = await (this.prisma as any).attributeDefinition.findMany({
        where: { categoryLeafId: listing.categoryLeafId, required: true },
        select: { key: true },
      });
      const requiredKeys = new Set<string>(requiredDefs.map((x: { key: string }) => x.key));
      const provided = new Set(listing.listingAttributes.map((x) => x.key));
      const missing = [...requiredKeys].filter((k) => !provided.has(k));
      if (missing.length > 0) {
        throw new BadRequestException(`Publish için eksik zorunlu özellikler: ${missing.join(', ')}`);
      }
    }

    return listing;
  }

  async listPublic(query: ListListingsQuery, ipOrKey: string) {
    this.enforcePublicRateLimit(ipOrKey);
    const { take, skip } = this.parseTakeSkip(query);
    const bbox = this.parseBBox(query.bbox);
    const q = String(query.q || '').trim();

    const where: Prisma.ListingWhereInput = {
      status: ListingStatus.PUBLISHED,
      ...(query.categoryLeafPathKey
        ? { categoryPathKey: String(query.categoryLeafPathKey) }
        : query.categoryPathKey
          ? { categoryPathKey: String(query.categoryPathKey) }
          : {}),
      ...(query.listingType ? { type: String(query.listingType) } : {}),
      ...(query.city ? { city: String(query.city) } : {}),
      ...(query.district ? { district: String(query.district) } : {}),
      ...(query.neighborhood ? { neighborhood: String(query.neighborhood) } : {}),
      ...(bbox
        ? {
            lat: { gte: bbox.latMin, lte: bbox.latMax },
            lng: { gte: bbox.lngMin, lte: bbox.lngMax },
          }
        : {}),
      ...(query.priceMin || query.priceMax
        ? {
            priceAmount: {
              gte: query.priceMin ? this.parseDecimal(query.priceMin, 'priceMin') || undefined : undefined,
              lte: query.priceMax ? this.parseDecimal(query.priceMax, 'priceMax') || undefined : undefined,
            },
          }
        : {}),
      ...(q
        ? {
            OR: [
              { title: { contains: q, mode: 'insensitive' } },
              { description: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.listing.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
        include: {
          categoryLeaf: { select: { id: true, name: true, pathKey: true } },
        },
      }),
      this.prisma.listing.count({ where }),
    ]);

    return {
      items: items.map((row) => this.applyPrivacyForPublic(row)),
      total,
      take,
      skip,
    };
  }

  async getPublicById(id: string) {
    const row = await this.prisma.listing.findFirst({
      where: { id, status: ListingStatus.PUBLISHED },
      include: {
        categoryLeaf: { select: { id: true, name: true, pathKey: true } },
        listingAttributes: true,
      },
    });
    if (!row) throw new NotFoundException('Listing not found');
    return this.applyPrivacyForPublic(row);
  }

  async createForUser(user: AuthUser, dto: CreateListingDto) {
    const leaf = await this.resolveLeafCategoryFromDto(dto);
    const priceAmount = this.parseDecimal(dto.priceAmount, 'priceAmount');
    const row = await this.prisma.listing.create({
      data: {
        createdById: user.sub,
        consultantId: dto.consultantId || user.sub,
        categoryLeafId: leaf?.id || null,
        categoryPathKey: leaf?.pathKey || null,
        title: String(dto.title || '').trim() || 'Yeni İlan Taslağı',
        description: String(dto.description || '').trim() || null,
        priceAmount,
        price: priceAmount ? Number(priceAmount) : null,
        currency: String(dto.currency || TRY_CURRENCY).toUpperCase(),
        city: dto.city?.trim() || null,
        district: dto.district?.trim() || null,
        neighborhood: dto.neighborhood?.trim() || null,
        lat: dto.lat ?? null,
        lng: dto.lng ?? null,
        privacyMode: dto.privacyMode || 'EXACT',
        type: dto.type?.trim() || null,
        rooms: dto.rooms?.trim() || null,
        status: 'DRAFT',
      },
    });

    await this.writeAudit(user.sub, 'LISTING_CREATED', row.id, { status: row.status });
    return row;
  }

  async listForUser(user: AuthUser, query: ListListingsQuery) {
    const { take, skip } = this.parseTakeSkip(query);
    const q = String(query.q || '').trim();

    const where: Prisma.ListingWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.categoryLeafPathKey
        ? { categoryPathKey: String(query.categoryLeafPathKey) }
        : query.categoryPathKey
          ? { categoryPathKey: String(query.categoryPathKey) }
          : {}),
      ...(query.listingType ? { type: String(query.listingType) } : {}),
      ...(query.city ? { city: String(query.city) } : {}),
      ...(query.district ? { district: String(query.district) } : {}),
      ...(query.neighborhood ? { neighborhood: String(query.neighborhood) } : {}),
      ...(q
        ? {
            OR: [
              { title: { contains: q, mode: 'insensitive' } },
              { description: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    if (!(this.isAdmin(user) && query.scope === 'all')) {
      where.OR = [
        { createdById: user.sub },
        { consultantId: user.sub },
        { userId: user.sub },
      ];
    }

    const [items, total] = await Promise.all([
      this.prisma.listing.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.listing.count({ where }),
    ]);
    return { items, total, take, skip };
  }

  async getByIdForUser(user: AuthUser, id: string) {
    const row = await this.prisma.listing.findUnique({
      where: { id },
      include: { listingAttributes: true, categoryLeaf: true },
    });
    if (!row) throw new NotFoundException('Listing not found');
    if (!this.isAdmin(user)) {
      this.assertCanMutate(user, row);
    }
    return row;
  }

  async patchForUser(user: AuthUser, id: string, dto: UpdateListingDto) {
    const current = await this.prisma.listing.findUnique({ where: { id } });
    if (!current) throw new NotFoundException('Listing not found');
    this.assertCanMutate(user, current);
    const hasCategoryPatch =
      dto.categoryLeafId !== undefined || dto.categoryLeafPathKey !== undefined || dto.categoryPathKey !== undefined;
    const leaf = hasCategoryPatch ? await this.resolveLeafCategoryFromDto(dto) : null;

    const priceAmount = dto.priceAmount !== undefined ? this.parseDecimal(dto.priceAmount, 'priceAmount') : undefined;
    const data: Prisma.ListingUncheckedUpdateInput = {
      categoryLeafId: hasCategoryPatch ? leaf?.id || null : undefined,
      categoryPathKey: hasCategoryPatch ? leaf?.pathKey || null : undefined,
      title: dto.title !== undefined ? String(dto.title).trim() || 'Yeni İlan Taslağı' : undefined,
      description: dto.description !== undefined ? String(dto.description).trim() || null : undefined,
      priceAmount,
      price: priceAmount ? Number(priceAmount) : undefined,
      currency: dto.currency !== undefined ? String(dto.currency || TRY_CURRENCY).toUpperCase() : undefined,
      city: dto.city !== undefined ? dto.city?.trim() || null : undefined,
      district: dto.district !== undefined ? dto.district?.trim() || null : undefined,
      neighborhood: dto.neighborhood !== undefined ? dto.neighborhood?.trim() || null : undefined,
      lat: dto.lat !== undefined ? dto.lat : undefined,
      lng: dto.lng !== undefined ? dto.lng : undefined,
      privacyMode: dto.privacyMode !== undefined ? dto.privacyMode : undefined,
      sahibindenUrl: dto.sahibindenUrl !== undefined ? dto.sahibindenUrl || null : undefined,
      type: dto.type !== undefined ? dto.type?.trim() || null : undefined,
      rooms: dto.rooms !== undefined ? dto.rooms?.trim() || null : undefined,
      status: dto.status !== undefined ? dto.status : undefined,
    };

    const updated = await this.prisma.listing.update({ where: { id }, data });
    await this.writeAudit(user.sub, 'LISTING_UPDATED', id);
    return updated;
  }

  async upsertAttributesForUser(user: AuthUser, id: string, dto: UpsertListingAttributesDto) {
    const row = await this.prisma.listing.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Listing not found');
    this.assertCanMutate(user, row);
    if (!Array.isArray(dto.attributes)) throw new BadRequestException('attributes array zorunlu');

    await this.prisma.$transaction(
      dto.attributes.map((attr) => {
        const key = String(attr.key || '').trim();
        if (!key) throw new BadRequestException('attribute.key zorunlu');
        return (this.prisma as any).listingAttribute.upsert({
          where: { listingId_key: { listingId: id, key } },
          update: { valueJson: attr.value as Prisma.InputJsonValue },
          create: { listingId: id, key, valueJson: attr.value as Prisma.InputJsonValue },
        });
      }),
    );

    await this.writeAudit(user.sub, 'LISTING_ATTRIBUTES_UPSERT', id, {
      count: dto.attributes.length,
    });
    return { ok: true };
  }

  async publishForUser(user: AuthUser, id: string) {
    const current = await this.prisma.listing.findUnique({ where: { id } });
    if (!current) throw new NotFoundException('Listing not found');
    this.assertCanMutate(user, current);
    await this.ensurePublishRequirements(id);

    const updated = await this.prisma.listing.update({
      where: { id },
      data: { status: ListingStatus.PUBLISHED },
    });
    await this.writeAudit(user.sub, 'LISTING_PUBLISHED', id);
    return updated;
  }

  async archiveForUser(user: AuthUser, id: string) {
    const current = await this.prisma.listing.findUnique({ where: { id } });
    if (!current) throw new NotFoundException('Listing not found');
    this.assertCanMutate(user, current);

    const updated = await this.prisma.listing.update({
      where: { id },
      data: { status: ListingStatus.ARCHIVED },
    });
    await this.writeAudit(user.sub, 'LISTING_ARCHIVED', id);
    return updated;
  }

  async getSahibindenExportForUser(user: AuthUser, id: string) {
    const listing = await this.prisma.listing.findUnique({
      where: { id },
      include: {
        categoryLeaf: { select: { name: true, pathKey: true } },
        listingAttributes: true,
      },
    });
    if (!listing) throw new NotFoundException('Listing not found');
    this.assertCanMutate(user, listing);

    const guideSteps = [
      'Sahibinden hesabına giriş yap ve "İlan Ver" adımını aç.',
      'Kategori olarak export edilen kategori yolunu seç.',
      'Başlık, açıklama, fiyat ve konum alanlarını kopyala-yapıştır ile doldur.',
      'Özellik alanlarını export listesindeki karşılıklarıyla gir.',
      'Önizleme sonrası ilanı yayınla ve oluşan URL’yi SatDedi ekranına geri kaydet.',
    ];

    await this.writeAudit(user.sub, 'LISTING_EXPORT_REQUESTED', id);

    return {
      listingId: listing.id,
      categoryPath: listing.categoryPathKey || listing.categoryLeaf?.pathKey || null,
      title: listing.title,
      description: listing.description,
      priceAmount: listing.priceAmount ?? listing.price,
      currency: listing.currency,
      location: {
        city: listing.city,
        district: listing.district,
        neighborhood: listing.neighborhood,
        lat: listing.lat,
        lng: listing.lng,
      },
      attributes: listing.listingAttributes.map((x) => ({ key: x.key, value: x.valueJson })),
      guideSteps,
    };
  }

  async patchSahibindenForUser(user: AuthUser, id: string, dto: UpdateSahibindenDto) {
    const current = await this.prisma.listing.findUnique({ where: { id } });
    if (!current) throw new NotFoundException('Listing not found');
    this.assertCanMutate(user, current);

    const updated = await this.prisma.listing.update({
      where: { id },
      data: {
        sahibindenUrl: dto.sahibindenUrl !== undefined ? dto.sahibindenUrl || null : undefined,
        exportedAt: dto.markExported ? new Date() : undefined,
        exportedById: dto.markExported ? user.sub : undefined,
      },
    });
    await this.writeAudit(user.sub, 'LISTING_SAHIBINDEN_UPDATED', id, {
      markExported: Boolean(dto.markExported),
    });
    return updated;
  }

  // Backward compatibility for existing consultant inbox integration
  async upsertFromDealMeta(dealId: string): Promise<{ listing: any; created: boolean }> {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');
    const consultantId = (deal as any).consultantId as string | null | undefined;
    if (!consultantId) throw new BadRequestException('Deal consultant ataması yok');

    const listingId = (deal as any).listingId as string | null | undefined;
    const title = [deal.city, deal.district, deal.type, deal.rooms].filter(Boolean).join(' - ') || 'Yeni İlan Taslağı';
    const baseData: Prisma.ListingUncheckedCreateInput = {
      consultantId,
      createdById: consultantId,
      title,
      city: deal.city || null,
      district: deal.district || null,
      type: deal.type || null,
      rooms: deal.rooms || null,
      status: 'DRAFT',
      currency: TRY_CURRENCY,
    };

    if (listingId) {
      const updated = await this.prisma.listing.update({
        where: { id: listingId },
        data: {
          title,
          city: deal.city || null,
          district: deal.district || null,
          type: deal.type || null,
          rooms: deal.rooms || null,
        },
      });
      return { listing: updated, created: false };
    }

    const created = await this.prisma.listing.create({ data: baseData });
    await this.prisma.deal.update({ where: { id: dealId }, data: { listingId: created.id } });
    return { listing: created, created: true };
  }
}
