'use client';
/* eslint-disable @typescript-eslint/no-explicit-any */

import React from 'react';
import { useParams } from 'next/navigation';
import RoleShell from '@/app/_components/RoleShell';
import { api } from '@/lib/api';
import { Alert } from '@/src/ui/components/Alert';
import { Badge } from '@/src/ui/components/Badge';
import { Button } from '@/src/ui/components/Button';
import { Card, CardDescription, CardTitle } from '@/src/ui/components/Card';
import { Input } from '@/src/ui/components/Input';
import { Select } from '@/src/ui/components/Select';
import { STATUS_LABELS, TYPE_LABELS } from '../_components/applications-shared';

export default function AdminApplicationDetailPage() {
  const params = useParams<{ id: string }>();
  const id = String(params?.id || '');

  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [note, setNote] = React.useState('');
  const [application, setApplication] = React.useState<any>(null);
  const [users, setUsers] = React.useState<Array<{ id: string; name?: string; email?: string }>>([]);

  const load = React.useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const [appRes, usersRes] = await Promise.all([
        api.get<any>(`/api/admin/applications/${id}`),
        api.get<any[]>('/api/admin/users'),
      ]);
      setApplication(appRes.data);
      setUsers(Array.isArray(usersRes.data) ? usersRes.data : []);
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Kayıt detayı alınamadı.');
    } finally {
      setLoading(false);
    }
  }, [id]);

  React.useEffect(() => {
    load();
  }, [load]);

  async function patch(data: Record<string, unknown>) {
    setSaving(true);
    setError(null);
    try {
      await api.patch(`/api/admin/applications/${id}`, data);
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Güncelleme başarısız.');
    } finally {
      setSaving(false);
    }
  }

  async function addNote() {
    if (!note.trim()) return;
    setSaving(true);
    setError(null);
    try {
      await api.post(`/api/admin/applications/${id}/notes`, { body: note.trim() });
      setNote('');
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Not eklenemedi.');
    } finally {
      setSaving(false);
    }
  }

  async function assignRoundRobin() {
    setSaving(true);
    setError(null);
    try {
      await api.post(`/api/admin/applications/${id}/assign`, {});
      await load();
    } catch (e: any) {
      setError(e?.data?.message || e?.message || 'Atama yapılamadı.');
    } finally {
      setSaving(false);
    }
  }

  if (!id) return null;

  return (
    <RoleShell role="ADMIN" title="Başvuru Detayı" subtitle={id} nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}
      {loading ? <Card><CardDescription>Yükleniyor…</CardDescription></Card> : null}

      {!loading && application ? (
        <div className="grid gap-4 xl:grid-cols-2">
          <Card>
            <CardTitle>{application.fullName}</CardTitle>
            <CardDescription>{TYPE_LABELS[application.type] || application.type}</CardDescription>
            <div className="mt-3 grid grid-cols-1 gap-2 text-sm">
              <div>Telefon: <b>{application.phone}</b></div>
              <div>Email: <b>{application.email || '-'}</b></div>
              <div>Konum: <b>{[application.city, application.district].filter(Boolean).join(' / ') || '-'}</b></div>
              <div>Kaynak: <b>{application.source || '-'}</b></div>
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              <Badge variant="primary">{STATUS_LABELS[application.status] || application.status}</Badge>
              <Badge variant="warning">{application.priority}</Badge>
              <Badge variant="neutral">SLA: {application.slaFirstResponseAt ? new Date(application.slaFirstResponseAt).toLocaleString('tr-TR') : '-'}</Badge>
            </div>

            <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-2">
              <Select value={application.status} onChange={(e) => patch({ status: e.target.value })} disabled={saving}>
                {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </Select>
              <Select value={application.priority} onChange={(e) => patch({ priority: e.target.value })} disabled={saving}>
                <option value="P0">P0</option>
                <option value="P1">P1</option>
                <option value="P2">P2</option>
              </Select>
              <Select value={application.assignedToUserId || ''} onChange={(e) => patch({ assignedToUserId: e.target.value || null })} disabled={saving} className="sm:col-span-2">
                <option value="">Atama yok</option>
                {users.map((u) => <option key={u.id} value={u.id}>{u.name || u.email}</option>)}
              </Select>
            </div>

            <div className="mt-3 flex flex-wrap gap-2">
              <Button variant="secondary" onClick={assignRoundRobin} loading={saving}>Round-robin Ata</Button>
              <Button variant="destructive" onClick={() => api.post(`/api/admin/applications/${id}/close`, { reason: 'Admin close' }).then(load)} disabled={saving}>Kapat</Button>
            </div>
          </Card>

          <Card>
            <CardTitle>Notlar</CardTitle>
            <div className="mt-3 flex gap-2">
              <Input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Not ekle..." />
              <Button onClick={addNote} loading={saving}>Ekle</Button>
            </div>
            <div className="mt-3 space-y-2">
              {(application.appNotes || []).map((n: any) => (
                <div key={n.id} className="rounded-xl border border-[var(--border)] bg-[var(--card-2)] p-3 text-sm">
                  <div className="text-xs text-[var(--muted)]">{n.author?.name || n.author?.email || '-'} • {new Date(n.createdAt).toLocaleString('tr-TR')}</div>
                  <div className="mt-1">{n.body}</div>
                </div>
              ))}
              {(!application.appNotes || application.appNotes.length === 0) ? <div className="text-sm text-[var(--muted)]">Henüz not yok.</div> : null}
            </div>

            <CardTitle className="mt-6">Olay Akışı</CardTitle>
            <div className="mt-3 space-y-2">
              {(application.events || []).map((ev: any) => (
                <div key={ev.id} className="rounded-xl border border-[var(--border)] bg-[var(--card-2)] p-3 text-xs text-[var(--muted)]">
                  <div className="font-medium text-[var(--text)]">{ev.eventType}</div>
                  <div>{new Date(ev.createdAt).toLocaleString('tr-TR')}</div>
                </div>
              ))}
            </div>
          </Card>
        </div>
      ) : null}
    </RoleShell>
  );
}
