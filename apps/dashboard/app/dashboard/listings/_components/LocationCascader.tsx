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

const PUBLIC_TR_API = 'https://turkiyeapi.dev/api/v1';
const FALLBACK_DISTRICTS: Record<string, string[]> = {
  konya: [
    'Ahırlı', 'Akören', 'Akşehir', 'Altınekin', 'Beyşehir', 'Bozkır', 'Cihanbeyli', 'Çeltik', 'Çumra',
    'Derbent', 'Derebucak', 'Doğanhisar', 'Emirgazi', 'Ereğli', 'Güneysınır', 'Hadim', 'Halkapınar', 'Hüyük',
    'Ilgın', 'Kadınhanı', 'Karapınar', 'Karatay', 'Kulu', 'Meram', 'Sarayönü', 'Selçuklu', 'Seydişehir',
    'Taşkent', 'Tuzlukçu', 'Yalıhüyük', 'Yunak',
  ],
};

const FALLBACK_NEIGHBORHOODS: Record<string, string[]> = {
  'konya::meram': ['Aşkan', 'Ayanbey', 'Dere', 'Harmancık', 'Kozağaç', 'Lalebahçe', 'Pirebi', 'Uluırmak', 'Yaka'],
  'konya::selçuklu': ['Akşemsettin', 'Bosna Hersek', 'Ferhuniye', 'Işıklar', 'Nişantaş', 'Sancak', 'Yazır'],
  'konya::karatay': ['Akabe', 'Aziziye', 'Çimenlik', 'Fevziçakmak', 'Hacıveyiszade', 'İşgalaman', 'Tatlıcak'],
};

type GooglePrediction = {
  terms?: Array<{ value?: string }>;
};

type LocalGoogle = {
  maps?: {
    places?: {
      AutocompleteService: new () => {
        getPlacePredictions: (
          request: {
            input: string;
            componentRestrictions?: { country: string };
            types?: string[];
          },
          callback: (predictions: GooglePrediction[] | null, status: string) => void,
        ) => void;
      };
    };
  };
};

function norm(value: string) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('tr-TR')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

async function fetchOptions(path: string) {
  const res = await fetch(path, { cache: 'no-store' });
  if (!res.ok) throw new Error('Lokasyon verisi alınamadı');
  return res.json() as Promise<{ cities?: string[]; districts?: string[]; neighborhoods?: string[] }>;
}

async function fetchTurkiyeApi(path: string) {
  const res = await fetch(`${PUBLIC_TR_API}${path}`, { cache: 'no-store' });
  if (!res.ok) throw new Error('Turkiye API hatası');
  const json = (await res.json()) as { data?: Array<{ name?: string }> } | Array<{ name?: string }>;
  const rows = Array.isArray(json) ? json : Array.isArray(json?.data) ? json.data : [];
  return Array.from(
    new Set(
      rows
        .map((r) => String(r?.name || '').trim())
        .filter(Boolean),
    ),
  ).sort((a, b) => a.localeCompare(b, 'tr'));
}

let mapsLoaderPromise: Promise<LocalGoogle> | null = null;

function getWindowGoogle(): LocalGoogle | undefined {
  return (window as unknown as { google?: LocalGoogle }).google;
}

async function loadGoogleMapsPlaces(): Promise<LocalGoogle> {
  if (typeof window === 'undefined') throw new Error('Tarayıcı ortamı gerekli');
  const existing = getWindowGoogle();
  if (existing?.maps?.places) return existing;
  if (mapsLoaderPromise) return mapsLoaderPromise;

  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
  if (!apiKey) throw new Error('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY tanımlı değil');

  mapsLoaderPromise = new Promise<LocalGoogle>((resolve, reject) => {
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places`;
    script.async = true;
    script.defer = true;
    script.onload = () => {
      const loaded = getWindowGoogle();
      if (loaded?.maps?.places) resolve(loaded);
      else reject(new Error('Google Places yüklenemedi'));
    };
    script.onerror = () => reject(new Error('Google Places script yüklenemedi'));
    document.head.appendChild(script);
  });
  return mapsLoaderPromise;
}

async function fetchNeighborhoodsFromGoogle(city: string, district: string): Promise<string[]> {
  try {
    const g = await loadGoogleMapsPlaces();
    const Ctor = g.maps?.places?.AutocompleteService;
    if (!Ctor) return [];
    const svc = new Ctor();
    const rows = await new Promise<string[]>((resolve) => {
      svc.getPlacePredictions(
        {
          input: `${district}, ${city} mahalle`,
          componentRestrictions: { country: 'tr' },
          types: ['geocode'],
        },
        (predictions) => {
          const names = Array.from(
            new Set(
              (predictions || [])
                .map((p) => String(p.terms?.[0]?.value || '').replace(/\s+Mahallesi$/i, '').trim())
                .filter(Boolean),
            ),
          ).sort((a, b) => a.localeCompare(b, 'tr'));
          resolve(names);
        },
      );
    });
    return rows;
  } catch {
    return [];
  }
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
      .then(async (payload) => {
        if (!alive) return;
        let next = Array.isArray(payload.districts) ? payload.districts : [];
        if (next.length === 0) {
          try {
            next = await fetchTurkiyeApi(`/districts?province=${encodeURIComponent(value.city)}`);
          } catch {
            next = [];
          }
        }
        if (next.length === 0) {
          next = FALLBACK_DISTRICTS[norm(value.city)] || [];
        }
        setDistricts(next);
      })
      .catch(() => {
        if (!alive) return;
        setDistricts(FALLBACK_DISTRICTS[norm(value.city)] || []);
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
      .then(async (payload) => {
        if (!alive) return;
        let next = Array.isArray(payload.neighborhoods) ? payload.neighborhoods : [];
        if (next.length === 0) {
          try {
            next = await fetchTurkiyeApi(
              `/neighborhoods?province=${encodeURIComponent(value.city)}&district=${encodeURIComponent(value.district)}`,
            );
          } catch {
            next = [];
          }
        }
        if (next.length === 0) {
          next = FALLBACK_NEIGHBORHOODS[`${norm(value.city)}::${norm(value.district)}`] || [];
        }
        if (next.length === 0) {
          next = await fetchNeighborhoodsFromGoogle(value.city, value.district);
        }
        setNeighborhoods(next);
      })
      .catch(() => {
        if (!alive) return;
        setNeighborhoods(FALLBACK_NEIGHBORHOODS[`${norm(value.city)}::${norm(value.district)}`] || []);
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
