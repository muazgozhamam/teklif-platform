'use client';

import React from 'react';

type LatLng = { lat: number; lng: number };

type Props = {
  value: LatLng | null;
  onChange: (next: LatLng) => void;
  focusAddress?: {
    city?: string | null;
    district?: string | null;
    neighborhood?: string | null;
    country?: string | null;
  };
  className?: string;
};

type MapsClickEvent = {
  latLng?: {
    lat: () => number;
    lng: () => number;
  };
};

type MapsListener = { remove: () => void };

type MapsMarker = {
  setPosition: (pos: LatLng) => void;
  getPosition: () => { lat: () => number; lng: () => number } | null;
  addListener: (eventName: string, handler: () => void) => MapsListener;
};

type MapsInstance = {
  addListener: (eventName: string, handler: (e: MapsClickEvent) => void) => MapsListener;
};

type MapsNamespace = {
  Map: new (
    el: HTMLElement,
    options: {
      center: LatLng;
      zoom: number;
      mapTypeControl?: boolean;
      streetViewControl?: boolean;
      fullscreenControl?: boolean;
    },
  ) => MapsInstance;
  Marker: new (options: { position: LatLng; map: MapsInstance; draggable?: boolean }) => MapsMarker;
  Geocoder: new () => {
    geocode: (
      request: { address: string },
      callback: (
        results: Array<{ geometry?: { location?: { lat: () => number; lng: () => number } } }> | null,
        status: string,
      ) => void,
    ) => void;
  };
};

type GoogleNamespace = { maps: MapsNamespace };

declare global {
  interface Window {
    google?: GoogleNamespace;
  }
}

let mapsLoaderPromise: Promise<GoogleNamespace> | null = null;

async function loadGoogleMaps(): Promise<GoogleNamespace> {
  if (typeof window === 'undefined') throw new Error('Tarayıcı ortamı gerekli');
  if (window.google?.maps) return window.google;
  if (mapsLoaderPromise) return mapsLoaderPromise;

  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
  if (!apiKey) throw new Error('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY tanımlı değil');

  mapsLoaderPromise = new Promise<GoogleNamespace>((resolve, reject) => {
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places`;
    script.async = true;
    script.defer = true;
    script.onload = () => {
      if (window.google?.maps) resolve(window.google);
      else reject(new Error('Google Maps yüklenemedi'));
    };
    script.onerror = () => reject(new Error('Google Maps script yüklenemedi'));
    document.head.appendChild(script);
  });

  return mapsLoaderPromise;
}

export function MapPinPicker({ value, onChange, focusAddress, className }: Props) {
  const mapRef = React.useRef<HTMLDivElement | null>(null);
  const mapInstanceRef = React.useRef<MapsInstance | null>(null);
  const markerRef = React.useRef<MapsMarker | null>(null);
  const onChangeRef = React.useRef(onChange);
  const valueRef = React.useRef<LatLng | null>(value);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    onChangeRef.current = onChange;
  }, [onChange]);

  React.useEffect(() => {
    valueRef.current = value;
  }, [value]);

  React.useEffect(() => {
    let alive = true;
    let mapClickListener: MapsListener | null = null;
    let markerDragListener: MapsListener | null = null;

    async function init() {
      if (!mapRef.current) return;
      setError(null);
      try {
        const googleNs = await loadGoogleMaps();
        if (!alive || !mapRef.current) return;

        const initial = valueRef.current || { lat: 39.0, lng: 35.0 };
        const map = new googleNs.maps.Map(mapRef.current, {
          center: initial,
          zoom: valueRef.current ? 14 : 6,
          mapTypeControl: false,
          streetViewControl: false,
          fullscreenControl: false,
        });
        mapInstanceRef.current = map;

        const marker = new googleNs.maps.Marker({
          position: initial,
          map,
          draggable: true,
        });
        markerRef.current = marker;

        mapClickListener = map.addListener('click', (evt: MapsClickEvent) => {
          const lat = evt.latLng?.lat();
          const lng = evt.latLng?.lng();
          if (typeof lat !== 'number' || typeof lng !== 'number') return;
          marker.setPosition({ lat, lng });
          onChangeRef.current({ lat, lng });
        });

        markerDragListener = marker.addListener('dragend', () => {
          const pos = marker.getPosition();
          if (!pos) return;
          onChangeRef.current({ lat: pos.lat(), lng: pos.lng() });
        });
      } catch (e) {
        if (!alive) return;
        setError(e instanceof Error ? e.message : 'Harita yüklenemedi');
      }
    }

    void init();
    return () => {
      alive = false;
      mapClickListener?.remove();
      markerDragListener?.remove();
    };
  }, []);

  React.useEffect(() => {
    if (!value || !markerRef.current) return;
    markerRef.current.setPosition(value);
  }, [value]);

  const focusKey = React.useMemo(() => {
    const city = String(focusAddress?.city || '').trim();
    const district = String(focusAddress?.district || '').trim();
    const neighborhood = String(focusAddress?.neighborhood || '').trim();
    const country = String(focusAddress?.country || 'Türkiye').trim();
    return [neighborhood, district, city, country].filter(Boolean).join(', ');
  }, [focusAddress?.city, focusAddress?.district, focusAddress?.neighborhood, focusAddress?.country]);

  React.useEffect(() => {
    if (!focusKey || typeof window === 'undefined' || !window.google?.maps || !mapInstanceRef.current) return;
    const geocoder = new window.google.maps.Geocoder();
    geocoder.geocode({ address: focusKey }, (results, status) => {
      if (status !== 'OK' || !results?.length) return;
      const loc = results[0]?.geometry?.location;
      if (!loc) return;
      const lat = loc.lat();
      const lng = loc.lng();
      const anyMap = mapInstanceRef.current as unknown as { panTo?: (pos: LatLng) => void; setZoom?: (z: number) => void };
      anyMap.panTo?.({ lat, lng });
      anyMap.setZoom?.(15);
    });
  }, [focusKey]);

  return (
    <div className={className}>
      <div ref={mapRef} className="h-[320px] w-full rounded-xl border border-[var(--border)] bg-[var(--card-2)]" />
      {error ? (
        <div className="mt-2 rounded-lg border border-[var(--danger)]/40 bg-[var(--danger)]/10 px-3 py-2 text-xs">
          {error}
        </div>
      ) : null}
    </div>
  );
}
