'use client';

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { api } from '@/lib/api';
import { Badge } from '@/src/ui/components/Badge';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';

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
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <KpiCard label="Açık Deal" value={stats?.dealsMineOpen ?? 0} loading={statsLoading} />
        <KpiCard label="İlana Hazır" value={stats?.dealsReadyForListing ?? 0} loading={statsLoading} />
        <KpiCard label="Taslak İlan" value={stats?.listingsDraft ?? 0} loading={statsLoading} />
        <KpiCard label="Yayındaki İlan" value={stats?.listingsPublished ?? 0} loading={statsLoading} />
      </div>

      {statsErr ? <div className="mt-3 rounded-xl border border-[color-mix(in_srgb,var(--danger)_40%,transparent)] bg-[color-mix(in_srgb,var(--danger)_10%,transparent)] px-3 py-2 text-sm text-[var(--danger)]">{statsErr}</div> : null}

      <div className="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <CardTitle>Operasyon Kuyruğu</CardTitle>
              <CardDescription>Gelen deal’leri ilana dönüştür ve yayın döngüsünü hızlandır.</CardDescription>
            </div>
            <Badge variant="warning">Hedef: Hızlı yayın</Badge>
          </div>

          <div className="mt-4 grid gap-2.5">
            <QueueRow title="Gelen kutusundaki atamaları temizle" note="Önce deal sahiplen, sonra listing üret." ctaHref="/consultant/inbox" ctaLabel="Gelen Kutusu" />
            <QueueRow title="İlana hazır deal’leri yayınla" note="Taslakları tamamlayıp yayına al." ctaHref="/consultant/listings" ctaLabel="İlanlar" />
            <QueueRow title="Eksik içerik ve fiyat girişini tamamla" note="İlan kalite puanını yükselt." ctaHref="/consultant/listings" ctaLabel="Taslaklar" />
          </div>
        </Card>

        <Card>
          <CardTitle>Hızlı Aksiyonlar</CardTitle>
          <CardDescription>Danışman günlük çalışma kısayolları.</CardDescription>
          <div className="mt-4 grid gap-2">
            <QuickAction href="/consultant/inbox" label="Gelen kutusunu aç" />
            <QuickAction href="/consultant/listings" label="İlanları yönet" />
            <QuickAction href="/consultant/listings?status=DRAFT" label="Taslakları düzenle" />
          </div>
        </Card>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 lg:grid-cols-3">
        <StatusCard title="Listing Hazırlık Oranı" value={computeReadiness(stats?.dealsReadyForListing ?? 0, stats?.dealsMineOpen ?? 0)} hint="Hazır Deal / Açık Deal" />
        <StatusCard title="Yayın Performansı" value={computePublish(stats?.listingsPublished ?? 0, stats?.listingsDraft ?? 0)} hint="Yayında / Taslak" />
        <StatusCard title="Operasyon Durumu" value="Aktif" hint="Inbox ve listing akışı açık" />
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Link href="/consultant/inbox" className={linkCardClass}>
          <div className="font-semibold">Gelen Kutusu</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Atanan deal akışını yönet.</div>
        </Link>
        <Link href="/consultant/listings" className={linkCardClass}>
          <div className="font-semibold">İlanlarım</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Taslak ve yayındaki ilanları düzenle.</div>
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

function computeReadiness(ready: number, open: number) {
  if (!open) return '%0';
  return `%${Math.round((ready / open) * 100)}`;
}

function computePublish(published: number, draft: number) {
  const total = published + draft;
  if (!total) return '%0';
  return `%${Math.round((published / total) * 100)}`;
}

const linkCardClass = 'rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 text-[var(--text)] transition-colors hover:border-[var(--border-2)]';
