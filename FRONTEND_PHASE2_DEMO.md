# satdedi.com Frontend Phase 2 Demo

## Amaç
Phase 2 kapsamını tek akışta doğrulamak:
- Role landing derinleştirmeleri
- Public listings UX iyileştirmeleri
- Admin kullanıcı/audit filtreleri
- Broker/Consultant handoff iyileştirmeleri

## Tek Komut Signoff
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
API_BASE_URL=http://localhost:3001 DASHBOARD_BASE_URL=http://localhost:3000 ./scripts/smoke-frontend-phase2-signoff.sh
```

## Manuel Demo Akışı (5-7 dk)
1. `http://localhost:3000/login` aç.
2. Admin ile giriş yap ve `admin`, `admin/users`, `admin/audit` ekranlarında filtre davranışlarını kontrol et.
3. Consultant ile giriş yap ve `consultant` ile `consultant/inbox` sayfalarını kontrol et.
4. Public `listings` sayfasında arama/filtre/pagination davranışlarını kontrol et.

## Kabul Kriterleri
- Script yeşil (`smoke-frontend-phase2-signoff OK`).
- Role guard yanlış role URL'lerinde güvenli yönlendirme yapıyor.
- Admin operasyon ekranları filtrelerle birlikte hata vermeden açılıyor.
- Consultant handoff akışı (`dealId` odaklı) bozulmadan çalışıyor.
