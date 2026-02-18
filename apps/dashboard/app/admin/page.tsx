'use client';

import React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { api } from '@/lib/api';
import { requireRole } from '@/lib/auth';
import { Badge } from '@/src/ui/components/Badge';
import { Button } from '@/src/ui/components/Button';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Select } from '@/src/ui/components/Select';

type AdminStats = {
  role: 'ADMIN';
  usersTotal: number;
  leadsTotal: number;
  dealsTotal: number;
  listingsTotal: number;
};

export default function AdminHomePage() {
  const router = useRouter();
  const [allowed, setAllowed] = React.useState(false);
  const [stats, setStats] = React.useState<AdminStats | null>(null);
  const [statsLoading, setStatsLoading] = React.useState(true);
  const [statsErr, setStatsErr] = React.useState<string | null>(null);
  const [targetRole, setTargetRole] = React.useState<'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER'>('ADMIN');

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
        const [perfRes, usersRes] = await Promise.all([
          api.get<{
            totalLeads?: number;
            totalDealsWon?: number;
            totalPortfolio?: number;
          }>('/admin/performance/overview'),
          api.get<Array<{ id: string }>>('/api/admin/users'),
        ]);
        if (!mounted) return;

        setStats({
          role: 'ADMIN',
          usersTotal: Array.isArray(usersRes.data) ? usersRes.data.length : 0,
          leadsTotal: Number(perfRes.data?.totalLeads || 0),
          dealsTotal: Number(perfRes.data?.totalDealsWon || 0),
          listingsTotal: Number(perfRes.data?.totalPortfolio || 0),
        });
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
      <main className="mx-auto max-w-5xl p-6 opacity-80">
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="ADMIN"
      title="Admin Komuta Ekranı"
      subtitle="Lead akışı, ekip operasyonu ve kritik aksiyonlar tek ekranda."
      headerControls={
        <div className="flex min-w-0 items-center gap-2">
          <Select
            value={targetRole}
            onChange={(e) => setTargetRole(e.target.value as 'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER')}
            uiSize="sm"
            className="min-w-0 rounded-md md:h-9 md:w-[138px] md:px-3 md:text-sm"
            aria-label="Rol seç"
          >
            <option value="ADMIN">Admin</option>
            <option value="BROKER">Broker</option>
            <option value="CONSULTANT">Danışman</option>
            <option value="HUNTER">İş Ortağı</option>
          </Select>
          <Button type="button" size="sm" className="rounded-md md:h-9 md:text-sm" onClick={() => router.push(roleRoute(targetRole))}>
            Aç
          </Button>
        </div>
      }
      nav={[
        { href: '/admin', label: 'Panel' },
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/audit', label: 'Denetim' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <KpiCard label="Toplam Kullanıcı" value={stats?.usersTotal ?? 0} loading={statsLoading} />
        <KpiCard label="Toplam Lead" value={stats?.leadsTotal ?? 0} loading={statsLoading} />
        <KpiCard label="Toplam Deal" value={stats?.dealsTotal ?? 0} loading={statsLoading} />
        <KpiCard label="Toplam İlan" value={stats?.listingsTotal ?? 0} loading={statsLoading} />
      </div>

      {statsErr ? <AlertMessage type="error" message={statsErr} /> : null}

      <div className="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <CardTitle>Operasyon Kuyruğu</CardTitle>
              <CardDescription>Günlük kritik iş listesi ve hızlı yönlendirmeler.</CardDescription>
            </div>
            <Badge variant="warning">Öncelik: Orta</Badge>
          </div>
          <div className="mt-4 grid gap-2.5">
            <QueueRow title="Onay bekleyen iş ortağı başvuruları" note="İş ortağı ekranına erişim için rol atamalarını doğrula." ctaHref="/admin/onboarding" ctaLabel="Uyum Süreci" />
            <QueueRow title="Rol değişikliği talepleri" note="Kullanıcı rol güncellemeleri ve parola yenilemeleri." ctaHref="/admin/users" ctaLabel="Kullanıcılar" />
            <QueueRow title="Denetim kayıtlarında son 24 saat" note="Kritik aksiyonlar ve başarısız işlemler." ctaHref="/admin/audit" ctaLabel="Denetim" />
          </div>
        </Card>

        <Card>
          <CardTitle>Hızlı Aksiyonlar</CardTitle>
          <CardDescription>En sık yapılan yönetim işlemleri.</CardDescription>
          <div className="mt-4 grid gap-2">
            <QuickAction href="/admin/users" label="Yeni kullanıcı oluştur / rol değiştir" />
            <QuickAction href="/admin/onboarding" label="Başvuru durumlarını güncelle" />
            <QuickAction href="/admin/commission" label="Komisyon dağılımını düzenle" />
            <QuickAction href="/admin/audit" label="İşlem loglarını incele" />
          </div>
        </Card>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 lg:grid-cols-3">
        <StatusCard title="Dönüşüm Sağlığı" value={computeConversion(stats?.dealsTotal ?? 0, stats?.leadsTotal ?? 0)} hint="Deal / Lead" />
        <StatusCard title="Portföy Yoğunluğu" value={computeDensity(stats?.listingsTotal ?? 0, stats?.usersTotal ?? 0)} hint="İlan / Kullanıcı" />
        <StatusCard title="Operasyon Durumu" value="Stabil" hint="API ve panel erişimi aktif" />
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Link href="/admin/users" className={linkCardClass}>
          <div className="font-semibold">Kullanıcı Yönetimi</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Rol, aktif/pasif ve kullanıcı düzenlemeleri.</div>
        </Link>
        <Link href="/admin/onboarding" className={linkCardClass}>
          <div className="font-semibold">Uyum Süreci</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Rol bazlı onboarding ilerlemesini görüntüle.</div>
        </Link>
        <Link href="/admin/audit" className={linkCardClass}>
          <div className="font-semibold">Denetim Kayıtları</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Aksiyonları ham ve kanonik alanlarla incele.</div>
        </Link>
        <Link href="/admin/commission" className={linkCardClass}>
          <div className="font-semibold">Komisyon Ayarları</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Temel komisyon oranı ve dağılım yüzdeleri.</div>
        </Link>
      </div>
    </RoleShell>
  );
}

function KpiCard({ label, value, loading }: { label: string; value: number; loading: boolean }) {
  return (
    <Card className="p-4">
      <div className="text-xs text-[var(--muted)]">{label}</div>
      <div className="mt-1 text-[clamp(22px,5vw,28px)] font-semibold leading-none text-[var(--text)]">{loading ? '…' : value}</div>
    </Card>
  );
}

function QueueRow({ title, note, ctaHref, ctaLabel }: { title: string; note: string; ctaHref: string; ctaLabel: string }) {
  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--card-2)] p-3">
      <div className="text-sm font-medium text-[var(--text)]">{title}</div>
      <div className="mt-1 text-xs text-[var(--muted)]">{note}</div>
      <div className="mt-2">
        <Link href={ctaHref} className="text-xs text-[var(--primary)] hover:underline">
          {ctaLabel}
        </Link>
      </div>
    </div>
  );
}

function QuickAction({ href, label }: { href: string; label: string }) {
  return (
    <Link href={href} className="rounded-xl border border-[var(--border)] bg-[var(--card-2)] px-3 py-2 text-sm text-[var(--text)] transition-colors hover:border-[var(--border-2)]">
      {label}
    </Link>
  );
}

function StatusCard({ title, value, hint }: { title: string; value: string; hint: string }) {
  return (
    <Card className="p-4">
      <div className="text-xs text-[var(--muted)]">{title}</div>
      <div className="mt-1 text-xl font-semibold text-[var(--text)]">{value}</div>
      <div className="mt-1 text-xs text-[var(--muted-2)]">{hint}</div>
    </Card>
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

function roleRoute(role: 'ADMIN' | 'BROKER' | 'CONSULTANT' | 'HUNTER') {
  if (role === 'BROKER') return '/broker';
  if (role === 'CONSULTANT') return '/consultant';
  if (role === 'HUNTER') return '/hunter';
  return '/admin';
}

const linkCardClass = 'rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 text-[var(--text)] transition-colors hover:border-[var(--border-2)]';
