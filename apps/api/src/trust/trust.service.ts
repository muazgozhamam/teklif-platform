import { Injectable } from '@nestjs/common';
import { AuditAction, AuditEntityType, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type TrustQuery = {
  userId?: string;
  role?: Role;
  take?: number;
  skip?: number;
};

@Injectable()
export class TrustService {
  constructor(private readonly prisma: PrismaService) {}

  private clamp(v: number, min = 0, max = 100) {
    return Math.max(min, Math.min(max, v));
  }

  async getUserTrust(userId: string) {
    const uid = String(userId ?? '').trim();
    if (!uid) throw new Error('userId is required');

    const user = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { id: true, email: true, role: true, isActive: true, createdAt: true },
    });
    if (!user) throw new Error('User not found');

    const [auditEvents, loginDeniedInactiveCount, ownsLeads, consultantWonDeals] = await Promise.all([
      this.prisma.auditLog.count({ where: { actorUserId: uid } }),
      this.prisma.auditLog.count({ where: { actorUserId: uid, action: 'LOGIN_DENIED_INACTIVE' as AuditAction } }),
      this.prisma.lead.count({ where: { sourceUserId: uid } }),
      this.prisma.deal.count({ where: { consultantId: uid, status: 'WON' } }),
    ]);

    let score = 50;
    if (user.isActive) score += 10;
    score += Math.min(15, auditEvents * 0.2);
    score += Math.min(10, ownsLeads * 0.5);
    score += Math.min(20, consultantWonDeals * 2);
    score -= Math.min(25, loginDeniedInactiveCount * 5);

    const trustScore = this.clamp(Number(score.toFixed(2)));
    const riskLevel = trustScore >= 75 ? 'LOW' : trustScore >= 45 ? 'MEDIUM' : 'HIGH';

    return {
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        isActive: user.isActive,
        createdAt: user.createdAt,
      },
      trustScore,
      riskLevel,
      signals: {
        auditEvents,
        loginDeniedInactiveCount,
        ownsLeads,
        consultantWonDeals,
      },
    };
  }

  async listTrust(query: TrustQuery) {
    const take = Math.min(Math.max(Number(query.take ?? 20) || 20, 1), 100);
    const skip = Math.max(Number(query.skip ?? 0) || 0, 0);
    const role = query.role;
    const userId = String(query.userId ?? '').trim();

    const where: any = {};
    if (role) where.role = role;
    if (userId) where.id = userId;

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

    const items = await Promise.all(users.map((u) => this.getUserTrust(u.id)));
    return { items, total, take, skip };
  }

  async markReviewedByAdmin(userId: string, actorUserId: string | null) {
    const uid = String(userId ?? '').trim();
    if (!uid) throw new Error('userId is required');

    const user = await this.prisma.user.findUnique({ where: { id: uid }, select: { id: true } });
    if (!user) throw new Error('User not found');

    await this.prisma.auditLog.create({
      data: {
        actorUserId: actorUserId || null,
        actorRole: Role.ADMIN,
        action: 'USER_PATCHED',
        entityType: AuditEntityType.USER,
        entityId: uid,
        metaJson: {
          trustReview: true,
          reviewedAt: new Date().toISOString(),
        },
      },
    });

    return { ok: true, userId: uid, reviewed: true };
  }
}
