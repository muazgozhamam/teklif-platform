"use client";

import React, { useMemo, useState } from "react";
import ModalShell from "@/components/ui/ModalShell";

type ConsultantApplyModalProps = {
  open: boolean;
  onClose: () => void;
};

type FormState = {
  fullName: string;
  phone: string;
  email: string;
  city: string;
  district: string;
  hasMyk: "" | "EVET" | "HAYIR";
  mykNo: string;
  experience: string;
  workType: "" | "BAGIMSIZ" | "OFIS";
  officeName: string;
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
  hasMyk: "",
  mykNo: "",
  experience: "",
  workType: "",
  officeName: "",
  consent: false,
};

export default function ConsultantApplyModal({ open, onClose }: ConsultantApplyModalProps) {
  const [form, setForm] = useState<FormState>(INITIAL);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const isOffice = form.workType === "OFIS";
  const showMykNo = form.hasMyk === "EVET";

  const subtitle = useMemo(
    () => "Kısa birkaç bilgiyle başvurunu alalım.",
    [],
  );

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
    if (!form.hasMyk) next.hasMyk = "MYK bilgisi zorunlu.";
    if (!form.experience) next.experience = "Deneyim zorunlu.";
    if (!form.workType) next.workType = "Çalışma tipi zorunlu.";
    if (!form.consent) next.consent = "Onay vermen gerekiyor.";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  async function onSubmit() {
    if (!validate()) return;
    setLoading(true);
    try {
      const body = {
        type: "CONSULTANT",
        fullName: form.fullName.trim(),
        email: form.email.trim(),
        phone: form.phone.trim(),
        city: form.city.trim(),
        district: form.district.trim(),
        data: {
          hasMyk: form.hasMyk,
          mykNo: form.mykNo.trim() || null,
          experience: form.experience,
          workType: form.workType,
          officeName: form.officeName.trim() || null,
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
    <ModalShell open={open} onClose={resetAndClose} title="Danışman başvurusu" maxWidthClass="max-w-[460px]">
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

          <Field label="MYK belgen var mı?" error={errors.hasMyk}>
            <div className="flex gap-3 text-sm">
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.hasMyk === "EVET"} onChange={() => setField("hasMyk", "EVET")} />
                Evet
              </label>
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.hasMyk === "HAYIR"} onChange={() => setField("hasMyk", "HAYIR")} />
                Hayır
              </label>
            </div>
          </Field>

          {showMykNo ? (
            <Field label="MYK No (opsiyonel)">
              <input value={form.mykNo} onChange={(e) => setField("mykNo", e.target.value)} className={inputCls} />
            </Field>
          ) : null}

          <Field label="Deneyim" error={errors.experience}>
            <select value={form.experience} onChange={(e) => setField("experience", e.target.value as FormState["experience"])} className={inputCls}>
              <option value="">Seç</option>
              <option value="0-1">0-1 yıl</option>
              <option value="1-3">1-3 yıl</option>
              <option value="3-5">3-5 yıl</option>
              <option value="5+">5+ yıl</option>
            </select>
          </Field>

          <Field label="Çalışma tipi" error={errors.workType}>
            <div className="flex gap-3 text-sm">
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.workType === "BAGIMSIZ"} onChange={() => setField("workType", "BAGIMSIZ")} />
                Bağımsız
              </label>
              <label className="inline-flex items-center gap-2">
                <input type="radio" checked={form.workType === "OFIS"} onChange={() => setField("workType", "OFIS")} />
                Ofise bağlı
              </label>
            </div>
          </Field>

          {isOffice ? (
            <Field label="Ofis adı (opsiyonel)">
              <input value={form.officeName} onChange={(e) => setField("officeName", e.target.value)} className={inputCls} />
            </Field>
          ) : null}

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

const inputCls = "w-full min-w-0 rounded-2xl border px-3 py-2 text-sm outline-none focus:ring-2";
