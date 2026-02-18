# SatDedi - Dev Notes (Conversation Backup)

Bu dosya, uzun sohbetin teknik hafızasını korumak için hazırlanmıştır.
Not: Tam kelime kelime transcript yerine, üretimde işe yarayan karar/geçmiş/commit/test özeti tutulur.

## 1) Ortam ve Dağıtım Akışı
- Repo: `/Users/muazgozhamam/Desktop/teklif-platform`
- Monorepo:
  - `apps/api` (NestJS + Prisma)
  - `apps/dashboard` (Next.js 16 App Router)
- Domainler:
  - Prod Dashboard: `https://app.satdedi.com`
  - Prod API: `https://api.satdedi.com`
  - Stage Dashboard: `https://stage.satdedi.com`
  - Stage API: `https://api-stage-44dd.up.railway.app`
- Railway branch mapping kararı:
  - `develop` -> stage
  - `main` -> production

## 2) Geçilen Büyük Fazlar (Özet)

### Faz A - Release/Smoke/Domain Stabilizasyon
- Release zinciri çalıştırıldı.
- `JWT_SECRET` / `JWT_REFRESH_SECRET` eksikliği uyarıları görüldü.
- `health/metrics` 404 not edildi (observability backlog).
- Security headers (HSTS, X-Content-Type-Options) eksikliği not edildi.

### Faz B - Landing / ChatGPT-benzeri Ana Sayfa UI
- Header, giriş aksiyonları, rol butonları, suggestion card, modal yapısı iteratif geliştirildi.
- Dark/light sistem temasına otomatik uyum (`prefers-color-scheme`) yaklaşımı benimsendi.
- Chat giriş alanında örnek metin davranışı için birden çok revizyon yapıldı.
- Modal deneyimi (X, overlay, ESC, merkezleme) standartlaştırıldı.

### Faz C - Chat API entegrasyonu ve stream sorunları
- `POST /public/chat/stream` endpointi için 404/route-wiring/deploy branch problemleri çözüldü.
- Prod/Stage branch mapping hataları tespit edilip düzeltildi.
- SSE heartbeat/cleanup/disconnect davranışları iyileştirildi.
- UI tarafında proxy/doğrudan API akışlarında 500/502 debug edildi.
- OpenAI Responses format hatası tespit edildi: `input_text` yerine `output_text/refusal` format beklentisi.
- Env eksikleri (`OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`) giderildi.

### Faz D - Role-based Dashboard düzeni
- Sidebar/tokens/layout yaklaşımı OpenAI-benzeri low-contrast enterprise stile taşındı.
- Accordion sidebar + role bazlı section modeline geçildi.
- Performance modülü (admin/performance) eklendi.

### Faz E - Auth ve rol kullanıcıları
- Stage DB’de kullanıcı oluşturma/rol atama akışı defalarca debug edildi.
- Enum/kolon uyuşmazlıkları (ör. `BROKER`, `isActive`) manuel SQL + bootstrap ile düzeltildi.
- Son durumda role hesaplarıyla giriş sağlandı.

## 3) Önemli Teknik Kararlar
- UI iterasyonları önce `develop` + stage üzerinde doğrulanacak.
- Prod üzerinde doğrudan deney yapılmayacak.
- Chat tarafında sistem “SatDedi funnel” davranışına zorlanacak (kısa yönlendirme, role/form tetikleme).
- Komisyon/hakediş için ledger-first, immutable snapshot, reverse-only yaklaşımı benimsendi.

## 4) Son Büyük İş: Hakediş (Commission) Faz 1

### Son push
- Branch: `develop`
- Commit: `9db0e3d`
- Mesaj: `feat(commission): add phase1 ledger-first hakedis system`

### Kapsam
- Prisma’ya yeni hakediş modelleri eklendi:
  - `CommissionPolicyVersion`
  - `CommissionSnapshot`
  - `CommissionAllocation`
  - `CommissionLedgerEntry`
  - `CommissionPayout`
  - `CommissionPayoutAllocation`
  - `CommissionDispute`
- Migration eklendi:
  - `apps/api/prisma/migrations/20260218220000_commission_phase1/migration.sql`
- API modülü eklendi:
  - `apps/api/src/commission/*`
- Dashboard sayfaları eklendi:
  - Admin:
    - `/admin/commission`
    - `/admin/commission/pending`
    - `/admin/commission/payouts`
    - `/admin/commission/disputes`
    - `/admin/commission/deals/[dealId]`
  - Broker:
    - `/broker/commission/approval`
  - Consultant:
    - `/consultant/commission`
  - Hunter:
    - `/hunter/commission`
- Sidebar menüsüne Hakediş grupları eklendi (`role-nav.ts`).
- Dokümantasyon:
  - `docs/commission.md`

### Faz 1 business rule özeti
- Snapshot create: yalnızca `Deal.status = WON`.
- Base amount: şu an `listing.price` üzerinden çözülüyor; yoksa validation error.
- Idempotency: `idempotencyKey` unique.
- Maker-checker: oluşturan onaylayamaz (override opsiyonlu).
- Payout: allocation bazlı kısmi/tam ödeme desteklenir.
- Reverse: silme yok, ledger `DEBIT/REVERSAL` entry ile ters kayıt.

## 5) Build/Test Durumu
- `apps/api` build geçti.
- `apps/dashboard` tarafında workspace’te önceden var olan bağımsız sorunlar görüldü:
  - duplicate route conflict:
    - `/(hunter)/hunter/leads...` ve `/hunter/leads...`
  - bir adet mevcut lint/type dosya sorunu (`app/(hunter)/hunter/dashboard/page.tsx` civarı).
- Bunlar hakediş işinden bağımsız legacy/workspace kirleri olarak notlandı.

