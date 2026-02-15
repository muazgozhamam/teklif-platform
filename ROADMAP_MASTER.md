# ROADMAP_MASTER

## 1) Executive Summary
Teklif Platform’un platform-seviyesi "Done" tanımı:
- Lead -> Deal -> Listing hattı deterministik, role-guard’lı ve smoke ile tekrar doğrulanabilir.
- Commission snapshot gerçek kaynak (source of truth), immutable ve raporlama uçlarıyla tüketilebilir.
- Audit trail raw + canonical kontratıyla geriye dönük uyumlu, sorgulanabilir ve güvenilir.
- Network/Org temeli (hiyerarşi + ofis/bölge) canlı akışları bozmadan devrede.
- Release süreçleri (CI/CD, migration safety, observability, backup/restore, security) üretim standardına çıkarılmış.

## 2) Principles & Guardrails
- Backward-safe migration: yıkıcı olmayan, mümkünse `IF NOT EXISTS` odaklı, reset gerektirmeyen ilerleme.
- Feature-flag first: riskli veya davranış değiştiren katmanlar flag arkasında çıkar.
- Audit immutability: geçmiş kayıtlar değiştirilmez, alias/canonical katmanı ile geriye dönük uyum korunur.
- Deterministic verification: her kritik faz en az bir smoke script ile tek komutta doğrulanır.
- Role discipline: JWT formatı ve Role enum keyfi değiştirilmez.
- No silent regressions: build/lint/test/smoke kapısından geçmeyen iş "done" sayılmaz.
- Small safe increments: fazlar küçük, izole, geri alınabilir değişim paketleriyle ilerler.

## 3) Current State Snapshot
### Tamamlanan ana yapı taşları
- Core workflow:
  - Lead -> Deal -> Listing deterministik akış aktif.
- Commission:
  - Snapshot üretimi (WON tetiklemeli) aktif.
  - Rapor uçları aktif: `/me/commissions`, `/admin/commissions`, `/broker/commissions`.
- Audit:
  - Raw + canonical alanları, alias güvenli normalize katmanı, testleri ve dokümantasyon mevcut.
- Network foundation:
  - `User.parentId` hiyerarşisi, `CommissionSplitConfig`, admin yönetim uçları, testler mevcut.
- Network read-model:
  - Upline/path/split map helper’ları ve smoke doğrulamaları mevcut.
- Commission metadata trace:
  - `networkMeta` (flagged), `splitTrace`, `officeTrace` (math değiştirmeden) aktif.
- Organization foundation:
  - Region + Office modeli ve optional scoping filtreleri eklendi.
- Verification ops:
  - Unified smoke pack ve restart-and-verify scriptleri mevcut.

### Mevcut doğrulama varlıkları (örnek)
- `scripts/smoke/smoke-pack-task45.sh`
- `scripts/smoke/run-api-verification.sh`
- `scripts/smoke/restart-and-verify-api.sh`
- `scripts/smoke/smoke-network-foundation.sh`
- `scripts/smoke-stats.sh`
- `scripts/smoke-admin-users.sh`
- `scripts/smoke-audit.sh`
- `scripts/smoke-commission-won.sh`
- `scripts/smoke-commission-reports.sh`
- `scripts/diag/diag-query-plans.sh`

## 4) Master Phases

## FAZ 1 — Core Workflow Engine
### Objective
Role bazlı Lead -> Deal -> Listing akışını deterministik ve güvenli hale getirmek.

### Scope
- Role guard + route guard standardizasyonu
- Lead lifecycle
- Deal lifecycle
- Listing pipeline
- E2E deterministic smoke

### Deliverables
- Rol matrisi ve guard politikalarının tek kaynaktan uygulanması.
- Lead status geçiş kurallarının netleştirilmesi ve doğrulanması.
- Deal assignment + status geçişlerinin stabilize edilmesi.
- Deal’den listing create/upsert akışının idempotent davranışla korunması.
- End-to-end smoke akışının tekrar üretilebilir olması.

### Acceptance Criteria
- Role dışı erişimler `403` ile reddedilir.
- Lead -> Deal -> Listing akışı tek komut smoke ile doğrulanır.
- Lint/build/test + smoke seti kırılmadan geçer.

