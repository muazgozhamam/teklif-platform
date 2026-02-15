# satdedi.com Ops Handover (Final)

Bu dokuman, teknik teslim sonrasi operasyon ekibinin gunluk/haftalik calisma akisini standardize eder.

## 1) Gunluk Rutine Baslangic (5-10 dk)
1. Domain/health kontrolu:
   - `APP_DOMAIN=satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-domain-readiness.sh`
2. Post go-live smoke:
   - `APP_DOMAIN=satdedi.com API_DOMAIN=api.satdedi.com ./scripts/ops/satdedi-post-go-live-smoke.sh`
3. Kritik metrik/alert paneli:
   - `apps/api/docs/observability-alerting.md` referansi ile threshold takibi.

## 2) Deploy Oncesi Gate
1. Predeploy safety:
   - `ENV_TARGET=local BASE_URL=http://localhost:3001 ./scripts/ops/predeploy-migration-safety.sh`
2. Phase 3 signoff:
   - `BASE_URL=http://localhost:3001 DASHBOARD_URL=http://localhost:3000 ./scripts/smoke-phase3-signoff.sh`

## 3) Incident Akisi
1. API health kotuysa once `/health` ve `/health/metrics` durumunu kontrol et.
2. Auth kaynakli hata varsa `scripts/smoke-auth-refresh.sh` calistir.
3. Veri/smoke regresyonu varsa `scripts/smoke/smoke-pack-task45.sh` calistir.
4. Audit tutarliligi icin `scripts/smoke-audit-integrity.sh` calistir.

## 4) Haftalik Bakim
1. Backup drill:
   - `./scripts/ops/drill-backup-restore.sh`
2. Query plan kontrolu:
   - `DATABASE_URL=... ./scripts/diag/diag-query-plans.sh`
3. Load baseline:
   - `BASE_URL=http://localhost:3001 ./scripts/diag/diag-load-baseline.sh`

## 5) Handover Kapsami (Tamamlanan)
- Core workflow, audit, network/org, allocation ledger, Phase 1-2 frontend, Phase 3 readiness/go-live smoke.
- Master referanslar:
  - `ROADMAP_MASTER_CHECKLIST.md`
  - `SATDEDI_DOMAIN_GO_LIVE.md`
  - `SATDEDI_POST_GO_LIVE.md`

## 6) Sonraki Uretim Adimi
- Canli panel tasarim ve operasyon UX iyilestirmeleri (Frontend Phase 3+).
