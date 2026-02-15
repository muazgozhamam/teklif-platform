# satdedi.com Frontend Phase 1 Demo

## Amaç
Role-based dashboard akışını uçtan uca göstermek:
- Giriş
- Role landing
- KPI (read-only)
- Listing list/detail

## Çalıştırma
```bash
cd /Users/muazgozhamam/Desktop/teklif-platform
./scripts/dev-up.sh
API_BASE_URL=http://localhost:3001 DASHBOARD_BASE_URL=http://localhost:3000 ./scripts/smoke-frontend-phase1.sh
```

## Demo Hesapları
- Admin: `admin@local.dev / admin123`
- Consultant: `consultant1@test.com / pass123`
- Broker: admin panelden oluşturulabilir veya seed broker hesabı
- Hunter: admin panelden oluşturulabilir veya seed hunter hesabı

## 5 Dakika Demo Akışı
1. `http://localhost:3000/login` aç.
2. Admin ile giriş yap.
3. `http://localhost:3000/admin`:
   - KPI kartlarını doğrula.
   - `Kullanıcılar`, `Uyum Süreci`, `Komisyon` menülerini gez.
4. Consultant hesabı ile giriş yap.
5. `http://localhost:3000/consultant`:
   - KPI kartlarını doğrula.
   - `Gelen Kutusu` ve `İlanlar` geçişini kontrol et.
6. Broker hesabı ile giriş yap.
7. `http://localhost:3000/broker`:
   - KPI kartlarını doğrula.
   - `Bekleyen Leadler` ve `Yeni Deal` akışını aç.
8. Public listing sayfasını aç: `http://localhost:3000/listings`.

## Kabul Kriterleri
- Login ekranı açılıyor.
- Role guard yanlış role URL’sinde güvenli role landing’e yönlendiriyor.
- Admin/Broker/Consultant landing KPI kartları görünüyor.
- Listing sayfaları hata vermeden açılıyor.
- `scripts/smoke-frontend-phase1.sh` yeşil.
