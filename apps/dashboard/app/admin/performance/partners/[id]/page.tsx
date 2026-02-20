'use client';

import React from 'react';
import Link from 'next/link';
import { useParams, useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import PerformancePageShell from '../../_components/PerformancePageShell';
import KpiCardsGrid from '../../_components/KpiCardsGrid';
import DataTable from '../../_components/DataTable';
import ErrorBanner from '../../_components/ErrorBanner';
import { formatMoney, formatNumber, getRangeFromSearch } from '../../_components/performance-utils';

type Activity = { id: string; status: string; updatedAt: string };
type Payload = {
  id: string;
  name: string;
  role: string;
  kpis: { refCount?: number; portfolioCount?: number; salesCount?: number; revenueAttributedSum?: number };
  recentActivities: Activity[];
};

export default function PartnerPerformanceDetailPage() {
  const params = useParams<{ id: string }>();
  const searchParams = useSearchParams();
  const [data, setData] = React.useState<Payload | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const { from, to, city } = getRangeFromSearch(searchParams);
    let mounted = true;
    async function load() {
      setError(null);
      try {
        const res = await api.get<Payload>(`/admin/performance/partners/${params.id}`, { params: { from, to, city: city || undefined } });
        if (mounted) setData(res.data);
      } catch {
        if (mounted) {
          setError('İş ortağı detay verisi alınamadı.');
          setData({ id: params.id, name: 'Bilinmiyor', role: 'HUNTER', kpis: {}, recentActivities: [] });
        }
      }
    }
    load();
    return () => { mounted = false; };
  }, [params.id, searchParams]);

  const d = data || { id: params.id, name: 'Yükleniyor...', role: 'HUNTER', kpis: {}, recentActivities: [] };

  return (
    <PerformancePageShell title={`İş Ortağı Detay / ${d.name}`} subtitle="Referans ve dönüşüm aktiviteleri">
      {error ? <ErrorBanner message={error} /> : null}
      <div className="mb-2">
        <Link href="/admin/performance/leaderboard/partners" className="text-xs text-[var(--primary)] hover:underline">← İş ortağı sıralaması</Link>
      </div>
      <KpiCardsGrid
        items={[
          { label: 'Referans', value: formatNumber(Number(d.kpis.refCount || 0)) },
          { label: 'Portföy', value: formatNumber(Number(d.kpis.portfolioCount || 0)) },
          { label: 'Satış', value: formatNumber(Number(d.kpis.salesCount || 0)) },
          { label: 'Atfedilen Ciro', value: formatMoney(Number(d.kpis.revenueAttributedSum || 0)) },
        ]}
      />
      <DataTable
        title="Son Aktiviteler"
        rows={d.recentActivities}
        columns={[
          { key: 'id', label: 'Referans ID' },
          { key: 'status', label: 'Durum', sortable: true },
          { key: 'updatedAt', label: 'Güncelleme', sortable: true, render: (r) => new Date(String(r.updatedAt)).toLocaleString('tr-TR') },
        ]}
      />
    </PerformancePageShell>
  );
}
