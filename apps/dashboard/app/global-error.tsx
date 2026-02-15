'use client';

type GlobalErrorProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function GlobalError({ reset }: GlobalErrorProps) {
  return (
    <html lang="tr">
      <body>
        <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', background: '#fff7f7' }}>
          <div style={{ width: 460, maxWidth: '92vw', border: '1px solid #ffd6d6', borderRadius: 16, padding: 18, background: '#fff' }}>
            <div style={{ fontWeight: 800, color: '#8a1c1c' }}>Beklenmeyen bir hata oluştu</div>
            <div style={{ marginTop: 8, color: '#6b2a2a', fontSize: 13 }}>
              Sayfa işlenirken bir sorun oluştu. Tekrar dene veya giriş sayfasına dön.
            </div>
            <div style={{ marginTop: 14, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button
                onClick={() => reset()}
                style={{ border: '1px solid #d9b3b3', background: '#fff', borderRadius: 10, padding: '9px 12px', fontWeight: 700 }}
              >
                Tekrar Dene
              </button>
              <a
                href="/login"
                style={{ textDecoration: 'none', color: '#111', border: '1px solid #d9b3b3', borderRadius: 10, padding: '9px 12px', fontWeight: 700 }}
              >
                Girişe Dön
              </a>
            </div>
          </div>
        </main>
      </body>
    </html>
  );
}
