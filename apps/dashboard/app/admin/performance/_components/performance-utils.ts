export type DatePreset = '7d' | '30d' | 'month' | 'custom';

export function isoDate(d: Date) {
  return d.toISOString().slice(0, 10);
}

export function getDefaultRange() {
  const to = new Date();
  const from = new Date(to.getTime() - 30 * 24 * 60 * 60 * 1000);
  return { from: isoDate(from), to: isoDate(to) };
}

export function getRangeFromSearch(search: URLSearchParams | ReadonlyURLSearchParams) {
  const defaults = getDefaultRange();
  const from = search.get('from') || defaults.from;
  const to = search.get('to') || defaults.to;
  const city = search.get('city') || '';
  return { from, to, city };
}

export function formatMoney(value: number) {
  return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: 'TRY', maximumFractionDigits: 0 }).format(value || 0);
}

export function formatNumber(value: number) {
  return new Intl.NumberFormat('tr-TR').format(value || 0);
}

export function toRate(value: number) {
  return `${Number(value || 0).toFixed(2)}%`;
}
