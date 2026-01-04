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

  return (
    <main className="min-h-screen bg-gray-50">
      <div className="mx-auto flex min-h-screen max-w-md flex-col">
        <header className="sticky top-0 z-10 border-b bg-white px-4 py-3">
          <div className="flex items-center justify-between">
            <div className="text-sm font-semibold">Teklif Platform</div>
            <div className="text-xs text-gray-500">Girişsiz Teklif</div>
          </div>
        </header>

        <div ref={listRef} className="flex-1 space-y-3 overflow-y-auto px-4 py-4">
          {messages.map((m) => (
            <div key={m.id} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
              <div
                className={[
                  "max-w-[85%] rounded-2xl px-4 py-3 text-sm leading-relaxed",
                  m.role === "user"
                    ? "bg-black text-white"
                    : m.role === "system"
                    ? "bg-red-50 text-red-700 border border-red-200"
                    : "bg-white text-gray-900 border",
                ].join(" ")}
              >
                {m.text}
              </div>
            </div>
          ))}

          {typing && (
            <div className="flex justify-start">
              <div className="rounded-2xl border bg-white px-4 py-3 text-sm text-gray-600">Yazıyor…</div>
            </div>
          )}

          {phase === "collect_phone" && (
            <div className="mt-2 rounded-2xl border bg-white px-4 py-3 text-xs text-gray-600">
              Reklam, SMS veya pazarlama amacıyla kullanılmaz.
            </div>
          )}

          {lastError && (
            <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-xs text-red-700">
              {lastError}
            </div>
          )}
        </div>

        <div className="border-t bg-white px-4 py-3">
          <div className="flex items-end gap-2">
            
{phase === "collect_phone" ? (
  <input
    type="tel"
    inputMode="numeric"
    autoComplete="tel"
    value={input}
    onChange={(e) => setInput(maskPhoneTR(e.target.value))}
    placeholder="05xx xxx xx xx"
    className="flex-1 rounded-2xl border px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-black/10 disabled:bg-gray-100"
  />
) : (
<textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder={placeholder}
              disabled={disabled}
              rows={phase === "collect_intent" ? 3 : 2}
              className="flex-1 resize-none rounded-2xl border px-4 py-3 text-sm outline-none focus:ring-2 focus:ring-black/10 disabled:bg-gray-100"
            />
)}
            <button
              onClick={onSend}
              disabled={disabled || (phase === "collect_phone" ? !isValidPhoneTRForApi(input) : !input.trim())}
              className="rounded-2xl bg-black px-4 py-3 text-sm font-medium text-white disabled:opacity-50"
            >{phase === "collect_phone" ? "Talebi Gönder" : "Gönder"}</button>
          </div>

          {phase === "collect_intent" && (
            <div className="mt-3 grid grid-cols-2 gap-2">
              <a href="/danisman-ol" className="inline-flex items-center justify-center rounded-2xl border px-3 py-2 text-xs text-gray-700">
                Danışman ol
              </a>
              <a href="/is-ortagi-ol" className="inline-flex items-center justify-center rounded-2xl border px-3 py-2 text-xs text-gray-700">
                İş ortağı ol
              </a>
            </div>
          )}

          {phase === "done" && (
            <div className="mt-3">
              <button
                onClick={() => window.location.reload()}
                className="w-full rounded-2xl border px-3 py-2 text-xs text-gray-700"
              >
                Yeni talep oluştur
              </button>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
