"use client";

import Link from "next/link";

export default function PartnerApplyPage() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col justify-center px-4 py-10">
      <h1 className="text-3xl font-semibold tracking-tight" style={{ color: "var(--color-text-primary)" }}>
        İş Ortağı Başvurusu
      </h1>
      <p className="mt-3 text-sm leading-6" style={{ color: "var(--color-text-secondary)" }}>
        Bu sayfa hazırlanıyor. Hızlı başvuru için ana sayfadaki “İş ortağı ol” akışını kullanabilirsin.
      </p>
      <div className="mt-6">
        <Link
          href="/"
          className="inline-flex rounded-xl px-4 py-2 text-sm font-medium text-white"
          style={{ background: "var(--color-primary-600)" }}
        >
          Ana sayfaya dön
        </Link>
      </div>
    </main>
  );
}

