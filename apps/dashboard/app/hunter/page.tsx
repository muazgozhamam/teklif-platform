'use client';

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { requireRole } from '@/lib/auth';
import { api } from '@/lib/api';

type HunterLead = {
  id: string;
  status: string;
  createdAt: string;
};

export default function HunterDashboardPage() {
  const [allowed, setAllowed] = React.useState(false);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [rows, setRows] = React.useState<HunterLead[]>([]);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<HunterLead[]>('/hunter/leads');
      setRows(Array.isArray(res.data) ? res.data : []);
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'message' in e
          ? String((e as { message?: string }).message || '')
          : '';
      setError(msg || 'İstatistik alınamadı');
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const ok = requireRole(['HUNTER']);
    setAllowed(ok);
    if (ok) load();
  }, [load]);

  const total = rows.length;
  const open = rows.filter((r) => String(r.status || '').toUpperCase() === 'OPEN').length;
  const inProgress = rows.filter((r) => String(r.status || '').toUpperCase() === 'IN_PROGRESS').length;
  const completed = rows.filter((r) => String(r.status || '').toUpperCase() === 'COMPLETED').length;

  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="HUNTER"
      title="İş Ortağı Komuta Ekranı"
      subtitle="Lead üretimi, takip ve dönüşüm akışını tek merkezde yönet."
      nav={[
        { href: '/hunter', label: 'Panel' },
        { href: '/hunter/leads', label: 'Leadlerim' },
        { href: '/hunter/leads/new', label: 'Yeni Lead' },
      ]}
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(170px,1fr))', gap: 10, marginBottom: 12 }}>
        <KpiCard label="Toplam Lead" value={total} loading={loading} />
        <KpiCard label="Açık Lead" value={open} loading={loading} />
        <KpiCard label="İşlemde" value={inProgress} loading={loading} />
        <KpiCard label="Tamamlanan" value={completed} loading={loading} />
      </div>
      {error ? <div style={{ marginBottom: 12, color: 'crimson' }}>{error}</div> : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(320px,1fr))', gap: 12 }}>
        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <div>
              <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Operasyon Kuyruğu</h2>
              <p style={{ margin: '6px 0 0', fontSize: 13, color: '#6f665c' }}>Yeni lead gönder, durumları izle, broker dönüşünü hızlandır.</p>
            </div>
            <span style={{ fontSize: 12, borderRadius: 999, border: '1px solid #e5ded1', background: '#f8f3ec', color: '#7a6f62', padding: '3px 9px' }}>
              Hedef: Düzenli giriş
            </span>
          </div>

          <div style={{ marginTop: 14, display: 'grid', gap: 10 }}>
            <QueueRow title="Yeni lead oluştur" note="Detaylı ve temiz lead notu bırak." ctaHref="/hunter/leads/new" ctaLabel="Yeni Lead" />
            <QueueRow title="Gönderilen lead durumlarını kontrol et" note="Açık / işlemde / tamamlandı takibi." ctaHref="/hunter/leads" ctaLabel="Leadlerim" />
            <QueueRow title="Düşük dönüşümde input kalitesini artır" note="Konum ve ihtiyaç bilgisini net gir." ctaHref="/hunter/leads/new" ctaLabel="Lead Kalitesi" />
          </div>
        </section>

        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Hızlı Aksiyonlar</h2>
          <p style={{ margin: '6px 0 12px', fontSize: 13, color: '#6f665c' }}>Günlük çalışma kısayolları.</p>
          <div style={{ display: 'grid', gap: 8 }}>
            <QuickAction href="/hunter/leads/new" label="Hemen lead gönder" />
            <QuickAction href="/hunter/leads" label="Leadlerimi aç" />
          </div>
        </section>
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <StatusCard title="Tamamlanma Oranı" value={computeRate(completed, total)} hint="Tamamlanan / Toplam Lead" />
        <StatusCard title="Aktif Takip" value={computeRate(open + inProgress, total)} hint="Açık+İşlemde / Toplam" />
        <StatusCard title="Operasyon Durumu" value="Aktif" hint="Lead gönderim hattı açık" />
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <Link href="/hunter/leads/new" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Lead Gönder</div>
          <div style={linkNoteStyle}>Yeni müşteri talebi oluştur.</div>
        </Link>
        <Link href="/hunter/leads" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Leadlerimi Gör</div>
          <div style={linkNoteStyle}>Gönderilen kayıtların durumunu izle.</div>
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

function computeRate(part: number, total: number) {
  if (!total) return '%0';
  return `%${Math.round((part / total) * 100)}`;
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
