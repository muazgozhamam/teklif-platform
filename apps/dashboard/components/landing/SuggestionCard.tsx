import React from "react";
import StyleCarousel from "./StyleCarousel";

type SuggestionCardProps = {
  onTryNow: () => void;
  onClose: () => void;
};

export default function SuggestionCard({ onTryNow, onClose }: SuggestionCardProps) {
  return (
    <section
      className="grid gap-4 rounded-3xl border p-4 md:grid-cols-[1fr_1.2fr]"
      style={{ borderColor: "var(--color-border)", background: "var(--color-surface)", boxShadow: "var(--shadow-md)" }}
    >
      <div>
        <h2 className="text-lg font-semibold" style={{ color: "var(--color-text-primary)" }}>
          SatDedi&apos;ye nasıl katılmak istiyorsun?
        </h2>
        <p className="mt-2 text-sm leading-6" style={{ color: "var(--color-text-secondary)" }}>
          Rolünü seç, sana özel süreci başlatalım.
        </p>
        <button
          type="button"
          onClick={onTryNow}
          aria-label="Asistanla başla ve giriş alanına odaklan"
          className="mt-4 rounded-full px-4 py-2 text-sm font-medium text-white transition hover:opacity-90"
          style={{ background: "var(--color-primary-600)" }}
        >
          Asistanla başla
        </button>
      </div>

      <div>
        <div className="mb-2 flex items-center justify-between">
          <p className="text-xs uppercase tracking-[0.12em]" style={{ color: "var(--color-text-muted)" }}>
            Sürece Katıl
          </p>
          <button
            type="button"
            onClick={onClose}
            aria-label="Öneri kartını kapat"
            className="rounded-full border px-2 py-1 text-xs"
            style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
          >
            X
          </button>
        </div>
        <StyleCarousel />
      </div>
    </section>
  );
}
