import type { VercelRequest, VercelResponse } from "@vercel/node";

type Provider = "gemini" | "openAI";

const WINDOW_MS = 60_000;
const MAX_REQUESTS_PER_WINDOW = 15;
const MAX_PROMPT_BYTES = 20_000;
const MAX_BODY_BYTES = 64 * 1024;

// Best-effort per-instance throttling. Configure a Vercel Firewall rate-limit
// rule for this route before production use; serverless instances do not share
// this in-memory counter.
const requestWindows = new Map<string, { startedAt: number; count: number }>();

function json(res: VercelResponse, status: number, body: Record<string, unknown>) {
  res.setHeader("Cache-Control", "no-store, private");
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  return res.status(status).json(body);
}

function clientAddress(req: VercelRequest): string {
  const forwarded = req.headers["x-forwarded-for"];
  const first = Array.isArray(forwarded) ? forwarded[0] : forwarded?.split(",")[0];
  return (first || req.headers["x-real-ip"] || "unknown").trim().slice(0, 128);
}

function allowRequest(address: string): boolean {
  const now = Date.now();
  const current = requestWindows.get(address);
  if (!current || now - current.startedAt >= WINDOW_MS) {
    requestWindows.set(address, { startedAt: now, count: 1 });
    if (requestWindows.size > 2_000) {
      for (const [key, value] of requestWindows) {
        if (now - value.startedAt >= WINDOW_MS) requestWindows.delete(key);
      }
    }
    return true;
  }
  if (current.count >= MAX_REQUESTS_PER_WINDOW) return false;
  current.count += 1;
  return true;
}

function parseBody(req: VercelRequest): Record<string, unknown> | null {
  try {
    const raw = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
    return raw as Record<string, unknown>;
  } catch {
    return null;
  }
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  res.setHeader("Cache-Control", "no-store, private");
  res.setHeader("X-Content-Type-Options", "nosniff");

  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return json(res, 405, { error: "method_not_allowed" });
  }

  const declaredLength = Number(req.headers["content-length"] || 0);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return json(res, 413, { error: "request_too_large" });
  }

  const address = clientAddress(req);
  if (!allowRequest(address)) {
    res.setHeader("Retry-After", "60");
    return json(res, 429, { error: "rate_limited" });
  }

  const provider = req.query.provider;
  if (provider !== "gemini" && provider !== "openAI") {
    return json(res, 404, { error: "provider_not_found" });
  }

  const body = parseBody(req);
  const payload = body?.payload;
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return json(res, 400, { error: "invalid_payload" });
  }

  const prompt = provider === "gemini"
    ? (((payload as Record<string, unknown>).contents as Array<{ parts?: Array<{ text?: string }> }> | undefined)?.[0]?.parts?.[0]?.text)
    : (payload as Record<string, unknown>).input;

  if (typeof prompt !== "string" || prompt.trim().length === 0 ||
      Buffer.byteLength(prompt, "utf8") > MAX_PROMPT_BYTES) {
    return json(res, 400, { error: "invalid_prompt" });
  }

  const timeout = AbortSignal.timeout(25_000);
  try {
    let upstream: Response;
    if (provider === "gemini") {
      const apiKey = process.env.GEMINI_API_KEY?.trim();
      if (!apiKey) return json(res, 503, { error: "gemini_not_configured" });

      const model = process.env.GEMINI_MODEL?.trim() || "gemini-2.5-flash";
      const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
      upstream = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          tools: [{ google_search: {} }],
          generationConfig: { temperature: 0.1, maxOutputTokens: 2048 },
        }),
        signal: timeout,
      });
    } else {
      const apiKey = process.env.OPENAI_API_KEY?.trim();
      if (!apiKey) return json(res, 503, { error: "openai_not_configured" });

      const model = process.env.OPENAI_MODEL?.trim() || "gpt-5.4";
      upstream = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          tools: [{ type: "web_search" }],
          input: prompt,
          max_output_tokens: 2048,
          store: false,
        }),
        signal: timeout,
      });
    }

    const responseText = await upstream.text();
    if (responseText.length > 2 * 1024 * 1024) {
      return json(res, 502, { error: "upstream_response_too_large" });
    }

    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.setHeader("Cache-Control", "no-store, private");
    if (!upstream.ok) {
      // Do not forward provider diagnostics verbatim; they may contain request
      // details. The status is enough for the iOS client to try its fallback.
      return json(res, upstream.status, { error: "upstream_provider_error", provider });
    }

    let parsed: unknown;
    try { parsed = JSON.parse(responseText); }
    catch { return json(res, 502, { error: "invalid_upstream_response" }); }
    return res.status(200).json(parsed as Record<string, unknown>);
  } catch (error) {
    const timedOut = error instanceof Error && error.name === "TimeoutError";
    return json(res, timedOut ? 504 : 502, {
      error: timedOut ? "upstream_timeout" : "upstream_unavailable",
    });
  }
}