### Dependencies
- Auth/JWT altyapısı
- Prisma schema + migrations
- Dashboard role routing

### Risks + Mitigations
- Risk: role karmaşası.
- Mitigation: endpoint-level guard + smoke coverage.
- Risk: state transition drift.
- Mitigation: durum geçiş testleri ve audit doğrulaması.

### Validation
- `scripts/smoke-consultant-inbox-listing.sh`
- `scripts/smoke-broker-approve-to-listing.sh`
- `scripts/smoke/run-api-verification.sh`

## FAZ 2 — Operation Control Layer
### Objective
Operasyonel kontrol, görünürlük ve yönetim kabiliyeti sağlamak.

### Scope
- Admin users/roles/isActive/commission config
- Dashboard role-based metrics
- Audit/timeline contract stabilizasyonu

### Deliverables
- Admin kullanıcı yönetimi + komisyon config yönetimi.
- `/stats/me` role-aware metrik endpoint’i.
- Audit API’de raw + canonical response kontratı.

### Acceptance Criteria
- Admin-only endpoint’ler non-admin için kapalı.
- Stats endpoint role’e göre beklenen alanları döner.
- Audit query/filter raw veya canonical ile eşleşir.

### Dependencies
- Auth + RBAC
- Audit module

### Risks + Mitigations
- Risk: backward compatibility kırılması.
- Mitigation: legacy action/entity alias katmanı ve testler.

### Validation
- `scripts/smoke-admin-users.sh`
- `scripts/smoke-stats.sh`
- `scripts/smoke-audit.sh`

## FAZ 3 — Commission Engine
### Objective
Commission truth katmanını immutable snapshot modeliyle stabilize etmek.

### Scope
- Commission config
- WON tetiklemeli snapshot
- Reporting endpointleri
- Snapshot immutability
- Commission değişikliklerinde audit uyumluluğu

### Deliverables
- Snapshot üretimi idempotent davranışla tekilleştirilir.
- Consultant/Broker/Admin rapor uçları standardize edilir.
- Snapshot read endpoint rol kurallarıyla korunur.
- Commission audit canonical mapping semantik olarak doğru tutulur.

### Acceptance Criteria
- Aynı deal için ikinci snapshot oluşmaz.
- Report endpointlerinde pagination + filter stabil çalışır.
- Immutable kayıtlar güncellenmeden okunur.

### Dependencies
- Deal lifecycle
- Commission config modeli

### Risks + Mitigations
- Risk: eşzamanlı WON çağrılarında duplicate.
- Mitigation: DB unique + transaction/upsert.

### Validation
- `scripts/smoke-commission-won.sh`
- `scripts/smoke-commission-reports.sh`
- `scripts/smoke-audit.sh`

## FAZ 4 — Network & Org Structure
### Objective
Organizasyonel model ve network izlerini üretime hazır temelde kurmak.

### Scope
- User hiyerarşi
- Commission split config
- Region + Office foundation
- Office/Region scoping
- `networkMeta` + `splitTrace` + `officeTrace` (flagged)
- Performans indeksleri + query plan diag

### Deliverables
- Parent/upline/path helper + admin yönetim endpointleri.
- Region/Office atamaları ve listeleri.
- Commission snapshot metadata trace yakalama (math değişmeden).
- Hot query’leri destekleyen minimal indeks seti.

### Acceptance Criteria
- Network loop/cycle güvenliği servis katmanında korunur.
- Scoping filtreleri opsiyonel ve backward-compatible çalışır.
- Flag kapalıyken davranış değişmez.
- Query plan çıktılarında index kullanım sinyalleri görülebilir.

### Dependencies
- Audit contract
- Commission snapshot akışı

### Risks + Mitigations
- Risk: metadata capture’ın commission logic’i etkilemesi.
- Mitigation: strict no-math-change kuralı + test.

### Validation
- `scripts/smoke/smoke-network-foundation.sh`
- `scripts/smoke/smoke-pack-task45.sh`
- `scripts/diag/diag-query-plans.sh`

