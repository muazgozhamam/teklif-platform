#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
DASH="$ROOT/apps/dashboard"

if [ ! -d "$DASH" ]; then
  echo "ERROR: apps/dashboard bulunamadı."
  exit 1
fi

# Router tespiti
APP_DIR=""
PAGES_DIR=""

if [ -d "$DASH/src/app" ]; then
  APP_DIR="$DASH/src/app"
elif [ -d "$DASH/app" ]; then
  APP_DIR="$DASH/app"
fi

if [ -z "$APP_DIR" ]; then
  if [ -d "$DASH/src/pages" ]; then
    PAGES_DIR="$DASH/src/pages"
  elif [ -d "$DASH/pages" ]; then
    PAGES_DIR="$DASH/pages"
  fi
fi

if [ -n "$APP_DIR" ]; then
  echo "==> Detected App Router at: $APP_DIR"
  echo "ERROR: Senin projede src/app yok demiştin ama bulundu; önceki script farklı gördü."
  echo "Bu durumda önceki script revize edilir; çıktıyı yapıştır."
  exit 1
fi

if [ -z "$PAGES_DIR" ]; then
  echo "ERROR: Ne app router ne pages router bulundu."
  echo "Dashboard içeriği:"
  (cd "$DASH" && find . -maxdepth 2 -type d -print)
  exit 1
fi

echo "==> Detected Pages Router at: $PAGES_DIR"

# lib klasörü
mkdir -p "$DASH/src/lib"
mkdir -p "$PAGES_DIR/offers"

