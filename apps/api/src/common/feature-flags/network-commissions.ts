export function isNetworkCommissionsEnabled(): boolean {
  const raw = String(process.env.NETWORK_COMMISSIONS_ENABLED ?? '').trim().toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

