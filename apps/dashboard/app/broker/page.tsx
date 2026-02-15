'use client';

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { api } from '@/lib/api';

type BrokerStats = {
  role: 'BROKER';
  leadsPending: number;
  leadsApproved: number;
  dealsCreated: number;
};

export default function BrokerRootPage() {
  const [stats, setStats] = React.useState<BrokerStats | null>(null);
  const [statsLoading, setStatsLoading] = React.useState(true);
  const [statsErr, setStatsErr] = React.useState<string | null>(null);

  React.useEffect(() => {
    let mounted = true;
    async function loadStats() {
      setStatsLoading(true);
      setStatsErr(null);
      try {
        const res = await api.get<BrokerStats | { role?: string }>('/stats/me');
        const data = res.data;
        if (!mounted) return;
        if (data && (data as { role?: string }).role === 'BROKER') {
          setStats(data as BrokerStats);
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
  }, []);

  return (
    <RoleShell
      role="BROKER"
      title="Broker Paneli"
      subtitle="Lead inceleme ve deal yönetimini buradan takip et."
      nav={[
        { href: '/broker', label: 'Panel' },
        { href: '/broker/leads/pending', label: 'Bekleyen Leadler' },
        { href: '/broker/deals/new', label: 'Yeni Deal' },
        { href: '/broker/hunter-applications', label: 'Hunter Başvuruları' },
      ]}
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 10, marginBottom: 12 }}>
        {statsLoading ? (
          <>
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
            <div style={{ height: 74, border: '1px solid #eee', borderRadius: 10, background: '#f3f4f6' }} />
          </>
        ) : (
          <>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Bekleyen Lead</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.leadsPending ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Onaylı Lead</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.leadsApproved ?? 0}</div>
            </div>
            <div style={{ border: '1px solid #eee', borderRadius: 10, padding: 10, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#666' }}>Oluşan Deal</div>
              <div style={{ fontSize: 24, fontWeight: 800 }}>{stats?.dealsCreated ?? 0}</div>
            </div>
          </>
        )}
      </div>
      {statsErr ? <div style={{ marginBottom: 12, color: 'crimson' }}>{statsErr}</div> : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <a href="/broker/leads/pending" style={{ textDecoration: 'none', color: '#1f1b16', border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
          <div style={{ fontWeight: 700 }}>Lead Kuyruğu</div>
          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13 }}>Onay bekleyen lead’leri aç.</div>
        </a>
        <a href="/broker/deals/new" style={{ textDecoration: 'none', color: '#1f1b16', border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
          <div style={{ fontWeight: 700 }}>Deal Oluştur</div>
          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13 }}>Manuel deal oluşturma akışı.</div>
        </a>
        <a href="/broker/hunter-applications" style={{ textDecoration: 'none', color: '#1f1b16', border: '1px solid #e2dbd1', borderRadius: 14, padding: 16, background: '#fff' }}>
          <div style={{ fontWeight: 700 }}>Hunter Başvuruları</div>
          <div style={{ marginTop: 6, opacity: 0.75, fontSize: 13 }}>Ağ başvurularını gözden geçir.</div>
        </a>
      </div>
    </RoleShell>
  );
}
