# AI Context Pack

Bu klasor yeni chat'lerde hizli devam etmek icin kalici proje hafizasidir.

## Kullanim
- Yeni chat acarken once `ai-context/project.md` dosyasini yapistir.
- Sorunla devam edeceksen `ai-context/issues.md` icindeki ilgili issue notunu da ekle.
- Ortam/deploy gerekiyorsa `ai-context/services.md` ve `ai-context/env.md` dosyalarini da ekle.

## Tek seferlik hatirlatma (yeni chat acilis metni)
Asagidaki metni yeni chat'e yapistir:

```text
Bu repoda calis: /Users/muazgozhamam/Desktop/teklif-platform
Ilk olarak ai-context/project.md, ai-context/services.md ve ai-context/issues.md dosyalarini oku.
Deploy akisini ai-context/services.md'deki branch mapping'e gore uygula.
Secret deger isteme/yazma; sadece env key adlari ile ilerle.
```

## Deploy kisayolu
- Stage icin calisma branch'i: `develop`
- Prod icin calisma branch'i: `main`
- Detayli akis: `ai-context/services.md`
