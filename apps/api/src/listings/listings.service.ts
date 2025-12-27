import { BadRequestException, Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ListingStatus } from '@prisma/client';
import { CreateListingDto, UpdateListingDto } from './listings.dto';

@Injectable()
export class ListingsService {
  constructor(private prisma: PrismaService) {}

  async getById(id: string) {
    const listing = await this.prisma.listing.findUnique({
      where: { id },
      include: { consultant: true },
    });
    if (!listing) throw new NotFoundException('Listing not found');
    return listing;
  }

  async list(params: { consultantId?: string; status?: ListingStatus }) {
    const { consultantId, status } = params;
    return this.prisma.listing.findMany({
      where: {
        ...(consultantId ? { consultantId } : {}),
        ...(status ? { status } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(consultantId: string, dto: CreateListingDto) {
    const title = String(dto.title ?? '').trim();
    if (!title) throw new BadRequestException('title is required');

    return this.prisma.listing.create({
      data: {
        consultantId,
        title,
        description: dto.description?.trim() || null,
        price: dto.price ?? null,
        currency: (dto.currency ?? 'TRY').trim() || 'TRY',

        city: dto.city?.trim() || null,
        district: dto.district?.trim() || null,
        type: dto.type?.trim() || null,
        rooms: dto.rooms?.trim() || null,
      },
    });
  }

  async update(id: string, consultantId: string, dto: UpdateListingDto) {
    const data: any = {};

    const listing = await this.prisma.listing.findUnique({ where: { id } });
    if (!listing) throw new NotFoundException('Listing not found');
    if (listing.consultantId !== consultantId) {
      throw new BadRequestException('Listing does not belong to this consultant');
    }

    const updateData: any = {
};
    if (dto.title !== undefined) data.title = String(dto.title).trim();
    if (dto.description !== undefined) data.description = (dto.description ?? '').trim() || null;
    if (dto.price !== undefined) data.price = dto.price ?? null;
    if (dto.currency !== undefined) data.currency = String(dto.currency ?? 'TRY').trim() || 'TRY';

    if (dto.city !== undefined) data.city = (dto.city ?? '').trim() || null;
    if (dto.district !== undefined) data.district = (dto.district ?? '').trim() || null;
    if (dto.type !== undefined) data.type = (dto.type ?? '').trim() || null;
    if (dto.rooms !== undefined) data.rooms = (dto.rooms ?? '').trim() || null;

    if (dto.status !== undefined) data.status = dto.status as any;

    return this.prisma.listing.update({where: { id }, data });
  }

  async getByDealId(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const listingId = (deal as any).listingId as string | null | undefined;
    if (!listingId) return null;

    return this.prisma.listing.findUnique({ where: { id: listingId } });
  }



  // Idempotent: Deal üzerinde listingId varsa update eder, yoksa create+link yapar

  async upsertFromDeal(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    if (!(deal as any).consultantId) {
      throw new ConflictException('Deal is not assigned to a consultant yet');
    }

    const _city = (deal as any).city ?? null;
    const _district = (deal as any).district ?? null;
    const _type = (deal as any).type ?? null;
    const _rooms = (deal as any).rooms ?? null;

    const _title =
      [_city, _district, _type, _rooms].filter(Boolean).join(' - ') || 'İlan Taslağı';

    const updateData: any = {
      city: _city,
      district: _district,
      type: _type,
      rooms: _rooms,
      title: _title,
    };

    const createData: any = {
      ...updateData,
      consultant: { connect: { id: (deal as any).consultantId } },
    };

    const listingId = (deal as any).listingId as string | null | undefined;

    if (listingId) {
      return this.prisma.listing.update({
        where: { id: listingId },
        data: updateData,
      });
    }

    const listing = await this.prisma.listing.create({ data: createData });

    await this.prisma.deal.update({
      where: { id: dealId },
      data: { listingId: listing.id },
    });

    return listing;
  }





  // Idempotent: Deal üzerinde listingId varsa update eder, yoksa create+link yapar



}
