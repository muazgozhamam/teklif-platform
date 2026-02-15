import { Role } from '@prisma/client';
import { TrustService } from './trust.service';

describe('TrustService', () => {
  it('computes trust profile with risk level', async () => {
    const prisma: any = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'u1', email: 'u1@test.com', role: Role.CONSULTANT, isActive: true, createdAt: new Date() }),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      auditLog: {
        count: jest.fn().mockResolvedValueOnce(10).mockResolvedValueOnce(0),
        create: jest.fn(),
      },
      lead: { count: jest.fn().mockResolvedValue(5) },
      deal: { count: jest.fn().mockResolvedValue(2) },
    };

    const svc = new TrustService(prisma);
    const out = await svc.getUserTrust('u1');

    expect(out.user.id).toBe('u1');
    expect(out.trustScore).toBeGreaterThan(0);
    expect(['LOW', 'MEDIUM', 'HIGH']).toContain(out.riskLevel);
  });

  it('lists trust profiles paginated', async () => {
    const prisma: any = {
      user: {
        findMany: jest.fn().mockResolvedValue([{ id: 'u1' }, { id: 'u2' }]),
        count: jest.fn().mockResolvedValue(2),
        findUnique: jest
          .fn()
          .mockResolvedValueOnce({ id: 'u1', email: 'u1@test.com', role: Role.HUNTER, isActive: true, createdAt: new Date() })
          .mockResolvedValueOnce({ id: 'u2', email: 'u2@test.com', role: Role.BROKER, isActive: false, createdAt: new Date() }),
      },
      auditLog: {
        count: jest
          .fn()
          .mockResolvedValueOnce(3)
          .mockResolvedValueOnce(1)
          .mockResolvedValueOnce(2)
          .mockResolvedValueOnce(0),
        create: jest.fn(),
      },
      lead: { count: jest.fn().mockResolvedValue(1) },
      deal: { count: jest.fn().mockResolvedValue(0) },
    };

    const svc = new TrustService(prisma);
    const out = await svc.listTrust({ take: 10, skip: 0 });

    expect(out.items).toHaveLength(2);
    expect(out.total).toBe(2);
  });
});
