# satdedi.com Release Day One-Shot

Bu dokuman release gunu operasyonu tek komutta calistirmak icindir.

## Hedef
- Pre-prod signoff
- Domain + SSL readiness
- Post go-live smoke

## Tek Komut
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
APP_DOMAIN=satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-release-day.sh
```

## Adimlar
1. `scripts/smoke-phase3-signoff.sh`
2. `scripts/ops/satdedi-domain-readiness.sh`
3. `scripts/ops/satdedi-post-go-live-smoke.sh`

## Beklenen Sonuc
- Tum adimlar yeşil
- Son satir: `satdedi-release-day OK`

## Not
- Lokal testte istersen `BASE_URL` ve `DASHBOARD_URL` override edebilirsin.
