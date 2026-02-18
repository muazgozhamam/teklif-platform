"use client";

import React, { useEffect, useId } from "react";
import { createPortal } from "react-dom";

type ModalProps = {
  isOpen: boolean;
  title?: string;
  onClose: () => void;
  children: React.ReactNode;
  maxWidthClass?: string;
};

export default function Modal({
  isOpen,
  title,
  onClose,
  children,
  maxWidthClass = "max-w-md",
}: ModalProps) {
  const generatedId = useId();
  const titleId = title ? `app-modal-title-${generatedId}` : undefined;
  const canUseDom = typeof window !== "undefined" && typeof document !== "undefined";

  useEffect(() => {
    if (!isOpen) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };

    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [isOpen, onClose]);

  if (!canUseDom || !isOpen) return null;

  return createPortal(
    <div className="fixed inset-0 z-[9999]" role="presentation">
      <button
        type="button"
        aria-label="Modal arka planını kapat"
        onClick={onClose}
        className="absolute inset-0 h-full w-full cursor-default bg-slate-900/45 backdrop-blur-[6px]"
      />

      <div
        role="dialog"
        aria-modal="true"
        aria-label={title ? undefined : "Modal"}
        aria-labelledby={titleId}
        onClick={(e) => e.stopPropagation()}
        className={`fixed left-1/2 top-1/2 z-[10000] w-[calc(100%-2rem)] ${maxWidthClass} max-h-[calc(100dvh-2rem)] -translate-x-1/2 -translate-y-1/2 overflow-auto rounded-3xl border p-5 shadow-2xl sm:w-full sm:p-6`}
        style={{ borderColor: "var(--color-border)", background: "var(--color-surface)" }}
      >
      <button
        type="button"
        onClick={onClose}
        aria-label="Modalı kapat"
        className="absolute right-4 top-4 rounded-full border px-2 py-1 text-xs"
        style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
      >
        ×
      </button>

        {title ? (
          <h2 id={titleId} className="text-xl font-semibold tracking-tight" style={{ color: "var(--color-text-primary)" }}>
            {title}
          </h2>
        ) : null}

        <div className={title ? "mt-4" : ""}>{children}</div>
      </div>
    </div>,
    document.body,
  );
}
