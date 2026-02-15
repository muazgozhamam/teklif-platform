# satdedi PR Workflow (Hizli Akis)

Bu dokuman, PR acma/merge surecini minimum tik ile standardize eder.

## 1) Agent (Codex) Sorumlulugu
- Branch acar (`codex/fXX-next`)
- Degisiklikleri yapar
- Gerekli kontrolu calistirir (lint/build/smoke/syntax)
- Pushlar
- Sana hazir olarak sunar:
  - PR link
  - Base/Compare
  - Title
  - Description

## 2) Senin Sorumlulugun (UI)
1. PR linkini ac
2. Title/description yapistir
3. `Create pull request`
4. `Enable auto-merge` (opsiyonel)
5. CI yesilse merge tamam

## 3) Standart Commit Paketleri
- `feat(role-auth): ...`
- `feat(ui-tr): ...`
- `chore(smoke-docs): ...`

## 4) Conflict Politikasi
- Conflict'e kadar agent cozer.
- Gercek conflict durumunda kisa yonlendirme + cozum adimlari verilir.

## 5) Hedef
- PR acma suresi < 1 dakika
- Merge operasyonu gunde 1-2 pencereye toplanir
