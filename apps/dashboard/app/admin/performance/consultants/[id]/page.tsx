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

type Activity = { id: string; status: string; updatedAt: string; location?: string };
type Payload = {
  id: string;
  name: string;
  role: string;
  kpis: { portfolioCount?: number; dealsWonCount?: number; revenueSum?: number };
  recentActivities: Activity[];
};

export default function ConsultantPerformanceDetailPage() {
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
        const res = await api.get<Payload>(`/admin/performance/consultants/${params.id}`, { params: { from, to, city: city || undefined } });
        if (mounted) setData(res.data);
      } catch {
        if (mounted) {
          setError('Danışman detay verisi alınamadı.');
          setData({ id: params.id, name: 'Bilinmiyor', role: 'CONSULTANT', kpis: {}, recentActivities: [] });
        }
      }
    }
    load();
    return () => { mounted = false; };
  }, [params.id, searchParams]);

  const d = data || { id: params.id, name: 'Yükleniyor...', role: 'CONSULTANT', kpis: {}, recentActivities: [] };

  return (
    <PerformancePageShell title={`Danışman Detay / ${d.name}`} subtitle="KPI ve son aktiviteler">
      {error ? <ErrorBanner message={error} /> : null}
      <div className="mb-2">
        <Link href="/admin/performance/leaderboard/consultants" className="text-xs text-[var(--primary)] hover:underline">← Danışman sıralaması</Link>
      </div>
      <KpiCardsGrid
        items={[
          { label: 'Portföy', value: formatNumber(Number(d.kpis.portfolioCount || 0)) },
          { label: 'Kapanan İşlem', value: formatNumber(Number(d.kpis.dealsWonCount || 0)) },
          { label: 'Ciro', value: formatMoney(Number(d.kpis.revenueSum || 0)) },
        ]}
      />
      <DataTable
        title="Son Aktiviteler"
        rows={d.recentActivities}
        columns={[
          { key: 'id', label: 'Kayıt ID' },
          { key: 'status', label: 'Durum', sortable: true },
          { key: 'location', label: 'Lokasyon' },
          { key: 'updatedAt', label: 'Güncelleme', sortable: true, render: (r) => new Date(String(r.updatedAt)).toLocaleString('tr-TR') },
        ]}
      />
    </PerformancePageShell>
  );
}
