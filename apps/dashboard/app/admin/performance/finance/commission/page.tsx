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

type RoleCommission = { role: string; amount: number };
type UserCommission = { userId: string; name: string; amount: number };
type Payload = { commissionSum: number; pendingCommission: number; commissionByRole: RoleCommission[]; commissionByUser: UserCommission[] };

export default function FinanceCommissionPage() {
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
        const res = await api.get<Payload>('/admin/performance/finance/commission', { params: { from, to } });
        if (mounted) setData(res.data);
      } catch {
        if (mounted) {
          setError('Komisyon verisi alınamadı.');
          setData({ commissionSum: 0, pendingCommission: 0, commissionByRole: [], commissionByUser: [] });
        }
      } finally {
        if (mounted) setLoading(false);
      }
    }
    load();
    return () => { mounted = false; };
  }, [searchParams]);

  const d = data || { commissionSum: 0, pendingCommission: 0, commissionByRole: [], commissionByUser: [] };

  return (
    <PerformancePageShell title="Komisyon Analizi" subtitle="Komisyon dağılımını ve kullanıcı kırılımını görün.">
      {error ? <ErrorBanner message={error} /> : null}
      <KpiCardsGrid
        items={[
          { label: 'Toplam Komisyon', value: loading ? '…' : formatMoney(d.commissionSum) },
          { label: 'Bekleyen Komisyon', value: loading ? '…' : formatMoney(d.pendingCommission) },
          { label: 'Rol Dağılımı', value: loading ? '…' : formatNumber(d.commissionByRole.length) },
        ]}
      />
      {d.commissionByRole.length === 0 ? (
        <EmptyState title="Rol bazlı komisyon verisi yok" />
      ) : (
        <DataTable
          title="Rol Bazlı Komisyon"
          rows={d.commissionByRole}
          columns={[
            { key: 'role', label: 'Rol', sortable: true },
            { key: 'amount', label: 'Tutar', sortable: true, render: (r) => formatMoney(Number(r.amount)) },
          ]}
        />
      )}
      {d.commissionByUser.length === 0 ? (
        <EmptyState title="Kullanıcı bazlı komisyon verisi yok" />
      ) : (
        <DataTable
          title="Kullanıcı Bazlı Komisyon"
          rows={d.commissionByUser}
          columns={[
            { key: 'name', label: 'Kullanıcı', sortable: true },
            { key: 'amount', label: 'Komisyon', sortable: true, render: (r) => formatMoney(Number(r.amount)) },
          ]}
        />
      )}
    </PerformancePageShell>
  );
}
