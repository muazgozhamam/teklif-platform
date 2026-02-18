'use client';

import React from 'react';
import { useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import PerformancePageShell from '../../_components/PerformancePageShell';
import KpiCardsGrid from '../../_components/KpiCardsGrid';
import DataTable from '../../_components/DataTable';
import EmptyState from '../../_components/EmptyState';
import ErrorBanner from '../../_components/ErrorBanner';
import { formatNumber, getRangeFromSearch, toRate } from '../../_components/performance-utils';

type Row = { consultantId: string; name: string; portfolioCount: number; salesCount: number; rate: number };
type Payload = { totalPortfolio: number; salesFromPortfolio: number; portfolioToSaleRate: number; avgTimeToCloseDays: number; breakdownByConsultant: Row[] };

export default function PortfolioToSalePage() {
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
        const res = await api.get<Payload>('/admin/performance/funnel/portfolio-to-sale', { params: { from, to } });
        if (mounted) setData(res.data);
      } catch {
        if (mounted) {
          setError('Portföy → satış funnel verisi alınamadı.');
          setData({ totalPortfolio: 0, salesFromPortfolio: 0, portfolioToSaleRate: 0, avgTimeToCloseDays: 0, breakdownByConsultant: [] });
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }
    load();
    return () => { mounted = false; };
  }, [searchParams]);

  const d = data || { totalPortfolio: 0, salesFromPortfolio: 0, portfolioToSaleRate: 0, avgTimeToCloseDays: 0, breakdownByConsultant: [] };

  return (
    <PerformancePageShell title="Funnel / Portföy → Satış" subtitle="Portföyden kapanan satışa dönüşüm.">
      {error ? <ErrorBanner message={error} /> : null}
      <KpiCardsGrid
        items={[
          { label: 'Toplam Portföy', value: loading ? '…' : formatNumber(d.totalPortfolio) },
          { label: 'Satışa Dönen', value: loading ? '…' : formatNumber(d.salesFromPortfolio) },
          { label: 'Dönüşüm Oranı', value: loading ? '…' : toRate(d.portfolioToSaleRate) },
          { label: 'Ortalama Kapanış Süresi', value: loading ? '…' : `${Number(d.avgTimeToCloseDays || 0).toFixed(1)} gün` },
        ]}
      />
      {d.breakdownByConsultant.length === 0 ? (
        <EmptyState title="Danışman kırılımı bulunamadı" />
      ) : (
        <DataTable
          title="Danışman Kırılımı"
          rows={d.breakdownByConsultant}
          columns={[
            { key: 'name', label: 'Danışman', sortable: true },
            { key: 'portfolioCount', label: 'Portföy', sortable: true },
            { key: 'salesCount', label: 'Satış', sortable: true },
            { key: 'rate', label: 'Oran', sortable: true, render: (r) => toRate(Number(r.rate)) },
          ]}
        />
      )}
    </PerformancePageShell>
  );
}