## FAZ 5 — Finance & Allocation Ledger (CRITICAL MISSING)
### Objective
Snapshot üstünden ödeme öncesi dağıtım kayıt katmanını tamamlamak.

### Scope
- CommissionAllocation model
- V1 allocation generation (safe identity)
- Approve/Void state workflow
- CSV payout export + idempotent marking (bank entegrasyonu yok)
- Finansal integrity kuralları

### Deliverables
- Snapshot bazlı deterministic allocation üretimi.
- Admin allocation yönetim uçları (listele/approve/void).
- Export pipeline (CSV) ve duplicate-safe işaretleme.
- Integrity kontrolleri (sum/invariant) ve audit kayıtları.

### Acceptance Criteria
- Allocation üretimi idempotent çalışır.
- State transition kuralları ihlalde reddedilir.
- Export edilen toplamlar snapshot truth ile eşleşir.

### Dependencies
- Commission snapshot
- Admin auth + audit

### Risks + Mitigations
- Risk: finansal tutarsızlık.
- Mitigation: invariant testleri + immutable referans model.

### Validation
- `scripts/smoke/smoke-pack-task45.sh` (allocation mode)
- `scripts/smoke-commission-won.sh`
- Allocation service/controller testleri

## FAZ 6 — Security & Data Discipline
### Objective
Üretim güvenliğini ve veri disiplinini sertleştirmek.

### Scope
- Auth hardening (expiry/refresh stratejisi)
- Rate limiting
- Validation strictness
- Audit integrity hardening
- RBAC matrix dokümantasyonu

### Deliverables
- Token yaşam döngüsü standartları.
- API rate-limit politikası.
- DTO/validation strict modları.
- Audit tamper-evidence stratejisi.
- RBAC dokümanı + endpoint matrisi.

### Acceptance Criteria
- Yetkisiz erişim ve brute-force davranışları kontrollü engellenir.
- Kritik endpointlerde validation bypass mümkün olmaz.
- Security regression smoke/test setine bağlanır.

### Dependencies
- Auth + middleware + guards
- Audit altyapısı

### Risks + Mitigations
- Risk: aşırı katı policy ile kullanıcı deneyimi kırılması.
- Mitigation: staged rollout + flag + telemetry.

### Validation
- Security smoke seti (yeni)
- Auth integration testleri (yeni)

## FAZ 7 — Performance & Scalability
### Objective
Büyüyen veri hacminde tutarlı gecikme ve maliyet profili sağlamak.

### Scope
- Pagination standardı
- N+1 önleme
- Dashboard caching
- Background jobs + idempotency
- Load test plan/budget

### Deliverables
- Tüm liste endpointlerinde standard pagination.
- Yüksek trafikli sorgularda select minimizasyonu.
- Job queue kuralları (retry/idempotency).
- Performans bütçesi ve yük test raporları.

### Acceptance Criteria
- Kritik endpoint latency hedefleri dokümante ve ölçülebilir.
- N+1 sınıfı problemler tespit/engellenmiş olur.
- Load test sonuçları release gate’e bağlanır.

### Dependencies
- Observability
- DB indexing discipline

### Risks + Mitigations
- Risk: over-indexing ve write maliyeti.
- Mitigation: hot-query temelli minimal index yaklaşımı.

### Validation
- `scripts/diag/diag-query-plans.sh`
- Load test scriptleri (yeni)

## FAZ 8 — DevOps & Release Readiness
### Objective
Canlıya güvenli ve tekrar üretilebilir release hattı kurmak.

### Scope
- Environment/secrets yönetimi
- CI pipeline (lint/test/build/migrate/smoke)
- Backup + restore drills
- Deploy strategy + migration safety
- Observability + alerting

### Deliverables
- Ortamlar (dev/stage/prod) için net config matrisi.
- CI’da migration + smoke gate.
- Restore senaryoları ve periyodik tatbikat.
- Deploy rollback/roll-forward playbook.
- Log/metric/trace dashboard ve alarm seti.

### Acceptance Criteria
- Production release check-list’i otomatik gate’lerle enforced olur.
- Backup’tan restore süresi ve başarı oranı ölçülür.
- Critical alert’ler actionable olur.

