import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

type ReviewDto = { reviewNote?: string };

@Controller('broker/hunter-applications')
export class HunterApplicationsBrokerController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@Query('status') status?: string) {
    const st = (status ?? 'PENDING').toUpperCase();
    const where = st ? { status: st as any } : undefined;

    const items = await this.prisma.hunterApplication.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    return { items };
  }

@Post(':id/approve')
  async approve(@Param('id') id: string, @Body() dto: ReviewDto) {
    const app = await this.prisma.hunterApplication.findUnique({ where: { id } });
    if (!app) return { ok: false, message: 'Application not found' };

    // Email is required for User. If not provided, generate from phone.
    const phoneDigits = String(app.phone ?? '').replace(/\D+/g, '');
    const baseLocal = phoneDigits ? `hunter+${phoneDigits}` : `hunter+${app.id}`;
    const baseDomain = 'pending.local';

    const providedEmail = (app.email ? String(app.email).trim() : '') || '';
    const baseEmail = (providedEmail || `${baseLocal}@${baseDomain}`).toLowerCase();

    // Ensure uniqueness if already exists
    let email = baseEmail;
    const exists0 = await this.prisma.user.findUnique({ where: { email } });
    if (exists0) {
      const local = baseEmail.split('@')[0] || baseLocal;
      const domain = baseEmail.split('@')[1] || baseDomain;
      email = `${local}+${app.id}@${domain}`.toLowerCase();
    }

    // Temporary password for first login (project currently stores password as String).
    const tempPassword = randomBytes(9).toString('base64url'); // ~12 chars
    const now = new Date();

    const result = await this.prisma.$transaction(async (tx) => {
      // 1) Approve application
      const updatedApp = await tx.hunterApplication.update({
        where: { id },
        data: {
          status: 'APPROVED' as any,
          reviewNote: dto.reviewNote ?? null,
          reviewedAt: now,
        },
        select: { id: true, status: true },
      });

      // 2) Create or activate user
      const existing = await tx.user.findUnique({ where: { email } });
      let created = false;

      if (!existing) {
        await tx.user.create({
          data: {
            email,
            password: tempPassword,
            name: app.fullName,
            role: 'HUNTER' as any,
            isActive: true,
            approvedAt: now,
            approvedByUserId: null,
          },
          select: { id: true },
        });
        created = true;
      } else {
        await tx.user.update({
          where: { email },
          data: {
            role: 'HUNTER' as any,
            isActive: true,
            approvedAt: now,
            approvedByUserId: null,
          },
          select: { id: true },
        });
      }

      return { updatedApp, created };
    });

    return {
      ok: true,
      id: result.updatedApp.id,
      status: result.updatedApp.status,
      user: {
        email,
        created: result.created,
        tempPassword: result.created ? tempPassword : undefined,
      },
    };
  }

  @Post(':id/reject')
  async reject(@Param('id') id: string, @Body() dto: ReviewDto) {
    const row = await this.prisma.hunterApplication.update({
      where: { id },
      data: {
        status: 'REJECTED' as any,
        reviewNote: dto.reviewNote ?? null,
        reviewedAt: new Date(),
      },
      select: { id: true, status: true },
    });
    return { ok: true, ...row };
  }
}
