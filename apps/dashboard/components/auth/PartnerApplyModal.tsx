"use client";

import React, { useState } from "react";
import ModalShell from "@/components/ui/ModalShell";

type PartnerApplyModalProps = {
  open: boolean;
  onClose: () => void;
};

type FormState = {
  fullName: string;
  phone: string;
  email: string;
  city: string;
  district: string;
  workMode: "" | "BIREYSEL" | "FIRMA";
  companyName: string;
  hasReferralExp: "" | "EVET" | "HAYIR";
  verticals: string[];
  consent: boolean;
};

const API_BASE = (
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE ||
  "http://localhost:3001"
).replace(/\/+$/, "");

const VERTICALS = ["Konut", "Ticari", "Arsa", "Yatırım"] as const;

const INITIAL: FormState = {
  fullName: "",
  phone: "",
  email: "",
  city: "",
  district: "",
  workMode: "",
  companyName: "",
  hasReferralExp: "",
  verticals: [],
  consent: false,
};

export default function PartnerApplyModal({ open, onClose }: PartnerApplyModalProps) {
  const [form, setForm] = useState<FormState>(INITIAL);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const isCompany = form.workMode === "FIRMA";

  function setField<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((p) => ({ ...p, [key]: value }));
    setErrors((p) => ({ ...p, [key]: "" }));
  }

  function toggleVertical(v: string) {
    const exists = form.verticals.includes(v);
    const next = exists ? form.verticals.filter((x) => x !== v) : [...form.verticals, v];
    setField("verticals", next);
  }

  function validate() {
    const next: Record<string, string> = {};
    if (!form.fullName.trim()) next.fullName = "Ad Soyad zorunlu.";
    if (!form.phone.trim()) next.phone = "Telefon zorunlu.";
    if (!form.email.trim()) next.email = "E-posta zorunlu.";
    if (!form.city.trim()) next.city = "İl zorunlu.";
    if (!form.district.trim()) next.district = "İlçe zorunlu.";
    if (!form.workMode) next.workMode = "Çalışma şekli zorunlu.";
    if (!form.hasReferralExp) next.hasReferralExp = "Bu alan zorunlu.";
    if (form.verticals.length === 0) next.verticals = "En az bir alan seç.";
    if (!form.consent) next.consent = "Onay vermen gerekiyor.";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  async function onSubmit() {
    if (!validate()) return;
    setLoading(true);
    try {
      const body = {
        type: "PARTNER",
        fullName: form.fullName.trim(),
        email: form.email.trim(),
        phone: form.phone.trim(),
        city: form.city.trim(),
        district: form.district.trim(),
        data: {
          workMode: form.workMode,
          companyName: form.companyName.trim() || null,
          hasReferralExp: form.hasReferralExp,
          verticals: form.verticals,
        },
      };

      const res = await fetch(`${API_BASE}/public/applications`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error("Başvuru gönderilemedi");
      setSuccess(true);
    } catch {
      setErrors((p) => ({ ...p, submit: "Gönderim sırasında sorun oluştu." }));
    } finally {
      setLoading(false);
    }
  }

  function resetAndClose() {
    setForm(INITIAL);
    setErrors({});
    setLoading(false);
    setSuccess(false);
    onClose();
  }

  return (
    <ModalShell open={open} onClose={resetAndClose} title="İş ortağı başvurusu" maxWidthClass="max-w-[460px]">
      {success ? (
        <div className="grid gap-4">
          <p className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
            Başvurun alındı. En kısa sürede dönüş yapacağız.
          </p>
          <button
            type="button"
            onClick={resetAndClose}
            className="rounded-2xl px-4 py-3 text-sm font-medium text-white"
            style={{ background: "var(--color-primary-600)" }}
          >
            Kapat
          </button>
        </div>
      ) : (
        <div className="grid gap-3">
          <p className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
            Talep yönlendirme ve iş ortaklığı için kısa form.
          </p>

          <Field label="Ad Soyad" error={errors.fullName}>
            <input value={form.fullName} onChange={(e) => setField("fullName", e.target.value)} className={inputCls} />
          </Field>

          <Field label="Telefon" error={errors.phone}>
            <input value={form.phone} onChange={(e) => setField("phone", e.target.value)} className={inputCls} />
          </Field>

          <Field label="E-posta" error={errors.email}>
            <input type="email" value={form.email} onChange={(e) => setField("email", e.target.value)} className={inputCls} />
          </Field>

          <div className="grid grid-cols-2 gap-2">
            <Field label="İl" error={errors.city}>
              <input value={form.city} onChange={(e) => setField("city", e.target.value)} className={inputCls} />
            </Field>
            <Field label="İlçe" error={errors.district}>
              <input value={form.district} onChange={(e) => setField("district", e.target.value)} className={inputCls} />
            </Field>
          </div>

          <Field label="Çalışma şekli" error={errors.workMode}>
            <div className="flex gap-3 text-sm">
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.workMode === "BIREYSEL"} onChange={() => setField("workMode", "BIREYSEL")} />
                Bireysel
              </label>
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.workMode === "FIRMA"} onChange={() => setField("workMode", "FIRMA")} />
                Firma
              </label>
            </div>
          </Field>

          {isCompany ? (
            <Field label="Firma adı (opsiyonel)">
              <input value={form.companyName} onChange={(e) => setField("companyName", e.target.value)} className={inputCls} />
            </Field>
          ) : null}

          <Field label="Daha önce emlak/lead yönlendirme yaptın mı?" error={errors.hasReferralExp}>
            <div className="flex gap-3 text-sm">
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.hasReferralExp === "EVET"} onChange={() => setField("hasReferralExp", "EVET")} />
                Evet
              </label>
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.hasReferralExp === "HAYIR"} onChange={() => setField("hasReferralExp", "HAYIR")} />
                Hayır
              </label>
            </div>
          </Field>

          <Field label="Hangi alanlarda yönlendirebilirsin?" error={errors.verticals}>
            <div className="flex flex-wrap gap-2">
              {VERTICALS.map((v) => {
                const active = form.verticals.includes(v);
                return (
                  <button
                    key={v}
                    type="button"
                    onClick={() => toggleVertical(v)}
                    className="rounded-full border px-3 py-1.5 text-xs"
                    style={{
                      borderColor: active ? "var(--color-primary-600)" : "var(--color-border)",
                      color: active ? "#fff" : "var(--color-text-secondary)",
                      background: active ? "var(--color-primary-600)" : "transparent",
                    }}
                  >
                    {v}
                  </button>
                );
              })}
            </div>
          </Field>

          <label className="inline-flex items-start gap-2 text-sm">
            <input type="checkbox" checked={form.consent} onChange={(e) => setField("consent", e.target.checked)} />
            <span>Bilgilerimin değerlendirme amacıyla kullanılmasını kabul ediyorum.</span>
          </label>
          {errors.consent ? <p className="text-xs text-red-500">{errors.consent}</p> : null}
          {errors.submit ? <p className="text-xs text-red-500">{errors.submit}</p> : null}

          <button
            type="button"
            disabled={loading}
            onClick={onSubmit}
            className="rounded-2xl px-4 py-3 text-sm font-medium text-white disabled:opacity-70"
            style={{ background: "var(--color-primary-600)" }}
          >
            {loading ? "Gönderiliyor" : "Başvuruyu gönder"}
          </button>
        </div>
      )}
    </ModalShell>
  );
}

function Field({
  label,
  error,
  children,
}: {
  label: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-1">
      <label className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
        {label}
      </label>
      {children}
      {error ? <p className="text-xs text-red-500">{error}</p> : null}
    </div>
  );
}

const inputCls = "rounded-2xl border px-3 py-2 text-sm outline-none focus:ring-2";
