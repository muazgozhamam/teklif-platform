import { Injectable } from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminOnboardingService {
  constructor(private readonly prisma: PrismaService) {}

  private buildChecklist(role: string, isActive: boolean) {
    const base = [
      { key: 'role-assigned', label: 'Rol atandı', required: true, done: role !== 'USER' },
      { key: 'account-active', label: 'Hesap aktif', required: true, done: Boolean(isActive) },
    ];
    if (role === 'CONSULTANT') {
      base.push({ key: 'consultant-profile', label: 'Danışman profili', required: false, done: true });
    }
    if (role === 'HUNTER') {
      base.push({ key: 'hunter-profile', label: 'İş ortağı profili', required: false, done: true });
    }
    return base;
  }

  async listUsers(params: { role?: string; take?: string; skip?: string }) {
    const take = Math.min(Math.max(Number(params.take || 20), 1), 100);
    const skip = Math.max(Number(params.skip || 0), 0);
    const role = String(params.role || '').trim().toUpperCase();
    const allowedRoles = new Set(['HUNTER', 'BROKER', 'CONSULTANT', 'ADMIN', 'USER']);
    const where: Prisma.UserWhereInput =
      role && role !== 'ALL' && allowedRoles.has(role) ? { role: role as Role } : {};

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        select: {
          id: true,
          email: true,
          role: true,
          isActive: true,
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    const items = users.map((u) => {
      const checklist = this.buildChecklist(String(u.role), Boolean(u.isActive));
      const done = checklist.filter((c) => c.done).length;
      const completionPct = checklist.length > 0 ? Math.round((done / checklist.length) * 100) : 0;
      const supported = ['HUNTER', 'BROKER', 'CONSULTANT'].includes(String(u.role));
      return {
        user: {
          id: u.id,
          email: u.email,
          role: u.role,
          isActive: u.isActive,
          officeId: null,
        },
        supported,
        completionPct,
        checklist,
      };
    });

    return {
      items,
      total,
      take,
      skip,
      role: role || null,
    };
  }
}
