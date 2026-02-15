# satdedi.com Frontend Phase 2 Demo

## Amaç
Phase 2 ile eklenen operasyonel iyileştirmeleri göstermek:
- Role landing ekranlarında hızlı yenile + son güncelleme
- Public listings sayfasında filtre + pagination
- Broker -> Consultant handoff akışı (dealId query)
- Admin users/audit gelişmiş filtreler

## Çalıştırma
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
API_BASE_URL=http://localhost:3001 DASHBOARD_BASE_URL=http://localhost:3000 ./scripts/smoke-frontend-phase2-signoff.sh
```

## Demo Hesapları
- Admin: `admin@local.dev / admin123`
- Consultant: `consultant1@test.com / pass123`

## 6 Dakika Demo Akışı
1. `http://localhost:3000/admin` aç.
2. KPI kartları üstünde `Yenile` butonu ve `Son güncelleme` alanını doğrula.
3. `http://localhost:3000/admin/users`:
   - Rol filtresi + aktiflik filtresi kullan.
4. `http://localhost:3000/admin/audit`:
   - `from/to` filtreleri ile kayıt araması yap.
5. `http://localhost:3000/listings?status=PUBLISHED&page=1&pageSize=12&q=istanbul` aç:
   - filtreli listeleme + boş durum + pagination kontrol et.
6. `http://localhost:3000/consultant/inbox?dealId=<dealId>&tab=mine` aç:
   - hedef deal odaklama ve sekme davranışını kontrol et.

## Kabul Kriterleri
- Phase 2 signoff scripti yeşil.
- Admin/Broker/Consultant/Hunter route’ları kırılmadan açılıyor (200/redirect).
- Listings filtre/pagination çalışıyor.
- Consultant inbox query handoff route çalışıyor.
