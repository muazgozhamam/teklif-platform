import { UnauthorizedException } from '@nestjs/common';
import { StatsCacheService } from './stats-cache.service';
import { StatsService } from './stats.service';

describe('StatsService cache', () => {
  const buildPrisma = () => ({
    user: { count: jest.fn().mockResolvedValue(10) },
    lead: { count: jest.fn().mockResolvedValue(20) },
    deal: { count: jest.fn().mockResolvedValue(30) },
    listing: { count: jest.fn().mockResolvedValue(40) },
  });

  it('caches per role+user and avoids duplicate DB calls within TTL', async () => {
    const prisma: any = buildPrisma();
    const service = new StatsService(prisma, new StatsCacheService());

    const first = await service.getMe('u1', 'ADMIN');
    const second = await service.getMe('u1', 'ADMIN');

    expect(first).toEqual(second);
    expect(prisma.user.count).toHaveBeenCalledTimes(1);
    expect(prisma.lead.count).toHaveBeenCalledTimes(1);
    expect(prisma.deal.count).toHaveBeenCalledTimes(1);
    expect(prisma.listing.count).toHaveBeenCalledTimes(1);
  });

  it('uses different cache buckets for different users', async () => {
    const prisma: any = buildPrisma();
    const service = new StatsService(prisma, new StatsCacheService());

    await service.getMe('u1', 'ADMIN');
    await service.getMe('u2', 'ADMIN');

    expect(prisma.user.count).toHaveBeenCalledTimes(2);
  });

  it('throws on missing user id', async () => {
    const prisma: any = buildPrisma();
    const service = new StatsService(prisma, new StatsCacheService());

    await expect(service.getMe('', 'ADMIN')).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
