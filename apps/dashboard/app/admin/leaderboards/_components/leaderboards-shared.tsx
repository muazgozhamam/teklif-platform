'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import Link from 'next/link';
import RoleShell from '@/app/_components/RoleShell';
import { api } from '@/lib/api';
import { Alert } from '@/src/ui/components/Alert';
import { Button } from '@/src/ui/components/Button';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Select } from '@/src/ui/components/Select';
import { Table, Td, Th } from '@/src/ui/components/Table';

type LeaderboardRole = 'HUNTER' | 'CONSULTANT' | 'BROKER';
type RangeValue = '7d' | '30d' | '90d';

type LeaderboardRow = {
  userId: string;
  name: string;
  role: LeaderboardRole;
  score: number;
  breakdown?: Record<string, unknown>;
};

const ROLE_LABELS: Record<LeaderboardRole, string> = {
  HUNTER: 'HUNTER',
  CONSULTANT: 'CONSULTANT',
  BROKER: 'BROKER',
};

const BREAKDOWN_LABELS: Record<string, string> = {
  leadsCreated: 'leadsCreated',
  qualified: 'qualified',
  portfolioConverted: 'portfolioConverted',
  dealsInfluenced: 'dealsInfluenced',
  spamPenalty: 'spamPenalty',
  listings: 'listings',
  dealsWon: 'dealsWon',
  gmv: 'gmv',
  avgCloseDays: 'avgCloseDays',
  disputePenalty: 'disputePenalty',
  dealsBrokered: 'dealsBrokered',
  approvedSnapshots: 'approvedSnapshots',
  disputeRatePenalty: 'disputeRatePenalty',
};

const RANGE_TO_DAYS: Record<RangeValue, number> = {
  '7d': 7,
  '30d': 30,
  '90d': 90,
};

function formatBreakdown(breakdown: Record<string, unknown> | undefined) {
  if (!breakdown || Object.keys(breakdown).length === 0) return '-';
  return Object.entries(breakdown)
    .map(([key, value]) => `${BREAKDOWN_LABELS[key] || key}: ${String(value ?? 0)}`)
    .join(' | ');
}

function LeaderboardQuickLink({ href, title, desc }: { href: string; title: string; desc: string }) {
  return (
    <Link href={href} className="ui-interactive rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 hover:bg-[var(--interactive-hover-bg)]">
      <CardTitle>{title}</CardTitle>
      <CardDescription>{desc}</CardDescription>
    </Link>
  );
}

export function LeaderboardsOverviewPage() {
  return (
    <RoleShell role="ADMIN" title="Performans - Genel" subtitle="Rol bazlı sıralama panellerine geçiş." nav={[]}>
      <div className="mb-3 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">Sıralama Panelleri</div>
      <div className="grid gap-3 md:grid-cols-3">
        <LeaderboardQuickLink href="/admin/leaderboards/hunter" title="İş Ortağı Sıralama" desc="Kalite ağırlıklı iş ortağı skoru." />
        <LeaderboardQuickLink href="/admin/leaderboards/consultant" title="Danışman Sıralama" desc="Dönüşüm + GMV odaklı skor." />
        <LeaderboardQuickLink href="/admin/leaderboards/broker" title="Broker Sıralama" desc="İşlem + onay kalitesi skoru." />
      </div>
    </RoleShell>
  );
}

export function LeaderboardRolePage({
  title,
  role,
}: {
  title: string;
  role: LeaderboardRole;
}) {
  const [range, setRange] = React.useState<RangeValue>('30d');
  const [rows, setRows] = React.useState<LeaderboardRow[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const to = new Date();
      const from = new Date(to.getTime() - RANGE_TO_DAYS[range] * 86400000);
      const res = await api.get<{ rows?: LeaderboardRow[] }>('/api/admin/leaderboards', {
        params: { role, from: from.toISOString(), to: to.toISOString() },
      });
      setRows(Array.isArray(res.data?.rows) ? res.data.rows : []);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Sıralama verisi alınamadı.');
    } finally {
      setLoading(false);
    }
  }, [range, role]);

  React.useEffect(() => {
    void load();
  }, [load]);

  return (
    <RoleShell role="ADMIN" title={title} subtitle="Kalite ve dönüşüm odaklı performans sıralaması." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <Card>
        <div className="flex items-center gap-2">
          <Select value={range} onChange={(e) => setRange(e.target.value as RangeValue)} className="w-[160px]">
            <option value="7d">Son 7 gün</option>
            <option value="30d">Son 30 gün</option>
            <option value="90d">Son 90 gün</option>
          </Select>
          <Button variant="secondary" onClick={load} loading={loading}>Yenile</Button>
        </div>
      </Card>

      <Card className="mt-4 overflow-hidden p-0">
        <div className="overflow-x-auto">
          <Table className="min-w-[760px]">
            <thead>
              <tr>
                <Th>#</Th>
                <Th>İsim</Th>
                <Th>Rol</Th>
                <Th>Skor</Th>
                <Th>Detay</Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => (
                <tr key={row.userId} className="hover:bg-[var(--interactive-hover-bg)]">
                  <Td>{i + 1}</Td>
                  <Td>{row.name}</Td>
                  <Td>{ROLE_LABELS[row.role] || row.role}</Td>
                  <Td><b>{row.score}</b></Td>
                  <Td className="text-xs text-[var(--muted)]">{formatBreakdown(row.breakdown)}</Td>
                </tr>
              ))}
              {!loading && rows.length === 0 ? <tr><Td colSpan={5} className="text-[var(--muted)]">Kayıt yok.</Td></tr> : null}
            </tbody>
          </Table>
        </div>
      </Card>
    </RoleShell>
  );
}
