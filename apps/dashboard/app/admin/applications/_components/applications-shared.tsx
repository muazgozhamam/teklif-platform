'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import RoleShell from '@/app/_components/RoleShell';
import { api } from '@/lib/api';
import { Alert } from '@/src/ui/components/Alert';
import { Badge } from '@/src/ui/components/Badge';
import { Button } from '@/src/ui/components/Button';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';
import { Select } from '@/src/ui/components/Select';
import { Table, Td, Th } from '@/src/ui/components/Table';

export const TYPE_LABELS: Record<string, string> = {
  CUSTOMER_LEAD: 'Müşteri Adayı',
  PORTFOLIO_LEAD: 'Portföy Adayı',
  CONSULTANT_CANDIDATE: 'Danışman Adayı',
  HUNTER_CANDIDATE: 'Avcı Adayı',
  BROKER_CANDIDATE: 'Broker Adayı',
  PARTNER_CANDIDATE: 'İş Ortağı Adayı',
  CORPORATE_LEAD: 'Kurumsal Talep',
  SUPPORT_REQUEST: 'Destek Talebi',
  COMPLAINT: 'Şikayet',
};

export const STATUS_LABELS: Record<string, string> = {
  NEW: 'Yeni',
  QUALIFIED: 'Nitelikli',
  IN_REVIEW: 'İncelemede',
  MEETING_SCHEDULED: 'Görüşme',
  APPROVED: 'Onaylandı',
  ONBOARDED: 'Sürece Alındı',
  REJECTED: 'Reddedildi',
  CLOSED: 'Kapalı',
};

function badgeForStatus(status: string): 'neutral' | 'warning' | 'primary' | 'success' | 'danger' {
  if (status === 'NEW') return 'warning';
  if (status === 'QUALIFIED' || status === 'IN_REVIEW' || status === 'MEETING_SCHEDULED') return 'primary';
  if (status === 'APPROVED' || status === 'ONBOARDED') return 'success';
  if (status === 'REJECTED' || status === 'CLOSED') return 'danger';
  return 'neutral';
}

function badgeForPriority(priority: string): 'neutral' | 'warning' | 'danger' {
  if (priority === 'P0') return 'danger';
  if (priority === 'P1') return 'warning';
  return 'neutral';
}

type ApplicationRow = {
  id: string;
  createdAt: string;
  type: string;
  status: string;
  fullName: string;
  phone: string;
  email?: string | null;
  city?: string | null;
  district?: string | null;
  priority: 'P0' | 'P1' | 'P2';
  assignedTo?: { id: string; name?: string | null; email?: string | null } | null;
  lastActivityAt: string;
};

export function ApplicationsOverviewPage() {
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [data, setData] = React.useState<{
    newToday: number;
    qualified: number;
    inReview: number;
    totalOpen: number;
    avgFirstResponseMinutes: number;
    slaBreaches: number;
  } | null>(null);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<any>('/api/admin/applications/overview');
      setData(res.data);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Genel bakış verisi alınamadı.');
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    load();
  }, [load]);

  return (
    <RoleShell role="ADMIN" title="Aday & Talepler" subtitle="Başvuru ve talepleri tek havuzdan takip et, doğru kişiye yönlendir." nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}

      <div className="mb-3 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">Genel Durum</div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-6">
        <KpiCard label="Bugün Yeni" value={loading ? '…' : String(data?.newToday || 0)} />
        <KpiCard label="Nitelikli" value={loading ? '…' : String(data?.qualified || 0)} />
        <KpiCard label="İncelemede" value={loading ? '…' : String(data?.inReview || 0)} />
        <KpiCard label="Açık Kayıt" value={loading ? '…' : String(data?.totalOpen || 0)} />
        <KpiCard label="Ort. İlk Dönüş" value={loading ? '…' : `${data?.avgFirstResponseMinutes || 0} dk`} />
        <KpiCard label="Süreyi Aşan" value={loading ? '…' : String(data?.slaBreaches || 0)} />
      </div>

      <div className="mb-3 mt-4 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">Kategoriler</div>
      <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <QuickLink href="/admin/applications/pool" title="Aday Havuzu" desc="Tüm başvuruları tek listede yönet." />
        <QuickLink href="/admin/applications/customers" title="Müşteri Adayları" desc="Alıcı ve kiracı taleplerini yönetin." />
        <QuickLink href="/admin/applications/portfolio" title="Portföy Adayları" desc="Satıcı/ev sahibi talepleri." />
        <QuickLink href="/admin/applications/consultants" title="Danışman Adayları" desc="Danışman başvuruları." />
        <QuickLink href="/admin/applications/hunters" title="Avcı Adayları" desc="Avcı adaylarını filtreleyip değerlendir." />
        <QuickLink href="/admin/applications/brokers" title="Broker Adayları" desc="Broker aday başvurularını takip et." />
        <QuickLink href="/admin/applications/partners" title="İş Ortağı Adayları" desc="Partner ve iş ortağı başvuruları." />
        <QuickLink href="/admin/applications/corporate" title="Kurumsal Talepler" desc="Kurumsal müşteri ve kurum talepleri." />
        <QuickLink href="/admin/applications/support" title="Destek / Şikayet" desc="Destek ve şikayet kayıtlarını yönetin." />
      </div>
    </RoleShell>
  );
}

