'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { useParams } from 'next/navigation';
import { api } from '@/lib/api';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage, ToastView, useToast } from '@/app/_components/UiFeedback';
import { requireRole } from '@/lib/auth';

type JsonObject = Record<string, unknown>;


type Listing = {
  id: string;
  title?: string | null;
  description?: string | null;
  price?: number | null;
  currency?: string | null;
  city?: string | null;
  district?: string | null;
  type?: string | null;
  rooms?: string | null;
  status?: string | null;
  createdAt?: string;
  updatedAt?: string;
  consultantId?: string | null;
};

type AuditRow = {
  id: string;
  createdAt: string;
  action: string;
  actorEmail?: string | null;
  actorRole?: string | null;
  metaJson?: Record<string, unknown> | null;
};

function getErrorMessage(e: unknown, fallback: string) {
  if (typeof e === 'string') return e;
  if (e && typeof e === 'object') {
    const o = e as { message?: string; data?: { message?: string } };
    return o.data?.message || o.message || fallback;
  }
  return fallback;
}

function Btn({
  children,
  onClick,
  disabled,
  variant,
}: {
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  variant?: 'primary' | 'ghost' | 'danger';
}) {
  const base: React.CSSProperties = {
    borderRadius: 10,
    padding: '9px 12px',
    fontSize: 13,
    fontWeight: 800,
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.6 : 1,
    border: '1px solid #E5E7EB',
    background: '#fff',
  };

  const v = variant || 'ghost';
  const styles: Record<string, React.CSSProperties> = {
    ghost: { background: '#fff', color: '#111827' },
    primary: { background: '#111827', color: '#fff', border: '1px solid #111827' },
    danger: { background: '#991B1B', color: '#fff', border: '1px solid #991B1B' },
  };

  return (
    <button style={{ ...base, ...styles[v] }} onClick={disabled ? undefined : onClick} disabled={disabled}>
      {children}
    </button>
  );
}

function Field({ label, children, hint }: { label: string; children: React.ReactNode; hint?: string }) {
  return (
    <label style={{ display: 'grid', gap: 6 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10 }}>
        <div style={{ fontSize: 13, fontWeight: 900 }}>{label}</div>
        {hint ? <div style={{ fontSize: 12, color: '#6B7280' }}>{hint}</div> : null}
      </div>
      {children}
    </label>
  );
}

