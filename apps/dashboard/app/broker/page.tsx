'use client';

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { api } from '@/lib/api';
import { Badge } from '@/src/ui/components/Badge';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';

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
      subtitle="Referans onayı, işlem üretimi ve iş ortağı operasyonu tek merkezde."
      nav={[
        { href: '/broker', label: 'Panel' },
        { href: '/broker/leads/pending', label: 'Bekleyen Referanslar' },
        { href: '/broker/deals/new', label: 'Yeni İşlem' },
        { href: '/broker/hunter-applications', label: 'İş Ortağı Başvuruları' },
      ]}
    >
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <KpiCard label="Bekleyen Referans" value={stats?.leadsPending ?? 0} loading={statsLoading} />
        <KpiCard label="Onaylı Referans" value={stats?.leadsApproved ?? 0} loading={statsLoading} />
        <KpiCard label="Oluşan İşlem" value={stats?.dealsCreated ?? 0} loading={statsLoading} />
        <KpiCard label="Onay Oranı" value={computeApproval(stats?.leadsApproved ?? 0, stats?.leadsPending ?? 0)} loading={statsLoading} />
      </div>

      {statsErr ? <div className="mt-3 rounded-xl border border-[color-mix(in_srgb,var(--danger)_40%,transparent)] bg-[color-mix(in_srgb,var(--danger)_10%,transparent)] px-3 py-2 text-sm text-[var(--danger)]">{statsErr}</div> : null}

      <div className="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <CardTitle>Operasyon Kuyruğu</CardTitle>
              <CardDescription>Anlık onay, işlem ve başvuru iş akışı.</CardDescription>
            </div>
            <Badge variant="warning">Hedef: Hızlı dönüş</Badge>
          </div>
          <div className="mt-4 grid gap-2.5">
            <QueueRow title="Bekleyen referansları onayla / reddet" note="Pipeline akışını güncel tut." ctaHref="/broker/leads/pending" ctaLabel="Referans Kuyruğu" />
            <QueueRow title="İşlem oluştur ve danışmana devret" note="Referanstan işleme geçiş süresini kısalt." ctaHref="/broker/deals/new" ctaLabel="Yeni İşlem" />
            <QueueRow title="İş ortağı başvurularını değerlendir" note="Ağa yeni iş ortağı ekleme kalitesini artır." ctaHref="/broker/hunter-applications" ctaLabel="Başvurular" />
          </div>
        </Card>

        <Card>
          <CardTitle>Hızlı Aksiyonlar</CardTitle>
          <CardDescription>Broker günlük akış kısayolları.</CardDescription>
          <div className="mt-4 grid gap-2">
            <QuickAction href="/broker/leads/pending" label="Bekleyen referans listesini aç" />
            <QuickAction href="/broker/deals/new" label="Yeni işlem oluştur" />
            <QuickAction href="/broker/hunter-applications" label="İş ortağı başvurularını incele" />
          </div>
        </Card>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 lg:grid-cols-3">
        <StatusCard title="Dönüşüm Sağlığı" value={computePipeline(stats?.dealsCreated ?? 0, stats?.leadsApproved ?? 0)} hint="İşlem / Onaylı Referans" />
        <StatusCard title="İnceleme Hızı" value={statsLoading ? '…' : (stats?.leadsPending ?? 0) > 20 ? 'Dikkat' : 'İyi'} hint="Bekleyen referans yoğunluğu" />
        <StatusCard title="Ağ Operasyonu" value="Aktif" hint="İş ortağı başvuru değerlendirme açık" />
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <Link href="/broker/leads/pending" className={linkCardClass}>
          <div className="font-semibold">Referans Kuyruğu</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Onay bekleyen referansları aç.</div>
        </Link>
        <Link href="/broker/deals/new" className={linkCardClass}>
          <div className="font-semibold">İşlem Oluştur</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Manuel işlem oluşturma akışı.</div>
        </Link>
        <Link href="/broker/hunter-applications" className={linkCardClass}>
          <div className="font-semibold">İş Ortağı Başvuruları</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Ağ başvurularını gözden geçir.</div>
        </Link>
      </div>
    </RoleShell>
  );
}

function KpiCard({ label, value, loading }: { label: string; value: number | string; loading: boolean }) {
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

function computeApproval(approved: number, pending: number) {
  const total = approved + pending;
  if (!total) return '%0';
  return `%${Math.round((approved / total) * 100)}`;
}

function computePipeline(deals: number, approvedLeads: number) {
  if (!approvedLeads) return '%0';
  return `%${Math.round((deals / approvedLeads) * 100)}`;
}

const linkCardClass = 'rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 text-[var(--text)] transition-colors hover:border-[var(--border-2)]';
