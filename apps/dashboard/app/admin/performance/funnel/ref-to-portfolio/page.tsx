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

type PartnerRow = { partnerId: string; name: string; refCount: number; portfolioCount: number; rate: number };
type Payload = { totalRef: number; portfolioFromRef: number; refToPortfolioRate: number; breakdownByPartner: PartnerRow[] };

export default function RefToPortfolioPage() {
  const searchParams = useSearchParams();
  const [data, setData] = React.useState<Payload | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    const { from, to, city } = getRangeFromSearch(searchParams);
    let mounted = true;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const res = await api.get<Payload>('/admin/performance/funnel/ref-to-portfolio', { params: { from, to, city: city || undefined } });
        if (mounted) setData(res.data);
      } catch {
        if (mounted) {
          setError('Dönüşüm verisi alınamadı.');
          setData({ totalRef: 0, portfolioFromRef: 0, refToPortfolioRate: 0, breakdownByPartner: [] });
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }
    load();
    return () => { mounted = false; };
  }, [searchParams]);

  const d = data || { totalRef: 0, portfolioFromRef: 0, refToPortfolioRate: 0, breakdownByPartner: [] };

  return (
    <PerformancePageShell title="Referans → Portföy" subtitle="Referansların portföye dönüşümünü takip edin.">
      {error ? <ErrorBanner message={error} /> : null}
      <KpiCardsGrid
        items={[
          { label: 'Toplam Referans', value: loading ? '…' : formatNumber(d.totalRef) },
          { label: 'Portföye Dönüşen', value: loading ? '…' : formatNumber(d.portfolioFromRef) },
          { label: 'Dönüşüm Oranı', value: loading ? '…' : toRate(d.refToPortfolioRate) },
        ]}
      />
      {d.breakdownByPartner.length === 0 ? (
        <EmptyState title="Partner kırılımı bulunamadı" note="Seçili tarih aralığında veri yok." />
      ) : (
        <DataTable
          title="Partner Kırılımı"
          rows={d.breakdownByPartner}
          columns={[
            { key: 'name', label: 'İş Ortağı', sortable: true },
            { key: 'refCount', label: 'Referans', sortable: true },
            { key: 'portfolioCount', label: 'Portföy', sortable: true },
            { key: 'rate', label: 'Oran', sortable: true, render: (r) => toRate(Number(r.rate)) },
          ]}
        />
      )}
    </PerformancePageShell>
  );
}
