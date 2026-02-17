"use client";

import React, { useMemo, useState } from "react";
import Modal from "@/components/ui/Modal";

type GuestLeadGateModalProps = {
  open: boolean;
  onClose: () => void;
  onSubmitSuccess: (data: {
    fullName: string;
    phone: string;
    email: string;
    propertyType: string;
    location: string;
  }) => void;
};

export default function GuestLeadGateModal({ open, onClose, onSubmitSuccess }: GuestLeadGateModalProps) {
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [propertyType, setPropertyType] = useState("konut");
  const [location, setLocation] = useState("");
  const [touched, setTouched] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const formOk = useMemo(
    () => fullName.trim() && phone.trim() && propertyType.trim() && location.trim(),
    [fullName, location, phone, propertyType],
  );

  function submit() {
    setTouched(true);
    if (!formOk) return;

    onSubmitSuccess({
      fullName: fullName.trim(),
      phone: phone.trim(),
      email: email.trim(),
      propertyType: propertyType.trim(),
      location: location.trim(),
    });
    setSubmitted(true);
  }

  return (
    <Modal
      isOpen={open}
      title={submitted ? "Teşekkürler" : "Devam etmek için kısa form"}
      onClose={onClose}
      maxWidthClass="max-w-lg"
    >
      {submitted ? (
        <div>
          <p className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
            Bilgilerin alındı, sohbete devam edebilirsin.
          </p>
          <button
            type="button"
            onClick={onClose}
            className="mt-3 h-10 rounded-xl px-4 text-sm font-medium text-white"
            style={{ background: "var(--color-primary-600)" }}
          >
            Kapat
          </button>
        </div>
      ) : (
        <div className="grid gap-3">
          <p className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
            5 mesaj sınırına ulaştın; devam etmek için bilgilerini bırak.
          </p>

          <input
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            placeholder="Ad Soyad"
            className="h-11 rounded-xl border px-3 text-sm outline-none"
            style={{ borderColor: "var(--color-border)", background: "var(--color-bg)", color: "var(--color-text-primary)" }}
          />

          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="Telefon"
            className="h-11 rounded-xl border px-3 text-sm outline-none"
            style={{ borderColor: "var(--color-border)", background: "var(--color-bg)", color: "var(--color-text-primary)" }}
          />

          <input
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="E-posta (opsiyonel)"
            className="h-11 rounded-xl border px-3 text-sm outline-none"
            style={{ borderColor: "var(--color-border)", background: "var(--color-bg)", color: "var(--color-text-primary)" }}
          />

          <select
            value={propertyType}
            onChange={(e) => setPropertyType(e.target.value)}
            className="h-11 rounded-xl border px-3 text-sm outline-none"
            style={{ borderColor: "var(--color-border)", background: "var(--color-bg)", color: "var(--color-text-primary)" }}
          >
            <option value="konut">Konut</option>
            <option value="arsa">Arsa</option>
            <option value="tarla">Tarla</option>
            <option value="ticari">Ticari</option>
          </select>

          <input
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            placeholder="Konum (İl / İlçe)"
            className="h-11 rounded-xl border px-3 text-sm outline-none"
            style={{ borderColor: "var(--color-border)", background: "var(--color-bg)", color: "var(--color-text-primary)" }}
          />

          {!formOk && touched ? (
            <p className="text-xs" style={{ color: "var(--color-danger-600)" }}>
              Lütfen zorunlu alanları doldur.
            </p>
          ) : null}

          <button
            type="button"
            onClick={submit}
            className="mt-1 h-11 rounded-xl text-sm font-medium text-white"
            style={{ background: "var(--color-primary-600)" }}
          >
            Devam Et
          </button>
        </div>
      )}
    </Modal>
  );
}
