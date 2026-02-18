'use client';

import React from 'react';
import { useSearchParams } from 'next/navigation';
import { api } from '@/lib/api';
import PerformancePageShell from '../_components/PerformancePageShell';
import KpiCardsGrid from '../_components/KpiCardsGrid';
import ErrorBanner from '../_components/ErrorBanner';
import { formatMoney, formatNumber, getRangeFromSearch, toRate } from '../_components/performance-utils';

type OverviewData = {
  totalRevenue: number;
  totalDealsWon: number;
  totalLeads: number;
  totalPortfolio: number;
  conversionRefToPortfolio: number;
  conversionPortfolioToSale: number;
};

export default function AdminPerformanceOverviewPage() {
  const searchParams = useSearchParams();
  const [data, setData] = React.useState<OverviewData | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const { from, to } = getRangeFromSearch(searchParams);
    let mounted = true;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const res = await api.get<OverviewData>('/admin/performance/overview', { params: { from, to } });
        if (mounted) setData(res.data);
      } catch {
        if (mounted) {
          setError('Performans verileri alınamadı. Varsayılan değerler gösteriliyor.');
          setData({
            totalRevenue: 0,
            totalDealsWon: 0,
            totalLeads: 0,
            totalPortfolio: 0,
            conversionRefToPortfolio: 0,
            conversionPortfolioToSale: 0,
          });
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }
    load();
    return () => {
      mounted = false;
    };
  }, [searchParams]);

  const d = data || {
    totalRevenue: 0,
    totalDealsWon: 0,
    totalLeads: 0,
    totalPortfolio: 0,
    conversionRefToPortfolio: 0,
    conversionPortfolioToSale: 0,
  };

  return (
    <PerformancePageShell title="Performans / Genel Bakış" subtitle="Referans, portföy, satış ve finans KPI özetleri.">
      {error ? <ErrorBanner message={error} /> : null}
      <KpiCardsGrid
        items={[
          { label: 'Toplam Ciro', value: loading ? '…' : formatMoney(d.totalRevenue) },
          { label: 'Kapanan Satış', value: loading ? '…' : formatNumber(d.totalDealsWon) },
          { label: 'Toplam Lead', value: loading ? '…' : formatNumber(d.totalLeads) },
          { label: 'Toplam Portföy', value: loading ? '…' : formatNumber(d.totalPortfolio) },
          { label: 'Ref → Portföy', value: loading ? '…' : toRate(d.conversionRefToPortfolio) },
          { label: 'Portföy → Satış', value: loading ? '…' : toRate(d.conversionPortfolioToSale) },
        ]}
      />
    </PerformancePageShell>
  );
}
