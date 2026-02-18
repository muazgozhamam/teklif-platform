'use client';

import React from 'react';

type Intent = 'CONSULTANT_APPLY' | 'HUNTER_APPLY' | 'BUYER_HOME' | 'OWNER_SELL' | 'OWNER_RENT' | 'INVESTOR' | 'GENERIC';

type Props = {
  intent: Intent;
  submitting: boolean;
  submitted: boolean;
  onSubmit: (payload: Record<string, string>) => Promise<void>;
};

function fieldsByIntent(intent: Intent) {
  if (intent === 'CONSULTANT_APPLY') {
    return [
      { key: 'fullName', label: 'Ad Soyad', required: true },
      { key: 'cityDistrict', label: 'Şehir / İlçe', required: true },
      { key: 'experienceYears', label: 'Deneyim (yıl)', required: true },
      { key: 'workType', label: 'Çalışma tipi', required: true },
      { key: 'phone', label: 'Telefon', required: true },
      { key: 'kvkk', label: 'KVKK onayı (evet)', required: true },
    ];
  }
  if (intent === 'HUNTER_APPLY') {
    return [
      { key: 'fullName', label: 'Ad Soyad', required: true },
      { key: 'city', label: 'Şehir', required: true },
      { key: 'networkStrength', label: 'Network gücü', required: true },
      { key: 'phone', label: 'Telefon', required: true },
      { key: 'kvkk', label: 'KVKK onayı (evet)', required: true },
    ];
  }
  if (intent === 'INVESTOR') {
    return [
      { key: 'cityDistrict', label: 'İl / İlçe', required: true },
      { key: 'budgetRange', label: 'Bütçe aralığı', required: true },
      { key: 'investmentType', label: 'Yatırım tipi', required: true },
      { key: 'timeline', label: 'Zaman planı', required: true },
      { key: 'phone', label: 'Telefon', required: true },
    ];
  }
  if (intent === 'BUYER_HOME') {
    return [
      { key: 'cityDistrict', label: 'İl / İlçe', required: true },
      { key: 'budgetRange', label: 'Bütçe aralığı', required: true },
      { key: 'homeType', label: 'Daire tipi (1+1 / 2+1 / 3+1)', required: true },
      { key: 'timeline', label: 'Satın alma zamanı', required: true },
      { key: 'phone', label: 'Telefon', required: true },
    ];
  }
  return [
    { key: 'operationType', label: 'İşlem (sat / kira)', required: true },
    { key: 'cityDistrict', label: 'İl / İlçe', required: true },
    { key: 'propertyType', label: 'Mülk tipi', required: true },
    { key: 'areaRange', label: 'Metrekare aralığı', required: true },
    { key: 'priceExpectation', label: 'Fiyat beklentisi', required: true },
    { key: 'phone', label: 'Telefon', required: true },
  ];
}

export default function FormCard({ intent, submitting, submitted, onSubmit }: Props) {
  const fields = React.useMemo(() => fieldsByIntent(intent), [intent]);
  const [values, setValues] = React.useState<Record<string, string>>({});
  const [error, setError] = React.useState('');

  const title =
    intent === 'CONSULTANT_APPLY'
      ? 'Danışman Başvuru Formu'
      : intent === 'HUNTER_APPLY'
        ? 'Avcı / İş Ortağı Formu'
        : intent === 'BUYER_HOME'
          ? 'Daire Satın Alma Formu'
        : intent === 'INVESTOR'
          ? 'Yatırım Talep Formu'
          : 'Mülk Sahibi Talep Formu';

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    for (const f of fields) {
      if (f.required && !String(values[f.key] ?? '').trim()) {
        setError(`Lütfen ${f.label} alanını doldurun.`);
        return;
      }
    }
    await onSubmit(values);
  }

  return (
    <div className="w-full max-w-[88%] rounded-3xl border border-[var(--border)] bg-[var(--card-2)] px-4 py-4">
      <div className="text-sm font-semibold text-[var(--text)]">{title}</div>
      <div className="mt-1 text-xs text-[var(--muted)]">Formu tamamlamadan sohbete devam edemezsin.</div>

      <form className="mt-3 grid gap-2" onSubmit={handleSubmit}>
        {fields.map((f) => (
          <label key={f.key} className="grid gap-1 text-xs text-[var(--muted)]">
            {f.label}
            <input
              value={values[f.key] ?? ''}
              disabled={submitting || submitted}
              onChange={(e) => setValues((prev) => ({ ...prev, [f.key]: e.target.value }))}
              className="h-9 rounded-lg border border-[var(--border)] bg-[var(--card)] px-2 text-sm text-[var(--text)] focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[var(--primary)]"
            />
          </label>
        ))}
        {error ? <div className="text-xs text-[var(--danger)]">{error}</div> : null}
        <button
          type="submit"
          disabled={submitting || submitted}
          className="mt-1 h-9 rounded-lg bg-[var(--primary)] px-3 text-sm font-medium text-white disabled:opacity-60"
        >
          {submitted ? 'Gönderildi' : submitting ? 'Gönderiliyor...' : 'Formu Gönder'}
        </button>
      </form>
    </div>
  );
}
