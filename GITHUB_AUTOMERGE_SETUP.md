# GitHub Auto-Merge Setup (satdedi)

Bu dokuman, `main` branch'i icin PR merge operasyonunu minimum tik ile standartlastirir.

## 1) Repository Ayarlari
GitHub -> `Settings` -> `General`
- `Allow auto-merge`: ON

## 2) Branch Protection (main)
GitHub -> `Settings` -> `Branches` -> `Add rule`
- Branch name pattern: `main`
- `Require a pull request before merging`: ON
- `Require status checks to pass before merging`: ON
- Required checks:
  - `quality`
  - `integration-smoke`
- `Require branches to be up to date before merging`: ON
- `Require conversation resolution before merging`: ON (opsiyonel ama tavsiye)
- `Allow auto-merge`: ON

## 3) Gunluk Kullanım
1. Codex branch pushlar ve PR metnini hazir verir.
2. Sen PR acarsin.
3. `Enable auto-merge` secersin.
4. CI yesil olunca merge otomatik tamamlanir.

## 4) Sorun Giderme
- Auto-merge butonu yoksa: repo-level `Allow auto-merge` kapali olabilir.
- PR merge edilmiyorsa: required checks tamamlanmamis veya branch outdated.
- Surekli conflict oluyorsa: merge penceresini gunde 1-2 kez sabitle.

## 5) Operasyon Hedefi
- PR acma + merge operasyonu manuelde < 1 dakika.
- CI gecen PR'lar beklemeden otomatik kapanir.
