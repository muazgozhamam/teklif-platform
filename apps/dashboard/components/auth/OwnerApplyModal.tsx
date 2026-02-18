"use client";

import React, { useMemo, useState } from "react";
import Modal from "@/components/ui/Modal";

type OwnerApplyModalProps = {
  open: boolean;
  mode: "RESIDENTIAL" | "COMMERCIAL";
  onClose: () => void;
};

type FormState = {
  fullName: string;
  phone: string;
  email: string;
  city: string;
  district: string;
  operation: "" | "SATIS" | "KIRALAMA";
  m2: string;
  roomOrUnit: string;
  note: string;
  consent: boolean;
};

const API_BASE = (
  process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  process.env.NEXT_PUBLIC_API_BASE ||
  "http://localhost:3001"
).replace(/\/+$/, "");

const INITIAL: FormState = {
  fullName: "",
  phone: "",
  email: "",
  city: "",
  district: "",
  operation: "",
  m2: "",
  roomOrUnit: "",
  note: "",
  consent: false,
};

export default function OwnerApplyModal({ open, mode, onClose }: OwnerApplyModalProps) {
  const [form, setForm] = useState<FormState>(INITIAL);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const propertyLabel = mode === "RESIDENTIAL" ? "Konut" : "Ticari mülk";
  const title = mode === "RESIDENTIAL" ? "Konut sahibi talep formu" : "Ticari mülk talep formu";
  const subtitle = useMemo(() => `${propertyLabel} için kısa birkaç bilgiyle süreci başlatalım.`, [propertyLabel]);

  function setField<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((p) => ({ ...p, [key]: value }));
    setErrors((p) => ({ ...p, [key]: "" }));
  }

  function validate() {
    const next: Record<string, string> = {};
    if (!form.fullName.trim()) next.fullName = "Ad Soyad zorunlu.";
    if (!form.phone.trim()) next.phone = "Telefon zorunlu.";
    if (!form.email.trim()) next.email = "E-posta zorunlu.";
    if (!form.city.trim()) next.city = "İl zorunlu.";
    if (!form.district.trim()) next.district = "İlçe zorunlu.";
    if (!form.operation) next.operation = "Satış/kiralama seçimi zorunlu.";
    if (!form.consent) next.consent = "Onay vermen gerekiyor.";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  async function onSubmit() {
    if (!validate()) return;
    setLoading(true);
    try {
      const body = {
        type: "OWNER",
        fullName: form.fullName.trim(),
        email: form.email.trim(),
        phone: form.phone.trim(),
        city: form.city.trim(),
        district: form.district.trim(),
        data: {
          propertyType: mode,
          operation: form.operation,
          m2: form.m2.trim() || null,
          roomOrUnit: form.roomOrUnit.trim() || null,
          note: form.note.trim() || null,
        },
      };

      const res = await fetch(`${API_BASE}/public/applications`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error("Talep gönderilemedi");
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
    <Modal isOpen={open} onClose={resetAndClose} title={title} maxWidthClass="max-w-[460px]">
      {success ? (
        <div className="grid gap-4">
          <p className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
            Talebin alındı. Ekibimiz kısa sürede seninle iletişime geçecek.
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
            {subtitle}
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

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field label="İl" error={errors.city}>
              <input value={form.city} onChange={(e) => setField("city", e.target.value)} className={inputCls} />
            </Field>
            <Field label="İlçe" error={errors.district}>
              <input value={form.district} onChange={(e) => setField("district", e.target.value)} className={inputCls} />
            </Field>
          </div>

          <Field label="İşlem tipi" error={errors.operation}>
            <div className="flex gap-3 text-sm">
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.operation === "SATIS"} onChange={() => setField("operation", "SATIS")} />
                Satış
              </label>
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.operation === "KIRALAMA"} onChange={() => setField("operation", "KIRALAMA")} />
                Kiralama
              </label>
            </div>
          </Field>

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field label={mode === "RESIDENTIAL" ? "Oda sayısı" : "Ünite tipi"}>
              <input value={form.roomOrUnit} onChange={(e) => setField("roomOrUnit", e.target.value)} className={inputCls} />
            </Field>
            <Field label="m² (opsiyonel)">
              <input value={form.m2} onChange={(e) => setField("m2", e.target.value)} className={inputCls} />
            </Field>
          </div>

          <Field label="Kısa not (opsiyonel)">
            <textarea value={form.note} onChange={(e) => setField("note", e.target.value)} rows={3} className={inputCls} />
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
            {loading ? "Gönderiliyor" : "Talebi gönder"}
          </button>
        </div>
      )}
    </Modal>
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

const inputCls = "w-full min-w-0 rounded-2xl border px-3 py-2 text-sm outline-none focus:outline-none focus:ring-0 focus-visible:ring-0";