### Dependencies
- Test/smoke güvenilirliği
- Infra erişimleri

### Risks + Mitigations
- Risk: migration sırasında downtime.
- Mitigation: backward-compatible migration + staged deploy.

### Validation
- CI pipeline artefaktları
- Release dry-run raporları

## FAZ 9 — Growth & Organization
### Objective
Ürünü ölçekli operasyon ve network büyümesine taşımak.

### Scope
- Franchise foundation
- KPI engine
- Gamification
- Reputation/trust
- Partner onboarding + training ops

### Deliverables
- Bölgesel liderlik + ofis override policy dokümanı.
- Funnel KPI modelleri (Lead->Deal->Listing->Sale).
- Rozet/level/sıralama mekanikleri.
- Partner enablement süreçleri.

### Acceptance Criteria
- KPI’lar dashboard’da ölçülebilir ve doğrulanabilir.
- Franchise policy teknik guard’larla uyumlu olur.
- Growth mekanikleri abuse riskine karşı korumalı olur.

### Dependencies
- Org model
- Performance + observability

### Risks + Mitigations
- Risk: growth feature’larının core workflow’u bozması.
- Mitigation: core’den izole rollout + smoke gates.

### Validation
- KPI smoke/report setleri (yeni)
- Growth experiment raporları

## 5) Implementation Order (Canonical Sequence)
1. FAZ 1 stabilizasyon + deterministik smoke.
2. FAZ 2 operasyon kontrolü ve audit kontratı.
3. FAZ 3 commission snapshot/report doğrulaması.
4. FAZ 4 network/org foundation + performance index disiplini.
5. FAZ 5 allocation ledger + payout export hazırlığı.
6. FAZ 6 security hardening + veri disiplini.
7. FAZ 7 performans/ölçek testleri.
8. FAZ 8 release/devops güvence katmanı.
9. FAZ 9 growth/franchise/kpi katmanı.

## 6) Definition of Done (Platform-Level)
Bir faz "done" sayılması için:
- Kod kalite kapıları:
  - `apps/api build` green
  - `apps/api test` green
  - `apps/dashboard lint` green
  - `apps/dashboard build` green (UI değiştiyse)
- Regression smoke kapıları green.
- Fazın acceptance kriterleri script/test/doküman kanıtıyla doğrulanmış.
- Migration/backward-compat değerlendirmesi tamamlanmış.
- Audit ve role-security etkisi gözden geçirilmiş.

## 7) Appendix

### A) Feature Flags
- `NETWORK_COMMISSIONS_ENABLED` (default: `false`)
  - Amaç: Snapshot’a network metadata (`networkMeta`) capture.
- `COMMISSION_ALLOCATION_ENABLED` (default: `false`)
  - Amaç: Snapshot sonrası allocation generation (v1 ledger).
- `AUTO_SEED_ADMIN` (script-level, default: `1`)
  - Amaç: `restart-and-verify` öncesi admin/demo user seed.

### B) Key Endpoints by Role
#### ADMIN
- `/admin/users` (GET/POST), `/admin/users/:id` (PATCH/DELETE)
- `/admin/users/:id/set-password` (POST)
- `/admin/commission-config` (GET/PATCH)
- `/admin/network/parent` (POST)
- `/admin/network/:userId/path` (GET)
- `/admin/network/:userId/upline` (GET)
- `/admin/network/commission-split` (GET/POST)
- `/admin/org/regions` (GET/POST)
- `/admin/org/offices` (GET/POST)
- `/admin/org/offices/:officeId/users` (GET)
- `/admin/org/regions/:regionId/offices` (GET)
- `/admin/org/users/office` (POST)
- `/admin/org/leads/region` (POST)
- `/admin/deals` (GET)
- `/admin/commissions` (GET)
- `/admin/audit` (GET)
- `/admin/allocations` (GET)
- `/admin/allocations/:id/approve` (POST)
- `/admin/allocations/:id/void` (POST)
- `/admin/allocations/export.csv` (GET)
- `/admin/allocations/export/mark` (POST)
- `/admin/onboarding/users` (GET)

