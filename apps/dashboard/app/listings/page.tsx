/* eslint-disable @typescript-eslint/no-explicit-any */

type Listing = {
  id: string;
  title?: string | null;
  price?: number | null;
  currency?: string | null;
  city?: string | null;
  district?: string | null;
  status?: string | null;
  createdAt?: string | null;
};

type ListingsSearchParams = {
  status?: string;
  q?: string;
  page?: string;
  pageSize?: string;
};

type ListingsResult = {
  items: Listing[];
  total: number;
  page: number;
  pageSize: number;
  error: string | null;
};

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.API_BASE_URL ||
  'http://localhost:3001';

const DEFAULT_PAGE_SIZE = 12;

function parseArray(payload: any): Listing[] {
  if (Array.isArray(payload)) return payload as Listing[];
  if (payload && Array.isArray(payload.items)) return payload.items as Listing[];
  if (payload && Array.isArray(payload.data)) return payload.data as Listing[];
  if (payload && payload.result && Array.isArray(payload.result.items)) return payload.result.items as Listing[];
  return [];
}

function parseTotal(payload: any, fallback: number): number {
  const candidates = [payload?.total, payload?.count, payload?.result?.total];
  for (const c of candidates) {
    if (typeof c === 'number' && Number.isFinite(c)) return c;
    const n = Number(c);
    if (Number.isFinite(n)) return n;
  }
  return fallback;
}

function toInt(value: string | undefined, fallback: number, min: number, max: number) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(n)));
}

function fmtPrice(price?: number | null, currency?: string | null) {
  if (price === null || price === undefined) return 'Fiyat girilmemis';
  try {
    const txt = new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 0 }).format(price);
    return `${txt} ${(currency || 'TRY').toUpperCase()}`;
  } catch {
    return `${price} ${(currency || 'TRY').toUpperCase()}`;
  }
}

function buildUrl(page: number, pageSize: number, status: string, q: string) {
  const p = new URLSearchParams();
  p.set('status', status);
  p.set('page', String(page));
  p.set('pageSize', String(pageSize));
  if (q.trim()) p.set('q', q.trim());
  return `/listings?${p.toString()}`;
}

async function getListings(searchParams: ListingsSearchParams): Promise<ListingsResult> {
  const status = (searchParams.status || 'PUBLISHED').toUpperCase();
  const q = String(searchParams.q || '').trim();
  const page = toInt(searchParams.page, 1, 1, 9999);
  const pageSize = toInt(searchParams.pageSize, DEFAULT_PAGE_SIZE, 1, 50);

  const params = new URLSearchParams();
  params.set('status', status);
  params.set('page', String(page));
  params.set('pageSize', String(pageSize));
  if (q) params.set('q', q);

  const url = `${API_BASE.replace(/\/+$/, '')}/listings?${params.toString()}`;

  try {
    const res = await fetch(url, { cache: 'no-store' });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      return {
        items: [],
        total: 0,
        page,
        pageSize,
        error: `Ilanlar alinamadi (${res.status}) ${text}`.trim(),
      };
    }

    const payload = await res.json();
    const items = parseArray(payload);
    const total = parseTotal(payload, items.length);

    return { items, total, page, pageSize, error: null };
  } catch (e: any) {
    return {
      items: [],
      total: 0,
      page,
      pageSize,
      error: e?.message ? String(e.message) : 'Ilanlar alinamadi',
    };
  }
}

