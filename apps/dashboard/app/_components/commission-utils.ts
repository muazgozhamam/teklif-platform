export function minorToNumber(value: unknown): number {
  if (value === null || value === undefined) return 0;
  const raw = String(value);
  const n = Number(raw);
  if (Number.isNaN(n)) return 0;
  return n;
}

export function formatMinorTry(value: unknown): string {
  const minor = minorToNumber(value);
  const amount = minor / 100;
  return new Intl.NumberFormat('tr-TR', {
    style: 'currency',
    currency: 'TRY',
    maximumFractionDigits: 2,
  }).format(amount);
}
