'use client';

import React from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import PerformancePageShell from '../../_components/PerformancePageShell';
import DataTable from '../../_components/DataTable';
import ErrorBanner from '../../_components/ErrorBanner';
import EmptyState from '../../_components/EmptyState';
import KpiCardsGrid from '../../_components/KpiCardsGrid';
import { formatMoney, formatNumber, getRangeFromSearch, toRate } from '../../_components/performance-utils';

type Row = {
  consultantId: string;
  name: string;
  dealsWonCount: number;
  revenueSum: number;
  avgCommission: number;
  conversionRate: number;
  avgCloseDays: number;
};

type Payload = { rows: Row[] };

export default function LeaderboardConsultantsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [rows, setRows] = React.useState<Row[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const { from, to } = getRangeFromSearch(searchParams);
    let mounted = true;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const res = await api.get<Payload>('/admin/performance/leaderboard/consultants', { params: { from, to } });
        if (mounted) {
          const sorted = [...(res.data.rows || [])].sort((a, b) => (b.revenueSum === a.revenueSum ? b.dealsWonCount - a.dealsWonCount : b.revenueSum - a.revenueSum));
          setRows(sorted);
        }
      } catch {
        if (mounted) {
          setRows([]);
          setError('Danışman sıralama verisi alınamadı.');
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }
    load();
    return () => { mounted = false; };
  }, [searchParams]);

  const totalRevenue = rows.reduce((sum, row) => sum + Number(row.revenueSum || 0), 0);
  const totalWon = rows.reduce((sum, row) => sum + Number(row.dealsWonCount || 0), 0);

  return (
    <PerformancePageShell title="Liderlik / Danışmanlar" subtitle="Danışman performans sıralaması.">
      {error ? <ErrorBanner message={error} /> : null}
      <KpiCardsGrid
        items={[
          { label: 'Toplam Danışman', value: loading ? '…' : formatNumber(rows.length) },
          { label: 'Toplam Ciro', value: loading ? '…' : formatMoney(totalRevenue) },
          { label: 'Toplam Kapanan İşlem', value: loading ? '…' : formatNumber(totalWon) },
        ]}
      />
      {rows.length === 0 ? (
        <EmptyState title="Danışman sıralama boş" />
      ) : (
        <DataTable
          title="Danışmanlar"
          rows={rows}
          columns={[
            { key: 'name', label: 'Danışman', sortable: true },
            { key: 'dealsWonCount', label: 'Kapanan', sortable: true },
            { key: 'revenueSum', label: 'Ciro', sortable: true, render: (r) => formatMoney(Number(r.revenueSum)) },
            { key: 'avgCommission', label: 'Ort. Komisyon', sortable: true, render: (r) => formatMoney(Number(r.avgCommission)) },
            { key: 'conversionRate', label: 'Dönüşüm', sortable: true, render: (r) => toRate(Number(r.conversionRate)) },
            { key: 'avgCloseDays', label: 'Ort. Kapanış Gün', sortable: true, render: (r) => Number(r.avgCloseDays || 0).toFixed(1) },
          ]}
          onRowClick={(row) => router.push(`/admin/performance/consultants/${String(row.consultantId)}`)}
          searchPlaceholder="Danışman ara..."
        />
      )}
    </PerformancePageShell>
  );
}
