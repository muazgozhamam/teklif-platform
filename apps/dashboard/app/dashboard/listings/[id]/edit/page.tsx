'use client';

import React from 'react';
import { useParams } from 'next/navigation';
import { api } from '@/lib/api';
import { requireAuth } from '@/lib/auth';
import { Button } from '@/src/ui/components/Button';
import { Input } from '@/src/ui/components/Input';
import { Card } from '@/src/ui/components/Card';
import { CategoryCascader } from '../../_components/CategoryCascader';
import { MapPinPicker } from '../../_components/MapPinPicker';

type Listing = {
  id: string;
  title?: string | null;
  description?: string | null;
  priceAmount?: string | number | null;
  currency?: string | null;
  city?: string | null;
  district?: string | null;
  neighborhood?: string | null;
  lat?: number | null;
  lng?: number | null;
  privacyMode?: 'EXACT' | 'APPROXIMATE' | 'HIDDEN';
  categoryPathKey?: string | null;
  status?: string;
  sahibindenUrl?: string | null;
  listingAttributes?: Array<{ key: string; valueJson: unknown }>;
};

type AttributeDef = {
  key: string;
  label: string;
  type: 'TEXT' | 'NUMBER' | 'BOOLEAN' | 'SELECT' | 'MULTISELECT';
  required: boolean;
  optionsJson?: string[] | null;
};

type ExportPayload = {
  guideSteps?: string[];
  categoryPath?: string | null;
  title?: string;
  description?: string | null;
};

