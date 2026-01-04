"use client";
/* eslint-disable @typescript-eslint/no-explicit-any */

import { useState } from "react";
import { api } from "@/lib/api";

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