## 6) Bilinen Risk/Backlog
- Commission modeli için faz 2/3:
  - dispute lifecycle aktivasyonu
  - period lock
  - FX/tax hesaplarının gerçek iş kurallarına bağlanması
  - audit olay setinin genişletilmesi
- Stage/prod DB schema drift riski: migration rollout adımı dikkatle yapılmalı.

## 7) Sonraki Önerilen Adımlar
1. Stage API’de migration deploy et.
2. Stage dashboard + API için commission smoke test yap:
   - snapshot create
   - pending list
   - approve
   - payout
   - deal detail ledger kontrolü
3. Faz 2 backlogunu ticketlaştır:
   - partial reverse edge case
   - dispute akışı
   - payout batch raporlaması
4. Dashboard duplicate route/lint legacy sorunlarını ayrı teknik borç işi olarak temizle.

## 8) Hızlı Devam Promptu (Yeni Sohbet İçin)
Aşağıdaki metni yeni sohbete yapıştır:

"Bu dosyayı bağlam olarak kullan: `/Users/muazgozhamam/Desktop/teklif-platform/dev-notes.md`. 
Son commit `9db0e3d` üzerinden devam et. Önce stage migration + commission smoke test yap, sonra Faz 2 planını uygula."

## 9) Kritik Kimlik Bilgileri / Erişim Notları (Operasyonel)

> Bu bölüm hassas bilgi içerir. Sadece güvenli ekip içinde kullanılmalı.

### Stage / Prod giriş hesapları (rol test)
- Admin:
  - email: `admin@satdedi.com`
  - şifre: `SatDediAdmin!2026`
- Danışman:
  - email: `consultant@satdedi.com`
  - şifre: `SatDediConsultant!2026`
- İş Ortağı (Hunter):
  - email: `hunter@satdedi.com`
  - şifre: `SatDediHunter!2026`
- Broker:
  - email: `broker@satdedi.com`
  - şifre: `SatDediBroker!2026`

### DB bağlantı dizesi (Neon)
- `postgresql://neondb_owner:npg_iYbn89QmPhUL@ep-damp-morning-aga5beey-pooler.c-2.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require&schema=public`

### Ortam değişkenleri (kritik)
- API servislerinde:
  - `OPENAI_API_KEY` (stage + prod set edilmeli)
  - `OPENAI_CHAT_MODEL` (kullanılan değer: `gpt-5-mini`)
  - `JWT_SECRET`
  - `JWT_REFRESH_SECRET`
  - `DATABASE_URL`
- Dashboard servislerinde:
  - `NEXT_PUBLIC_API_BASE_URL`
    - stage için: `https://api-stage-44dd.up.railway.app`
    - prod için: `https://api.satdedi.com`

### Railway / Deploy
- Proje: `cozy-tranquility`
- Branch eşlemesi:
  - stage env: `develop`
  - production env: `main`
- Domain:
  - stage dashboard: `stage.satdedi.com`
  - prod dashboard: `app.satdedi.com`

## 10) Sık Kullanılan Doğrulama Komutları

### API health
```bash
curl -i https://api-stage-44dd.up.railway.app/health
curl -i https://api.satdedi.com/health
```

### Chat stream kontrolü
```bash
curl -N -X POST "https://api-stage-44dd.up.railway.app/public/chat/stream" \
  -H "Accept: text/event-stream" \
  -H "Content-Type: application/json" \
  -d '{"message":"Merhaba","history":[]}'
```

### Sync chat endpoint kontrolü
```bash
curl -i -X POST https://api.satdedi.com/public/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Merhaba","history":[]}'
```

### Stage kullanıcı register (gerekirse)
```bash
curl -X POST https://api-stage-44dd.up.railway.app/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"SatDedi Admin","email":"admin@satdedi.com","password":"SatDediAdmin!2026"}'
```

## 11) Stage DB DDL Kurtarma Komutları (kullanılmış)

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'Role' AND e.enumlabel = 'BROKER'
  ) THEN
    ALTER TYPE "Role" ADD VALUE 'BROKER';
  END IF;
END $$;

ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "isActive" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "approvedAt" TIMESTAMP(3);
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "approvedByUserId" TEXT;
```

## 12) Önemli Commit Geçmişi (yakın dönem)
- `9db0e3d` - Hakediş faz 1 (ledger-first)
- `43406f0` - performance-utils TS tip düzeltmesi
- `474178a` - sidebar accordion persist/auto-expand
- `52f51b2` - admin role switcher header taşınması
- `0034213` - grouped icon sidebar nav
- `f828d83` - interaction state token standardizasyonu
- `97a585c` - Sürece katıl -> modal form akışı
- `264a7e8` - Aday müşteri formu adlandırması

## 13) Halen Açık Konular (unutulmaması gerekenler)
- Dashboard duplicate route sorunu:
  - `app/(hunter)/hunter/leads/...` ile `app/hunter/leads/...` çakışıyor.
- `app/(hunter)/hunter/dashboard/page.tsx` lint/type sorunları.
- `middleware` deprecation uyarısı (Next 16): `proxy` geçişi backlog.
- Security header eksikleri (HSTS, X-Content-Type-Options) platform düzeyi tamamlanmalı.

## 14) Yeni Sohbette “Tam Devam” Mesajı

Yeni sohbete aşağıyı tek parça yapıştır:

```text
Bu dosyayı tek kaynak kabul et: /Users/muazgozhamam/Desktop/teklif-platform/dev-notes.md
Son commit: 9db0e3d (develop)
Önce stage migration + commission smoke test yap.
Sonra dashboard duplicate route/lint borçlarını temizle.
Ardından hakediş faz 2’ye geç (partial reverse + dispute activate).
```
