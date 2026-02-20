'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';
import { AlertMessage } from '@/app/_components/UiFeedback';
import { requireRole } from '@/lib/auth';
import { Badge } from '@/src/ui/components/Badge';
import { Button } from '@/src/ui/components/Button';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';
import { Select } from '@/src/ui/components/Select';
import { Table, Td, Th } from '@/src/ui/components/Table';

type Role = 'USER' | 'BROKER' | 'ADMIN' | 'CONSULTANT' | 'HUNTER';

type AdminUser = {
  id: string;
  email: string;
  name: string | null;
  role: Role | string;
  isActive: boolean;
  createdAt?: string;
};

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers || {}),
    },
    cache: 'no-store',
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

export default function AdminUsersPage() {
  const [allowed, setAllowed] = React.useState(false);
  const [rows, setRows] = React.useState<AdminUser[]>([]);
  const [q, setQ] = React.useState('');
  const [loading, setLoading] = React.useState(true);
  const [savingId, setSavingId] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);
  const stats = React.useMemo(() => {
    const total = rows.length;
    const active = rows.filter((row) => row.isActive).length;
    const passive = total - active;
    const admins = rows.filter((row) => row.role === 'ADMIN').length;
    return { total, active, passive, admins };
  }, [rows]);

  React.useEffect(() => {
    setAllowed(requireRole(['ADMIN']));
  }, []);

  const load = React.useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const qs = q.trim() ? `?q=${encodeURIComponent(q.trim())}` : '';
      const data = await api<AdminUser[]>(`/api/admin/users${qs}`);
      setRows(data);
    } catch (e: any) {
      setError(e?.message || 'Yükleme hatası');
    } finally {
      setLoading(false);
    }
  }, [q]);

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

  async function patchUser(userId: string, patch: { role?: Role; isActive?: boolean }) {
    setSavingId(userId);
    setError(null);

    const prev = rows;
    setRows(prev.map((r) => (r.id === userId ? { ...r, ...patch } : r)));

    try {
      await api(`/api/admin/users/${userId}`, {
        method: 'PATCH',
        body: JSON.stringify(patch),
      });
    } catch (e: any) {
      setRows(prev);
      setError(e?.message || 'Kaydetme hatası');
    } finally {
      setSavingId(null);
    }
  }

  return (
    <RoleShell
      role="ADMIN"
      title="Kullanıcılar"
      subtitle="Kullanıcıları listele, rol güncelle ve hesap durumunu yönet."
      nav={[]}
    >
      <div className="mb-3 text-xs font-medium uppercase tracking-wider text-[var(--muted)]">Kullanıcı Yönetimi</div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Card><CardDescription>Toplam Kullanıcı</CardDescription><CardTitle className="mt-1">{loading ? '…' : String(stats.total)}</CardTitle></Card>
        <Card><CardDescription>Aktif</CardDescription><CardTitle className="mt-1">{loading ? '…' : String(stats.active)}</CardTitle></Card>
        <Card><CardDescription>Pasif</CardDescription><CardTitle className="mt-1">{loading ? '…' : String(stats.passive)}</CardTitle></Card>
        <Card><CardDescription>Yönetici</CardDescription><CardTitle className="mt-1">{loading ? '…' : String(stats.admins)}</CardTitle></Card>
      </div>

      <Card>
        <div className="flex flex-wrap items-center gap-2">
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Email/isim ara..." className="max-w-md" />
          <Button onClick={load} variant="secondary" loading={loading}>
            Yenile
          </Button>
        </div>
      </Card>

      {error ? <AlertMessage type="error" message={error} /> : null}

      <Card className="mt-4 overflow-hidden p-0">
        <div className="border-b border-[var(--border)] px-4 py-3 text-sm font-medium text-[var(--text)]">{loading ? 'Yükleniyor…' : `${rows.length} kullanıcı`}</div>
        <div className="overflow-x-auto">
          <Table className="min-w-[860px]">
            <thead>
              <tr>
                <Th>E-posta</Th>
                <Th>İsim</Th>
                <Th>Rol</Th>
                <Th>Durum</Th>
                <Th>Oluşturulma</Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((u) => (
                <tr key={u.id} className="hover:bg-[var(--interactive-hover-bg)]">
                  <Td>{u.email}</Td>
                  <Td>{u.name || '-'}</Td>
                  <Td>
                    <div className="flex items-center gap-2">
                      <Select
                        value={(u.role as Role) || 'USER'}
                        onChange={(e) => patchUser(u.id, { role: e.target.value as Role })}
                        disabled={savingId === u.id}
                        uiSize="sm"
                        className="max-w-[220px]"
                      >
                        <option value="USER">Kullanıcı (USER)</option>
                        <option value="BROKER">Broker (BROKER)</option>
                        <option value="CONSULTANT">Danışman (CONSULTANT)</option>
                        <option value="HUNTER">Hunter (HUNTER)</option>
                        <option value="ADMIN">Yönetici (ADMIN)</option>
                      </Select>
                      {savingId === u.id ? <span className="text-xs text-[var(--muted)]">Kaydediliyor…</span> : null}
                    </div>
                  </Td>
                  <Td>
                    <button
                      type="button"
                      onClick={() => patchUser(u.id, { isActive: !u.isActive })}
                      disabled={savingId === u.id}
                      className="ui-interactive rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--focus-ring)]"
                    >
                      <Badge variant={u.isActive ? 'success' : 'neutral'}>{u.isActive ? 'Aktif' : 'Pasif'}</Badge>
                    </button>
                  </Td>
                  <Td>{u.createdAt ? new Date(u.createdAt).toLocaleString() : '-'}</Td>
                </tr>
              ))}
              {!loading && rows.length === 0 ? (
                <tr>
                  <Td colSpan={5} className="text-[var(--muted)]">Kayıt yok.</Td>
                </tr>
              ) : null}
            </tbody>
          </Table>
        </div>
      </Card>
    </RoleShell>
  );
}
