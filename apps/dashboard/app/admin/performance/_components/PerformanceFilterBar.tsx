'use client';

import React from 'react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { Button } from '@/src/ui/components/Button';
import { Input } from '@/src/ui/components/Input';
import { Card } from '@/src/ui/components/Card';
import { Select } from '@/src/ui/components/Select';
import { getDefaultRange, getRangeFromSearch, type DatePreset, isoDate } from './performance-utils';

export default function PerformanceFilterBar() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const initial = getRangeFromSearch(searchParams);

  const [preset, setPreset] = React.useState<DatePreset>('30d');
  const [from, setFrom] = React.useState(initial.from);
  const [to, setTo] = React.useState(initial.to);
  const [city, setCity] = React.useState(initial.city);

  React.useEffect(() => {
    const next = getRangeFromSearch(searchParams);
    setFrom(next.from);
    setTo(next.to);
    setCity(next.city);
  }, [searchParams]);

  function applyPreset(next: DatePreset) {
    setPreset(next);
    const now = new Date();
    if (next === '7d') {
      setFrom(isoDate(new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)));
      setTo(isoDate(now));
      return;
    }
    if (next === '30d') {
      const defaults = getDefaultRange();
      setFrom(defaults.from);
      setTo(defaults.to);
      return;
    }
    if (next === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      setFrom(isoDate(start));
      setTo(isoDate(now));
    }
  }

  function onApply() {
    const qp = new URLSearchParams(searchParams.toString());
    if (from) qp.set('from', from); else qp.delete('from');
    if (to) qp.set('to', to); else qp.delete('to');
    if (city.trim()) qp.set('city', city.trim()); else qp.delete('city');
    router.push(`${pathname}?${qp.toString()}`);
  }

  return (
    <Card className="mb-4">
      <div className="grid gap-3 md:grid-cols-[190px_1fr_1fr_1fr_auto] md:items-end">
        <div className="grid gap-1">
          <label className="text-xs text-[var(--muted)]">Aralık</label>
          <Select
            value={preset}
            onChange={(e) => applyPreset(e.target.value as DatePreset)}
          >
            <option value="7d">Son 7 gün</option>
            <option value="30d">Son 30 gün</option>
            <option value="month">Bu ay</option>
            <option value="custom">Özel</option>
          </Select>
        </div>
        <div className="grid gap-1">
          <label className="text-xs text-[var(--muted)]">Başlangıç</label>
          <Input type="date" value={from} onChange={(e) => { setFrom(e.target.value); setPreset('custom'); }} />
        </div>
        <div className="grid gap-1">
          <label className="text-xs text-[var(--muted)]">Bitiş</label>
          <Input type="date" value={to} onChange={(e) => { setTo(e.target.value); setPreset('custom'); }} />
        </div>
        <div className="grid gap-1">
          <label className="text-xs text-[var(--muted)]">Şehir / Bölge</label>
          <Input placeholder="Örn. Konya" value={city} onChange={(e) => setCity(e.target.value)} />
        </div>
        <Button onClick={onApply}>Uygula</Button>
      </div>
    </Card>
  );
}
