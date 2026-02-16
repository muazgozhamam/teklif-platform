"use client";

import Link from "next/link";
import React, { useState } from "react";
import LandingActionButton from "./LandingActionButton";
import AuthModal from "./AuthModal";

export default function LandingHeader() {
  const [authOpen, setAuthOpen] = useState(false);

  return (
    <>
      <header className="py-3">
        <div className="mx-auto flex w-full max-w-[960px] items-center justify-between gap-4">
          <Link
            href="/"
            aria-label="SatDedi ana sayfa"
            className="shrink-0"
            style={{
              color: "var(--color-text-primary)",
              fontSize: "20px",
              fontWeight: 700,
              letterSpacing: "-0.2px",
              lineHeight: 1.2,
            }}
          >
            SatDedi
          </Link>

          <nav className="hidden items-center gap-2 md:flex" aria-label="Landing üst aksiyonlar">
            <LandingActionButton href="/apply/consultant" label="Danışman ol" variant="outline" />
            <LandingActionButton href="/apply/partner" label="İş ortağı ol" variant="outline" />
            <LandingActionButton label="Giriş yap" variant="primary" onClick={() => setAuthOpen(true)} />
          </nav>

          <details className="relative md:hidden">
            <summary
              className="list-none cursor-pointer rounded-full border px-3 py-2 text-sm"
              style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
              aria-label="Menü"
            >
              Menü
            </summary>
            <div
              className="absolute right-0 z-20 mt-2 w-48 rounded-2xl border p-2 shadow-md"
              style={{ borderColor: "var(--color-border)", background: "var(--color-surface)" }}
            >
              <div className="flex flex-col gap-1">
                <LandingActionButton href="/apply/consultant" label="Danışman ol" variant="ghost" />
                <LandingActionButton href="/apply/partner" label="İş ortağı ol" variant="ghost" />
                <LandingActionButton label="Giriş yap" variant="primary" onClick={() => setAuthOpen(true)} />
              </div>
            </div>
          </details>
        </div>
      </header>
      <AuthModal open={authOpen} onClose={() => setAuthOpen(false)} />
    </>
  );
}
