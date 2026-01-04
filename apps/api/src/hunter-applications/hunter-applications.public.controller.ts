import { Body, Controller, Post } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type CreateHunterApplicationDto = {
  fullName: string;
  phone: string;
  email?: string;
  city?: string;
  district?: string;
  note?: string;
};

@Controller('public/hunter-applications')
export class HunterApplicationsPublicController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Body() dto: CreateHunterApplicationDto) {
    const fullName = String(dto.fullName ?? '').trim();
    const phone = String(dto.phone ?? '').trim();

    if (!fullName || !phone) {
      return { ok: false, message: 'fullName and phone are required' };
    }

    const row = await this.prisma.hunterApplication.create({
      data: {
        fullName,
        phone,
        email: dto.email?.trim() || null,
        city: dto.city?.trim() || null,
        district: dto.district?.trim() || null,
        note: dto.note?.trim() || null,
      },
      select: { id: true, status: true, createdAt: true },
    });

    return { ok: true, id: row.id, status: row.status, createdAt: row.createdAt };
  }
}
