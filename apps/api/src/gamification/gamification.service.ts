import { Injectable, UnauthorizedException } from '@nestjs/common';
import { DealStatus, LeadStatus, ListingStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type LeaderboardQuery = {
  role: Role;
  take?: number;
  skip?: number;
};

type ScoreProfile = {
  points: number;
  tier: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM';
  badges: string[];
  stats: Record<string, number>;
};

@Injectable()
export class GamificationService {
  constructor(private readonly prisma: PrismaService) {}

  private tier(points: number): ScoreProfile['tier'] {
    if (points >= 600) return 'PLATINUM';
    if (points >= 300) return 'GOLD';
    if (points >= 100) return 'SILVER';
    return 'BRONZE';
  }

  private scoreHunter(stats: { leadsTotal: number; leadsApproved: number }): ScoreProfile {
    const points = stats.leadsTotal * 10 + stats.leadsApproved * 25;
    const badges: string[] = [];
    if (stats.leadsTotal >= 1) badges.push('LEAD_STARTER');
    if (stats.leadsTotal >= 20) badges.push('LEAD_HUNTER_PRO');
    if (stats.leadsApproved >= 5) badges.push('APPROVAL_MACHINE');
    return { points, tier: this.tier(points), badges, stats };
  }

  private scoreConsultant(stats: { listingsPublished: number; listingsSold: number; dealsWon: number }): ScoreProfile {
    const points = stats.listingsPublished * 10 + stats.listingsSold * 40 + stats.dealsWon * 20;
    const badges: string[] = [];
    if (stats.listingsPublished >= 1) badges.push('PUBLISHER');
    if (stats.listingsSold >= 3) badges.push('CLOSER');
    if (stats.dealsWon >= 5) badges.push('DEAL_WINNER');
    return { points, tier: this.tier(points), badges, stats };
  }

  private scoreBroker(stats: { officesManaged: number; huntersManaged: number }): ScoreProfile {
    const points = stats.officesManaged * 100 + stats.huntersManaged * 20;
    const badges: string[] = [];
    if (stats.officesManaged >= 1) badges.push('OFFICE_CAPTAIN');
    if (stats.huntersManaged >= 5) badges.push('NETWORK_BUILDER');
    return { points, tier: this.tier(points), badges, stats };
  }

  async getMyProfile(userId: string, roleRaw: string) {
    const role = String(roleRaw ?? '').trim().toUpperCase() as Role | '';
    if (!userId) throw new UnauthorizedException('Unauthorized');

    if (role === Role.HUNTER) {
      const [leadsTotal, leadsApproved] = await Promise.all([
        this.prisma.lead.count({ where: { sourceUserId: userId } }),
        this.prisma.lead.count({ where: { sourceUserId: userId, status: LeadStatus.APPROVED } }),
      ]);
      const profile = this.scoreHunter({ leadsTotal, leadsApproved });
      return { role: Role.HUNTER, ...profile };
    }

    if (role === Role.CONSULTANT) {
      const [listingsPublished, listingsSold, dealsWon] = await Promise.all([
        this.prisma.listing.count({ where: { consultantId: userId, status: ListingStatus.PUBLISHED } }),
        this.prisma.listing.count({ where: { consultantId: userId, status: ListingStatus.SOLD } }),
        this.prisma.deal.count({ where: { consultantId: userId, status: DealStatus.WON } }),
      ]);
      const profile = this.scoreConsultant({ listingsPublished, listingsSold, dealsWon });
      return { role: Role.CONSULTANT, ...profile };
    }

    if (role === Role.BROKER) {
      const [officesManaged, huntersManaged] = await Promise.all([
        this.prisma.office.count({ where: { brokerId: userId } }),
        this.prisma.user.count({ where: { parentId: userId, role: Role.HUNTER } }),
      ]);
      const profile = this.scoreBroker({ officesManaged, huntersManaged });
      return { role: Role.BROKER, ...profile };
    }

    if (role === Role.ADMIN) {
      return {
        role: Role.ADMIN,
        points: 0,
        tier: this.tier(0),
        badges: ['SYSTEM_ADMIN'],
        stats: { managedSystem: 1 },
      };
    }

    return {
      role: Role.USER,
      points: 0,
      tier: this.tier(0),
      badges: [],
      stats: {},
    };
  }

  async getLeaderboard(query: LeaderboardQuery) {
    const take = Math.min(Math.max(Number(query.take ?? 20) || 20, 1), 100);
    const skip = Math.max(Number(query.skip ?? 0) || 0, 0);
    const role = query.role;

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where: { role },
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        select: { id: true, email: true, name: true, role: true },
      }),
      this.prisma.user.count({ where: { role } }),
    ]);

    const items = await Promise.all(
      users.map(async (u) => {
        const profile = await this.getMyProfile(u.id, u.role);
        return {
          user: { id: u.id, email: u.email, name: u.name, role: u.role },
          points: profile.points,
          tier: profile.tier,
          badges: profile.badges,
          stats: profile.stats,
        };
      }),
    );

    items.sort((a, b) => b.points - a.points);
    return { items, total, take, skip, role };
  }
}
