"use client";

import React from "react";
import ModalShell from "@/components/ui/ModalShell";
import Logo from "@/components/brand/Logo";

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
  function startGoogleAuth() {
    if (typeof window === "undefined") return;
    const redirect = `${window.location.origin}/login`;
    window.location.href = `${API_BASE}/auth/google?redirect=${encodeURIComponent(redirect)}`;
  }

  return (
    <ModalShell open={open} onClose={onClose} title="Oturum aç veya kaydol">
        <div className="mb-1">
          <Logo size="md" />
        </div>
        <div className="mt-5 grid gap-2">
          <button
            type="button"
            onClick={startGoogleAuth}
            aria-label="Google ile devam et"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left transition"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-primary)", background: "var(--color-bg-soft)" }}
          >
            <span className="flex items-center gap-3">
              <GoogleIcon className="h-5 w-5 flex-shrink-0" />
              <span>Google ile devam et</span>
            </span>
          </button>
          <button
            type="button"
            disabled
            aria-label="Apple ile devam et (yakında)"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left opacity-60"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
          >
            <span className="flex items-center gap-3">
              <AppleIcon className="h-5 w-5 flex-shrink-0 opacity-70" />
              <span>Apple ile devam et (yakında)</span>
            </span>
          </button>
          <button
            type="button"
            disabled
            aria-label="Microsoft ile devam et (yakında)"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left opacity-60"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
          >
            <span className="flex items-center gap-3">
              <MicrosoftIcon className="h-5 w-5 flex-shrink-0 opacity-70" />
              <span>Microsoft ile devam et (yakında)</span>
            </span>
          </button>
          <button
            type="button"
            disabled
            aria-label="Telefon ile devam et (yakında)"
            className="rounded-2xl border px-4 py-3 text-sm font-medium text-left opacity-60"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
          >
            <span className="flex items-center gap-3">
              <PhoneIcon className="h-5 w-5 flex-shrink-0 opacity-70" />
              <span>Telefon ile devam et (yakında)</span>
            </span>
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
            className="rounded-2xl border px-4 py-3 text-sm outline-none focus:outline-none focus:ring-0 focus-visible:ring-0"
            style={{
              borderColor: "var(--color-border)",
              color: "var(--color-text-primary)",
              background: "var(--color-surface)",
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
    </ModalShell>
  );
}

function GoogleIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className={className}>
      <path
        fill="#EA4335"
        d="M12 10.2v3.9h5.5c-.2 1.3-.8 2.4-1.8 3.1l3 2.3c1.8-1.6 2.8-4 2.8-6.9 0-.7-.1-1.5-.2-2.2H12z"
      />
      <path
        fill="#34A853"
        d="M12 21c2.6 0 4.8-.9 6.4-2.4l-3-2.3c-.8.6-2 .9-3.4.9-2.6 0-4.7-1.7-5.5-4l-3.1 2.4C5 18.9 8.2 21 12 21z"
      />
      <path
        fill="#FBBC05"
        d="M6.5 13.2c-.2-.6-.3-1.2-.3-1.8s.1-1.2.3-1.8L3.4 7.2C2.8 8.5 2.4 9.9 2.4 11.4c0 1.5.4 2.9 1 4.2l3.1-2.4z"
      />
      <path
        fill="#4285F4"
        d="M12 5.6c1.4 0 2.7.5 3.7 1.4l2.8-2.8C16.8 2.7 14.6 1.8 12 1.8 8.2 1.8 5 3.9 3.4 7.2l3.1 2.4c.8-2.3 2.9-4 5.5-4z"
      />
    </svg>
  );
}

function AppleIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className={className} fill="currentColor">
      <path d="M16.37 12.22c.02 2.19 1.92 2.92 1.94 2.93-.02.05-.3 1.02-.98 2.02-.59.86-1.2 1.72-2.16 1.74-.94.02-1.24-.55-2.32-.55-1.09 0-1.42.53-2.3.57-.93.03-1.64-.92-2.24-1.77-1.22-1.76-2.16-4.98-.9-7.18.63-1.09 1.75-1.77 2.97-1.79.92-.02 1.8.61 2.32.61.52 0 1.49-.75 2.51-.64.43.02 1.63.17 2.4 1.3-.06.04-1.43.83-1.42 2.76z" />
      <path d="M14.86 4.93c.49-.58.82-1.38.73-2.18-.71.03-1.56.47-2.07 1.05-.45.51-.84 1.33-.73 2.12.79.06 1.58-.4 2.07-.99z" />
    </svg>
  );
}

function MicrosoftIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className={className}>
      <rect x="3" y="3" width="8" height="8" fill="#F25022" />
      <rect x="13" y="3" width="8" height="8" fill="#7FBA00" />
      <rect x="3" y="13" width="8" height="8" fill="#00A4EF" />
      <rect x="13" y="13" width="8" height="8" fill="#FFB900" />
    </svg>
  );
}

function PhoneIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className={className} fill="none" stroke="currentColor" strokeWidth="1.8">
      <path d="M22 16.92v2.2a2 2 0 0 1-2.18 2A19.8 19.8 0 0 1 11.2 18a19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.88 4.34 2 2 0 0 1 4.86 2.2h2.2a2 2 0 0 1 2 1.72c.13 1 .38 1.97.74 2.87a2 2 0 0 1-.45 2.1L8.4 9.85a16 16 0 0 0 5.75 5.75l.96-.95a2 2 0 0 1 2.1-.45c.9.36 1.87.61 2.87.74A2 2 0 0 1 22 16.92z" />
    </svg>
  );
}
