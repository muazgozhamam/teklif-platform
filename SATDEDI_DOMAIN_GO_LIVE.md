# satdedi.com Domain Go-Live

Bu dokuman `satdedi.com` icin canliya cikis oncesi domain + routing + SSL kontrol adimlarini tanimlar.

## Hedef
- Dashboard alan adi: `satdedi.com`
- API alan adi: `api.satdedi.com`
- HTTPS zorunlu, health endpoint acik.

## DNS
1. `satdedi.com` icin platformun verdigi A/CNAME kayitlarini ekle.
2. `api.satdedi.com` icin API hostuna A/CNAME kaydi ekle.
3. TTL'i gecici olarak dusuk (60-300s) tut, stabil olduktan sonra arttir.

## SSL/TLS
1. Her iki host icin sertifika provisioning tamamlanmis olmali.
2. HTTP -> HTTPS redirect aktif olmali.
3. HSTS header aktif olmasi tavsiye edilir.

## API CORS/Env
- `apps/dashboard/.env.local` veya prod env:
  - `NEXT_PUBLIC_API_BASE_URL=https://api.satdedi.com`
- API env:
  - `PORT` (platform defaultu)
  - `DATABASE_URL`
  - `JWT_SECRET`
  - `JWT_REFRESH_SECRET`

## Go-Live Kontrol Komutu
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
APP_DOMAIN=satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-domain-readiness.sh
```

## Beklenen Sonuc
- `Dashboard https://satdedi.com/login status=200`
- `API health https://api.satdedi.com/health status=200`
- Script sonunda `satdedi-domain-readiness OK`

## Rollback Notu
- DNS veya SSL sorununda once API endpointini dogrula (`/health`).
- Gerekirse DNS'i onceki kayda geri al ve TTL dolumunu bekle.
