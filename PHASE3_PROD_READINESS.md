# Phase 3 Prod Readiness (satdedi.com)

Bu dokuman Phase 3'e giris kontrol listesidir.

## Hedef
- Canliya gecis oncesi minimum teknik kapilari tek komutla dogrulamak.
- Build/lint/health ve temel env kontrollerini standartlastirmak.

## Hazirlik
- API ve dashboard lokal/staging ortamda ayakta olmali.
- `apps/api/.env` ve `apps/dashboard/.env.local` dosyalari ortama gore ayarlanmis olmali.

## Tek Komut Readiness
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
BASE_URL=http://localhost:3001 DASHBOARD_URL=http://localhost:3000 ./scripts/smoke-phase3-readiness.sh
```

## Opsiyonel Frontend Signoff ile
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
BASE_URL=http://localhost:3001 DASHBOARD_URL=http://localhost:3000 RUN_FRONTEND_SIGNOFF=1 ./scripts/smoke-phase3-readiness.sh
```

## Kontrol Edilenler
1. API health (`/health`)
2. Dashboard login route (`/login`)
3. Env anahtar varlik kontrolu (hizli)
4. `apps/api build`
5. `apps/dashboard lint`
6. `apps/dashboard next build --webpack`
7. (opsiyonel) Phase 2 frontend signoff scripti

## Notlar
- Env kontrolu bu asamada uyarilar verir; fail etmez.
- Gercek production deploy, secrets manager ve SSL/domain adimlari bir sonraki alt taskta tamamlanir.
