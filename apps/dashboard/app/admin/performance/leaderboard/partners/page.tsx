'use client';

import React from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import PerformancePageShell from '../../_components/PerformancePageShell';
import KpiCardsGrid from '../../_components/KpiCardsGrid';
import DataTable from '../../_components/DataTable';
import EmptyState from '../../_components/EmptyState';
import ErrorBanner from '../../_components/ErrorBanner';
import { formatMoney, formatNumber, getRangeFromSearch, toRate } from '../../_components/performance-utils';

type Row = {
  partnerId: string;
  name: string;
  refCount: number;
  portfolioCount: number;
  refToPortfolioRate: number;
  salesAttributedCount: number;
  revenueAttributedSum: number;
};

type Payload = { rows: Row[] };

export default function LeaderboardPartnersPage() {
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
        const res = await api.get<Payload>('/admin/performance/leaderboard/partners', { params: { from, to } });
        if (mounted) {
          const sorted = [...(res.data.rows || [])].sort((a, b) => (b.refCount === a.refCount ? b.revenueAttributedSum - a.revenueAttributedSum : b.refCount - a.refCount));
          setRows(sorted);
        }
      } catch {
        if (mounted) {
          setRows([]);
          setError('İş ortağı leaderboard verisi alınamadı.');
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }
    load();
    return () => { mounted = false; };
  }, [searchParams]);

  const totalRef = rows.reduce((sum, row) => sum + Number(row.refCount || 0), 0);
  const totalRevenue = rows.reduce((sum, row) => sum + Number(row.revenueAttributedSum || 0), 0);

  return (
    <PerformancePageShell title="Liderlik / İş Ortakları" subtitle="İş ortağı referans ve dönüşüm performansı.">
      {error ? <ErrorBanner message={error} /> : null}
      <KpiCardsGrid
        items={[
          { label: 'Toplam İş Ortağı', value: loading ? '…' : formatNumber(rows.length) },
          { label: 'Toplam Referans', value: loading ? '…' : formatNumber(totalRef) },
          { label: 'Atfedilen Ciro', value: loading ? '…' : formatMoney(totalRevenue) },
        ]}
      />
      {rows.length === 0 ? (
        <EmptyState title="İş ortağı leaderboard boş" />
      ) : (
        <DataTable
          title="İş Ortakları"
          rows={rows}
          columns={[
            { key: 'name', label: 'İş Ortağı', sortable: true },
            { key: 'refCount', label: 'Referans', sortable: true },
            { key: 'portfolioCount', label: 'Portföy', sortable: true },
            { key: 'refToPortfolioRate', label: 'Oran', sortable: true, render: (r) => toRate(Number(r.refToPortfolioRate)) },
            { key: 'salesAttributedCount', label: 'Satış', sortable: true },
            { key: 'revenueAttributedSum', label: 'Atfedilen Ciro', sortable: true, render: (r) => formatMoney(Number(r.revenueAttributedSum)) },
          ]}
          onRowClick={(row) => router.push(`/admin/performance/partners/${String(row.partnerId)}`)}
          searchPlaceholder="İş ortağı ara..."
        />
      )}
    </PerformancePageShell>
  );
}
