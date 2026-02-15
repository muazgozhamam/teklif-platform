import { Role } from '@prisma/client';
import { GamificationService } from './gamification.service';

describe('GamificationService', () => {
  it('returns hunter profile with points and badges', async () => {
    const prisma: any = {
      lead: { count: jest.fn().mockResolvedValueOnce(10).mockResolvedValueOnce(6) },
      listing: { count: jest.fn() },
      deal: { count: jest.fn() },
      office: { count: jest.fn() },
      user: { count: jest.fn(), findMany: jest.fn() },
    };
    const svc = new GamificationService(prisma);
    const out = await svc.getMyProfile('h1', Role.HUNTER);
    expect(out.points).toBe(10 * 10 + 6 * 25);
    expect(out.badges).toContain('LEAD_STARTER');
    expect(out.tier).toBeDefined();
  });

  it('returns admin leaderboard ordered by points', async () => {
    const prisma: any = {
      user: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'u1', email: 'u1@test.com', name: 'U1', role: Role.HUNTER },
          { id: 'u2', email: 'u2@test.com', name: 'U2', role: Role.HUNTER },
        ]),
        count: jest.fn().mockResolvedValue(2),
      },
      lead: {
        count: jest
          .fn()
          .mockResolvedValueOnce(2)
          .mockResolvedValueOnce(1)
          .mockResolvedValueOnce(20)
          .mockResolvedValueOnce(10),
      },
      listing: { count: jest.fn() },
      deal: { count: jest.fn() },
      office: { count: jest.fn() },
    };
    const svc = new GamificationService(prisma);
    const out = await svc.getLeaderboard({ role: Role.HUNTER, take: 20, skip: 0 });
    expect(out.items).toHaveLength(2);
    expect(out.items[0].points).toBeGreaterThanOrEqual(out.items[1].points);
  });
});
