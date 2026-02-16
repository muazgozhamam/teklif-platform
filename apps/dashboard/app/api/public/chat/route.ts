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

  const bodyText = await req.text();
  const contentType = req.headers.get("content-type") || "application/json";

  try {
    const upstream = await fetch(upstreamUrl, {
      method: "POST",
      headers: { "content-type": contentType },
      body: bodyText,
      cache: "no-store",
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
    return new Response(
      JSON.stringify({ message: "Upstream API request failed" }),
      { status: 502, headers: { "content-type": "application/json; charset=utf-8" } },
    );
  }
}