#### BROKER
- `/broker/leads/pending` (GET)
- `/broker/leads/pending/paged` (GET)
- `/broker/leads/:id/approve` (POST)
- `/broker/leads/:id/reject` (POST)
- `/broker/leads/:id/deal` (POST)
- `/broker/commissions` (GET)
- `/deals/:id/won` (POST, policy’ye göre ADMIN/BROKER)

#### HUNTER
- `/hunter/leads` (GET/POST)

#### CONSULTANT
- `/deals/inbox/mine` (GET)
- `/deals/inbox/pending` (GET)
- `/me/commissions` (GET)
- `/onboarding/me` (GET)
- `/listings/deals/:dealId/listing` (POST/GET)

#### COMMON
- `/health` (GET)
- `/auth/login` (POST)
- `/auth/me` (GET)
- `/stats/me` (GET)

### C) Audit Canonical Actions/Entities + Alias List
#### Canonical entity tipleri
- `LEAD`, `DEAL`, `LISTING`, `REGION`, `OFFICE`, `USER`, `COMMISSION_CONFIG`, `AUTH`

#### Canonical action örnekleri
- `LEAD_CREATED`, `LEAD_STATUS_CHANGED`
- `DEAL_CREATED`, `DEAL_ASSIGNED`, `DEAL_STATUS_CHANGED`
- `LISTING_UPSERTED`, `LISTING_PUBLISHED`, `LISTING_SOLD`
- `USER_CREATED`, `USER_PATCHED`, `USER_PASSWORD_SET`
- `COMMISSION_SNAPSHOT_CREATED`, `COMMISSION_SNAPSHOT_NETWORK_CAPTURED`
- `NETWORK_PARENT_SET`, `COMMISSION_SPLIT_CONFIG_SET`
- `REGION_CREATED`, `OFFICE_CREATED`, `USER_OFFICE_ASSIGNED`, `LEAD_REGION_ASSIGNED`
- `COMMISSION_ALLOCATED`, `COMMISSION_ALLOCATION_APPROVED`, `COMMISSION_ALLOCATION_VOIDED`
- `LOGIN_DENIED_INACTIVE`

#### Legacy/alias uyumluluk
- Raw legacy action’lar tutulur (drop edilmez).
- Alias örnekleri canonical’a normalize edilir (örn. commission update varyantları).
- Filter semantiği: raw == query OR canonical == query.

### D) Smoke Scripts & Coverage
- `scripts/smoke/run-api-verification.sh`
  - API health + smoke-pack wrapper.
- `scripts/smoke/restart-and-verify-api.sh`
  - API restart + health wait + verify, ops akışı.
- `scripts/smoke/smoke-pack-task45.sh`
  - Network + org + audit canonical + snapshot metadata + (opsiyonel) allocation.
- `scripts/smoke/smoke-network-foundation.sh`
  - Parent/path/upline/split + audit doğrulaması.
- `scripts/smoke-admin-users.sh`
  - Admin users/role/isActive davranışları.
- `scripts/smoke-stats.sh`
  - Role bazlı `/stats/me` doğrulaması.
- `scripts/smoke-audit.sh`
  - Lead/Deal/Listing/commission audit akış doğrulaması.
- `scripts/smoke-commission-won.sh`
  - WON -> snapshot idempotency + amount checks.
- `scripts/smoke-commission-reports.sh`
  - Consultant/broker/admin rapor endpointleri.
- `scripts/smoke-onboarding.sh`
  - Onboarding read-model (`/onboarding/me`, `/admin/onboarding/users`) doğrulaması.

### E) Data Model Glossary
- Lead: Talep/aday kayıt girdisi, ilk operasyon nesnesi.
- Deal: Lead’den türeyen işlem/satış fırsatı nesnesi.
- Listing: Deal’den üretilen ilan/portföy nesnesi.
- CommissionSnapshot: WON anındaki immutable komisyon truth kaydı.
- CommissionAllocation: Snapshot bazlı ödeme öncesi dağıtım ledger satırı.
- Region: Coğrafi segment (city/district).
- Office: Operasyonel birim, region’a bağlı, broker yönetimli olabilir.
- Network (User hierarchy): Kullanıcı parent-child hiyerarşisi.
