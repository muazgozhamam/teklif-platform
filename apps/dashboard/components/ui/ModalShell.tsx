"use client";

import React, { useEffect } from "react";

type ModalShellProps = {
  open: boolean;
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  maxWidthClass?: string;
};

export default function ModalShell({
  open,
  title,
  onClose,
  children,
  maxWidthClass = "max-w-md",
}: ModalShellProps) {
  useEffect(() => {
    if (!open) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <button
        type="button"
        aria-label="Modalı kapat"
        onClick={onClose}
        className="absolute inset-0"
        style={{ background: "rgba(15,23,42,0.46)", backdropFilter: "blur(6px)" }}
      />

      <div
        className={`relative w-full ${maxWidthClass} max-h-[85vh] overflow-auto rounded-3xl border p-6 shadow-2xl`}
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
          {title}
        </h2>

        <div className="mt-4">{children}</div>
      </div>
    </div>
  );
}
