/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * SSR İlanlar sayfası (Server Component)
 * - API'den PUBLISHED ilanları sunucu tarafında çeker
 * - Listing ID'lerini HTML'e basar (e2e doğrulaması için)
 */

type Listing = {
  id: string;
  title?: string | null;
  price?: number | null;
  city?: string | null;
  district?: string | null;
};

function resolveArrayPayload(payload: any): Listing[] {
  if (Array.isArray(payload)) return payload as Listing[];
  if (payload && Array.isArray(payload.items)) return payload.items as Listing[];
  if (payload && Array.isArray(payload.data)) return payload.data as Listing[];
  if (payload && payload.result && Array.isArray(payload.result.items)) return payload.result.items as Listing[];
  return [];
}

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.API_BASE_URL ||
  "http://localhost:3001";

async function getListings(): Promise<Listing[]> {
  // status=PUBLISHED filtresi (API varsayılanı PUBLISHED ise de sorun olmaz)
  const url = `${API_BASE}/listings?status=PUBLISHED`;
  const res = await fetch(url, {
    cache: "no-store",
    // Sunucu fetch önbelleğini atla; HTML'de güncel veri garanti
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`İlanlar alınamadı (${res.status}) ${text}`);
  }

  const payload = await res.json();
  return resolveArrayPayload(payload);
}

export default async function ListingsPage() {
  const listings = await getListings();

  return (
    <main style={{ padding: 24 }}>
      <h1>İlanlar</h1>

      {listings.length === 0 ? (
        <p>İlan bulunamadı.</p>
      ) : (
        <ul>
          {listings.map((l) => (
            <li key={l.id}>
              {/* ID'yi text olarak basıyoruz: e2e HTML içinde görsün */}
              <span data-listing-id={l.id}>{l.id}</span>
              {/* e2e sağlamlığı için ek işaretleyiciler */}
              <span style={{ display: "none" }}>{`LISTING_ID:${l.id}`}</span>
              <span style={{ display: "none" }}>{`ID=${l.id}`}</span>
              {l.title ? ` — ${l.title}` : ""}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