export default function ConsultantListingEditPage() {
  const params = useParams<{ id: string }>();
  const id = String((params as unknown as JsonObject)?.id ?? '').trim();
  const [allowed, setAllowed] = useState(false);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const [data, setData] = useState<Listing | null>(null);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [price, setPrice] = useState<string>('');
  const [currency, setCurrency] = useState('TRY');
  const [city, setCity] = useState('');
  const [district, setDistrict] = useState('');
  const [type, setType] = useState('');
  const [rooms, setRooms] = useState('');
  const [status, setStatus] = useState('');
  const [auditRows, setAuditRows] = useState<AuditRow[]>([]);
  const [auditLoading, setAuditLoading] = useState(false);
  const { toast, show } = useToast();

  const canPublish = useMemo(() => {
    const t = title.trim();
    const p = Number(String(price).replace(/,/g, '.'));
    return t.length > 0 && Number.isFinite(p) && p > 0;
  }, [title, price]);

  async function load() {
    if (!id) return;
    setLoading(true);
    setErr(null);
    try {
      const r = await api.get<Listing>(`/listings/${id}`);
      const l = (r?.data ?? r) as unknown as JsonObject as Listing;

      setData(l);
      setTitle(String(l?.title ?? ''));
      setDescription(String(l?.description ?? ''));
      setPrice(l?.price === null || l?.price === undefined ? '' : String(l.price));
      setCurrency(String(l?.currency ?? 'TRY'));
      setCity(String(l?.city ?? ''));
      setDistrict(String(l?.district ?? ''));
      setType(String(l?.type ?? ''));
      setRooms(String(l?.rooms ?? ''));
      setStatus(String(l?.status ?? ''));
      await loadAudit();
    } catch (e: unknown) {
      console.error('load listing failed:', e);
      setErr(getErrorMessage(e, 'İlan yüklenemedi'));
    } finally {
      setLoading(false);
    }
  }

  async function loadAudit() {
    if (!id) return;
    setAuditLoading(true);
    try {
      const r = await api.get<AuditRow[]>(`/audit/entity/LISTING/${id}`);
      const rows = (r?.data ?? r) as unknown as AuditRow[];
      setAuditRows(Array.isArray(rows) ? rows : []);
    } catch {
      setAuditRows([]);
    } finally {
      setAuditLoading(false);
    }
  }

  useEffect(() => {
    setAllowed(requireRole(['CONSULTANT']));
  }, []);

  useEffect(() => {
    if (!allowed) return;
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allowed, id]);

  async function save() {
    if (!id) return;
    setSaving(true);
    setErr(null);
    try {
      const payload: {
        title: string;
        description: string | null;
        currency: string;
        city: string | null;
        district: string | null;
        type: string | null;
        rooms: string | null;
        price?: number | null;
      } = {
        title: title.trim(),
        description: description.trim() || null,
        currency: currency.trim() || 'TRY',
        city: city.trim() || null,
        district: district.trim() || null,
        type: type.trim() || null,
        rooms: rooms.trim() || null,
      };

      if (price.trim().length === 0) {
        payload.price = null;
      } else {
        const p = Number(price.replace(/,/g, '.'));
        payload.price = Number.isFinite(p) ? p : null;
      }

      const r = await api.put<Listing>(`/listings/${id}`, payload);
      const l = (r?.data ?? r) as unknown as JsonObject as Listing;
      setData(l);
      setStatus(String(l?.status ?? status));
      show('success', 'İlan kaydedildi');
    } catch (e: unknown) {
      console.error('save listing failed:', e);
      setErr(getErrorMessage(e, 'Kaydetme başarısız'));
    } finally {
      setSaving(false);
    }
  }

  async function publish() {
    if (!id) return;
    if (!canPublish) {
      show('error', 'Yayınlamak için en az Başlık ve Fiyat gerekli.');
      return;
    }
    setPublishing(true);
    setErr(null);
    try {
      await save();
      const r = await api.post<Listing>(`/listings/${id}/publish`, {});
      const l = (r?.data ?? r) as unknown as JsonObject as Listing;
      setData(l);
      setStatus(String(l?.status ?? 'PUBLISHED'));
      show('success', 'İlan yayına alındı');
      await loadAudit();
    } catch (e: unknown) {
      console.error('publish listing failed:', e);
      setErr(getErrorMessage(e, 'Yayına alma başarısız'));
    } finally {
      setPublishing(false);
    }
  }

  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="CONSULTANT"
      title="İlan Düzenle"
      subtitle="Deal’den üretilen ilanı düzenle, yayınla ve zaman çizelgesini izle."
      nav={[
        { href: '/consultant', label: 'Panel' },
        { href: '/consultant/inbox', label: 'Gelen Kutusu' },
        { href: '/consultant/listings', label: 'İlanlar' },
      ]}
    >
    <div style={{ padding: 2, maxWidth: 980, margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
        <div>
          <div style={{ fontSize: 22, fontWeight: 900, letterSpacing: -0.2 }}>İlan Düzenle</div>
          <div style={{ marginTop: 6, color: '#6B7280', fontSize: 13 }}>
            İlan: <code>{id || '—'}</code> {status ? <span> • Durum: <b>{status}</b></span> : null}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
          <Btn onClick={() => (window.location.href = '/consultant/inbox')}>← Gelen Kutusu</Btn>
          <Btn onClick={() => load()} disabled={loading || saving || publishing}>
            Yenile
          </Btn>
          <Btn variant="primary" onClick={() => save()} disabled={loading || saving || publishing}>
            {saving ? 'Kaydediliyor…' : 'Kaydet'}
          </Btn>
          <Btn variant="primary" onClick={() => publish()} disabled={loading || saving || publishing || !canPublish}>
            {publishing ? 'Yayına alınıyor…' : 'Yayınla'}
          </Btn>
        </div>
      </div>

      {err ? <AlertMessage type="error" message={err} /> : null}

      <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 14 }}>
        <div style={{ border: '1px solid #EEF2F7', borderRadius: 18, padding: 14, background: '#fff' }}>
          <div style={{ fontSize: 14, fontWeight: 900, marginBottom: 10 }}>Temel Bilgiler</div>

          <div style={{ display: 'grid', gap: 12 }}>
            <Field label="Başlık" hint="Zorunlu (Yayınlama için)">
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Örn: Konya Meram 2+1 Satılık"
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13 }}
              />
            </Field>

            <Field label="Açıklama">
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Detaylar…"
                rows={10}
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13, resize: 'vertical' }}
              />
            </Field>
          </div>
        </div>

        <div style={{ border: '1px solid #EEF2F7', borderRadius: 18, padding: 14, background: '#fff' }}>
          <div style={{ fontSize: 14, fontWeight: 900, marginBottom: 10 }}>Meta</div>

          <div style={{ display: 'grid', gap: 12 }}>
            <Field label="Fiyat" hint="Zorunlu (Yayınlama için)">
              <input
                value={price}
                onChange={(e) => setPrice(e.target.value)}
                placeholder="Örn: 3750000"
                inputMode="decimal"
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13 }}
              />
            </Field>

            <Field label="Para Birimi">
              <input
                value={currency}
                onChange={(e) => setCurrency(e.target.value)}
                placeholder="TRY"
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13 }}
              />
            </Field>

            <Field label="Şehir">
              <input
                value={city}
                onChange={(e) => setCity(e.target.value)}
                placeholder="Konya"
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13 }}
              />
            </Field>

            <Field label="İlçe">
              <input
                value={district}
                onChange={(e) => setDistrict(e.target.value)}
                placeholder="Meram"
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13 }}
              />
            </Field>

            <Field label="Tür">
              <input
                value={type}
                onChange={(e) => setType(e.target.value)}
                placeholder="SATILIK / KIRALIK"
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13 }}
              />
            </Field>

            <Field label="Oda">
              <input
                value={rooms}
                onChange={(e) => setRooms(e.target.value)}
                placeholder="2+1"
                style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10, fontSize: 13 }}
              />
            </Field>

            <div style={{ marginTop: 6, fontSize: 12, color: '#6B7280' }}>
              Backend publish kuralı: <b>title</b> dolu + <b>price</b> set olmalı.
            </div>
          </div>
        </div>
      </div>

      <div style={{ marginTop: 14, border: '1px solid #EEF2F7', borderRadius: 18, padding: 14, background: '#fff' }}>
        <div style={{ fontSize: 14, fontWeight: 900, marginBottom: 8 }}>Denetim Zaman Çizelgesi</div>
        {auditLoading ? (
          <div style={{ color: '#6B7280', fontSize: 13 }}>Zaman çizelgesi yükleniyor…</div>
        ) : auditRows.length === 0 ? (
          <div style={{ color: '#6B7280', fontSize: 13 }}>Audit kaydı bulunamadı.</div>
        ) : (
          <div style={{ display: 'grid', gap: 8 }}>
            {auditRows.map((r) => (
              <div key={r.id} style={{ border: '1px solid #E5E7EB', borderRadius: 12, padding: 10 }}>
                <div style={{ fontSize: 12, color: '#6B7280' }}>
                  {new Date(r.createdAt).toLocaleString()} • {r.actorEmail || r.actorRole || 'system'}
                </div>
                <div style={{ marginTop: 4, fontSize: 13, fontWeight: 800 }}>{r.action}</div>
                {r.metaJson ? (
                  <pre style={{ marginTop: 6, fontSize: 11, color: '#4B5563', whiteSpace: 'pre-wrap' }}>
                    {JSON.stringify(r.metaJson)}
                  </pre>
                ) : null}
              </div>
            ))}
          </div>
        )}
      </div>

      {loading && <div style={{ marginTop: 14, color: '#6B7280', fontSize: 13 }}>Yükleniyor…</div>}

      {data && (
        <div style={{ marginTop: 14, color: '#6B7280', fontSize: 12 }}>
          createdAt: {data.createdAt || '—'} • updatedAt: {data.updatedAt || '—'} • consultantId: {data.consultantId || '—'}
        </div>
      )}
      <ToastView toast={toast} />
    </div>
    </RoleShell>
  );
}
