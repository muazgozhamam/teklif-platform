'use client';

import React from 'react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { Input } from '@/src/ui/components/Input';
import { Button } from '@/src/ui/components/Button';
import { Card } from '@/src/ui/components/Card';

type Listing = {
  id: string;
  title: string;
  description?: string | null;
  priceAmount?: string | number | null;
  price?: number | null;
  currency?: string | null;
  city?: string | null;
  district?: string | null;
  neighborhood?: string | null;
  lat?: number | null;
  lng?: number | null;
  privacyMode?: 'EXACT' | 'APPROXIMATE' | 'HIDDEN';
  categoryPathKey?: string | null;
  status?: string;
};

type ListResponse = {
  items: Listing[];
  total: number;
  take: number;
  skip: number;
};

function formatPrice(row: Listing) {
  const amount = row.priceAmount ?? row.price;
  if (amount === null || amount === undefined || amount === '') return '—';
  const n = Number(amount);
  if (!Number.isFinite(n)) return String(amount);
  return `${new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 0 }).format(n)} ${row.currency || 'TRY'}`;
}

function buildBBoxFromItems(items: Listing[]) {
  const points = items.filter((x) => typeof x.lat === 'number' && typeof x.lng === 'number');
  if (!points.length) return null;
  const latValues = points.map((p) => p.lat as number);
  const lngValues = points.map((p) => p.lng as number);
  const latMin = Math.min(...latValues);
  const latMax = Math.max(...latValues);
  const lngMin = Math.min(...lngValues);
  const lngMax = Math.max(...lngValues);
  return { latMin, latMax, lngMin, lngMax };
}

function toMapPoint(row: Listing, bbox: { latMin: number; latMax: number; lngMin: number; lngMax: number }) {
  if (typeof row.lat !== 'number' || typeof row.lng !== 'number') return null;
  const latRange = Math.max(0.000001, bbox.latMax - bbox.latMin);
  const lngRange = Math.max(0.000001, bbox.lngMax - bbox.lngMin);
  const x = ((row.lng - bbox.lngMin) / lngRange) * 100;
  const y = (1 - (row.lat - bbox.latMin) / latRange) * 100;
  return {
    x: Math.max(2, Math.min(98, x)),
    y: Math.max(2, Math.min(98, y)),
  };
}

