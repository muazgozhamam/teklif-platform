import { Role } from '@prisma/client';
import { OnboardingService } from './onboarding.service';

describe('OnboardingService', () => {
  it('returns consultant onboarding with completion', async () => {
    const prisma: any = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'u1',
          email: 'consultant@test.com',
          role: Role.CONSULTANT,
          isActive: true,
          officeId: 'office-1',
        }),
        findMany: jest.fn(),
        count: jest.fn(),
      },
      lead: { count: jest.fn().mockResolvedValue(0) },
      listing: { count: jest.fn().mockResolvedValue(1) },
    };
    const svc = new OnboardingService(prisma);
    const out = await svc.getUserOnboarding('u1');

    expect(out.supported).toBe(true);
    expect(out.user.id).toBe('u1');
    expect(out.completionPct).toBe(100);
    expect(out.checklist.find((x) => x.key === 'office_assigned')?.done).toBe(true);
    expect(out.checklist.find((x) => x.key === 'first_listing_created')?.done).toBe(true);
  });

  it('returns paged onboarding list with role filter', async () => {
    const prisma: any = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'u2',
          email: 'hunter@test.com',
          role: Role.HUNTER,
          isActive: true,
          officeId: null,
        }),
        findMany: jest.fn().mockResolvedValue([{ id: 'u2' }]),
        count: jest.fn().mockResolvedValue(1),
      },
      lead: { count: jest.fn().mockResolvedValue(1) },
      listing: { count: jest.fn().mockResolvedValue(0) },
    };
    const svc = new OnboardingService(prisma);
    const out = await svc.listOnboarding('hunter', 10, 0);

    expect(out.role).toBe(Role.HUNTER);
    expect(out.total).toBe(1);
    expect(out.items).toHaveLength(1);
    expect(out.items[0].user.id).toBe('u2');
  });
});
