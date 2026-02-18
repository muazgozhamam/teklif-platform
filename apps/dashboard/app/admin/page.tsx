'use client';

import React from 'react';
import Link from 'next/link';
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
      title="Admin Komuta Ekranı"
      subtitle="Lead akışı, ekip operasyonu ve kritik aksiyonlar tek ekranda."
      nav={[
        { href: '/admin', label: 'Panel' },
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/audit', label: 'Denetim' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 10, marginBottom: 12 }}>
        <KpiCard label="Toplam Kullanıcı" value={stats?.usersTotal ?? 0} loading={statsLoading} />
        <KpiCard label="Toplam Lead" value={stats?.leadsTotal ?? 0} loading={statsLoading} />
        <KpiCard label="Toplam Deal" value={stats?.dealsTotal ?? 0} loading={statsLoading} />
        <KpiCard label="Toplam İlan" value={stats?.listingsTotal ?? 0} loading={statsLoading} />
      </div>
      {statsErr ? <AlertMessage type="error" message={statsErr} /> : null}

      <div style={{ display: 'grid', gridTemplateColumns: '1.45fr 1fr', gap: 12 }}>
        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <div>
              <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Operasyon Kuyruğu</h2>
              <p style={{ margin: '6px 0 0', fontSize: 13, color: '#6f665c' }}>Günlük kritik iş listesi ve hızlı yönlendirmeler.</p>
            </div>
            <span style={{ fontSize: 12, borderRadius: 999, border: '1px solid #e5ded1', background: '#f8f3ec', color: '#7a6f62', padding: '3px 9px' }}>
              Öncelik: Orta
            </span>
          </div>

          <div style={{ marginTop: 14, display: 'grid', gap: 10 }}>
            <QueueRow title="Onay bekleyen iş ortağı başvuruları" note="Hunter ekranına erişim için rol atamalarını doğrula." ctaHref="/admin/onboarding" ctaLabel="Uyum Süreci" />
            <QueueRow title="Rol değişikliği talepleri" note="Kullanıcı rol güncellemeleri ve parola yenilemeleri." ctaHref="/admin/users" ctaLabel="Kullanıcılar" />
            <QueueRow title="Denetim kayıtlarında son 24 saat" note="Kritik aksiyonlar ve başarısız işlemler." ctaHref="/admin/audit" ctaLabel="Denetim" />
          </div>
        </section>

        <section style={{ border: '1px solid #e2dbd1', borderRadius: 16, padding: 16, background: '#fff' }}>
          <h2 style={{ margin: 0, fontSize: 18, color: '#1f1b16' }}>Hızlı Aksiyonlar</h2>
          <p style={{ margin: '6px 0 12px', fontSize: 13, color: '#6f665c' }}>En sık yapılan yönetim işlemleri.</p>
          <div style={{ display: 'grid', gap: 8 }}>
            <QuickAction href="/admin/users" label="Yeni kullanıcı oluştur / rol değiştir" />
            <QuickAction href="/admin/onboarding" label="Başvuru durumlarını güncelle" />
            <QuickAction href="/admin/commission" label="Komisyon dağılımını düzenle" />
            <QuickAction href="/admin/audit" label="İşlem loglarını incele" />
          </div>
        </section>
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <StatusCard
          title="Dönüşüm Sağlığı"
          value={computeConversion(stats?.dealsTotal ?? 0, stats?.leadsTotal ?? 0)}
          hint="Deal / Lead"
        />
        <StatusCard
          title="Portföy Yoğunluğu"
          value={computeDensity(stats?.listingsTotal ?? 0, stats?.usersTotal ?? 0)}
          hint="İlan / Kullanıcı"
        />
        <StatusCard
          title="Operasyon Durumu"
          value="Stabil"
          hint="API ve panel erişimi aktif"
        />
      </div>

      <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 12 }}>
        <Link href="/admin/users" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Kullanıcı Yönetimi</div>
          <div style={linkNoteStyle}>Rol, aktif/pasif ve kullanıcı düzenlemeleri.</div>
        </Link>
        <Link href="/admin/onboarding" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Uyum Süreci</div>
          <div style={linkNoteStyle}>Rol bazlı onboarding ilerlemesini görüntüle.</div>
        </Link>
        <Link href="/admin/audit" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Denetim Kayıtları</div>
          <div style={linkNoteStyle}>Aksiyonları ham ve kanonik alanlarla incele.</div>
        </Link>
        <Link href="/admin/commission" style={linkCardStyle}>
          <div style={{ fontWeight: 700 }}>Komisyon Ayarları</div>
          <div style={linkNoteStyle}>Temel komisyon oranı ve dağılım yüzdeleri.</div>
        </Link>
      </div>
    </RoleShell>
  );
}

function KpiCard({ label, value, loading }: { label: string; value: number; loading: boolean }) {
  return (
    <div style={{ border: '1px solid #eee', borderRadius: 12, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 26, fontWeight: 800, minHeight: 36 }}>{loading ? '…' : value}</div>
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

function computeConversion(deals: number, leads: number) {
  if (!leads) return '%0';
  return `%${Math.round((deals / leads) * 100)}`;
}

function computeDensity(listings: number, users: number) {
  if (!users) return '0.00';
  return (listings / users).toFixed(2);
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
