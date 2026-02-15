'use client';

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { api } from '@/lib/api';
import { requireRole } from '@/lib/auth';

type AdminStats = {
  role: 'ADMIN';
  usersTotal: number;
  leadsTotal: number;
  dealsTotal: number;
  listingsTotal: number;
};

export default function AdminHomePage() {
  const [allowed, setAllowed] = React.useState(false);
  const [stats, setStats] = React.useState<AdminStats | null>(null);
  const [statsLoading, setStatsLoading] = React.useState(true);
  const [statsErr, setStatsErr] = React.useState<string | null>(null);

  React.useEffect(() => {
    setAllowed(requireRole(['ADMIN']));
  }, []);

  React.useEffect(() => {
    if (!allowed) return;
    let mounted = true;
    async function loadStats() {
      setStatsLoading(true);
      setStatsErr(null);
      try {
        const res = await api.get<AdminStats | { role?: string }>('/stats/me');
        const data = res.data;
        if (!mounted) return;
        if (data && (data as { role?: string }).role === 'ADMIN') {
          setStats(data as AdminStats);
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
      role="ADMIN"
      title="Yönetici Paneli"
      subtitle="satdedi.com operasyon akışını tek ekrandan takip et."
      nav={[
        { href: '/admin', label: 'Panel' },
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/audit', label: 'Denetim' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
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
              <div style={{ fontSize: 12, color: '#666' }}>Toplam Kullanıcı</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.usersTotal ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Toplam Lead</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.leadsTotal ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Toplam Deal</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.dealsTotal ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Toplam İlan</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.listingsTotal ?? 0}</div>
            </div>
          </>
        )}
      </div>
      {statsErr ? <AlertMessage type="error" message={statsErr} /> : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <a href="/admin/users" style={{ textDecoration: 'none', color: '#1f1b16', border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
          <div style={{ fontWeight: 700 }}>Kullanıcı Yönetimi</div>
          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13 }}>Rol, aktif/pasif ve kullanıcı düzenlemeleri.</div>
        </a>
        <a href="/admin/onboarding" style={{ textDecoration: 'none', color: '#1f1b16', border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
          <div style={{ fontWeight: 700 }}>Uyum Süreci</div>
          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13 }}>Rol bazlı onboarding ilerlemesini görüntüle.</div>
        </a>
        <a href="/admin/audit" style={{ textDecoration: 'none', color: '#1f1b16', border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
          <div style={{ fontWeight: 700 }}>Denetim Kayıtları</div>
          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13 }}>Aksiyonları ham ve kanonik alanlarla incele.</div>
        </a>
        <a href="/admin/commission" style={{ textDecoration: 'none', color: '#1f1b16', border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
          <div style={{ fontWeight: 700 }}>Komisyon Ayarları</div>
          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13 }}>Temel komisyon oranı ve dağılım yüzdeleri.</div>
        </a>
      </div>
    </RoleShell>
  );
}
