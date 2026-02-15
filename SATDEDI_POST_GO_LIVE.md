# satdedi.com Post Go-Live Smoke

Bu dokuman, deploy sonrasi ilk 5 dakikada minimum calisma kontrolunu standardize eder.

## Hedef
- Dashboard public route'lari ayakta mi?
- API liveness/health endpoint'leri ayakta mi?
- Auth + korunmali endpoint temel akisi calisiyor mu?

## Tek Komut
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
APP_DOMAIN=satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-post-go-live-smoke.sh
```

## Beklenen Cikti
- `Dashboard /login status=200|307|308`
- `Dashboard /listings status=200|307|308`
- `API /health status=200|204`
- `Admin login ok`
- `/stats/me role=ADMIN`
- Son satir: `satdedi-post-go-live-smoke OK`

## Not
- `ADMIN_EMAIL` / `ADMIN_PASSWORD` env ile override edilebilir.
- Gercek production ortaminda demo credential yerine operasyon hesabini kullan.
