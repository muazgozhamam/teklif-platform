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

type GooglePrediction = {
  description: string;
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

const CITIES = [
  'Adana','Adıyaman','Afyonkarahisar','Ağrı','Amasya','Ankara','Antalya','Artvin','Aydın','Balıkesir',
  'Bilecik','Bingöl','Bitlis','Bolu','Burdur','Bursa','Çanakkale','Çankırı','Çorum','Denizli',
  'Diyarbakır','Edirne','Elazığ','Erzincan','Erzurum','Eskişehir','Gaziantep','Giresun','Gümüşhane','Hakkari',
  'Hatay','Isparta','Mersin','İstanbul','İzmir','Kars','Kastamonu','Kayseri','Kırklareli','Kırşehir',
  'Kocaeli','Konya','Kütahya','Malatya','Manisa','Kahramanmaraş','Mardin','Muğla','Muş','Nevşehir',
  'Niğde','Ordu','Rize','Sakarya','Samsun','Siirt','Sinop','Sivas','Tekirdağ','Tokat',
  'Trabzon','Tunceli','Şanlıurfa','Uşak','Van','Yozgat','Zonguldak','Aksaray','Bayburt','Karaman',
  'Kırıkkale','Batman','Şırnak','Bartın','Ardahan','Iğdır','Yalova','Karabük','Kilis','Osmaniye','Düzce',
];

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

function unique(values: string[]) {
  return Array.from(new Set(values.filter(Boolean)));
}

export function LocationCascader({ value, onChange }: Props) {
  const [districts, setDistricts] = React.useState<string[]>([]);
  const [neighborhoods, setNeighborhoods] = React.useState<string[]>([]);
  const [loadingDistricts, setLoadingDistricts] = React.useState(false);
  const [loadingNeighborhoods, setLoadingNeighborhoods] = React.useState(false);

  React.useEffect(() => {
    if (!value.city) {
      setDistricts([]);
      setNeighborhoods([]);
      return;
    }
    let alive = true;
    setLoadingDistricts(true);
    loadGoogleMapsPlaces()
      .then((g) => {
        const Ctor = g.maps?.places?.AutocompleteService;
        if (!Ctor) {
          setDistricts([]);
          setLoadingDistricts(false);
          return;
        }
        const svc = new Ctor();
        svc.getPlacePredictions(
          {
            input: `${value.city} ilçeleri`,
            componentRestrictions: { country: 'tr' },
            types: ['(regions)'],
          },
          (predictions) => {
            if (!alive) return;
            const parsed = unique(
              (predictions || [])
                .map((p) => (p.terms?.[0]?.value || '').replace(/\s+İlçesi$/i, '').trim()),
            );
            setDistricts(parsed);
            setLoadingDistricts(false);
          },
        );
      })
      .catch(() => {
        if (!alive) return;
        setDistricts([]);
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
    loadGoogleMapsPlaces()
      .then((g) => {
        const Ctor = g.maps?.places?.AutocompleteService;
        if (!Ctor) {
          setNeighborhoods([]);
          setLoadingNeighborhoods(false);
          return;
        }
        const svc = new Ctor();
        svc.getPlacePredictions(
          {
            input: `${value.district}, ${value.city} mahalle`,
            componentRestrictions: { country: 'tr' },
            types: ['geocode'],
          },
          (predictions) => {
            if (!alive) return;
            const parsed = unique(
              (predictions || [])
                .map((p) => (p.terms?.[0]?.value || '').replace(/\s+Mahallesi$/i, '').trim()),
            );
            setNeighborhoods(parsed);
            setLoadingNeighborhoods(false);
          },
        );
      })
      .catch(() => {
        if (!alive) return;
        setNeighborhoods([]);
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
        >
          <option value="">İl seçin</option>
          {CITIES.map((city) => (
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
