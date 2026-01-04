'use client';

import { useMemo, useState } from 'react';
const API_BASE = (
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE ||
  'http://localhost:3001'
).replace(/\/+$/, '');

type DraftLead = {
  title: string;
  city: string;
  district: string;
  type: string; // satılık/kiralık/arsa/dükkan vb.
  budget: string;
  notes: string;
};

export default function HunterNewLeadPage() {
  const [draft, setDraft] = useState<DraftLead>({
    title: '',
    city: '',
    district: '',
    type: 'satılık',
    budget: '',
    notes: '',
  });

  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<{ leadId: string } | null>(null);
  const canSubmit = useMemo(() => {
    return draft.title.trim().length >= 3 && draft.city.trim().length >= 2;
  }, [draft.title, draft.city]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit || submitting) return;

    setSubmitting(true);
    setResult(null);

    // Hunter formunu şimdilik /leads initialText'e serialize ediyoruz.
    const initialText = [
      `Hunter Lead`,
      `Başlık: ${draft.title}`.trim(),
      `Tür: ${draft.type}`.trim(),
      `Şehir: ${draft.city}`.trim(),
      draft.district.trim() ? `İlçe/Bölge: ${draft.district}` : '',
      draft.budget.trim() ? `Bütçe/Fiyat: ${draft.budget}` : '',
      draft.notes.trim() ? `Not: ${draft.notes}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    try {
      const token = localStorage.getItem('accessToken') || '';

      const r = await fetch(`${API_BASE}/hunter/leads`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ initialText }),
      });

      if (!r.ok) {
        const t = await r.text().catch(() => '');
        alert(`Lead gönderilemedi. HTTP ${r.status}
${t.slice(0, 200)}`);
        return;
      }

      let leadId = '';
      try {
        const data = (await r.json()) as { id?: string; leadId?: string };
        leadId = (data.leadId || data.id || '').toString();
      } catch {
        const t = await r.text().catch(() => '');
        const m = t.match(/"id"\s*:\s*"([^"]+)"/);
        leadId = (m?.[1] || '').toString();
      }

      if (!leadId) {
        alert('Lead oluşturuldu ama leadId dönmedi. Response formatını kontrol etmemiz gerekiyor.');
        return;
      }

      setResult({ leadId });
    } catch (err) {
      alert('Lead gönderilemedi (network).');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main style={{ padding: 24, maxWidth: 960, margin: '0 auto' }}>
      <div style={{ marginBottom: 16 }}>
        <a href="/hunter" style={{ textDecoration: 'none', opacity: 0.85 }}>
          ← Hunter Dashboard
        </a>
      </div>

      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Lead Gönder</h1>
      <p style={{ opacity: 0.8, marginBottom: 16 }}>
        Bu ekran skeleton. Sonraki adımda API’ye bağlayıp lead’i sisteme düşüreceğiz.
      </p>

      
      {result ? (
        <div
          style={{
            border: '1px solid rgba(0,0,0,0.12)',
            borderRadius: 12,
            padding: 14,
            marginBottom: 14,
          }}
        >
          <div style={{ fontWeight: 700, marginBottom: 6 }}>Lead gönderildi</div>
          <div style={{ opacity: 0.85, marginBottom: 10 }}>
            Lead ID: <code>{result.leadId}</code>
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button
              type="button"
              onClick={() => navigator.clipboard.writeText(result.leadId)}
              style={{
                padding: '10px 14px',
                borderRadius: 10,
                border: '1px solid rgba(0,0,0,0.18)',
                cursor: 'pointer',
                fontWeight: 600,
              }}
            >
              Kopyala
            </button>
            <a
              href="/hunter"
              style={{
                padding: '10px 14px',
                borderRadius: 10,
                border: '1px solid rgba(0,0,0,0.18)',
                textDecoration: 'none',
                display: 'inline-flex',
                alignItems: 'center',
                opacity: 0.9,
              }}
            >
              Hunter Dashboard
            </a>
          </div>
        </div>
      ) : null}

<form
        onSubmit={onSubmit}
        style={{
          border: '1px solid rgba(0,0,0,0.12)',
          borderRadius: 12,
          padding: 16,
        }}
      >
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={{ fontWeight: 600 }}>Başlık</span>
            <input disabled={!!result}
              value={draft.title}
              onChange={(e) => setDraft({ ...draft, title: e.target.value })}
              placeholder="Örn: 2+1 Satılık Daire (Meram)"
              style={{ padding: 10, borderRadius: 10, border: '1px solid rgba(0,0,0,0.18)' }}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={{ fontWeight: 600 }}>Emlak Türü</span>
            <select disabled={!!result}
              value={draft.type}
              onChange={(e) => setDraft({ ...draft, type: e.target.value })}
              style={{ padding: 10, borderRadius: 10, border: '1px solid rgba(0,0,0,0.18)' }}
            >
              <option value="satılık">Satılık</option>
              <option value="kiralık">Kiralık</option>
              <option value="arsa">Arsa</option>
              <option value="dükkan">Dükkan</option>
              <option value="ofis">Ofis</option>
              <option value="diğer">Diğer</option>
            </select>
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={{ fontWeight: 600 }}>Şehir</span>
            <input disabled={!!result}
              value={draft.city}
              onChange={(e) => setDraft({ ...draft, city: e.target.value })}
              placeholder="Örn: Konya"
              style={{ padding: 10, borderRadius: 10, border: '1px solid rgba(0,0,0,0.18)' }}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={{ fontWeight: 600 }}>İlçe / Bölge</span>
            <input disabled={!!result}
              value={draft.district}
              onChange={(e) => setDraft({ ...draft, district: e.target.value })}
              placeholder="Örn: Meram"
              style={{ padding: 10, borderRadius: 10, border: '1px solid rgba(0,0,0,0.18)' }}
            />
          </label>

          <label style={{ display: 'grid', gap: 6 }}>
            <span style={{ fontWeight: 600 }}>Bütçe / Fiyat</span>
            <input disabled={!!result}
              value={draft.budget}
              onChange={(e) => setDraft({ ...draft, budget: e.target.value })}
              placeholder="Örn: 3.500.000 TL"
              style={{ padding: 10, borderRadius: 10, border: '1px solid rgba(0,0,0,0.18)' }}
            />
          </label>

          <div />
        </div>

        <label style={{ display: 'grid', gap: 6, marginTop: 12 }}>
          <span style={{ fontWeight: 600 }}>Notlar</span>
          <textarea disabled={!!result}
            value={draft.notes}
            onChange={(e) => setDraft({ ...draft, notes: e.target.value })}
            placeholder="Örn: bina yaşı, kat, cephe, takas, aciliyet, vb."
            rows={5}
            style={{ padding: 10, borderRadius: 10, border: '1px solid rgba(0,0,0,0.18)' }}
          />
        </label>

        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <button
            type="submit"
            disabled={!canSubmit || submitting}
            style={{
              padding: '10px 14px',
              borderRadius: 10,
              border: '1px solid rgba(0,0,0,0.18)',
              cursor: !canSubmit || submitting ? 'not-allowed' : 'pointer',
              opacity: !canSubmit || submitting ? 0.6 : 1,
              fontWeight: 600,
            }}
          >
            {submitting ? 'Gönderiliyor…' : 'Lead Gönder'}
          </button>

          <a
            href="/hunter"
            style={{
              padding: '10px 14px',
              borderRadius: 10,
              border: '1px solid rgba(0,0,0,0.18)',
              textDecoration: 'none',
              display: 'inline-flex',
              alignItems: 'center',
              opacity: 0.9,
            }}
          >
            Vazgeç
          </a>
        </div>
      </form>
    </main>
  );
}
