'use client';

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { api } from '@/lib/api';

type ConsultantStats = {
  role: 'CONSULTANT';
  dealsMineOpen: number;
  dealsReadyForListing: number;
  listingsDraft: number;
  listingsPublished: number;
  listingsSold: number;
};

export default function ConsultantHome() {
  const [stats, setStats] = React.useState<ConsultantStats | null>(null);
  const [statsLoading, setStatsLoading] = React.useState(true);
  const [statsErr, setStatsErr] = React.useState<string | null>(null);

  React.useEffect(() => {
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
  }, []);

  return (
    <RoleShell
      role="CONSULTANT"
      title="Danışman Komuta Ekranı"
      subtitle="Atanan deal, ilan üretimi ve yayın sürecini tek merkezden yönet."
      nav={[
        { href: '/consultant', label: 'Panel' },
        { href: '/consultant/inbox', label: 'Gelen Kutusu' },
        { href: '/consultant/listings', label: 'İlanlar' },
      ]}
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(170px,1fr))', gap: 10, marginBottom: 12 }}>
        <KpiCard label="Açık Deal" value={stats?.dealsMineOpen ?? 0} loading={statsLoading} />
        <KpiCard label="İlana Hazır" value={stats?.dealsReadyForListing ?? 0} loading={statsLoading} />
        <KpiCard label="Taslak İlan" value={stats?.listingsDraft ?? 0} loading={statsLoading} />
        <KpiCard label="Yayındaki İlan" value={stats?.listingsPublished ?? 0} loading={statsLoading} />
      </div>
      {statsErr ? <div style={{ marginBottom: 12, color: 'crimson' }}>{statsErr}</div> : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(320px,1fr))', gap: 12 }}>
        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <div>
              <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Operasyon Kuyruğu</h2>
              <p style={{ margin: '6px 0 0', fontSize: 13, color: '#6f665c' }}>Gelen deal’leri ilana dönüştür ve yayın döngüsünü hızlandır.</p>
            </div>
            <span style={{ fontSize: 12, borderRadius: 999, border: '1px solid #e5ded1', background: '#f8f3ec', color: '#7a6f62', padding: '3px 9px' }}>
              Hedef: Hızlı yayın
            </span>
          </div>

          <div style={{ marginTop: 14, display: 'grid', gap: 10 }}>
            <QueueRow title="Gelen kutusundaki atamaları temizle" note="Önce deal sahiplen, sonra listing üret." ctaHref="/consultant/inbox" ctaLabel="Gelen Kutusu" />
            <QueueRow title="İlana hazır deal’leri yayınla" note="Taslakları tamamlayıp yayına al." ctaHref="/consultant/listings" ctaLabel="İlanlar" />
            <QueueRow title="Eksik içerik ve fiyat girişini tamamla" note="İlan kalite puanını yükselt." ctaHref="/consultant/listings" ctaLabel="Taslaklar" />
          </div>
        </section>

        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Hızlı Aksiyonlar</h2>
          <p style={{ margin: '6px 0 12px', fontSize: 13, color: '#6f665c' }}>Danışman günlük çalışma kısayolları.</p>
          <div style={{ display: 'grid', gap: 8 }}>
            <QuickAction href="/consultant/inbox" label="Gelen kutusunu aç" />
            <QuickAction href="/consultant/listings" label="İlanları yönet" />
            <QuickAction href="/consultant/listings?status=DRAFT" label="Taslakları düzenle" />
          </div>
        </section>
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <StatusCard title="Listing Hazırlık Oranı" value={computeReadiness(stats?.dealsReadyForListing ?? 0, stats?.dealsMineOpen ?? 0)} hint="Hazır Deal / Açık Deal" />
        <StatusCard title="Yayın Performansı" value={computePublish(stats?.listingsPublished ?? 0, stats?.listingsDraft ?? 0)} hint="Yayında / Taslak" />
        <StatusCard title="Operasyon Durumu" value="Aktif" hint="Inbox ve listing akışı açık" />
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <Link href="/consultant/inbox" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Gelen Kutusu</div>
          <div style={linkNoteStyle}>Atanan deal akışını yönet.</div>
        </Link>
        <Link href="/consultant/listings" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>İlanlarım</div>
          <div style={linkNoteStyle}>Taslak ve yayındaki ilanları düzenle.</div>
        </Link>
      </div>
    </RoleShell>
  );
}

function KpiCard({ label, value, loading }: { label: string; value: number; loading: boolean }) {
  return (
    <div style={{ border: '1px solid #eee', borderRadius: 12, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 'clamp(21px, 5vw, 24px)', fontWeight: 800, minHeight: 34 }}>{loading ? '…' : value}</div>
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

function computeReadiness(ready: number, open: number) {
  if (!open) return '%0';
  return `%${Math.round((ready / open) * 100)}`;
}

function computePublish(published: number, draft: number) {
  const total = published + draft;
  if (!total) return '%0';
  return `%${Math.round((published / total) * 100)}`;
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
