"use client";

import Link from "next/link";
import React, { useEffect, useRef, useState } from "react";
import LandingActionButton from "./LandingActionButton";
import AuthModal from "./AuthModal";
import ConsultantApplyModal from "@/components/auth/ConsultantApplyModal";
import PartnerApplyModal from "@/components/auth/PartnerApplyModal";
import Logo from "@/components/brand/Logo";

export default function LandingHeader() {
  const [authOpen, setAuthOpen] = useState(false);
  const [consultantOpen, setConsultantOpen] = useState(false);
  const [partnerOpen, setPartnerOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!menuOpen) return;

    const onPointerDown = (event: MouseEvent | TouchEvent) => {
      const target = event.target as Node | null;
      if (!menuRef.current || !target) return;
      if (menuRef.current.contains(target)) return;
      setMenuOpen(false);
    };

    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("touchstart", onPointerDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("touchstart", onPointerDown);
    };
  }, [menuOpen]);

  return (
    <>
      <header className="py-3">
        <div className="mx-auto flex w-full max-w-[960px] items-center justify-between gap-4">
          <Link
            href="/"
            aria-label="SatDedi ana sayfa"
            className="shrink-0"
          >
            <Logo size="md" />
          </Link>

          <nav className="hidden items-center gap-2 md:flex" aria-label="Landing üst aksiyonlar">
            <LandingActionButton label="Danışman ol" variant="outline" onClick={() => setConsultantOpen(true)} />
            <LandingActionButton label="İş ortağı ol" variant="outline" onClick={() => setPartnerOpen(true)} />
            <LandingActionButton label="Giriş yap" variant="primary" onClick={() => setAuthOpen(true)} />
          </nav>

          <div className="relative md:hidden" ref={menuRef}>
            <button
              type="button"
              onClick={() => setMenuOpen((prev) => !prev)}
              className="cursor-pointer rounded-full border px-3 py-2 text-sm"
              style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
              aria-label="Menü"
              aria-expanded={menuOpen}
              aria-haspopup="menu"
            >
              Menü
            </button>
            {menuOpen ? (
              <div
                className="absolute right-0 z-20 mt-2 w-48 rounded-2xl border p-2 shadow-md"
                style={{ borderColor: "var(--color-border)", background: "var(--color-surface)" }}
                role="menu"
              >
                <div className="flex flex-col gap-1">
                  <LandingActionButton
                    label="Danışman ol"
                    variant="ghost"
                    onClick={() => {
                      setMenuOpen(false);
                      setConsultantOpen(true);
                    }}
                  />
                  <LandingActionButton
                    label="İş ortağı ol"
                    variant="ghost"
                    onClick={() => {
                      setMenuOpen(false);
                      setPartnerOpen(true);
                    }}
                  />
                  <LandingActionButton
                    label="Giriş yap"
                    variant="primary"
                    onClick={() => {
                      setMenuOpen(false);
                      setAuthOpen(true);
                    }}
                  />
                </div>
              </div>
            ) : null}
          </div>
        </div>
      </header>
      <AuthModal open={authOpen} onClose={() => setAuthOpen(false)} />
      <ConsultantApplyModal open={consultantOpen} onClose={() => setConsultantOpen(false)} />
      <PartnerApplyModal open={partnerOpen} onClose={() => setPartnerOpen(false)} />
    </>
  );
}
