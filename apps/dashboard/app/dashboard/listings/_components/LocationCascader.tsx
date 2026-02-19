'use client';

import React from 'react';

type LocationValue = {
  city: string;
  district: string;
  neighborhood: string;
};

type Props = {
  value: LocationValue;
  onChange: (next: LocationValue) => void;
};

async function fetchOptions(path: string) {
  const res = await fetch(path, { cache: 'no-store' });
  if (!res.ok) throw new Error('Lokasyon verisi alınamadı');
  return res.json() as Promise<{ cities?: string[]; districts?: string[]; neighborhoods?: string[] }>;
}

export function LocationCascader({ value, onChange }: Props) {
  const [cities, setCities] = React.useState<string[]>([]);
  const [districts, setDistricts] = React.useState<string[]>([]);
  const [neighborhoods, setNeighborhoods] = React.useState<string[]>([]);
  const [loadingCities, setLoadingCities] = React.useState(false);
  const [loadingDistricts, setLoadingDistricts] = React.useState(false);
  const [loadingNeighborhoods, setLoadingNeighborhoods] = React.useState(false);

  React.useEffect(() => {
    let alive = true;
    setLoadingCities(true);
    fetchOptions('/api/public/listings/locations/cities')
      .then((payload) => {
        if (!alive) return;
        setCities(Array.isArray(payload.cities) ? payload.cities : []);
      })
      .catch(() => {
        if (!alive) return;
        setCities([]);
      })
      .finally(() => {
        if (!alive) return;
        setLoadingCities(false);
      });
    return () => {
      alive = false;
    };
  }, []);

  React.useEffect(() => {
    if (!value.city) {
      setDistricts([]);
      setNeighborhoods([]);
      return;
    }
    let alive = true;
    setLoadingDistricts(true);
    fetchOptions(`/api/public/listings/locations/districts?city=${encodeURIComponent(value.city)}`)
      .then((payload) => {
        if (!alive) return;
        const next = Array.isArray(payload.districts) ? payload.districts : [];
        setDistricts(next);
      })
      .catch(() => {
        if (!alive) return;
        setDistricts([]);
      })
      .finally(() => {
        if (!alive) return;
        setLoadingDistricts(false);
      });
    return () => {
      alive = false;
    };
  }, [value.city]);

  React.useEffect(() => {
    if (!value.city || !value.district) {
      setNeighborhoods([]);
      return;
    }
    let alive = true;
    setLoadingNeighborhoods(true);
    fetchOptions(
      `/api/public/listings/locations/neighborhoods?city=${encodeURIComponent(value.city)}&district=${encodeURIComponent(value.district)}`,
    )
      .then((payload) => {
        if (!alive) return;
        const next = Array.isArray(payload.neighborhoods) ? payload.neighborhoods : [];
        setNeighborhoods(next);
      })
      .catch(() => {
        if (!alive) return;
        setNeighborhoods([]);
      })
      .finally(() => {
        if (!alive) return;
        setLoadingNeighborhoods(false);
      });
    return () => {
      alive = false;
    };
  }, [value.city, value.district]);

  return (
    <div className="grid gap-2">
      <label className="grid gap-1">
        <span className="text-xs text-[var(--muted)]">İl *</span>
        <select
          className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
          value={value.city}
          onChange={(e) => onChange({ city: e.target.value, district: '', neighborhood: '' })}
          disabled={loadingCities}
        >
          <option value="">{loadingCities ? 'İller yükleniyor...' : 'İl seçin'}</option>
          {cities.map((city) => (
            <option key={city} value={city}>
              {city}
            </option>
          ))}
        </select>
      </label>

      <label className="grid gap-1">
        <span className="text-xs text-[var(--muted)]">İlçe *</span>
        <select
          className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
          value={value.district}
          onChange={(e) => onChange({ ...value, district: e.target.value, neighborhood: '' })}
          disabled={!value.city || loadingDistricts}
        >
          <option value="">
            {!value.city ? 'Önce il seçin' : loadingDistricts ? 'İlçeler yükleniyor...' : 'İlçe seçin'}
          </option>
          {districts.map((district) => (
            <option key={district} value={district}>
              {district}
            </option>
          ))}
        </select>
      </label>

      <label className="grid gap-1">
        <span className="text-xs text-[var(--muted)]">Mahalle *</span>
        <select
          className="h-10 rounded-xl border border-[var(--border)] bg-[var(--card)] px-3 text-sm"
          value={value.neighborhood}
          onChange={(e) => onChange({ ...value, neighborhood: e.target.value })}
          disabled={!value.city || !value.district || loadingNeighborhoods}
        >
          <option value="">
            {!value.city || !value.district
              ? 'Önce il ve ilçe seçin'
              : loadingNeighborhoods
                ? 'Mahalleler yükleniyor...'
                : 'Mahalle seçin'}
          </option>
          {neighborhoods.map((neighborhood) => (
            <option key={neighborhood} value={neighborhood}>
              {neighborhood}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}