export default function EditListingPage() {
  const params = useParams<{ id: string }>();
  const id = String(params?.id || '');
  const [allowed, setAllowed] = React.useState(false);
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [publishing, setPublishing] = React.useState(false);
  const [archiving, setArchiving] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [message, setMessage] = React.useState<string | null>(null);
  const [row, setRow] = React.useState<Listing | null>(null);
  const [attributeDefs, setAttributeDefs] = React.useState<AttributeDef[]>([]);
  const [attributeValues, setAttributeValues] = React.useState<Record<string, string>>({});
  const [exportPayload, setExportPayload] = React.useState<ExportPayload | null>(null);

  React.useEffect(() => {
    setAllowed(requireAuth());
  }, []);

  const load = React.useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<Listing>(`/listings/${id}`);
      setRow(res.data);
      const existing = Array.isArray(res.data?.listingAttributes) ? res.data.listingAttributes : [];
      const mapped: Record<string, string> = {};
      existing.forEach((item) => {
        mapped[item.key] = item?.valueJson == null ? '' : String(item.valueJson);
      });
      setAttributeValues(mapped);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'İlan yüklenemedi');
    } finally {
      setLoading(false);
    }
  }, [id]);

  React.useEffect(() => {
    if (!allowed) return;
    void load();
  }, [allowed, load]);

  function setField<K extends keyof Listing>(key: K, value: Listing[K]) {
    setRow((prev) => (prev ? { ...prev, [key]: value } : prev));
  }

  function setAttrValue(key: string, value: string) {
    setAttributeValues((prev) => ({ ...prev, [key]: value }));
  }

  React.useEffect(() => {
    const key = row?.categoryPathKey?.trim();
    if (!key) {
      setAttributeDefs([]);
      return;
    }
    let alive = true;
    fetch(`/api/public/listings/categories/attributes?pathKey=${encodeURIComponent(key)}`, { cache: 'no-store' })
      .then(async (res) => {
        if (!res.ok) throw new Error('Kategori özellikleri alınamadı');
        return res.json();
      })
      .then((payload: { attributes?: AttributeDef[] }) => {
        if (!alive) return;
        const defs = Array.isArray(payload?.attributes) ? payload.attributes : [];
        setAttributeDefs(defs);
        setAttributeValues((prev) => {
          const next: Record<string, string> = { ...prev };
          defs.forEach((d) => {
            if (next[d.key] === undefined) next[d.key] = '';
          });
          return next;
        });
      })
      .catch(() => {
        if (!alive) return;
        setAttributeDefs([]);
      });
    return () => {
      alive = false;
    };
  }, [row?.categoryPathKey]);

  async function save() {
    if (!row) return;
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      await api.patch(`/listings/${id}`, {
        title: row.title || '',
        description: row.description || '',
        categoryLeafPathKey: row.categoryPathKey || null,
        priceAmount: row.priceAmount || null,
        city: row.city || null,
        district: row.district || null,
        neighborhood: row.neighborhood || null,
        lat: row.lat ?? null,
        lng: row.lng ?? null,
        privacyMode: row.privacyMode || 'EXACT',
      });
      if (attributeDefs.length > 0) {
        await api.put(`/listings/${id}/attributes`, {
          attributes: attributeDefs
            .filter((d) => String(attributeValues[d.key] || '').trim())
            .map((d) => ({ key: d.key, value: attributeValues[d.key] })),
        });
      }
      setMessage('İlan kaydedildi.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Kaydetme başarısız');
    } finally {
      setSaving(false);
    }
  }

  async function publish() {
    setPublishing(true);
    setError(null);
    setMessage(null);
    try {
      await api.post(`/listings/${id}/publish`, {});
      setMessage('İlan yayına alındı.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Publish başarısız');
    } finally {
      setPublishing(false);
    }
  }

  async function archive() {
    setArchiving(true);
    setError(null);
    setMessage(null);
    try {
      await api.post(`/listings/${id}/archive`, {});
      setMessage('İlan arşive alındı.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Archive başarısız');
    } finally {
      setArchiving(false);
    }
  }

  async function loadExport() {
    setError(null);
    setMessage(null);
    try {
      const res = await api.get<ExportPayload>(`/listings/${id}/export/sahibinden`);
      setExportPayload(res.data);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Export alınamadı');
    }
  }

  async function markExported() {
    setError(null);
    setMessage(null);
    try {
      await api.patch(`/listings/${id}/sahibinden`, {
        sahibindenUrl: row?.sahibindenUrl || null,
        markExported: true,
      });
      setMessage('Sahibinden export bilgisi güncellendi.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Sahibinden güncellemesi başarısız');
    }
  }

  if (!allowed) return null;

  return (
    <main className="min-h-screen bg-[var(--bg)] px-4 py-6 text-[var(--text)] md:px-8">
      <div className="mx-auto w-full max-w-[920px]">
        <h1 className="mb-1 text-xl font-semibold">İlan Düzenle</h1>
        <p className="mb-4 text-sm text-[var(--muted)]">Publish için lat/lng pin zorunlu.</p>

        {loading ? <Card>Yükleniyor...</Card> : null}

        {!loading && row ? (
          <Card className="grid gap-3">
            <Input value={row.title || ''} onChange={(e) => setField('title', e.target.value)} placeholder="Başlık" />
            <textarea
              className="min-h-[120px] rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm outline-none"
              value={row.description || ''}
              onChange={(e) => setField('description', e.target.value)}
              placeholder="Açıklama"
            />
            <div className="grid gap-3 md:grid-cols-2">
              <Input value={String(row.priceAmount || '')} onChange={(e) => setField('priceAmount', e.target.value)} placeholder="Fiyat" />
              <div className="md:col-span-1">
                <CategoryCascader
                  value={row.categoryPathKey || ''}
                  onChange={(nextLeafPath) => setField('categoryPathKey', nextLeafPath)}
                />
              </div>
              <Input value={row.city || ''} onChange={(e) => setField('city', e.target.value)} placeholder="İl" />
              <Input value={row.district || ''} onChange={(e) => setField('district', e.target.value)} placeholder="İlçe" />
              <Input value={row.neighborhood || ''} onChange={(e) => setField('neighborhood', e.target.value)} placeholder="Mahalle" />
              <select
                className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
                value={row.privacyMode || 'EXACT'}
                onChange={(e) => setField('privacyMode', e.target.value as Listing['privacyMode'])}
              >
                <option value="EXACT">EXACT</option>
                <option value="APPROXIMATE">APPROXIMATE</option>
                <option value="HIDDEN">HIDDEN</option>
              </select>
              <div className="md:col-span-2 grid gap-2">
                <MapPinPicker
                  value={typeof row.lat === 'number' && typeof row.lng === 'number' ? { lat: row.lat, lng: row.lng } : null}
                  onChange={(next) => {
                    setField('lat', next.lat);
                    setField('lng', next.lng);
                  }}
                />
                <div className="text-xs text-[var(--muted)]">
                  Seçili Pin:{' '}
                  {typeof row.lat === 'number' && typeof row.lng === 'number'
                    ? `${row.lat.toFixed(6)}, ${row.lng.toFixed(6)}`
                    : 'Henüz seçilmedi'}
                </div>
              </div>
            </div>
            {attributeDefs.length > 0 ? (
              <div className="grid gap-2 rounded-xl border border-[var(--border)] bg-[var(--card-2)] p-3">
                <div className="text-sm font-medium">İlan Bilgileri</div>
                {attributeDefs.map((attr) => (
                  <label key={attr.key} className="grid gap-1">
                    <span className="text-xs text-[var(--muted)]">
                      {attr.label} {attr.required ? '*' : ''}
                    </span>
                    {attr.type === 'SELECT' ? (
                      <select
                        className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
                        value={attributeValues[attr.key] || ''}
                        onChange={(e) => setAttrValue(attr.key, e.target.value)}
                      >
                        <option value="">Seçiniz</option>
                        {(Array.isArray(attr.optionsJson) ? attr.optionsJson : []).map((opt) => (
                          <option key={`${attr.key}-${opt}`} value={opt}>
                            {opt}
                          </option>
                        ))}
                      </select>
                    ) : (
                      <Input
                        placeholder={attr.label}
                        value={attributeValues[attr.key] || ''}
                        onChange={(e) => setAttrValue(attr.key, e.target.value)}
                      />
                    )}
                  </label>
                ))}
              </div>
            ) : null}
            <Input
              value={row.sahibindenUrl || ''}
              onChange={(e) => setField('sahibindenUrl', e.target.value)}
              placeholder="Sahibinden URL (opsiyonel)"
            />
            <div className="flex flex-wrap gap-2">
              <Button variant="secondary" onClick={save} loading={saving}>Kaydet</Button>
              <Button variant="primary" onClick={publish} loading={publishing}>Yayına Al</Button>
              <Button variant="destructive" onClick={archive} loading={archiving}>Arşivle</Button>
              <Button variant="ghost" onClick={loadExport}>Sahibinden Export Helper</Button>
              <Button variant="ghost" onClick={markExported}>Export Yapıldı İşaretle</Button>
            </div>
          </Card>
        ) : null}

        {error ? <div className="mt-3 rounded-lg border border-[var(--danger)]/40 bg-[var(--danger)]/10 px-3 py-2 text-sm">{error}</div> : null}
        {message ? <div className="mt-3 rounded-lg border border-[var(--success)]/40 bg-[var(--success)]/10 px-3 py-2 text-sm">{message}</div> : null}

        {exportPayload ? (
          <Card className="mt-4">
            <div className="mb-2 text-sm font-semibold">Sahibinden Export Yardımcısı</div>
            <div className="text-xs text-[var(--muted)]">Kategori: {exportPayload.categoryPath || '-'}</div>
            <ol className="mt-2 list-decimal space-y-1 pl-5 text-sm">
              {(exportPayload.guideSteps || []).map((step, idx) => (
                <li key={`${idx}-${step}`}>{step}</li>
              ))}
            </ol>
          </Card>
        ) : null}
      </div>
    </main>
  );
}
