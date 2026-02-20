'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { requireRole } from '@/lib/auth';
import { Button } from '@/src/ui/components/Button';
import { Card } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';
import { Select } from '@/src/ui/components/Select';
import { Table, Td, Th } from '@/src/ui/components/Table';

type AuditItem = {
  id: string;
  createdAt: string;
  action: string;
  canonicalAction: string;
  entity: string;
  canonicalEntity: string;
  entityId: string;
  actor?: { email?: string | null; role?: string | null } | null;
};

type AuditListResponse = {
  items: AuditItem[];
  total: number;
  take: number;
  skip: number;
};

async function api<T>(path: string): Promise<T> {
  const res = await fetch(path, { method: 'GET', cache: 'no-store' });
  if (!res.ok) {
    let msg = res.statusText;
    try {
      const body = await res.json();
      msg = body?.message || msg;
    } catch {}
    throw new Error(`${res.status} ${msg}`);
  }
  return (await res.json()) as T;
}

export default function AdminAuditPage() {
  const [allowed, setAllowed] = React.useState(false);
  const [rows, setRows] = React.useState<AuditItem[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const [q, setQ] = React.useState('');
  const [action, setAction] = React.useState('');
  const [entityType, setEntityType] = React.useState('');
  const [take, setTake] = React.useState(20);
  const [skip, setSkip] = React.useState(0);
  const [total, setTotal] = React.useState(0);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const p = new URLSearchParams();
      p.set('take', String(take));
      p.set('skip', String(skip));
      if (q.trim()) p.set('q', q.trim());
      if (action.trim()) p.set('action', action.trim());
      if (entityType.trim()) p.set('entityType', entityType.trim());
      const data = await api<AuditListResponse>(`/api/admin/audit?${p.toString()}`);
      setRows(Array.isArray(data.items) ? data.items : []);
      setTotal(Number(data.total || 0));
    } catch (e: any) {
      setError(e?.message || 'Denetim kayıtları alınamadı');
    } finally {
      setLoading(false);
    }
  }, [action, entityType, q, skip, take]);

  React.useEffect(() => {
    setAllowed(requireRole(['ADMIN']));
  }, []);

  React.useEffect(() => {
    if (!allowed) return;
    load();
  }, [allowed, load]);

  if (!allowed) {
    return (
      <main className="p-6 opacity-80">
        <div>Yükleniyor…</div>
      </main>
    );
  }

  const page = Math.floor(skip / take) + 1;
  const totalPages = Math.max(1, Math.ceil(total / take));

  return (
    <RoleShell
      role="ADMIN"
      title="Denetim Kayıtları"
      subtitle="Sistemde yapılan işlemleri zaman sırasıyla takip et."
      nav={[
        { href: '/admin', label: 'Panel' },
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/audit', label: 'Denetim' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >
      <Card>
        <div className="flex flex-wrap items-center gap-2">
          <Input
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setSkip(0);
            }}
            placeholder="Ara: kayıt no, kullanıcı, işlem..."
            className="min-w-[220px] flex-1"
          />
          <Input
            value={action}
            onChange={(e) => {
              setAction(e.target.value);
              setSkip(0);
            }}
            placeholder="İşlem filtresi"
            className="w-full sm:w-44"
          />
          <Input
            value={entityType}
            onChange={(e) => {
              setEntityType(e.target.value);
              setSkip(0);
            }}
            placeholder="Kayıt tipi filtresi"
            className="w-full sm:w-44"
          />
          <Select
            value={String(take)}
            onChange={(e) => {
              setTake(Number(e.target.value));
              setSkip(0);
            }}
            className="w-full sm:w-28"
          >
            <option value="20">20</option>
            <option value="50">50</option>
            <option value="100">100</option>
          </Select>
          <Button onClick={load} variant="secondary" loading={loading}>
            Yenile
          </Button>
        </div>

        <div className="mt-3 text-xs text-[var(--muted)]">
          Toplam: <b className="text-[var(--text)]">{total}</b> | Sayfa: <b className="text-[var(--text)]">{page}</b>/<b className="text-[var(--text)]">{totalPages}</b>
        </div>
      </Card>

      {error ? <AlertMessage type="error" message={error} /> : null}

      <Card className="mt-4 overflow-hidden p-0">
        <div className="border-b border-[var(--border)] px-4 py-3 text-sm font-medium text-[var(--text)]">{loading ? 'Yükleniyor…' : `${rows.length} kayıt`}</div>
        <div className="overflow-x-auto">
          <Table className="min-w-[720px]">
            <thead>
              <tr>
                <Th>Zaman</Th>
                <Th>Olay</Th>
                <Th>İlgili Kayıt</Th>
                <Th>Yapan</Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-[var(--interactive-hover-bg)]">
                  <Td className="whitespace-nowrap">{new Date(r.createdAt).toLocaleString()}</Td>
                  <Td>
                    <div className="font-medium text-[var(--text)]">{r.canonicalAction || r.action}</div>
                    {r.canonicalAction && r.canonicalAction !== r.action ? (
                      <div className="text-xs text-[var(--muted)]">{r.action}</div>
                    ) : null}
                  </Td>
                  <Td>
                    <div className="font-medium text-[var(--text)]">{r.canonicalEntity || r.entity}</div>
                    <div className="text-xs text-[var(--muted)]">
                      <code>{r.entityId}</code>
                    </div>
                  </Td>
                  <Td>{r.actor?.email || r.actor?.role || '-'}</Td>
                </tr>
              ))}
              {!loading && rows.length === 0 ? (
                <tr>
                  <Td colSpan={4} className="text-[var(--muted)]">Kayıt bulunamadı.</Td>
                </tr>
              ) : null}
            </tbody>
          </Table>
        </div>
      </Card>

      <div className="mt-3 flex justify-end gap-2">
        <Button onClick={() => setSkip((s) => Math.max(s - take, 0))} variant="secondary" disabled={loading || skip <= 0}>
          Önceki
        </Button>
        <Button onClick={() => setSkip((s) => s + take)} variant="secondary" disabled={loading || skip + take >= total}>
          Sonraki
        </Button>
      </div>
    </RoleShell>
  );
}
