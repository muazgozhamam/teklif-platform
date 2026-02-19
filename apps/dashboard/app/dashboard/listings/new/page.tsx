'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { requireAuth } from '@/lib/auth';
import { Button } from '@/src/ui/components/Button';
import { Input } from '@/src/ui/components/Input';
import { Card } from '@/src/ui/components/Card';

type FormState = {
  categoryLeafPathKey: string;
  title: string;
  description: string;
  priceAmount: string;
  city: string;
  district: string;
  neighborhood: string;
  lat: string;
  lng: string;
  privacyMode: 'EXACT' | 'APPROXIMATE' | 'HIDDEN';
};

const INITIAL: FormState = {
  categoryLeafPathKey: '',
  title: '',
  description: '',
  priceAmount: '',
  city: '',
  district: '',
  neighborhood: '',
  lat: '',
  lng: '',
  privacyMode: 'EXACT',
};

export default function NewListingWizardPage() {
  const router = useRouter();
  const [allowed, setAllowed] = React.useState(false);
  const [step, setStep] = React.useState(1);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [categoryLeaves, setCategoryLeaves] = React.useState<Array<{ pathKey: string; name: string }>>([]);
  const [form, setForm] = React.useState<FormState>(INITIAL);

  React.useEffect(() => {
    setAllowed(requireAuth());
  }, []);

  React.useEffect(() => {
    let alive = true;
    fetch('/api/public/listings/categories/leaves', { cache: 'no-store' })
      .then(async (res) => {
        if (!res.ok) throw new Error('Kategori listesi alınamadı');
        return res.json();
      })
      .then((rows: Array<{ pathKey: string; name: string }>) => {
        if (!alive) return;
        const next = Array.isArray(rows) ? rows : [];
        setCategoryLeaves(next);
        setForm((prev) => ({
          ...prev,
          categoryLeafPathKey: prev.categoryLeafPathKey || next[0]?.pathKey || '',
        }));
      })
      .catch(() => {
        if (!alive) return;
        setCategoryLeaves([]);
      });
    return () => {
      alive = false;
    };
  }, []);

  function setField<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  const stepOneValid = form.categoryLeafPathKey.trim() && form.title.trim() && form.description.trim() && form.priceAmount.trim();
  const stepTwoValid = form.city.trim() && form.district.trim() && form.neighborhood.trim();
  const stepThreeValid = form.lat.trim() && form.lng.trim();

  async function createListing() {
    if (!stepOneValid || !stepTwoValid || !stepThreeValid) {
      setError('Yayın için tüm zorunlu alanları ve map pin konumunu doldur.');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const created = await api.post<{ id: string }>('/listings', {
        categoryLeafPathKey: form.categoryLeafPathKey,
        title: form.title,
        description: form.description,
        priceAmount: form.priceAmount,
        city: form.city,
        district: form.district,
        neighborhood: form.neighborhood,
        lat: Number(form.lat),
        lng: Number(form.lng),
        privacyMode: form.privacyMode,
      });
      const id = String(created.data?.id || '');
      if (id) {
        router.push(`/dashboard/listings/${id}/edit`);
      } else {
        throw new Error('İlan oluşturuldu ama id dönmedi.');
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'İlan oluşturulamadı');
    } finally {
      setSaving(false);
    }
  }

  if (!allowed) return null;

  return (
    <main className="min-h-screen bg-[var(--bg)] px-4 py-6 text-[var(--text)] md:px-8">
      <div className="mx-auto w-full max-w-[900px]">
        <div className="mb-4">
          <h1 className="text-xl font-semibold">Yeni İlan Wizard</h1>
          <p className="text-sm text-[var(--muted)]">Map pin zorunlu. Pin olmadan yayın adımına geçemezsin.</p>
        </div>

        <Card className="mb-3 flex items-center gap-2">
          <Button variant={step === 1 ? 'primary' : 'secondary'} onClick={() => setStep(1)}>1. Temel Bilgi</Button>
          <Button variant={step === 2 ? 'primary' : 'secondary'} onClick={() => setStep(2)}>2. Konum</Button>
          <Button variant={step === 3 ? 'primary' : 'secondary'} onClick={() => setStep(3)}>3. Map Pin</Button>
        </Card>

        {step === 1 ? (
          <Card className="grid gap-3">
            <select
              className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
              value={form.categoryLeafPathKey}
              onChange={(e) => setField('categoryLeafPathKey', e.target.value)}
            >
              {categoryLeaves.map((leaf) => (
                <option key={leaf.pathKey} value={leaf.pathKey}>
                  {leaf.name} ({leaf.pathKey})
                </option>
              ))}
            </select>
            <Input placeholder="Başlık *" value={form.title} onChange={(e) => setField('title', e.target.value)} />
            <textarea
              className="min-h-[120px] rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 py-2 text-sm outline-none"
              placeholder="Açıklama *"
              value={form.description}
              onChange={(e) => setField('description', e.target.value)}
            />
            <Input placeholder="Fiyat *" value={form.priceAmount} onChange={(e) => setField('priceAmount', e.target.value)} />
            <div className="flex justify-end">
              <Button variant="primary" disabled={!stepOneValid} onClick={() => setStep(2)}>Devam</Button>
            </div>
          </Card>
        ) : null}

        {step === 2 ? (
          <Card className="grid gap-3">
            <Input placeholder="İl *" value={form.city} onChange={(e) => setField('city', e.target.value)} />
            <Input placeholder="İlçe *" value={form.district} onChange={(e) => setField('district', e.target.value)} />
            <Input placeholder="Mahalle *" value={form.neighborhood} onChange={(e) => setField('neighborhood', e.target.value)} />
            <select
              className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
              value={form.privacyMode}
              onChange={(e) => setField('privacyMode', e.target.value as FormState['privacyMode'])}
            >
              <option value="EXACT">Konum: Exact</option>
              <option value="APPROXIMATE">Konum: Approximate</option>
              <option value="HIDDEN">Konum: Hidden</option>
            </select>
            <div className="flex justify-between">
              <Button variant="secondary" onClick={() => setStep(1)}>Geri</Button>
              <Button variant="primary" disabled={!stepTwoValid} onClick={() => setStep(3)}>Devam</Button>
            </div>
          </Card>
        ) : null}

        {step === 3 ? (
          <Card className="grid gap-3">
            <div className="text-sm text-[var(--muted)]">
              Harita pin zorunlu. Şimdilik lat/lng manuel giriliyor.
            </div>
            <Input placeholder="Latitude * (örn: 37.871)" value={form.lat} onChange={(e) => setField('lat', e.target.value)} />
            <Input placeholder="Longitude * (örn: 32.484)" value={form.lng} onChange={(e) => setField('lng', e.target.value)} />
            <div className="flex justify-between">
              <Button variant="secondary" onClick={() => setStep(2)}>Geri</Button>
              <Button variant="primary" loading={saving} disabled={!stepThreeValid} onClick={createListing}>
                Taslak Oluştur
              </Button>
            </div>
          </Card>
        ) : null}

        {error ? <div className="mt-3 rounded-lg border border-[var(--danger)]/40 bg-[var(--danger)]/10 px-3 py-2 text-sm">{error}</div> : null}
      </div>
    </main>
  );
}
