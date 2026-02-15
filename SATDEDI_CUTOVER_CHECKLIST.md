# satdedi.com Cutover Checklist

Bu dokuman domain cutover aninda hizli dogrulama icindir.

## Pre-cutover
- DNS kayitlari hazir
- SSL sertifikasi aktif
- API ve dashboard yeni hostta hazir

## Cutover sonrasi tek komut
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
NEW_APP_DOMAIN=satdedi.com NEW_API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-cutover-verify.sh
```

## Opsiyonel eski domain takibi
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
OLD_APP_DOMAIN=old.example.com OLD_API_DOMAIN=api.old.example.com NEW_APP_DOMAIN=satdedi.com NEW_API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-cutover-verify.sh
```

## Beklenen Sonuc
- New app `/login` status: 200/307/308
- New api `/health` status: 200/204
- Script sonunda `satdedi-cutover-verify OK`