export default async function ListingsPage({
  searchParams,
}: {
  searchParams: Promise<ListingsSearchParams>;
}) {
  const sp = await searchParams;
  const status = (sp.status || 'PUBLISHED').toUpperCase();
  const q = String(sp.q || '').trim();
  const result = await getListings(sp);

  const totalPages = Math.max(1, Math.ceil((result.total || 0) / result.pageSize));
  const canPrev = result.page > 1;
  const canNext = result.page < totalPages;

  return (
    <main style={{ padding: 24, maxWidth: 1100, margin: '0 auto' }}>
      <div style={{ marginBottom: 12 }}>
        <h1 style={{ margin: 0 }}>Ilanlar</h1>
        <p style={{ marginTop: 8, color: '#6b7280', fontSize: 13 }}>
          Durum ve arama filtreleriyle yayindaki ilanlari takip et.
        </p>
      </div>

      <form method="GET" style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center', marginBottom: 12 }}>
        <select name="status" defaultValue={status} style={{ padding: '9px 10px', border: '1px solid #ddd', borderRadius: 10 }}>
          <option value="PUBLISHED">PUBLISHED</option>
          <option value="DRAFT">DRAFT</option>
        </select>
        <input
          name="q"
          defaultValue={q}
          placeholder="Baslik / sehir / ilce ara..."
          style={{ minWidth: 280, flex: '1 1 280px', padding: '9px 10px', border: '1px solid #ddd', borderRadius: 10 }}
        />
        <input type="hidden" name="page" value="1" />
        <input type="hidden" name="pageSize" value={String(result.pageSize)} />
        <button type="submit" style={{ padding: '9px 14px', border: '1px solid #111', background: '#111', color: '#fff', borderRadius: 10 }}>
          Filtrele
        </button>
      </form>

      <div style={{ marginBottom: 10, color: '#6b7280', fontSize: 13 }}>
        Toplam <b>{result.total}</b> ilan • Sayfa <b>{result.page}</b>/<b>{totalPages}</b>
      </div>

      {result.error ? (
        <div style={{ marginBottom: 12, border: '1px solid #fecaca', background: '#fef2f2', color: '#991b1b', padding: 12, borderRadius: 12 }}>
          {result.error}
        </div>
      ) : null}

      {result.items.length === 0 && !result.error ? (
        <div style={{ border: '1px dashed #d1d5db', borderRadius: 12, padding: 18, color: '#6b7280' }}>
          Bu filtrede ilan bulunamadi.
        </div>
      ) : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(240px,1fr))', gap: 12 }}>
        {result.items.map((l) => (
          <article key={l.id} style={{ border: '1px solid #e5e7eb', background: '#fff', borderRadius: 14, padding: 12 }}>
            <div style={{ fontWeight: 700, marginBottom: 8 }}>{l.title || `${l.city || '-'} / ${l.district || '-'}`}</div>
            <div style={{ fontSize: 13, color: '#6b7280', marginBottom: 4 }}>ID: <code data-listing-id={l.id}>{l.id}</code></div>
            <div style={{ fontSize: 13, color: '#6b7280', marginBottom: 4 }}>Konum: {l.city || '-'} / {l.district || '-'}</div>
            <div style={{ fontSize: 13, color: '#6b7280', marginBottom: 8 }}>Fiyat: {fmtPrice(l.price, l.currency)}</div>
            <span style={{ fontSize: 11, fontWeight: 700, border: '1px solid #e5e7eb', borderRadius: 999, padding: '4px 8px' }}>
              {String(l.status || status)}
            </span>
            <span style={{ display: 'none' }}>{`LISTING_ID:${l.id}`}</span>
            <span style={{ display: 'none' }}>{`ID=${l.id}`}</span>
          </article>
        ))}
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 14 }}>
        <a
          href={canPrev ? buildUrl(result.page - 1, result.pageSize, status, q) : '#'}
          aria-disabled={!canPrev}
          style={{
            pointerEvents: canPrev ? 'auto' : 'none',
            opacity: canPrev ? 1 : 0.5,
            padding: '8px 12px',
            border: '1px solid #ddd',
            borderRadius: 10,
            color: '#111',
            textDecoration: 'none',
            background: '#fff',
          }}
        >
          Onceki
        </a>
        <a
          href={canNext ? buildUrl(result.page + 1, result.pageSize, status, q) : '#'}
          aria-disabled={!canNext}
          style={{
            pointerEvents: canNext ? 'auto' : 'none',
            opacity: canNext ? 1 : 0.5,
            padding: '8px 12px',
            border: '1px solid #ddd',
            borderRadius: 10,
            color: '#111',
            textDecoration: 'none',
            background: '#fff',
          }}
        >
          Sonraki
        </a>
      </div>
    </main>
  );
}
