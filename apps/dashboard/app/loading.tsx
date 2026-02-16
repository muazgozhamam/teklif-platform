import Logo from "@/components/brand/Logo";

export default function RootLoading() {
  return (
    <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', background: '#fcfaf6' }}>
      <div style={{ width: 360, maxWidth: '92vw', border: '1px solid #e9e2d7', borderRadius: 16, padding: 18, background: '#fff' }}>
        <div><Logo size="md" /></div>
        <div style={{ marginTop: 8, color: '#6f665c', fontSize: 13 }}>Sayfa yükleniyor…</div>
        <div style={{ marginTop: 14, height: 10, borderRadius: 999, background: '#efe8dd', overflow: 'hidden' }}>
          <div style={{ width: '42%', height: '100%', background: '#d2c2ac' }} />
        </div>
      </div>
    </main>
  );
}
