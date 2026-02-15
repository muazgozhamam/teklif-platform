'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';

type Config = {
  id: string;
  baseRate: number;
  hunterSplit: number;
  brokerSplit: number;
  consultantSplit: number;
  platformSplit: number;
};

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers || {}) },
    cache: 'no-store',
  });
  if (!res.ok) {
    let msg = res.statusText;
    try {
      const j = await res.json();
      msg = j?.message || msg;
    } catch {}
    throw new Error(`${res.status} ${msg}`);
  }
  return (await res.json()) as T;
}

export default function AdminCommissionPage() {
  const [cfg, setCfg] = React.useState<Config | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [err, setErr] = React.useState<string | null>(null);

  async function load() {
    setLoading(true);
    setErr(null);
    try {
      const data = await api<Config>('/api/admin/commission-config');
      setCfg(data);
    } catch (e: any) {
      setErr(e?.message || 'Yükleme başarısız');
    } finally {
      setLoading(false);
    }
  }

  React.useEffect(() => {
    load();
  }, []);

  async function save() {
    if (!cfg) return;
    setSaving(true);
    setErr(null);
    try {
      const updated = await api<Config>('/api/admin/commission-config', {
        method: 'PATCH',
        body: JSON.stringify({
          baseRate: Number(cfg.baseRate),
          hunterSplit: Number(cfg.hunterSplit),
          brokerSplit: Number(cfg.brokerSplit),
          consultantSplit: Number(cfg.consultantSplit),
          platformSplit: Number(cfg.platformSplit),
        }),
      });
      setCfg(updated);
    } catch (e: any) {
      setErr(e?.message || 'Kaydetme başarısız');
    } finally {
      setSaving(false);
    }
  }

  const total =
    Number(cfg?.hunterSplit || 0) +
    Number(cfg?.brokerSplit || 0) +
    Number(cfg?.consultantSplit || 0) +
    Number(cfg?.platformSplit || 0);

  return (
    <RoleShell
      role="ADMIN"
      title="Komisyon Yapılandırması"
      subtitle="Temel oran ve dağılım yüzdeleri."
      nav={[
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >

      {err && (
        <div style={{ marginTop: 12, padding: 12, borderRadius: 12, background: '#fff5f5', border: '1px solid #ffd6d6' }}>
          <strong>Hata:</strong> {err}
        </div>
      )}

      {loading && <div style={{ marginTop: 16 }}>Yükleniyor…</div>}

      {cfg && !loading && (
        <div style={{ marginTop: 16, border: '1px solid #eee', borderRadius: 14, padding: 16, display: 'grid', gap: 12 }}>
          <label>
            Temel Oran (0.03 = %3)
            <input
              type="number"
              step="0.001"
              value={cfg.baseRate}
              onChange={(e) => setCfg({ ...cfg, baseRate: Number(e.target.value) })}
              style={{ width: '100%', marginTop: 6, padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
            />
          </label>
          <label>
            Hunter Dağılımı (%)
            <input
              type="number"
              value={cfg.hunterSplit}
              onChange={(e) => setCfg({ ...cfg, hunterSplit: Number(e.target.value) })}
              style={{ width: '100%', marginTop: 6, padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
            />
          </label>
          <label>
            Broker Dağılımı (%)
            <input
              type="number"
              value={cfg.brokerSplit}
              onChange={(e) => setCfg({ ...cfg, brokerSplit: Number(e.target.value) })}
              style={{ width: '100%', marginTop: 6, padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
            />
          </label>
          <label>
            Danışman Dağılımı (%)
            <input
              type="number"
              value={cfg.consultantSplit}
              onChange={(e) => setCfg({ ...cfg, consultantSplit: Number(e.target.value) })}
              style={{ width: '100%', marginTop: 6, padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
            />
          </label>
          <label>
            Platform Dağılımı (%)
            <input
              type="number"
              value={cfg.platformSplit}
              onChange={(e) => setCfg({ ...cfg, platformSplit: Number(e.target.value) })}
              style={{ width: '100%', marginTop: 6, padding: 10, borderRadius: 10, border: '1px solid #ddd' }}
            />
          </label>

          <div style={{ fontSize: 13, opacity: 0.8 }}>
            Dağılım toplamı: <b>{total}</b> (100 olmalı)
          </div>

          <div style={{ display: 'flex', gap: 10 }}>
            <button onClick={save} disabled={saving} style={{ padding: '10px 14px', borderRadius: 10, border: '1px solid #111', background: '#111', color: '#fff' }}>
              {saving ? 'Kaydediliyor...' : 'Kaydet'}
            </button>
            <button onClick={load} disabled={loading || saving} style={{ padding: '10px 14px', borderRadius: 10, border: '1px solid #ddd', background: '#fff' }}>
              Yenile
            </button>
          </div>
        </div>
      )}
    </RoleShell>
  );
}
