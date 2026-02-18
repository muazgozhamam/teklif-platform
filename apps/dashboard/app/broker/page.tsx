'use client';

import React from 'react';
import Link from 'next/link';
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
      title="Broker Komuta Ekranı"
      subtitle="Lead onayı, deal üretimi ve iş ortağı operasyonu tek merkezde."
      nav={[
        { href: '/broker', label: 'Panel' },
        { href: '/broker/leads/pending', label: 'Bekleyen Leadler' },
        { href: '/broker/deals/new', label: 'Yeni Deal' },
        { href: '/broker/hunter-applications', label: 'Hunter Başvuruları' },
      ]}
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 10, marginBottom: 12 }}>
        <KpiCard label="Bekleyen Lead" value={stats?.leadsPending ?? 0} loading={statsLoading} />
        <KpiCard label="Onaylı Lead" value={stats?.leadsApproved ?? 0} loading={statsLoading} />
        <KpiCard label="Oluşan Deal" value={stats?.dealsCreated ?? 0} loading={statsLoading} />
        <KpiCard label="Onay Oranı" value={computeApproval(stats?.leadsApproved ?? 0, stats?.leadsPending ?? 0)} loading={statsLoading} />
      </div>
      {statsErr ? <div style={{ marginBottom: 12, color: 'crimson' }}>{statsErr}</div> : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(320px,1fr))', gap: 12 }}>
        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <div>
              <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Operasyon Kuyruğu</h2>
              <p style={{ margin: '6px 0 0', fontSize: 13, color: '#6f665c' }}>Anlık onay, deal ve başvuru iş akışı.</p>
            </div>
            <span style={{ fontSize: 12, borderRadius: 999, border: '1px solid #e5ded1', background: '#f8f3ec', color: '#7a6f62', padding: '3px 9px' }}>
              Hedef: Hızlı dönüş
            </span>
          </div>

          <div style={{ marginTop: 14, display: 'grid', gap: 10 }}>
            <QueueRow title="Bekleyen lead’leri onayla / reddet" note="Pipeline akışını güncel tut." ctaHref="/broker/leads/pending" ctaLabel="Lead Kuyruğu" />
            <QueueRow title="Deal oluştur ve danışmana devret" note="Lead’den deal’e geçiş süresini kısalt." ctaHref="/broker/deals/new" ctaLabel="Yeni Deal" />
            <QueueRow title="Hunter başvurularını değerlendir" note="Ağa yeni iş ortağı ekleme kalitesini artır." ctaHref="/broker/hunter-applications" ctaLabel="Başvurular" />
          </div>
        </section>

        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Hızlı Aksiyonlar</h2>
          <p style={{ margin: '6px 0 12px', fontSize: 13, color: '#6f665c' }}>Broker günlük akış kısayolları.</p>
          <div style={{ display: 'grid', gap: 8 }}>
            <QuickAction href="/broker/leads/pending" label="Bekleyen lead listesini aç" />
            <QuickAction href="/broker/deals/new" label="Yeni deal oluştur" />
            <QuickAction href="/broker/hunter-applications" label="Hunter başvurularını incele" />
          </div>
        </section>
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <StatusCard title="Dönüşüm Sağlığı" value={computePipeline(stats?.dealsCreated ?? 0, stats?.leadsApproved ?? 0)} hint="Deal / Onaylı Lead" />
        <StatusCard title="İnceleme Hızı" value={statsLoading ? '…' : (stats?.leadsPending ?? 0) > 20 ? 'Dikkat' : 'İyi'} hint="Bekleyen lead yoğunluğu" />
        <StatusCard title="Ağ Operasyonu" value="Aktif" hint="Hunter başvuru değerlendirme açık" />
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <Link href="/broker/leads/pending" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Lead Kuyruğu</div>
          <div style={linkNoteStyle}>Onay bekleyen lead’leri aç.</div>
        </Link>
        <Link href="/broker/deals/new" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Deal Oluştur</div>
          <div style={linkNoteStyle}>Manuel deal oluşturma akışı.</div>
        </Link>
        <Link href="/broker/hunter-applications" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Hunter Başvuruları</div>
          <div style={linkNoteStyle}>Ağ başvurularını gözden geçir.</div>
        </Link>
      </div>
    </RoleShell>
  );
}

function KpiCard({ label, value, loading }: { label: string; value: number | string; loading: boolean }) {
  return (
    <div style={{ border: '1px solid #eee', borderRadius: 12, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 'clamp(22px, 5vw, 26px)', fontWeight: 800, minHeight: 36 }}>{loading ? '…' : value}</div>
    </div>
  );
}

function QueueRow({
  title,
  note,
  ctaHref,
  ctaLabel,
}: {
  title: string;
  note: string;
  ctaHref: string;
  ctaLabel: string;
}) {
  return (
    <div style={{ border: '1px solid #ece7df', borderRadius: 12, padding: 12, background: '#fffdf9' }}>
      <div style={{ fontWeight: 700, color: '#1f1b16', fontSize: 14 }}>{title}</div>
      <div style={{ marginTop: 5, color: '#6f665c', fontSize: 12 }}>{note}</div>
      <div style={{ marginTop: 8 }}>
        <Link href={ctaHref} style={{ fontSize: 12, color: '#5c3b12', textDecoration: 'underline', textUnderlineOffset: 2 }}>
          {ctaLabel}
        </Link>
      </div>
    </div>
  );
}

function QuickAction({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      style={{
        textDecoration: 'none',
        border: '1px solid #e2dbd1',
        borderRadius: 12,
        padding: '10px 12px',
        color: '#2f2a24',
        background: '#fff',
        fontSize: 13,
        fontWeight: 600,
      }}
    >
      {label}
    </Link>
  );
}

function StatusCard({ title, value, hint }: { title: string; value: string; hint: string }) {
  return (
    <div style={{ border: '1px solid #e2dbd1', borderRadius: 14, padding: 14, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6f665c' }}>{title}</div>
      <div style={{ marginTop: 6, fontSize: 20, fontWeight: 800, color: '#1f1b16' }}>{value}</div>
      <div style={{ marginTop: 4, fontSize: 12, color: '#8a8072' }}>{hint}</div>
    </div>
  );
}

function computeApproval(approved: number, pending: number) {
  const total = approved + pending;
  if (!total) return '%0';
  return `%${Math.round((approved / total) * 100)}`;
}

function computePipeline(deals: number, approved: number) {
  if (!approved) return '%0';
  return `%${Math.round((deals / approved) * 100)}`;
}

const linkCardStyle: React.CSSProperties = {
  textDecoration: 'none',
  color: '#1f1b16',
  border: '1px solid #e2dbd1',
  borderRadius: 14,
  padding: 16,
  background: '#fff',
};

const linkNoteStyle: React.CSSProperties = {
  marginTop: 6,
  opacity: 0.75,
  fontSize: 13,
};
