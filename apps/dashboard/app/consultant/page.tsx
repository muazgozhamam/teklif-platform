'use client';

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { api } from '@/lib/api';
import { requireRole } from '@/lib/auth';

type ConsultantStats = {
  role: 'CONSULTANT';
  dealsMineOpen: number;
  dealsReadyForListing: number;
  listingsDraft: number;
  listingsPublished: number;
  listingsSold: number;
};

export default function ConsultantHome() {
  const [allowed, setAllowed] = React.useState(false);
  const [stats, setStats] = React.useState<ConsultantStats | null>(null);
  const [statsLoading, setStatsLoading] = React.useState(true);
  const [statsErr, setStatsErr] = React.useState<string | null>(null);

  React.useEffect(() => {
    setAllowed(requireRole(['CONSULTANT']));
  }, []);

  React.useEffect(() => {
    if (!allowed) return;
    let mounted = true;
    async function loadStats() {
      setStatsLoading(true);
      setStatsErr(null);
      try {
        const res = await api.get<ConsultantStats | { role?: string }>('/stats/me');
        const data = res.data;
        if (!mounted) return;
        if (data && (data as { role?: string }).role === 'CONSULTANT') {
          setStats(data as ConsultantStats);
        } else {
          setStats(null);
        }
      } catch (e: unknown) {
        if (!mounted) return;
        const msg = e && typeof e === 'object' && 'message' in e ? String((e as { message?: string }).message || '') : '';
        setStatsErr(msg || 'İstatistik alınamadı');
      } finally {
        if (mounted) setStatsLoading(false);
      }
    }
    loadStats();
    return () => {
      mounted = false;
    };
  }, [allowed]);

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
      title="Danışman Paneli"
      subtitle="Atanan deal ve listing akışlarını buradan yönet."
      nav={[
        { href: '/consultant', label: 'Panel' },
        { href: '/consultant/inbox', label: 'Gelen Kutusu' },
        { href: '/consultant/listings', label: 'İlanlar' },
      ]}
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(170px,1fr))', gap: 10, marginBottom: 12 }}>
        {statsLoading ? (
          <>
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
          </>
        ) : (
          <>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Açık Deal</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.dealsMineOpen ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>İlana Hazır</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.dealsReadyForListing ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Taslak İlan</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.listingsDraft ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Yayındaki İlan</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.listingsPublished ?? 0}</div>
            </div>
          </>
        )}
      </div>
      {statsErr ? <AlertMessage type="error" message={statsErr} /> : null}

      <div style={{ marginTop: 16, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        <button
          style={{ borderRadius: 14, padding: '12px 14px', border: '1px solid #E5E7EB', fontWeight: 900 }}
          onClick={() => (window.location.href = '/consultant/inbox')}
        >
          Gelen Kutusu
        </button>
        <button
          style={{ borderRadius: 14, padding: '12px 14px', border: '1px solid #E5E7EB', fontWeight: 900 }}
          onClick={() => (window.location.href = '/consultant/listings')}
        >
          İlanlarım
        </button>
      </div>
    </RoleShell>
  );
}
