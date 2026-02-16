import { NextRequest } from "next/server";

export const runtime = "nodejs";

function resolveApiBase() {
  const base =
    process.env.API_BASE_URL?.trim() ||
    process.env.NEXT_PUBLIC_API_BASE_URL?.trim() ||
    "https://api.satdedi.com";
  return base.replace(/\/+$/, "");
}

export async function POST(req: NextRequest) {
  const apiBase = resolveApiBase();
  const upstreamUrl = `${apiBase}/public/chat`;

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ message: "Invalid JSON payload" }),
      { status: 400, headers: { "content-type": "application/json; charset=utf-8" } },
    );
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    const accept = req.headers.get("accept") || "application/json";
    const userAgent = req.headers.get("user-agent") || "";
    const forwardedFor = req.headers.get("x-forwarded-for") || "";
    const host = req.headers.get("host") || "";

    const upstream = await fetch(upstreamUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "accept": accept,
        ...(userAgent ? { "user-agent": userAgent } : {}),
        ...(forwardedFor ? { "x-forwarded-for": forwardedFor } : {}),
        ...(host ? { "x-forwarded-host": host } : {}),
      },
      body: JSON.stringify(payload),
      cache: "no-store",
      signal: controller.signal,
    });

    const responseText = await upstream.text();

    if (!upstream.ok) {
      console.error(
        `[api/public/chat] upstream error status=${upstream.status} body=${responseText.slice(0, 500)}`,
      );
    }

    return new Response(responseText, {
      status: upstream.status,
      headers: {
        "content-type": upstream.headers.get("content-type") || "application/json; charset=utf-8",
      },
    });
  } catch (err) {
    console.error(
      `[api/public/chat] upstream fetch failed: ${err instanceof Error ? err.message : String(err)}`,
    );
    const isProd = process.env.NODE_ENV === "production";
    const details = err && typeof err === "object"
      ? {
          name: (err as { name?: unknown }).name ?? null,
          message: (err as { message?: unknown }).message ?? null,
          cause: (err as { cause?: unknown }).cause ?? null,
          upstreamUrl,
          apiBase,
        }
      : { name: null, message: String(err), cause: null, upstreamUrl, apiBase };
    return new Response(
      JSON.stringify(
        isProd
          ? { message: "Upstream API request failed" }
          : { message: "Upstream API request failed", details },
      ),
      { status: 502, headers: { "content-type": "application/json; charset=utf-8" } },
    );
  } finally {
    clearTimeout(timeout);
  }
}
