import { Injectable } from '@nestjs/common';
import { Prisma, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type OnboardingRole = 'HUNTER' | 'BROKER' | 'CONSULTANT';

@Injectable()
export class OnboardingService {
  constructor(private readonly prisma: PrismaService) {}

  private roleChecklist(role: OnboardingRole) {
    if (role === Role.HUNTER) {
      return [
        { key: 'account_active', label: 'Account active', required: true },
        { key: 'profile_basics', label: 'Basic profile completed', required: true },
        { key: 'first_lead_created', label: 'First lead created', required: true },
      ];
    }
    if (role === Role.BROKER) {
      return [
        { key: 'account_active', label: 'Account active', required: true },
        { key: 'office_assigned', label: 'Office assigned', required: true },
        { key: 'first_lead_approved', label: 'First lead approved', required: true },
      ];
    }
    return [
      { key: 'account_active', label: 'Account active', required: true },
      { key: 'office_assigned', label: 'Office assigned', required: true },
      { key: 'first_listing_created', label: 'First listing created', required: true },
    ];
  }

  async getUserOnboarding(userId: string) {
    const uid = String(userId ?? '').trim();
    if (!uid) throw new Error('userId is required');

    const user = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { id: true, email: true, role: true, isActive: true, officeId: true },
    });
    if (!user) throw new Error('User not found');

    const role = user.role as OnboardingRole;
    const supported = new Set<Role>([Role.HUNTER, Role.BROKER, Role.CONSULTANT]);
    if (!supported.has(role)) {
      return {
        user,
        supported: false,
        completionPct: 100,
        checklist: [],
      };
    }

    const [leadCount, leadApprovedCount, listingCount] = await Promise.all([
      this.prisma.lead.count({ where: { sourceUserId: uid } }),
      this.prisma.lead.count({ where: { sourceUserId: uid, status: 'APPROVED' } }),
      this.prisma.listing.count({ where: { consultantId: uid } }),
    ]);

    const base = this.roleChecklist(role).map((step) => ({ ...step, done: false }));

    for (const s of base) {
      if (s.key === 'account_active') s.done = !!user.isActive;
      if (s.key === 'profile_basics') s.done = true;
      if (s.key === 'office_assigned') s.done = !!user.officeId;
      if (s.key === 'first_lead_created') s.done = leadCount > 0;
      if (s.key === 'first_lead_approved') s.done = leadApprovedCount > 0;
      if (s.key === 'first_listing_created') s.done = listingCount > 0;
    }

    const doneCount = base.filter((s) => s.done).length;
    const completionPct = base.length ? Number(((doneCount / base.length) * 100).toFixed(2)) : 100;

    return {
      user,
      supported: true,
      completionPct,
      checklist: base,
      signals: {
        leadCount,
        leadApprovedCount,
        listingCount,
      },
    };
  }

  async listOnboarding(roleRaw?: string, takeRaw?: number, skipRaw?: number) {
    const role = String(roleRaw ?? '').trim().toUpperCase() as Role;
    const allowed = new Set<Role>([Role.HUNTER, Role.BROKER, Role.CONSULTANT]);
    const take = Math.min(Math.max(Number(takeRaw ?? 20) || 20, 1), 100);
    const skip = Math.max(Number(skipRaw ?? 0) || 0, 0);

    const where: Prisma.UserWhereInput = {};
    if (allowed.has(role)) where.role = role;

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        take,
        skip,
        orderBy: { createdAt: 'desc' },
        select: { id: true },
      }),
      this.prisma.user.count({ where }),
    ]);

    const items = await Promise.all(users.map((u) => this.getUserOnboarding(u.id)));
    return { items, total, take, skip, role: allowed.has(role) ? role : null };
  }
}
