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
