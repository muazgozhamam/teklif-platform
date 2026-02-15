'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import RoleShell from '@/app/_components/RoleShell';

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
    load();
  }, [load]);

  const pageIndex = Math.floor(skip / take) + 1;
  const totalPages = Math.max(1, Math.ceil(total / take));
  const canPrev = skip > 0;
  const canNext = skip + take < total;

  function colorForPct(v: number) {
    if (v >= 100) return '#1e7b34';
    if (v >= 66) return '#2f6feb';
    if (v >= 33) return '#9a6700';
    return '#cf222e';
  }

  return (
    <RoleShell
      role="ADMIN"
      title="Yönetici Uyum Süreci"
      subtitle="Partner uyum süreci ilerlemesini rol bazlı takip et."
      nav={[
        { href: '/admin', label: 'Panel' },
        { href: '/admin/users', label: 'Kullanıcılar' },
        { href: '/admin/audit', label: 'Denetim' },
        { href: '/admin/onboarding', label: 'Uyum Süreci' },
        { href: '/admin/commission', label: 'Komisyon' },
      ]}
    >
      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <button
          onClick={load}
          style={{ padding: '10px 14px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
          disabled={loading}
        >
          Yenile
        </button>
      </div>

      <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <select
          value={role}
          onChange={(e) => {
            setRole(e.target.value);
            setSkip(0);
          }}
          style={{ padding: '10px 12px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
        >
          <option value="ALL">Tümü</option>
          <option value="HUNTER">Hunter</option>
          <option value="BROKER">Broker</option>
          <option value="CONSULTANT">Danışman</option>
        </select>
        <select
          value={String(take)}
          onChange={(e) => {
            setTake(Number(e.target.value));
            setSkip(0);
          }}
          style={{ padding: '10px 12px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
        >
          <option value="10">10</option>
          <option value="20">20</option>
          <option value="50">50</option>
        </select>
        <div style={{ opacity: 0.7, fontSize: 13 }}>
          Toplam: <b>{total}</b> | Sayfa: <b>{pageIndex}</b>/<b>{totalPages}</b>
        </div>
      </div>

      {error && (
        <div style={{ marginTop: 12, padding: 12, borderRadius: 12, background: '#fff5f5', border: '1px solid #ffd6d6' }}>
          <strong>Hata:</strong> {error}
        </div>
      )}

      <div style={{ marginTop: 16, border: '1px solid #eee', borderRadius: 14, overflow: 'hidden' }}>
        <div style={{ padding: 12, borderBottom: '1px solid #eee', background: '#fafafa', fontWeight: 600 }}>
          {loading ? 'Yükleniyor…' : `${rows.length} uyum kaydı`}
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', background: 'white' }}>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>E-posta</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Rol</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Durum</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Tamamlama</th>
              <th style={{ padding: 12, borderBottom: '1px solid #eee' }}>Kontrol Listesi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.user.id}>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>{r.user.email}</td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>{r.user.role}</td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>{r.user.isActive ? 'Aktif' : 'Pasif'}</td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>
                  <span
                    style={{
                      display: 'inline-block',
                      minWidth: 66,
                      padding: '6px 10px',
                      borderRadius: 999,
                      border: '1px solid #ddd',
                      color: colorForPct(r.completionPct),
                    }}
                  >
                    %{r.completionPct}
                  </span>
                </td>
                <td style={{ padding: 12, borderBottom: '1px solid #f1f1f1' }}>
                  {r.checklist.length === 0 ? (
                    <span style={{ opacity: 0.65 }}>Yok</span>
                  ) : (
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                      {r.checklist.map((c) => (
                        <span
                          key={`${r.user.id}-${c.key}`}
                          style={{
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 6,
                            padding: '6px 10px',
                            borderRadius: 999,
                            border: '1px solid #e5e5e5',
                            background: c.done ? '#ecfdf3' : '#fff7ed',
                            color: c.done ? '#166534' : '#9a3412',
                            fontSize: 12,
                          }}
                          title={c.label}
                        >
                          {c.done ? '✓' : '•'} {c.key}
                        </span>
                      ))}
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {!loading && rows.length === 0 && (
              <tr>
                <td colSpan={5} style={{ padding: 16, opacity: 0.7 }}>
                  Kayıt yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>

        <div style={{ padding: 12, display: 'flex', gap: 8, justifyContent: 'flex-end', borderTop: '1px solid #eee' }}>
          <button
            onClick={() => setSkip((v) => Math.max(v - take, 0))}
            disabled={loading || !canPrev}
            style={{ padding: '8px 12px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
          >
            Önceki
          </button>
          <button
            onClick={() => setSkip((v) => v + take)}
            disabled={loading || !canNext}
            style={{ padding: '8px 12px', borderRadius: 10, border: '1px solid #ddd', background: 'white' }}
          >
            Sonraki
          </button>
        </div>
      </div>
    </RoleShell>
  );
}
