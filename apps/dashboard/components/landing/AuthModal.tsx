"use client";

import React, { useEffect } from "react";

type AuthModalProps = {
  open: boolean;
  onClose: () => void;
};

const API_BASE = (
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE ||
  "http://localhost:3001"
).replace(/\/+$/, "");

export default function AuthModal({ open, onClose }: AuthModalProps) {
  useEffect(() => {
    if (!open) return;
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [open, onClose]);

  if (!open) return null;

  function startGoogleAuth() {
    if (typeof window === "undefined") return;
    const redirect = `${window.location.origin}/login`;
    window.location.href = `${API_BASE}/auth/google?redirect=${encodeURIComponent(redirect)}`;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <button
        type="button"
        aria-label="Oturum aç modalını kapat"
        onClick={onClose}
        className="absolute inset-0"
        style={{ background: "rgba(15,23,42,0.46)", backdropFilter: "blur(6px)" }}
      />

      <div
        className="relative w-full max-w-md rounded-3xl border p-6 shadow-2xl"
        style={{ borderColor: "var(--color-border)", background: "var(--color-surface)" }}
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Modalı kapat"
          className="absolute right-4 top-4 rounded-full border px-2 py-1 text-xs"
          style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
        >
          X
        </button>

        <h2 className="text-xl font-semibold tracking-tight" style={{ color: "var(--color-text-primary)" }}>
          Oturum aç veya kaydol
        </h2>

        <div className="mt-5 grid gap-2">
          <button
            type="button"
            onClick={startGoogleAuth}
            aria-label="Google ile devam et"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left transition"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-primary)", background: "var(--color-bg-soft)" }}
          >
            Google ile devam et
          </button>
          <button
            type="button"
            disabled
            aria-label="Apple ile devam et (yakında)"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left opacity-60"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
          >
            Apple ile devam et (yakında)
          </button>
          <button
            type="button"
            disabled
            aria-label="Microsoft ile devam et (yakında)"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left opacity-60"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
          >
            Microsoft ile devam et (yakında)
          </button>
          <button
            type="button"
            disabled
            aria-label="Telefon ile devam et (yakında)"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left opacity-60"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
          >
            Telefon ile devam et (yakında)
          </button>
        </div>

        <div className="my-4 flex items-center gap-3">
          <div className="h-px flex-1" style={{ background: "var(--color-border)" }} />
          <span className="text-xs uppercase tracking-[0.12em]" style={{ color: "var(--color-text-muted)" }}>
            Ya da
          </span>
          <div className="h-px flex-1" style={{ background: "var(--color-border)" }} />
        </div>

        <div className="grid gap-2">
          <input
            type="email"
            placeholder="E-posta adresin"
            aria-label="E-posta adresi"
            className="rounded-2xl border px-4 py-3 text-sm outline-none focus:ring-2"
            style={{
              borderColor: "var(--color-border)",
              color: "var(--color-text-primary)",
              background: "var(--color-surface)",
              ["--tw-ring-color" as string]: "var(--color-brand-500)",
            }}
          />
          <button
            type="button"
            aria-label="E-posta ile devam et (yakında)"
            className="rounded-2xl px-4 py-3 text-sm font-medium text-white opacity-70"
            style={{ background: "var(--color-primary-600)" }}
            disabled
          >
            Devam
          </button>
        </div>
      </div>
    </div>
  );
}
