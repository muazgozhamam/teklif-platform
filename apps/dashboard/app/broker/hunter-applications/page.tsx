'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { api } from '@/lib/api';
import RoleShell from '@/app/_components/RoleShell';
import { requireRole } from '@/lib/auth';

type Status = 'PENDING' | 'APPROVED' | 'REJECTED';

type HunterApplication = {
  id: string;
  fullName: string;
  phone: string;
  email?: string | null;
  city?: string | null;
  district?: string | null;
  note?: string | null;
  status: Status;
  reviewNote?: string | null;
  reviewedAt?: string | null;
  createdAt: string;
  updatedAt: string;
};

function getErrMsg(e: unknown, fallback: string) {
  try {
    if (e instanceof Error && e.message) return e.message;
  } catch {}
  try {
    const obj = e as Record<string, unknown>;
    const msg = obj['message'];
    if (typeof msg === 'string' && msg) return msg;
  } catch {}
  return fallback;
}

function fmtDate(iso?: string | null) {
  if (!iso) return '-';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString();
}

export default function BrokerHunterApplicationsPage() {
  const [allowed, setAllowed] = useState(false);
  const [status, setStatus] = useState<Status>('PENDING');
  const [items, setItems] = useState<HunterApplication[]>([]);
  const [loading, setLoading] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionMsg, setActionMsg] = useState<string | null>(null);
  const [lastCred, setLastCred] = useState<{ email: string; tempPassword?: string } | null>(null);

  const reqSeq = useRef(0);

  const title = useMemo(() => `İş Ortağı Başvuruları`, []);

  async function load(currentStatus = status) {
    const seq = ++reqSeq.current;
    setLoading(true);
    setError(null);

    try {
      const res = await api.get('/broker/hunter-applications', { params: { status: currentStatus } });
      if (seq !== reqSeq.current) return;

      const data = res.data as { items?: HunterApplication[] };
      setItems(Array.isArray(data?.items) ? data.items : []);
    } catch (err: unknown) {
      setError(getErrMsg(err, 'Başvurular yüklenemedi'));
    } finally {
      setLoading(false);
    }
  }

  async function approve(id: string) {
    if (busyId) return;
    const reviewNote = window.prompt('Onay notu (opsiyonel):', 'Uygun') ?? undefined;

    setBusyId(id);
    setActionMsg(null);
    setError(null);

    try {
            const res = await api.post(`/broker/hunter-applications/${id}/approve`, { reviewNote });
      const data = res.data as { user?: { email?: string; tempPassword?: string; created?: boolean } };
      const email = data?.user?.email ? String(data.user.email) : '';
      const tempPassword = data?.user?.tempPassword ? String(data.user.tempPassword) : undefined;
      if (email) setLastCred({ email, tempPassword });
      setActionMsg(email ? `Onaylandı. Giriş bilgileri üretildi.` : 'Onaylandı.');
      await load(status);
    } catch (err: unknown) {
      setError(getErrMsg(err, 'Onaylama başarısız'));
    } finally {
      setBusyId(null);
    }
  }

  async function reject(id: string) {
    if (busyId) return;
    const reviewNote = window.prompt('Red nedeni (opsiyonel):', 'Uygun değil') ?? undefined;

    setBusyId(id);
    setActionMsg(null);
    setError(null);

    try {
      await api.post(`/broker/hunter-applications/${id}/reject`, { reviewNote });
      setLastCred(null);
      setActionMsg('Reddedildi.');
      await load(status);
    } catch (err: unknown) {
      setError(getErrMsg(err, 'Reddetme başarısız'));
    } finally {
      setBusyId(null);
    }
  }

  useEffect(() => {
    setAllowed(requireRole(['BROKER']));
  }, []);

  useEffect(() => {
    if (!allowed) return;
    void load(status);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allowed, status]);

  const counts = useMemo(() => {
    // lightweight UI hint only; not exact counts without extra endpoints
    return { shown: items.length };
  }, [items.length]);

  if (!allowed) {
    return (
      <main style={{ padding: 24, maxWidth: 960, margin: '0 auto', opacity: 0.8 }}>
        <div>Yükleniyor…</div>
      </main>
    );
  }

  return (
    <RoleShell
      role="BROKER"
      title="İş Ortağı Başvuruları"
      subtitle="Ağ başvurularını onayla veya reddet."
      nav={[
        { href: '/broker', label: 'Panel' },
        { href: '/broker/leads/pending', label: 'Bekleyen Referanslar' },
        { href: '/broker/deals/new', label: 'Yeni İşlem' },
        { href: '/broker/hunter-applications', label: 'İş Ortağı Başvuruları' },
      ]}
    >
    <div className="min-h-screen bg-gray-50">
      <div className="mx-auto max-w-6xl space-y-4 px-4 py-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
          <div>
            <h1 className="text-lg font-semibold tracking-tight text-gray-900">{title}</h1>
            <p className="mt-1 text-sm text-gray-600">
              Public başvuruları burada onaylayıp reddedebilirsin. Onaylananlar bir sonraki adımda kullanıcıya dönüşecek.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {(['PENDING', 'APPROVED', 'REJECTED'] as Status[]).map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => setStatus(s)}
                className={`rounded-md border px-3 py-2 text-sm ${
                  status === s ? 'bg-gray-900 text-white' : 'bg-white text-gray-900'
                }`}
                disabled={loading}
              >
                {s}
              </button>
            ))}
            <button
              type="button"
              onClick={() => void load(status)}
              className="ml-2 rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
              disabled={loading}
            >
              Yenile
            </button>
          </div>
        </div>

        {error ? (
          <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">{error}</div>
        ) : null}

        {actionMsg ? (
          <div className="rounded-md border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-800">
            {actionMsg}
          </div>
        ) : null}

        {lastCred ? (
          <div className="rounded-md border border-sky-200 bg-sky-50 p-3 text-sm text-sky-900">
            <div className="font-medium">Giriş Bilgileri</div>
            <div className="mt-2 space-y-1 text-xs">
              <div><span className="font-semibold">E-posta:</span> {lastCred.email}</div>
              <div><span className="font-semibold">Geçici Şifre:</span> {lastCred.tempPassword ?? '— (kullanıcı zaten vardı)'}</div>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                type="button"
                className="rounded-md border bg-white px-3 py-2 text-sm"
                onClick={async () => {
                  try { await navigator.clipboard.writeText(lastCred.email); setActionMsg('E-posta kopyalandı.'); } catch { setActionMsg(lastCred.email); }
                }}
              >
                E-postayı Kopyala
              </button>
              <button
                type="button"
                className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
                disabled={!lastCred.tempPassword}
                onClick={async () => {
                  if (!lastCred.tempPassword) return;
                  try { await navigator.clipboard.writeText(lastCred.tempPassword); setActionMsg('Şifre kopyalandı.'); } catch { setActionMsg(lastCred.tempPassword); }
                }}
              >
                Şifreyi Kopyala
              </button>
              <button
                type="button"
                className="rounded-md border bg-white px-3 py-2 text-sm"
                onClick={async () => {
                  const both = `E-posta: ${lastCred.email}\nŞifre: ${lastCred.tempPassword ?? ''}`;
                  try { await navigator.clipboard.writeText(both); setActionMsg('Bilgiler kopyalandı.'); } catch { setActionMsg(both); }
                }}
              >
                İkisini Kopyala
              </button>
              <button
                type="button"
                className="rounded-md border bg-white px-3 py-2 text-sm"
                onClick={() => setLastCred(null)}
              >
                Temizle
              </button>
            </div>
          </div>
        ) : null}


        <div className="rounded-xl border bg-white">
          <div className="flex items-center justify-between border-b px-4 py-3 text-sm text-gray-600">
            <div>{loading ? 'Yükleniyor…' : `${counts.shown} kayıt`}</div>
            <div className="text-xs text-gray-500">Route: /broker/hunter-applications</div>
          </div>

          <div className="divide-y">
            {items.length === 0 && !loading ? (
              <div className="px-4 py-10 text-center text-sm text-gray-500">Başvuru bulunamadı.</div>
            ) : null}

            {items.map((a) => (
              <div key={a.id} className="flex flex-col gap-3 px-4 py-4 md:flex-row md:items-center md:justify-between">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <div className="truncate text-sm font-semibold text-gray-900">{a.fullName}</div>
                    <div className="text-xs text-gray-500">{a.phone}</div>
                    <span className="rounded-full border px-2 py-0.5 text-xs text-gray-700">{a.status}</span>
                  </div>

                  <div className="mt-1 text-xs text-gray-600">
                    {(a.city || '-') + (a.district ? ` / ${a.district}` : '')} • Oluşturulma: {fmtDate(a.createdAt)}
                    {a.reviewedAt ? ` • İncelenme: ${fmtDate(a.reviewedAt)}` : ''}
                  </div>

                  {a.note ? <div className="mt-2 text-sm text-gray-800">{a.note}</div> : null}
                  {a.reviewNote ? <div className="mt-1 text-xs text-gray-600">İnceleme Notu: {a.reviewNote}</div> : null}
                  <div className="mt-2 text-xs text-gray-500">ID: {a.id}</div>
                </div>

                <div className="flex shrink-0 flex-wrap items-center gap-2">
                  {status === 'PENDING' ? (
                    <>
                      <button
                        type="button"
                        onClick={() => approve(a.id)}
                        disabled={busyId === a.id}
                        className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
                      >
                        {busyId === a.id ? 'İşleniyor…' : 'Onayla'}
                      </button>

                      <button
                        type="button"
                        onClick={() => reject(a.id)}
                        disabled={busyId === a.id}
                        className="rounded-md border bg-white px-3 py-2 text-sm disabled:opacity-50"
                      >
                        {busyId === a.id ? 'İşleniyor…' : 'Reddet'}
                      </button>
                    </>
                  ) : null}

                  <button
                    type="button"
                    className="rounded-md border bg-white px-3 py-2 text-sm"
                    onClick={async () => {
                      try {
                        await navigator.clipboard.writeText(a.id);
                        setActionMsg(`Başvuru ID kopyalandı: ${a.id}`);
                      } catch {
                        setActionMsg(`Başvuru ID: ${a.id}`);
                      }
                    }}
                  >
                    ID Kopyala
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="text-xs text-gray-500">
          Not: Bu ekran sadece başvuruları onaylar/reddeder. “Onaylandıktan sonra otomatik User oluşturma + isActive açma”
          bir sonraki adımda eklenecek.
        </div>
      </div>
    </div>
    </RoleShell>
  );
}
