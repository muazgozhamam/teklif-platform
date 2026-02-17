"use client";

import Link from "next/link";

export default function ResidentialOnboardingPage() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl flex-col justify-center px-4 py-10">
      <h1 className="text-3xl font-semibold tracking-tight" style={{ color: "var(--color-text-primary)" }}>
        Konut Onboarding
      </h1>
      <p className="mt-3 text-sm leading-6" style={{ color: "var(--color-text-secondary)" }}>
        Konut onboarding adımları hazırlanıyor. Şimdilik ana sayfadan chat ile süreci başlatabilirsin.
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

