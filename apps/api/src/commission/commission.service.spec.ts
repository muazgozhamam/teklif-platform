import { CommissionRoundingRule } from '@prisma/client';
import { CommissionService } from './commission.service';

describe('CommissionService core math', () => {
  const service = new CommissionService({} as any);

  it('applies ROUND_HALF_UP for tie values', () => {
    const value = (service as any).divideWithRounding(5n, 2n, CommissionRoundingRule.ROUND_HALF_UP);
    expect(value).toBe(3n);
  });

  it('applies BANKERS rounding for tie values', () => {
    const value = (service as any).divideWithRounding(5n, 2n, CommissionRoundingRule.BANKERS);
    expect(value).toBe(2n);
  });

  it('keeps allocation sum equal to pool', () => {
    const rows = (service as any).buildAllocationPlan({
      poolAmountMinor: 10_001n,
      roundingRule: CommissionRoundingRule.ROUND_HALF_UP,
      policy: {
        hunterPercentBasisPoints: 3000,
        consultantPercentBasisPoints: 5000,
        brokerPercentBasisPoints: 2000,
        systemPercentBasisPoints: 0,
      },
      participants: {
        hunterUserId: 'hunter-1',
        consultantUserId: 'consultant-1',
        brokerUserId: 'broker-1',
      },
    });

    const sum = rows.reduce((acc: bigint, row: { amountMinor: bigint }) => acc + row.amountMinor, 0n);
    expect(sum).toBe(10_001n);
  });
});
