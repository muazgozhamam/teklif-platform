export function isCommissionAllocationEnabled(): boolean {
  const raw = String(process.env.COMMISSION_ALLOCATION_ENABLED ?? '').trim().toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

