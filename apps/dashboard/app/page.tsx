"use client";
/* eslint-disable @typescript-eslint/no-explicit-any */

import React, { useEffect, useMemo, useRef, useState } from "react";

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3001";

const API_CANDIDATES = {
  createLead: ["/leads", "/wizard/leads", "/public/leads"],
  dealByLead: (leadId: string) => [
    `/deals/by-lead/${leadId}`,
    `/wizard/deals/by-lead/${leadId}`,
  ],
  wizardNext: (leadId: string) => [
    `/leads/${leadId}/wizard/next-question`,
  ],
  wizardAnswer: (leadId: string) => [
    `/leads/${leadId}/wizard/answer`,
  ],
  matchDeal: (dealId: string) => [
    `/deals/${dealId}/match`,
    `/match/${dealId}`,
    `/wizard/${dealId}/match`,
  ],
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  submitPhone: (leadId: string, _dealId: string) => [
    `/leads/${leadId}/contact`,
  ],
} as const;

async function fetchJson(path: string, init?: RequestInit) {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers || {}),
    },
    credentials: "include",
    cache: "no-store",
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`${init?.method || "GET"} ${path} -> ${res.status} ${text}`);
  }
  return res.json();
}

async function tryPost<T>(paths: string[], body: any): Promise<{ data: T; used: string }> {
  let lastErr: any = null;
  for (const p of paths) {
    try {
      const data = (await fetchJson(p, {
        method: "POST",
        body: JSON.stringify(body),
      })) as T;
      return { data, used: p };
    } catch (e) {
      lastErr = e;
    }
  }
  throw lastErr || new Error("No POST candidates worked");
}

async function tryGet<T>(paths: string[]): Promise<{ data: T; used: string }> {
  let lastErr: any = null;
  for (const p of paths) {
    try {
      const data = (await fetchJson(p)) as T;
      return { data, used: p };
    } catch (e) {
      lastErr = e;
    }
  }
  throw lastErr || new Error("No GET candidates worked");
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

const BOT_VARIANTS = {
  greet: [
    "Merhaba. Talebini kısaca anlat; birkaç soruyla netleştirip seni en uygun danışmana yönlendireyim.",
    "Merhaba! Kısaca neye ihtiyacın olduğunu yaz; birkaç soruyla netleştirip seni doğru danışmana yönlendireyim.",
    "Selam. Talebini kısaca yaz; birkaç soru sorup seni en uygun danışmana aktaracağım.",
  ],
  ack_short: [
    "Anladım. Birkaç kısa soru soracağım.",
    "Tamamdır. Netleştirmek için birkaç kısa soru soracağım.",
    "Harika, birkaç kısa soruyla netleştirelim.",
  ],
  analyzing: [
    "Teşekkürler. Talebini analiz ediyorum…",
    "Tamamdır. Talebini hızlıca değerlendiriyorum…",
    "Not aldım. Şimdi talebini inceliyorum…",
  ],
  phone_need: [
    "Seni en uygun danışmana yönlendirebilmem için bir iletişim bilgisine ihtiyacım var.",
    "Danışmanın sana ulaşabilmesi için cep telefonu numaranı alabilir miyim?",
    "Son bir adım: Danışmanın arayabilmesi için cep telefonu numaranı paylaşır mısın?",
  ],
  phone_privacy: [
    "Telefon numaran üçüncü kişilerle paylaşılmaz; yalnızca bu talep kapsamında danışmanın seninle iletişime geçmesi için kullanılır.",
    "Numaran sadece bu talep için, seni arayacak danışman tarafından kullanılır. Üçüncü kişilerle paylaşılmaz.",
    "Gizlilik önemli: Numaran yalnızca bu talep kapsamında danışmanın seni araması için kullanılır.",
  ],
  phone_invalid: [
    "Telefon numarasını kontrol eder misin? Örn: 05xx xxx xx xx",
    "Numara formatı biraz hatalı görünüyor. 05xx xxx xx xx şeklinde yazar mısın?",
    "Bir kontrol edelim: 05xx xxx xx xx formatında paylaşır mısın?",
  ],
  success_1: [
    "Teşekkürler. Talebini danışmana ilettim.",
    "Harika. Talebini danışmana ilettim.",
    "Tamamdır. Talebini danışmana aktardım.",
  ],
  success_2: [
    "Danışman kısa süre içinde seni arayarak detaylı bilgi paylaşacak.",
    "Danışman kısa süre içinde seni arayıp detayları netleştirecek.",
    "Danışman en kısa sürede seni arayıp süreç hakkında bilgi verecek.",
  ],
  success_3: [
    "Görüşme sırasında ek soruların olursa danışmanına iletebilirsin. İyi günler dilerim.",
    "Görüşmede aklına takılanları danışmanına sorabilirsin. İyi günler.",
    "Herhangi bir detay olursa danışmanınla birlikte netleştirirsiniz. İyi günler.",
  ],
  error_retry: [
    "Şu an bir sorun oluştu. Birazdan tekrar deneyebilir misin?",
    "Kısa bir problem oldu. Birazdan tekrar dener misin?",
    "Şu an teknik bir aksaklık var. Birkaç dakika sonra tekrar deneyebilir misin?",
  ],
} as const;

function pickOne<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}



