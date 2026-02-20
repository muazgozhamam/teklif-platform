'use client';

import React from 'react';
import { useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import PerformancePageShell from '../../_components/PerformancePageShell';
import KpiCardsGrid from '../../_components/KpiCardsGrid';
import DataTable from '../../_components/DataTable';
import EmptyState from '../../_components/EmptyState';
import ErrorBanner from '../../_components/ErrorBanner';
import { formatMoney, formatNumber, getRangeFromSearch } from '../../_components/performance-utils';

type RevenueByDay = { date: string; amount: number };
type RevenueByConsultant = { consultantId: string; name: string; amount: number };
type Payload = { revenueSum: number; revenueByDay: RevenueByDay[]; revenueByConsultant: RevenueByConsultant[] };

export default function FinanceRevenuePage() {
  const searchParams = useSearchParams();
  const [data, setData] = React.useState<Payload | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const { from, to } = getRangeFromSearch(searchParams);
    let mounted = true;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const res = await api.get<Payload>('/admin/performance/finance/revenue', { params: { from, to } });
        if (mounted) setData(res.data);
      } catch {
        if (mounted) {
          setError('Ciro verisi alınamadı.');
          setData({ revenueSum: 0, revenueByDay: [], revenueByConsultant: [] });
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }
    load();
    return () => { mounted = false; };
  }, [searchParams]);

  const d = data || { revenueSum: 0, revenueByDay: [], revenueByConsultant: [] };

  return (
    <PerformancePageShell title="Ciro Analizi" subtitle="Ciro dağılımını ve danışman bazlı kırılımı görün.">
      {error ? <ErrorBanner message={error} /> : null}
      <KpiCardsGrid
        items={[
          { label: 'Toplam Ciro', value: loading ? '…' : formatMoney(d.revenueSum) },
          { label: 'Günlük Kayıt', value: loading ? '…' : formatNumber(d.revenueByDay.length) },
          { label: 'Danışman Kırılımı', value: loading ? '…' : formatNumber(d.revenueByConsultant.length) },
        ]}
      />
      {d.revenueByDay.length === 0 ? (
        <EmptyState title="Günlük ciro verisi yok" />
      ) : (
        <DataTable
          title="Günlük Ciro"
          rows={d.revenueByDay}
          columns={[
            { key: 'date', label: 'Tarih', sortable: true },
            { key: 'amount', label: 'Tutar', sortable: true, render: (r) => formatMoney(Number(r.amount)) },
          ]}
        />
      )}
      {d.revenueByConsultant.length === 0 ? (
        <EmptyState title="Danışman bazlı ciro bulunamadı" />
      ) : (
        <DataTable
          title="Danışman Bazlı Ciro (Top 10)"
          rows={d.revenueByConsultant}
          columns={[
            { key: 'name', label: 'Danışman', sortable: true },
            { key: 'amount', label: 'Ciro', sortable: true, render: (r) => formatMoney(Number(r.amount)) },
          ]}
        />
      )}
    </PerformancePageShell>
  );
}
