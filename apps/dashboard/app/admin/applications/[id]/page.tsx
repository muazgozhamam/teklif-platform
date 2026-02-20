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
    <RoleShell role="ADMIN" title="Kayıt Detayı" subtitle={TYPE_LABELS[application?.type] || id} nav={[]}>
      {error ? <Alert type="error" message={error} className="mb-4" /> : null}
      {loading ? <Card><CardDescription>Yükleniyor…</CardDescription></Card> : null}

      {!loading && application ? (
        <div className="grid gap-4 xl:grid-cols-[1.4fr_1fr]">
          <Card>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <CardTitle>{application.fullName}</CardTitle>
                <CardDescription>{TYPE_LABELS[application.type] || application.type}</CardDescription>
              </div>
              <Badge variant={statusBadge(application.status)}>{STATUS_LABELS[application.status] || application.status}</Badge>
            </div>

            <div className="mt-4 grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
              <InfoRow label="Telefon" value={application.phone} />
              <InfoRow label="E-posta" value={application.email || '-'} />
              <InfoRow label="Konum" value={[application.city, application.district].filter(Boolean).join(' / ') || '-'} />
              <InfoRow label="Kaynak" value={application.source || '-'} />
              <InfoRow label="Öncelik" value={application.priority} />
              <InfoRow
                label="SLA İlk Dönüş"
                value={application.slaFirstResponseAt ? new Date(application.slaFirstResponseAt).toLocaleString('tr-TR') : '-'}
              />
            </div>

            <CardTitle className="mt-6">Notlar</CardTitle>
            <div className="mt-3 flex gap-2">
              <Input value={note} onChange={(e) => setNote(e.target.value)} placeholder="Kısa not ekle..." />
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

            <CardTitle className="mt-6">İşlem Geçmişi</CardTitle>
            <div className="mt-3 space-y-2">
              {(application.events || []).map((ev: any) => (
                <div key={ev.id} className="rounded-xl border border-[var(--border)] bg-[var(--card-2)] p-3 text-xs text-[var(--muted)]">
                  <div className="font-medium text-[var(--text)]">{eventLabel(ev.eventType)}</div>
                  <div>{new Date(ev.createdAt).toLocaleString('tr-TR')}</div>
                </div>
              ))}
            </div>
          </Card>

          <Card className="xl:sticky xl:top-4 xl:h-fit">
            <CardTitle>Aksiyonlar</CardTitle>
            <CardDescription>Kayıt durumunu güncelle, sorumlu ata veya kaydı kapat.</CardDescription>

            <div className="mt-4 grid grid-cols-1 gap-2">
              <div className="text-xs text-[var(--muted)]">Durum</div>
              <Select value={application.status} onChange={(e) => patch({ status: e.target.value })} disabled={saving}>
                {Object.entries(STATUS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </Select>

              <div className="mt-2 text-xs text-[var(--muted)]">Öncelik</div>
              <Select value={application.priority} onChange={(e) => patch({ priority: e.target.value })} disabled={saving}>
                <option value="P0">P0</option>
                <option value="P1">P1</option>
                <option value="P2">P2</option>
              </Select>

              <div className="mt-2 text-xs text-[var(--muted)]">Atanan Kişi</div>
              <Select
                value={application.assignedToUserId || ''}
                onChange={(e) => patch({ assignedToUserId: e.target.value || null })}
                disabled={saving}
              >
                <option value="">Atama yok</option>
                {users.map((u) => <option key={u.id} value={u.id}>{u.name || u.email}</option>)}
              </Select>
            </div>

            <div className="mt-4 grid grid-cols-1 gap-2">
              <Button variant="secondary" onClick={assignRoundRobin} loading={saving}>Sırayla Ata</Button>
              <Button variant="destructive" onClick={() => api.post(`/api/admin/applications/${id}/close`, { reason: 'Admin close' }).then(load)} disabled={saving}>
                Kaydı Kapat
              </Button>
            </div>
          </Card>
        </div>
      ) : null}
    </RoleShell>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--card-2)] px-3 py-2">
      <div className="text-xs text-[var(--muted)]">{label}</div>
      <div className="mt-0.5 text-sm font-medium text-[var(--text)]">{value}</div>
    </div>
  );
}

function eventLabel(type: string) {
  const map: Record<string, string> = {
    CREATED: 'Kayıt oluşturuldu',
    STATUS_CHANGED: 'Durum güncellendi',
    ASSIGNED: 'Atama yapıldı',
    NOTE_ADDED: 'Not eklendi',
    TAG_ADDED: 'Etiket eklendi',
    TAG_REMOVED: 'Etiket kaldırıldı',
    CLOSED: 'Kayıt kapatıldı',
  };
  return map[type] || type;
}

function statusBadge(status: string): 'neutral' | 'warning' | 'primary' | 'success' | 'danger' {
  if (status === 'NEW') return 'warning';
  if (status === 'QUALIFIED' || status === 'IN_REVIEW' || status === 'MEETING_SCHEDULED') return 'primary';
  if (status === 'APPROVED' || status === 'ONBOARDED') return 'success';
  if (status === 'REJECTED' || status === 'CLOSED') return 'danger';
  return 'neutral';
}
