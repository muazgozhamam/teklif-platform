'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { requireRole } from '@/lib/auth';
import { Badge } from '@/src/ui/components/Badge';
import { Button } from '@/src/ui/components/Button';
import { Card } from '@/src/ui/components/Card';
import { Select } from '@/src/ui/components/Select';
import { Table, Td, Th } from '@/src/ui/components/Table';

type OnboardingItem = {
  user: {
    id: string;
    email: string;
    role: 'HUNTER' | 'BROKER' | 'CONSULTANT' | 'ADMIN' | 'USER' | string;
    isActive: boolean;
    officeId: string | null;
  };
  supported: boolean;
  completionPct: number;
  checklist: Array<{
    key: string;
    label: string;
    required: boolean;
    done: boolean;
  }>;
};

type OnboardingListResponse = {
  items: OnboardingItem[];
  total: number;
  take: number;
  skip: number;
  role: string | null;
};

async function api<T>(path: string): Promise<T> {
  const res = await fetch(path, {
    method: 'GET',
    cache: 'no-store',
    headers: { 'Content-Type': 'application/json' },
  });
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

export default function AdminOnboardingPage() {
  const [allowed, setAllowed] = React.useState(false);
  const [rows, setRows] = React.useState<OnboardingItem[]>([]);
  const [role, setRole] = React.useState<string>('ALL');
  const [take, setTake] = React.useState<number>(20);
  const [skip, setSkip] = React.useState<number>(0);
  const [total, setTotal] = React.useState<number>(0);
  const [loading, setLoading] = React.useState<boolean>(true);
  const [error, setError] = React.useState<string | null>(null);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      params.set('take', String(take));
      params.set('skip', String(skip));
      if (role !== 'ALL') params.set('role', role);
      const data = await api<OnboardingListResponse>(`/api/admin/onboarding/users?${params.toString()}`);
      setRows(data.items || []);
      setTotal(Number(data.total || 0));
    } catch (e: any) {
      setError(e?.message || 'Yükleme hatası');
    } finally {
      setLoading(false);
    }
  }, [role, skip, take]);

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

  const pageIndex = Math.floor(skip / take) + 1;
  const totalPages = Math.max(1, Math.ceil(total / take));
  const canPrev = skip > 0;
  const canNext = skip + take < total;

  function variantForPct(v: number): 'danger' | 'warning' | 'primary' | 'success' {
    if (v >= 100) return 'success';
    if (v >= 66) return 'primary';
    if (v >= 33) return 'warning';
    return 'danger';
  }

  return (
    <RoleShell
      role="ADMIN"
      title="Yönetici Uyum Süreci"
      subtitle="Kullanıcıların ilk kurulum adımlarını takip et ve eksikleri tamamlat."
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
          <Select
            value={role}
            onChange={(e) => {
              setRole(e.target.value);
              setSkip(0);
            }}
            className="w-full sm:w-44"
          >
            <option value="ALL">Tümü</option>
            <option value="HUNTER">İş Ortağı</option>
            <option value="BROKER">Broker</option>
            <option value="CONSULTANT">Danışman</option>
            <option value="ADMIN">Yönetici</option>
          </Select>
          <Select
            value={String(take)}
            onChange={(e) => {
              setTake(Number(e.target.value));
              setSkip(0);
            }}
            className="w-full sm:w-28"
          >
            <option value="10">10</option>
            <option value="20">20</option>
            <option value="50">50</option>
          </Select>
          <Button onClick={load} variant="secondary" loading={loading}>
            Yenile
          </Button>
          <div className="text-xs text-[var(--muted)]">
            Toplam: <b className="text-[var(--text)]">{total}</b> | Sayfa: <b className="text-[var(--text)]">{pageIndex}</b>/<b className="text-[var(--text)]">{totalPages}</b>
          </div>
        </div>
      </Card>

      {error ? <AlertMessage type="error" message={error} /> : null}

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <MiniInfo title="Açık Kayıt" value={rows.length} />
        <MiniInfo title="Aktif Hesap" value={rows.filter((r) => r.user.isActive).length} />
        <MiniInfo title="Tamamlanan" value={rows.filter((r) => r.completionPct >= 100).length} />
      </div>

      <Card className="mt-4 overflow-hidden p-0">
        <div className="border-b border-[var(--border)] px-4 py-3 text-sm font-medium text-[var(--text)]">{loading ? 'Yükleniyor…' : `${rows.length} uyum kaydı`}</div>
        <div className="overflow-x-auto">
          <Table className="min-w-[920px]">
            <thead>
              <tr>
                <Th>Kullanıcı</Th>
                <Th>Rol</Th>
                <Th>Hesap</Th>
                <Th>İlerleme</Th>
                <Th>Eksik Adımlar</Th>
                <Th className="text-right">İşlem</Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.user.id} className="hover:bg-[var(--interactive-hover-bg)]">
                  <Td>{r.user.email}</Td>
                  <Td>{roleLabel(r.user.role)}</Td>
                  <Td><Badge variant={r.user.isActive ? 'success' : 'neutral'}>{r.user.isActive ? 'Aktif' : 'Pasif'}</Badge></Td>
                  <Td><Badge variant={variantForPct(r.completionPct)}> %{r.completionPct}</Badge></Td>
                  <Td>
                    {r.checklist.length === 0 || r.checklist.every((c) => c.done) ? (
                      <span className="text-xs text-[var(--muted)]">Eksik adım yok</span>
                    ) : (
                      <div className="flex flex-wrap gap-2">
                        {r.checklist
                          .filter((c) => !c.done)
                          .slice(0, 2)
                          .map((c) => (
                            <Badge key={`${r.user.id}-${c.key}`} variant="warning" className="text-[11px]">
                              {c.label}
                            </Badge>
                          ))}
                        {r.checklist.filter((c) => !c.done).length > 2 ? (
                          <span className="text-xs text-[var(--muted)]">+{r.checklist.filter((c) => !c.done).length - 2} adım</span>
                        ) : null}
                      </div>
                    )}
                  </Td>
                  <Td className="text-right">
                    <a
                      href="/admin/users"
                      className="inline-flex h-8 items-center justify-center rounded-xl border border-[var(--border)] bg-[var(--card-2)] px-3 text-xs font-medium text-[var(--text)] transition-colors hover:border-[var(--interactive-hover-border)] hover:bg-[var(--interactive-hover-bg)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]"
                    >
                      Kullanıcılar
                    </a>
                  </Td>
                </tr>
              ))}
              {!loading && rows.length === 0 ? (
                <tr>
                  <Td colSpan={6} className="text-[var(--muted)]">Kayıt yok.</Td>
                </tr>
              ) : null}
            </tbody>
          </Table>
        </div>

        <div className="flex justify-end gap-2 border-t border-[var(--border)] px-4 py-3">
          <Button onClick={() => setSkip((v) => Math.max(v - take, 0))} variant="secondary" disabled={loading || !canPrev}>
            Önceki
          </Button>
          <Button onClick={() => setSkip((v) => v + take)} variant="secondary" disabled={loading || !canNext}>
            Sonraki
          </Button>
        </div>
      </Card>
    </RoleShell>
  );
}

function MiniInfo({ title, value }: { title: string; value: number }) {
  return (
    <Card className="p-4">
      <div className="text-xs text-[var(--muted)]">{title}</div>
      <div className="mt-1 text-xl font-semibold text-[var(--text)]">{value}</div>
    </Card>
  );
}

function roleLabel(role: string) {
  if (role === 'HUNTER') return 'İş Ortağı';
  if (role === 'CONSULTANT') return 'Danışman';
  if (role === 'BROKER') return 'Broker';
  if (role === 'ADMIN') return 'Yönetici';
  if (role === 'USER') return 'Kullanıcı';
  return role;
}
