import React from "react";
import LandingHeader from "@/components/landing/LandingHeader";

export default function StickyHeader() {
  return (
    <div
      className="sticky top-0 z-40"
      style={{
        background: "color-mix(in oklab, var(--color-bg) 88%, transparent)",
        backdropFilter: "blur(8px)",
      }}
    >
      <LandingHeader />
    </div>
  );
}