export default function PublicListingsPage() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const listRef = React.useRef<HTMLDivElement | null>(null);
  const scrollMemoryRef = React.useRef(0);

  const [items, setItems] = React.useState<Listing[]>([]);
  const [total, setTotal] = React.useState(0);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [detail, setDetail] = React.useState<Listing | null>(null);
  const [detailLoading, setDetailLoading] = React.useState(false);

  const view = searchParams.get('view') === 'map' ? 'map' : 'list';
  const listingId = searchParams.get('listingId') || '';
  const q = searchParams.get('q') || '';
  const categoryLeafPathKey = searchParams.get('categoryLeafPathKey') || '';
  const listingType = searchParams.get('listingType') || '';
  const city = searchParams.get('city') || '';
  const district = searchParams.get('district') || '';
  const priceMin = searchParams.get('priceMin') || '';
  const priceMax = searchParams.get('priceMax') || '';
  const bboxFromUrl = searchParams.get('bbox') || '';

  const [formQ, setFormQ] = React.useState(q);
  const [formCategoryLeafPathKey, setFormCategoryLeafPathKey] = React.useState(categoryLeafPathKey);
  const [formListingType, setFormListingType] = React.useState(listingType);
  const [formCity, setFormCity] = React.useState(city);
  const [formDistrict, setFormDistrict] = React.useState(district);
  const [formPriceMin, setFormPriceMin] = React.useState(priceMin);
  const [formPriceMax, setFormPriceMax] = React.useState(priceMax);

  const [categoryLeaves, setCategoryLeaves] = React.useState<Array<{ pathKey: string; name: string }>>([]);

  React.useEffect(() => {
    setFormQ(q);
    setFormCategoryLeafPathKey(categoryLeafPathKey);
    setFormListingType(listingType);
    setFormCity(city);
    setFormDistrict(district);
    setFormPriceMin(priceMin);
    setFormPriceMax(priceMax);
  }, [q, categoryLeafPathKey, listingType, city, district, priceMin, priceMax]);

  React.useEffect(() => {
    let alive = true;
    fetch('/api/public/listings/categories/leaves', { cache: 'no-store' })
      .then(async (res) => {
        if (!res.ok) throw new Error('Kategori listesi alınamadı');
        return res.json();
      })
      .then((rows: Array<{ pathKey: string; name: string }>) => {
        if (!alive) return;
        setCategoryLeaves(Array.isArray(rows) ? rows : []);
      })
      .catch(() => {
        if (!alive) return;
        setCategoryLeaves([]);
      });
    return () => {
      alive = false;
    };
  }, []);

  const setQuery = React.useCallback(
    (patch: Record<string, string | null>) => {
      const next = new URLSearchParams(searchParams.toString());
      Object.entries(patch).forEach(([key, value]) => {
        if (value === null || value === '') next.delete(key);
        else next.set(key, value);
      });
      router.replace(`${pathname}?${next.toString()}`, { scroll: false });
    },
    [router, pathname, searchParams],
  );

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      if (q) params.set('q', q);
      if (categoryLeafPathKey) params.set('categoryLeafPathKey', categoryLeafPathKey);
      if (listingType) params.set('listingType', listingType);
      if (city) params.set('city', city);
      if (district) params.set('district', district);
      if (priceMin) params.set('priceMin', priceMin);
      if (priceMax) params.set('priceMax', priceMax);
      if (bboxFromUrl) params.set('bbox', bboxFromUrl);
      params.set('take', '50');

      const res = await fetch(`/api/public/listings?${params.toString()}`, { cache: 'no-store' });
      const payload = (await res.json().catch(() => null)) as ListResponse | null;
      if (!res.ok || !payload) throw new Error('İlanlar yüklenemedi');
      setItems(Array.isArray(payload.items) ? payload.items : []);
      setTotal(Number(payload.total || 0));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'İlanlar yüklenemedi');
      setItems([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [q, categoryLeafPathKey, listingType, city, district, priceMin, priceMax, bboxFromUrl]);

  React.useEffect(() => {
    void load();
  }, [load]);

  React.useEffect(() => {
    if (!listingId) {
      setDetail(null);
      return;
    }
    let alive = true;
    setDetailLoading(true);
    fetch(`/api/public/listings/${listingId}`, { cache: 'no-store' })
      .then(async (r) => {
        if (!r.ok) throw new Error('İlan detayı bulunamadı');
        return r.json();
      })
      .then((data: Listing) => {
        if (!alive) return;
        setDetail(data);
      })
      .catch(() => {
        if (!alive) return;
        setDetail(null);
      })
      .finally(() => {
        if (alive) setDetailLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [listingId]);

  const bbox = React.useMemo(() => buildBBoxFromItems(items), [items]);

  function openDrawer(id: string) {
    if (listRef.current) scrollMemoryRef.current = listRef.current.scrollTop;
    setQuery({ listingId: id });
  }

  function closeDrawer() {
    setQuery({ listingId: null });
    requestAnimationFrame(() => {
      if (listRef.current) listRef.current.scrollTop = scrollMemoryRef.current;
    });
  }

  function applyFilters() {
    setQuery({
      q: formQ || null,
      categoryLeafPathKey: formCategoryLeafPathKey || null,
      listingType: formListingType || null,
      city: formCity || null,
      district: formDistrict || null,
      priceMin: formPriceMin || null,
      priceMax: formPriceMax || null,
      bbox: null,
    });
  }

  function clearFilters() {
    setFormQ('');
    setFormCategoryLeafPathKey('');
    setFormListingType('');
    setFormCity('');
    setFormDistrict('');
    setFormPriceMin('');
    setFormPriceMax('');
    setQuery({
      q: null,
      categoryLeafPathKey: null,
      listingType: null,
      city: null,
      district: null,
      priceMin: null,
      priceMax: null,
      bbox: null,
    });
  }

  function setMapView(nextView: 'list' | 'map') {
    if (nextView === 'map' && bbox) {
      const nextBBox = `${bbox.latMin},${bbox.lngMin},${bbox.latMax},${bbox.lngMax}`;
      setQuery({ view: 'map', bbox: nextBBox });
      return;
    }
    setQuery({ view: nextView === 'map' ? 'map' : null });
  }

  return (
    <main className="min-h-screen bg-[var(--bg)] text-[var(--text)]">
      <div className="mx-auto w-full max-w-[1200px] px-4 py-6 md:px-8">
        <div className="mb-4 flex items-center justify-between gap-3">
          <div>
            <h1 className="text-xl font-semibold">İlanlar</h1>
            <p className="text-sm text-[var(--muted)]">Yayınlanan ilanları liste ve harita görünümünde inceleyebilirsin.</p>
          </div>
          <div className="flex items-center gap-2">
            <Button variant={view === 'list' ? 'primary' : 'secondary'} onClick={() => setMapView('list')}>
              Liste
            </Button>
            <Button variant={view === 'map' ? 'primary' : 'secondary'} onClick={() => setMapView('map')}>
              Harita
            </Button>
          </div>
        </div>

        <Card className="mb-4 grid gap-3 md:grid-cols-6">
          <Input className="md:col-span-2" placeholder="Başlık / açıklama ara" value={formQ} onChange={(e) => setFormQ(e.target.value)} />
          <select
            className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
            value={formCategoryLeafPathKey}
            onChange={(e) => setFormCategoryLeafPathKey(e.target.value)}
          >
            <option value="">Kategori (hepsi)</option>
            {categoryLeaves.map((leaf) => (
              <option key={leaf.pathKey} value={leaf.pathKey}>
                {leaf.name}
              </option>
            ))}
          </select>
          <select
            className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
            value={formListingType}
            onChange={(e) => setFormListingType(e.target.value)}
          >
            <option value="">İlan Tipi (hepsi)</option>
            <option value="SATILIK">Satılık</option>
            <option value="KIRALIK">Kiralık</option>
            <option value="DEVREN_SATILIK">Devren Satılık</option>
            <option value="DEVREN_KIRALIK">Devren Kiralık</option>
          </select>
          <Input placeholder="İl" value={formCity} onChange={(e) => setFormCity(e.target.value)} />
          <Input placeholder="İlçe" value={formDistrict} onChange={(e) => setFormDistrict(e.target.value)} />
          <Input placeholder="Min fiyat" value={formPriceMin} onChange={(e) => setFormPriceMin(e.target.value)} />
          <Input placeholder="Max fiyat" value={formPriceMax} onChange={(e) => setFormPriceMax(e.target.value)} />
          <div className="md:col-span-6 flex items-center gap-2">
            <Button variant="primary" onClick={applyFilters}>
              Filtrele
            </Button>
            <Button variant="ghost" onClick={clearFilters}>
              Temizle
            </Button>
            <span className="ml-auto text-xs text-[var(--muted)]">Toplam: {total}</span>
          </div>
        </Card>

        {error ? <div className="mb-4 rounded-xl border border-[var(--danger)]/40 bg-[var(--danger)]/10 px-3 py-2 text-sm">{error}</div> : null}

        <div ref={listRef} className="relative max-h-[70vh] overflow-auto rounded-2xl border border-[var(--border)] bg-[var(--card)]">
          {loading ? <div className="p-4 text-sm text-[var(--muted)]">Yükleniyor...</div> : null}
          {!loading && items.length === 0 ? <div className="p-4 text-sm text-[var(--muted)]">Sonuca uygun ilan bulunamadı.</div> : null}

          {!loading && view === 'list' ? (
            <div className="grid gap-3 p-3 md:grid-cols-2">
              {items.map((row) => (
                <button
                  key={row.id}
                  type="button"
                  onClick={() => openDrawer(row.id)}
                  className="ui-interactive rounded-xl border border-[var(--border)] bg-[var(--card-2)] p-3 text-left hover:bg-[var(--interactive-hover-bg)]"
                >
                  <div className="text-sm font-medium">{row.title || 'İlan'}</div>
                  <div className="mt-1 text-xs text-[var(--muted)]">
                    {[row.city, row.district, row.neighborhood].filter(Boolean).join(' / ') || 'Konum belirtilmedi'}
                  </div>
                  <div className="mt-2 text-sm">{formatPrice(row)}</div>
                </button>
              ))}
            </div>
          ) : null}

          {!loading && view === 'map' ? (
            <div className="relative h-[560px] bg-[linear-gradient(135deg,var(--card),var(--card-2))]">
              {!bbox ? <div className="p-4 text-sm text-[var(--muted)]">Harita için koordinatlı ilan bulunamadı.</div> : null}
              {bbox &&
                items.map((row) => {
                  const point = toMapPoint(row, bbox);
                  if (!point) return null;
                  return (
                    <button
                      key={row.id}
                      type="button"
                      onClick={() => openDrawer(row.id)}
                      className="absolute -translate-x-1/2 -translate-y-1/2 rounded-full border border-[var(--border)] bg-[var(--accent)] px-2 py-1 text-[10px] text-[var(--accent-foreground)] shadow"
                      style={{ left: `${point.x}%`, top: `${point.y}%` }}
                      title={row.title}
                    >
                      {formatPrice(row)}
                    </button>
                  );
                })}
              <div className="absolute bottom-2 left-2 rounded-md bg-[var(--card)]/90 px-2 py-1 text-[11px] text-[var(--muted)]">
                BBox: {bboxFromUrl || (bbox ? `${bbox.latMin.toFixed(3)},${bbox.lngMin.toFixed(3)},${bbox.latMax.toFixed(3)},${bbox.lngMax.toFixed(3)}` : '-')}
              </div>
            </div>
          ) : null}
        </div>
      </div>

      {listingId ? (
        <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm" onClick={closeDrawer}>
          <aside
            className="absolute right-0 top-0 h-full w-full max-w-[460px] overflow-auto border-l border-[var(--border)] bg-[var(--card)] p-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-3 flex items-center justify-between">
              <div className="text-sm font-semibold">İlan Detayı</div>
              <Button variant="ghost" onClick={closeDrawer}>
                Kapat
              </Button>
            </div>
            {detailLoading ? <div className="text-sm text-[var(--muted)]">Yükleniyor...</div> : null}
            {!detailLoading && !detail ? <div className="text-sm text-[var(--muted)]">Detay bulunamadı.</div> : null}
            {detail ? (
              <div className="grid gap-3 text-sm">
                <div className="text-base font-medium">{detail.title || 'İlan'}</div>
                <div className="text-[var(--muted)]">{detail.description || 'Açıklama yok'}</div>
                <div className="rounded-lg border border-[var(--border)] bg-[var(--card-2)] p-2">
                  <div>Fiyat: {formatPrice(detail)}</div>
                  <div>Konum: {[detail.city, detail.district, detail.neighborhood].filter(Boolean).join(' / ') || '-'}</div>
                  <div>Gizlilik: {detail.privacyMode || 'EXACT'}</div>
                  <div>Koordinat: {detail.lat ?? '-'}, {detail.lng ?? '-'}</div>
                </div>
              </div>
            ) : null}
          </aside>
        </div>
      ) : null}
    </main>
  );
}
