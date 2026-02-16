import Link from "next/link";
import React from "react";

const STYLES = [
  {
    title: "Konut Sahibi",
    subtitle: "Evimi satmak/kiralamak istiyorum",
    href: "/onboarding/residential",
  },
  {
    title: "Ticari Mülk",
    subtitle: "Ünitemi değerlendirmek istiyorum",
    href: "/onboarding/commercial",
  },
  {
    title: "Danışman",
    subtitle: "Portföy al, teklif üret",
    href: "/login?next=/dashboard",
  },
  {
    title: "İş Ortağı",
    subtitle: "Talep bul, süreci başlat",
    href: "/apply/partner",
  },
];

export default function StyleCarousel() {
  return (
    <div className="grid grid-cols-2 gap-2">
      {STYLES.map((item) => (
        <Link
          key={item.title}
          href={item.href}
          aria-label={`${item.title} olarak devam et`}
          className="rounded-2xl border p-2 text-left text-xs transition-transform hover:scale-[1.02]"
          style={{
            borderColor: "var(--color-border)",
            background: "var(--color-surface)",
            color: "var(--color-text-secondary)",
            boxShadow: "var(--shadow-sm)",
            textDecoration: "none",
          }}
        >
          <div className="font-medium" style={{ color: "var(--color-text-primary)" }}>
            {item.title}
          </div>
          <div className="mt-1">{item.subtitle}</div>
        </Link>
      ))}
    </div>
  );
}