export function ApplicationsListPage({
  title,
  subtitle,
  forcedType,
}: {
  title: string;
  subtitle: string;
  forcedType?: string;
}) {
  const router = useRouter();
  const [q, setQ] = React.useState('');
  const [status, setStatus] = React.useState('');
  const [priority, setPriority] = React.useState('');
  const [type, setType] = React.useState(forcedType || '');
  const [rows, setRows] = React.useState<ApplicationRow[]>([]);
  const [total, setTotal] = React.useState(0);
  const [take, setTake] = React.useState(20);
  const [skip, setSkip] = React.useState(0);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    setType(forcedType || '');
  }, [forcedType]);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get<any>('/api/admin/applications', {
        params: {
          q: q || undefined,
          status: status || undefined,
          priority: priority || undefined,
          type: forcedType || type || undefined,
          take,
          skip,
        },
      });
      setRows(Array.isArray(res.data?.items) ? res.data.items : []);
      setTotal(Number(res.data?.total || 0));
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Kayıt listesi alınamadı.');
    } finally {
      setLoading(false);
    }
  }, [forcedType, type, q, status, priority, take, skip]);

  React.useEffect(() => {
    load();
  }, [load]);

  return (
    <RoleShell role="ADMIN" title={title} subtitle={subtitle} nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}
      <Card>
        <div className="flex flex-wrap items-center gap-2">
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Ad, e-posta veya telefon ara" className="min-w-[220px] flex-1" />
          <Select value={status} onChange={(e) => setStatus(e.target.value)} className="w-full sm:w-[170px]">
            <option value="">Tüm Durumlar</option>
            {Object.entries(STATUS_LABELS).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </Select>
          <Select value={priority} onChange={(e) => setPriority(e.target.value)} className="w-full sm:w-[130px]">
            <option value="">Tüm Öncelik</option>
            <option value="P0">P0</option>
            <option value="P1">P1</option>
            <option value="P2">P2</option>
          </Select>
          {!forcedType ? (
            <Select value={type} onChange={(e) => setType(e.target.value)} className="w-full sm:w-[220px]">
              <option value="">Tüm Kayıt Türleri</option>
              {Object.entries(TYPE_LABELS).map(([v, l]) => (
                <option key={v} value={v}>{l}</option>
              ))}
            </Select>
          ) : null}
          <Button variant="secondary" onClick={() => { setSkip(0); load(); }} loading={loading}>Yenile</Button>
        </div>
        {forcedType ? (
          <div className="mt-3 text-xs text-[var(--muted)]">
            Aktif görünüm: <span className="text-[var(--text)]">{forcedType.split(',').map((v) => TYPE_LABELS[v] || v).join(', ')}</span>
          </div>
        ) : null}
      </Card>

      <Card className="mt-4 overflow-hidden p-0">
        <div className="border-b border-[var(--border)] px-4 py-3 text-xs text-[var(--muted)]">
          Toplam: <b className="text-[var(--text)]">{total}</b> | Sayfa: <b className="text-[var(--text)]">{Math.floor(skip / take) + 1}</b>
        </div>
        <div className="overflow-x-auto">
          <Table className="min-w-[1120px]">
            <thead>
              <tr>
                <Th>Tarih</Th>
                <Th>Tip</Th>
                <Th>Ad</Th>
                <Th>Konum</Th>
                <Th>Durum</Th>
                <Th>Atanan</Th>
                <Th>Öncelik</Th>
                <Th>Son Aktivite</Th>
                <Th className="text-right">İşlem</Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id} className="cursor-pointer hover:bg-[var(--interactive-hover-bg)]" onClick={() => router.push(`/admin/applications/${row.id}`)}>
                  <Td>{new Date(row.createdAt).toLocaleString('tr-TR')}</Td>
                  <Td>{TYPE_LABELS[row.type] || row.type}</Td>
                  <Td>
                    <div className="font-medium">{row.fullName}</div>
                    <div className="text-xs text-[var(--muted)]">{row.phone}</div>
                  </Td>
                  <Td>{[row.city, row.district].filter(Boolean).join(' / ') || '-'}</Td>
                  <Td><Badge variant={badgeForStatus(row.status)}>{STATUS_LABELS[row.status] || row.status}</Badge></Td>
                  <Td>{row.assignedTo?.name || row.assignedTo?.email || '-'}</Td>
                  <Td><Badge variant={badgeForPriority(row.priority)}>{row.priority}</Badge></Td>
                  <Td>{new Date(row.lastActivityAt).toLocaleString('tr-TR')}</Td>
                  <Td className="text-right">
                    <span className="text-xs text-[var(--primary)]">Detay</span>
                  </Td>
                </tr>
              ))}
              {!loading && rows.length === 0 ? (
                <tr><Td colSpan={9} className="text-[var(--muted)]">Bu filtrelerle kayıt bulunamadı.</Td></tr>
              ) : null}
            </tbody>
          </Table>
        </div>
      </Card>

      <div className="mt-3 flex justify-end gap-2">
        <Select value={String(take)} onChange={(e) => { setTake(Number(e.target.value)); setSkip(0); }} className="w-[100px]">
          <option value="20">20</option>
          <option value="50">50</option>
          <option value="100">100</option>
        </Select>
        <Button variant="secondary" onClick={() => setSkip((s) => Math.max(s - take, 0))} disabled={skip <= 0}>Önceki</Button>
        <Button variant="secondary" onClick={() => setSkip((s) => s + take)} disabled={skip + take >= total}>Sonraki</Button>
      </div>
    </RoleShell>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <CardDescription>{label}</CardDescription>
      <CardTitle className="mt-1">{value}</CardTitle>
    </Card>
  );
}

function QuickLink({ href, title, desc }: { href: string; title: string; desc: string }) {
  return (
    <Link href={href} className="ui-interactive rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4 hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)]">
      <div className="text-sm font-semibold text-[var(--text)]">{title}</div>
      <div className="mt-1 text-xs text-[var(--muted)]">{desc}</div>
    </Link>
  );
}