# API helper
cat > "$DASH/src/lib/api.ts" <<'TS'
export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || "http://localhost:3001";

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers || {}),
    },
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} ${res.statusText}: ${text}`);
  }

  return res.json() as Promise<T>;
}
TS

# Provider page (Pages Router)
cat > "$PAGES_DIR/offers/provider.tsx" <<'TSX'
import { useState } from "react";
import { api } from "../../src/lib/api";

type Offer = {
  id: string;
  requestId: string;
  providerId: string;
  price: number;
  description?: string | null;
  estimatedTime?: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export default function ProviderOfferPage() {
  const [providerId, setProviderId] = useState("provider_demo");
  const [requestId, setRequestId] = useState("test_request_1");
  const [price, setPrice] = useState(1500);
  const [description, setDescription] = useState("Deneme teklif");
  const [estimatedTime, setEstimatedTime] = useState("2 gün");
  const [result, setResult] = useState<Offer | null>(null);
  const [error, setError] = useState<string>("");

  async function submit() {
    setError("");
    setResult(null);
    try {
      const data = await api<Offer>(`/offers?providerId=${encodeURIComponent(providerId)}`, {
        method: "POST",
        body: JSON.stringify({ requestId, price, description, estimatedTime }),
      });
      setResult(data);
    } catch (e: any) {
      setError(e?.message || "Hata");
    }
  }

  return (
    <div style={{ padding: 20, maxWidth: 720 }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>Provider • Teklif Ver</h1>
      <p style={{ opacity: 0.7 }}>MVP: requestId üzerinden teklif oluşturur.</p>

      <div style={{ display: "grid", gap: 10, marginTop: 16 }}>
        <label>
          Provider ID
          <input value={providerId} onChange={(e) => setProviderId(e.target.value)} style={{ width: "100%", padding: 10, marginTop: 6 }} />
        </label>

        <label>
          Request ID
          <input value={requestId} onChange={(e) => setRequestId(e.target.value)} style={{ width: "100%", padding: 10, marginTop: 6 }} />
        </label>

        <label>
          Price
          <input type="number" value={price} onChange={(e) => setPrice(Number(e.target.value))} style={{ width: "100%", padding: 10, marginTop: 6 }} />
        </label>

        <label>
          Description
          <input value={description} onChange={(e) => setDescription(e.target.value)} style={{ width: "100%", padding: 10, marginTop: 6 }} />
        </label>

        <label>
          Estimated Time
          <input value={estimatedTime} onChange={(e) => setEstimatedTime(e.target.value)} style={{ width: "100%", padding: 10, marginTop: 6 }} />
        </label>

        <button onClick={submit} style={{ padding: 12, fontWeight: 700, cursor: "pointer" }}>
          Teklif Gönder
        </button>

        {error ? <pre style={{ color: "crimson", whiteSpace: "pre-wrap" }}>{error}</pre> : null}
        {result ? <pre style={{ background: "#111", color: "#0f0", padding: 12, borderRadius: 8, overflow: "auto" }}>{JSON.stringify(result, null, 2)}</pre> : null}
      </div>
    </div>
  );
}
TSX

# Customer page (Pages Router)
cat > "$PAGES_DIR/offers/customer.tsx" <<'TSX'
import { useState } from "react";
import { api } from "../../src/lib/api";

type Offer = {
  id: string;
  requestId: string;
  providerId: string;
  price: number;
  description?: string | null;
  estimatedTime?: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export default function CustomerOffersPage() {
  const [customerId, setCustomerId] = useState("customer_demo");
  const [requestId, setRequestId] = useState("test_request_1");
  const [offers, setOffers] = useState<Offer[]>([]);
  const [error, setError] = useState("");

  async function load() {
    setError("");
    try {
      const data = await api<Offer[]>(`/offers?requestId=${encodeURIComponent(requestId)}`);
      setOffers(data);
    } catch (e: any) {
      setError(e?.message || "Hata");
    }
  }

  async function setStatus(offerId: string, status: "ACCEPTED" | "REJECTED") {
    setError("");
    try {
      await api(`/offers/status?customerId=${encodeURIComponent(customerId)}&offerId=${encodeURIComponent(offerId)}`, {
        method: "PATCH",
        body: JSON.stringify({ status }),
      });
      await load();
    } catch (e: any) {
      setError(e?.message || "Hata");
    }
  }

  return (
    <div style={{ padding: 20, maxWidth: 920 }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>Customer • Gelen Teklifler</h1>

      <div style={{ display: "grid", gap: 10, marginTop: 16 }}>
        <label>
          Customer ID
          <input value={customerId} onChange={(e) => setCustomerId(e.target.value)} style={{ width: "100%", padding: 10, marginTop: 6 }} />
        </label>

        <label>
          Request ID
          <input value={requestId} onChange={(e) => setRequestId(e.target.value)} style={{ width: "100%", padding: 10, marginTop: 6 }} />
        </label>

        <button onClick={load} style={{ padding: 12, fontWeight: 700, cursor: "pointer" }}>
          Teklifleri Getir
        </button>

        {error ? <pre style={{ color: "crimson", whiteSpace: "pre-wrap" }}>{error}</pre> : null}

        <div style={{ display: "grid", gap: 10 }}>
          {offers.map((o) => (
            <div key={o.id} style={{ border: "1px solid #ddd", borderRadius: 10, padding: 12 }}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
                <strong>{o.providerId}</strong>
                <span>Status: <b>{o.status}</b></span>
              </div>
              <div style={{ marginTop: 6 }}>Price: <b>{o.price}</b></div>
              <div style={{ marginTop: 6, opacity: 0.85 }}>{o.description}</div>
              <div style={{ marginTop: 6, opacity: 0.85 }}>Süre: {o.estimatedTime}</div>

              <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
                <button onClick={() => setStatus(o.id, "ACCEPTED")} style={{ padding: 10, fontWeight: 700, cursor: "pointer" }}>
                  Kabul Et
                </button>
                <button onClick={() => setStatus(o.id, "REJECTED")} style={{ padding: 10, fontWeight: 700, cursor: "pointer" }}>
                  Reddet
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
TSX

echo "==> Pages created:"
echo " - /offers/provider"
echo " - /offers/customer"
echo ""
echo "If dashboard is running, open:"
echo " - http://localhost:3000/offers/provider"
echo " - http://localhost:3000/offers/customer"
