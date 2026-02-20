'use client';

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { requireRole } from '@/lib/auth';
import { api } from '@/lib/api';
import { Badge } from '@/src/ui/components/Badge';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';

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
      const msg = e && typeof e === 'object' && 'message' in e ? String((e as { message?: string }).message || '') : '';
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
      <main className="mx-auto max-w-5xl p-6 opacity-80">
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="HUNTER"
      title="İş Ortağı Komuta Ekranı"
      subtitle="Referans üretimi, takip ve dönüşüm akışını tek merkezde yönet."
      nav={[
        { href: '/hunter', label: 'Panel' },
        { href: '/hunter/leads', label: 'Referanslarım' },
        { href: '/hunter/leads/new', label: 'Yeni Referans' },
      ]}
    >
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <KpiCard label="Toplam Referans" value={total} loading={loading} />
        <KpiCard label="Açık Referans" value={open} loading={loading} />
        <KpiCard label="İşlemde" value={inProgress} loading={loading} />
        <KpiCard label="Tamamlanan" value={completed} loading={loading} />
      </div>

      {error ? <div className="mt-3 rounded-xl border border-[color-mix(in_srgb,var(--danger)_40%,transparent)] bg-[color-mix(in_srgb,var(--danger)_10%,transparent)] px-3 py-2 text-sm text-[var(--danger)]">{error}</div> : null}

      <div className="mt-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
        <Card>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <CardTitle>Operasyon Kuyruğu</CardTitle>
              <CardDescription>Yeni referans gönder, durumları izle, broker dönüşünü hızlandır.</CardDescription>
            </div>
            <Badge variant="warning">Hedef: Düzenli giriş</Badge>
          </div>

          <div className="mt-4 grid gap-2.5">
            <QueueRow title="Yeni referans oluştur" note="Detaylı ve temiz referans notu bırak." ctaHref="/hunter/leads/new" ctaLabel="Yeni Referans" />
            <QueueRow title="Gönderilen referans durumlarını kontrol et" note="Açık / işlemde / tamamlandı takibi." ctaHref="/hunter/leads" ctaLabel="Referanslarım" />
            <QueueRow title="Düşük dönüşümde input kalitesini artır" note="Konum ve ihtiyaç bilgisini net gir." ctaHref="/hunter/leads/new" ctaLabel="Referans Kalitesi" />
          </div>
        </Card>

        <Card>
          <CardTitle>Hızlı Aksiyonlar</CardTitle>
          <CardDescription>Günlük çalışma kısayolları.</CardDescription>
          <div className="mt-4 grid gap-2">
            <QuickAction href="/hunter/leads/new" label="Hemen referans gönder" />
            <QuickAction href="/hunter/leads" label="Referanslarımı aç" />
          </div>
        </Card>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 lg:grid-cols-3">
        <StatusCard title="Tamamlanma Oranı" value={computeRate(completed, total)} hint="Tamamlanan / Toplam Referans" />
        <StatusCard title="Aktif Takip" value={computeRate(open + inProgress, total)} hint="Açık+İşlemde / Toplam" />
        <StatusCard title="Operasyon Durumu" value="Aktif" hint="Referans gönderim hattı açık" />
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Link href="/hunter/leads/new" className={linkCardClass}>
          <div className="font-semibold">Referans Gönder</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Yeni müşteri talebi oluştur.</div>
        </Link>
        <Link href="/hunter/leads" className={linkCardClass}>
          <div className="font-semibold">Referanslarımı Gör</div>
          <div className="mt-1 text-xs text-[var(--muted)]">Gönderilen kayıtların durumunu izle.</div>
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

function computeRate(part: number, total: number) {
  if (!total) return '%0';
  return `%${Math.round((part / total) * 100)}`;
}

const linkCardClass = 'rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 text-[var(--text)] transition-colors hover:border-[var(--border-2)]';