function normalizePhoneTR(input: string) {
  return input.replace(/\D/g, "");
}


function maskPhoneTR(input: string) {
  const digits = input.replace(/\D/g, "").slice(0, 11);
  let out = "";

  if (digits.length > 0) out += digits.slice(0, 4);
  if (digits.length > 4) out += " " + digits.slice(4, 7);
  if (digits.length > 7) out += " " + digits.slice(7, 9);
  if (digits.length > 9) out += " " + digits.slice(9, 11);

  return out;
}
function isValidPhoneTRForApi(input: string) {
  const d = normalizePhoneTR(input);
  // Accept 10 digits (5xx...) or 11 digits starting with 0 (05xx...)
  return d.length === 10 || (d.length === 11 && d.startsWith("0"));
}


type Role = "bot" | "user" | "system";
type Msg = { id: string; role: Role; text: string };

type WizardNextResp =
  | { done: true; dealId?: string; listingId?: string }
  | { done: false; key?: string; field?: string; question: string; dealId?: string };
type Phase =
  | "collect_intent"
  | "wizard"
  | "collect_phone"
  | "submitting"
  | "done"
  | "error";

export default function PublicChatPage() {
  const [messages, setMessages] = useState<Msg[]>(() => [
    {
      id: "m1",
      role: "bot",
      text: pickOne(BOT_VARIANTS.greet),
    },
  ]);
  const [typing, setTyping] = useState(false);
  const [input, setInput] = useState("");
  const [phase, setPhase] = useState<Phase>("collect_intent");

  const [leadId, setLeadId] = useState<string | null>(null);
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [_wizardLeadId, setWizardLeadId] = useState<string | null>(null);
  const [dealId, setDealId] = useState<string | null>(null);

  const [pendingQuestion, setPendingQuestion] = useState<{ leadId: string; key: string; question: string } | null>(null);
  const [lastError, setLastError] = useState<string | null>(null);

  const listRef = useRef<HTMLDivElement | null>(null);

  const placeholder = useMemo(() => {
    if (phase === "collect_phone") return "05xx xxx xx xx";
    return "Lütfen bize ne istediğini söyle. Örn: 3+1 dairemin fiyatını öğrenmek istiyorum.";
  }, [phase]);

  useEffect(() => {
    const el = listRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [messages, typing]);

  function push(role: Role, text: string) {
    setMessages((prev) => [
      ...prev,
      { id: `m_${Date.now()}_${Math.random().toString(16).slice(2)}`, role, text },
    ]);
  }

  async function botSay(text: string, delay = 400) {
    setTyping(true);
    await sleep(delay);
    setTyping(false);
    push("bot", text);
  }

  async function botSaySmart(key: keyof typeof BOT_VARIANTS, delay = 400) {
    return botSay(pickOne(BOT_VARIANTS[key]), delay);
  }


  function applyPricePolicyIfNeeded(freeText: string) {
    const t = freeText.toLowerCase();
    const priceSignals = ["fiyat", "eder", "değer", "deger", "kaç para", "ne kadar"];
    return priceSignals.some((k) => t.includes(k));
  }

  async function startLeadFromText(text: string) {
  // 1) Lead oluştur (leadId kesin buradan gelir)
  const leadRes = await tryPost<{ id: string }>(
    (typeof (API_CANDIDATES as any).createLead === "function" ? (API_CANDIDATES as any).createLead() : (API_CANDIDATES as any).createLead) as any,
    { initialText: text }
  );

  const leadObj = (leadRes as any)?.data ?? (leadRes as any);
  const newLeadId = leadObj?.id;
  if (!newLeadId) {
    throw new Error("Lead create response did not include id");
  }

  setLeadId(newLeadId);
  setWizardLeadId(newLeadId);

  // 2) Deal'i lead üzerinden al (dealId buradan gelir)
  const dealRes = await tryGet<{ id: string }>(
    API_CANDIDATES.dealByLead(newLeadId) as any
  );

  const dealObj = (dealRes as any)?.data ?? (dealRes as any);
  const newDealId = dealObj?.id ?? null;
  if (newDealId) setDealId(newDealId);

  return { leadId: newLeadId, dealId: newDealId };
}


  async function wizardNext(leadId: string) {
    const { data } = await tryPost<WizardNextResp>(API_CANDIDATES.wizardNext(leadId) as any, {});
    return data;
  }

  async function wizardAnswer(leadId: string, key: string, answer: string) {
    const body = { key, answer };
    const { data } = await tryPost<WizardNextResp>(API_CANDIDATES.wizardAnswer(leadId) as any, body);
    return data;
  }

  async function match(dId: string) {
    await tryPost<any>(API_CANDIDATES.matchDeal(dId) as any, {});
  }

  async function submitPhone(lId: string, dId: string, phoneDigits: string) {
    const body = { phone: phoneDigits, phoneNumber: phoneDigits };
    await tryPost<any>(API_CANDIDATES.submitPhone(lId, dId) as any, body);
  }

  async function beginWizardFlow(leadId: string) {
    setPhase("wizard");
    const next = await wizardNext(leadId);

    // API next-question response içinde dealId döndürebilir (match için saklıyoruz)
    const maybeDealId = (next as any).dealId;
    if (maybeDealId) setDealId(maybeDealId);

    if ("done" in next && next.done) {
      await botSaySmart("analyzing", 600);
            const finalDealId = (next as any).dealId ?? dealId;
      if (finalDealId) await match(finalDealId);
      await askPhone();
      return;
    }

    const key = (next as any).key || (next as any).field;
    const question = (next as any).question;
    if (!key || !question) throw new Error("Wizard next response beklenen formatta değil (key/question).");

    setPendingQuestion({ leadId, key, question });
    await botSay(question, 500);
  }

  async function continueWizardWithAnswer(ans: string) {
    if (!pendingQuestion) return;

    await wizardAnswer(pendingQuestion.leadId, pendingQuestion.key, ans);

    // Answer endpoint kaydı döndürebilir; next soru için tekrar next-question çağır
    const next = await wizardNext(pendingQuestion.leadId);

    if ("done" in next && next.done) {
      setPendingQuestion(null);
      await botSaySmart("analyzing", 700);
      if (dealId) await match(dealId);
      await askPhone();
      return;
    }

    const nKey = (next as any).key || (next as any).field;
    const nQ = (next as any).question;
    if (!nKey || !nQ) throw new Error("Wizard answer response beklenen formatta değil (key/question).");

    setPendingQuestion({ leadId: pendingQuestion.leadId, key: nKey, question: nQ });
    await botSay(nQ, 500);
  }

  async function askPhone() {
    setPhase("collect_phone");
    await botSay(
      "Harika 👍 Talebini netleştirdim. Seni bu konuda en uygun danışmana yönlendirebilmem için cep telefonu numaranı paylaşır mısın? 🔒 Numaran kesinlikle üçüncü kişilerle paylaşılmaz ve yalnızca bu talep kapsamında kullanılır.",
      500
    );
  }

  async function finalizeWithPhone(phoneRaw: string) {
    if (!leadId || !dealId) throw new Error("leadId/dealId yok; akış tamamlanamaz.");

    const digits = normalizePhoneTR(phoneRaw);
    if (!isValidPhoneTRForApi(phoneRaw)) {
      await botSaySmart("phone_invalid", 300);
      return;
    }

    setPhase("submitting");
    setTyping(true);
    await sleep(400);

    await submitPhone(leadId, dealId, digits);

    setTyping(false);
    await botSaySmart("success_1", 350);
    await botSaySmart("success_2", 350);
    await botSaySmart("success_3", 350);
    setPhase("done");
  }

  async function onSend() {
    const text = input.trim();
    if (!text) return;

    setInput("");
    push("user", text);
    setLastError(null);

    try {
      if (phase === "collect_phone") {
        await finalizeWithPhone(text);
        return;
      }

      if (phase === "wizard") {
        await continueWizardWithAnswer(text);
        return;
      }

      if (phase === "collect_intent") {
        const priceHit = applyPricePolicyIfNeeded(text);

        setTyping(true);
        await sleep(350);
        setTyping(false);

        if (priceHit) {
          push(
            "bot",
            "Anladım. Fiyatlar bulunduğunuz bölge, bina özellikleri ve güncel piyasa koşullarına göre çok değişkenlik gösterdiği için buradan net bir rakam vermem doğru olmaz."
          );
          await botSay(
            "Ancak talebini netleştirip seni bu konuda en uygun danışmana yönlendirebilirim. Danışman kısa süre içinde seni arayarak fiyat aralığını ve izlenecek yolu paylaşır.",
            400
          );
        } else {
          await botSaySmart("ack_short", 300);
        }
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const { leadId: lId, dealId: dId } = await startLeadFromText(text);
        // Wizard leadId üzerinden ilerler
        setWizardLeadId(lId);
        await beginWizardFlow(lId);
      }
    } catch (e: any) {
      const msg = e?.message || "Beklenmeyen hata";
      setLastError(msg);
      setPhase("error");
      setTyping(false);
      push("system", `Hata: ${msg}`);
      await botSaySmart("error_retry", 300);
    }
  }

  const disabled = typing || phase === "submitting" || phase === "done";
  const isCenteredComposer = messages.length <= 1 && phase === "collect_intent";

  return (
    <main className="min-h-screen" style={{ background: "var(--color-bg)" }}>
      <div className="mx-auto flex min-h-screen w-full max-w-5xl flex-col px-4 md:px-6">
        <header className="sticky top-0 z-10 py-4">
          <div className="mx-auto flex w-full max-w-3xl items-center justify-between rounded-full border bg-white/90 px-4 py-2 backdrop-blur">
            <div className="text-sm font-semibold" style={{ color: "var(--color-text-primary)" }}>
              Satdedi GPT
            </div>
            <div className="text-xs" style={{ color: "var(--color-text-muted)" }}>
              Girişsiz Teklif
            </div>
          </div>
        </header>

        <div
          ref={listRef}
          className={[
            "mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 overflow-y-auto pt-4",
            isCenteredComposer ? "pb-6" : "pb-40",
          ].join(" ")}
        >
          {messages.length <= 1 && (
            <div className="mb-2 mt-8 text-center">
              <h1 className="text-3xl font-semibold tracking-tight" style={{ color: "var(--color-text-primary)" }}>
                Bugün nasıl yardımcı olabilirim?
              </h1>
            </div>
          )}

          {messages.map((m) => (
            <div key={m.id} className={`flex w-full ${m.role === "user" ? "justify-end" : "justify-start"}`}>
              <div
                className={[
                  "max-w-[88%] whitespace-pre-wrap rounded-3xl px-4 py-3 text-[15px] leading-7",
                  m.role === "user" ? "text-white" : "",
                ].join(" ")}
                style={
                  m.role === "user"
                    ? { background: "#2f2f2f" }
                    : m.role === "system"
                    ? {
                        background: "rgba(220,38,38,0.08)",
                        border: "1px solid rgba(220,38,38,0.25)",
                        color: "var(--color-danger-600)",
                      }
                    : {
                        background: "transparent",
                        color: "var(--color-text-primary)",
                      }
                }
              >
                {m.text}
              </div>
            </div>
          ))}

          {typing && (
            <div className="flex w-full justify-start">
              <div className="max-w-[88%] rounded-3xl px-4 py-3 text-[15px]" style={{ color: "var(--color-text-muted)" }}>
                Yazıyor...
              </div>
            </div>
          )}

          {phase === "collect_phone" && (
            <div
              className="mx-auto w-full max-w-2xl rounded-2xl border px-4 py-3 text-xs"
              style={{ borderColor: "var(--color-border)", background: "var(--color-surface)", color: "var(--color-text-secondary)" }}
            >
              Numaranız yalnızca bu talep için danışmanın sizinle iletişim kurması amacıyla kullanılır.
            </div>
          )}

          {lastError && (
            <div
              className="mx-auto w-full max-w-2xl rounded-2xl border px-4 py-3 text-xs"
              style={{ borderColor: "rgba(220,38,38,0.3)", background: "rgba(220,38,38,0.08)", color: "var(--color-danger-600)" }}
            >
              {lastError}
            </div>
          )}
        </div>

        <div
          className={[
            "left-0 right-0 z-20 px-3 md:px-6",
            isCenteredComposer
              ? "mx-auto flex w-full max-w-3xl flex-1 items-center justify-center pb-10"
              : "fixed bottom-0 pb-4 pt-2",
          ].join(" ")}
        >
          <div className="mx-auto w-full max-w-3xl">
            <div className="rounded-[28px] border bg-white p-3 shadow-lg" style={{ borderColor: "var(--color-border)" }}>
              <div className="flex items-end gap-2">
                {phase === "collect_phone" ? (
                  <input
                    type="tel"
                    inputMode="numeric"
                    autoComplete="tel"
                    value={input}
                    onChange={(e) => setInput(maskPhoneTR(e.target.value))}
                    placeholder="05xx xxx xx xx"
                    className="min-h-[44px] flex-1 rounded-2xl bg-transparent px-3 py-2 text-sm outline-none"
                  />
                ) : (
                  <textarea
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    placeholder={placeholder}
                    disabled={disabled}
                    rows={1}
                    className="max-h-36 min-h-[44px] flex-1 resize-none rounded-2xl bg-transparent px-3 py-2 text-sm outline-none disabled:bg-gray-100"
                  />
                )}
                <button
                  onClick={onSend}
                  disabled={disabled || (phase === "collect_phone" ? !isValidPhoneTRForApi(input) : !input.trim())}
                  className="h-11 rounded-xl px-4 text-sm font-medium text-white disabled:opacity-50"
                  style={{ background: "#2f2f2f" }}
                >
                  {phase === "collect_phone" ? "Gönder" : "Yolla"}
                </button>
              </div>

              {phase === "done" && (
                <div className="mt-2">
                  <button
                    onClick={() => window.location.reload()}
                    className="rounded-full border px-3 py-1.5 text-xs"
                    style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
                  >
                    Yeni talep oluştur
                  </button>
                </div>
              )}
            </div>

            {phase === "collect_intent" && (
              <div className="mt-3 flex items-center justify-center gap-2">
                <a
                  href="/danisman-ol"
                  className="inline-flex items-center justify-center rounded-full border bg-white px-3 py-1.5 text-xs shadow-sm"
                  style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
                >
                  Danışman ol
                </a>
                <a
                  href="/is-ortagi-ol"
                  className="inline-flex items-center justify-center rounded-full border bg-white px-3 py-1.5 text-xs shadow-sm"
                  style={{ borderColor: "var(--color-border)", color: "var(--color-text-secondary)" }}
                >
                  İş ortağı ol
                </a>
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  );
}
