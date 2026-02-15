import Link from 'next/link';

export default function NotFoundPage() {
  return (
    <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', background: '#faf7f2' }}>
      <div style={{ width: 460, maxWidth: '92vw', border: '1px solid #e8e1d7', borderRadius: 16, padding: 18, background: '#fff' }}>
        <div style={{ fontWeight: 800, fontSize: 20, color: '#2f2a24' }}>Sayfa Bulunamadı</div>
        <div style={{ marginTop: 8, color: '#6f665c', fontSize: 13 }}>
          Aradığın sayfa taşınmış veya kaldırılmış olabilir.
        </div>
        <div style={{ marginTop: 14, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Link
            href="/"
            style={{ textDecoration: 'none', color: '#111', border: '1px solid #ddd', borderRadius: 10, padding: '9px 12px', fontWeight: 700 }}
          >
            Ana Sayfa
          </Link>
          <Link
            href="/login"
            style={{ textDecoration: 'none', color: '#111', border: '1px solid #ddd', borderRadius: 10, padding: '9px 12px', fontWeight: 700 }}
          >
            Giriş
          </Link>
        </div>
      </div>
    </main>
  );
}
