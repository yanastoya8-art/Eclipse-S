import type { VercelRequest, VercelResponse } from "@vercel/node";
import {
  encryptShareCapability,
  publicShareBaseURL,
  sanitizeProviderHeaders,
  validatePublicMediaURL,
} from "./capability";

const WINDOW_MS = 60_000;
const MAX_REQUESTS_PER_WINDOW = 20;
const windows = new Map<string, { startedAt: number; count: number }>();

function clientAddress(req: VercelRequest): string {
  const forwarded = req.headers["x-forwarded-for"];
  const first = Array.isArray(forwarded) ? forwarded[0] : forwarded;
  return (first?.split(",")[0] || req.headers["x-real-ip"] || "unknown").toString().trim().slice(0, 128);
}

function allowRequest(address: string): boolean {
  const now = Date.now();
  const current = windows.get(address);
  if (!current || now - current.startedAt >= WINDOW_MS) {
    windows.set(address, { startedAt: now, count: 1 });
    if (windows.size > 2_000) {
      for (const [key, value] of windows) {
        if (now - value.startedAt >= WINDOW_MS) windows.delete(key);
      }
    }
    return true;
  }
  if (current.count >= MAX_REQUESTS_PER_WINDOW) return false;
  current.count += 1;
  return true;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  res.setHeader("Cache-Control", "no-store, private");
  res.setHeader("X-Content-Type-Options", "nosniff");
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "method_not_allowed" });
  }
  if (!process.env.BLOB_READ_WRITE_TOKEN?.trim()) {
    return res.status(503).json({ error: "share_service_not_configured" });
  }
  if (!allowRequest(clientAddress(req))) {
    res.setHeader("Retry-After", "60");
    return res.status(429).json({ error: "rate_limited" });
  }

  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    if (!body || typeof body.url !== "string" || body.url.length > 8_192) {
      return res.status(400).json({ error: "invalid_media_url" });
    }
    const mediaURL = await validatePublicMediaURL(body.url);
    const headers = sanitizeProviderHeaders(body.headers);
    const requestedExpiry = Number(body.expiresInSeconds ?? 86_400);
    const expiresInSeconds = Number.isFinite(requestedExpiry)
      ? Math.min(86_400, Math.max(60, Math.floor(requestedExpiry)))
      : 86_400;
    const expiresAt = Date.now() + expiresInSeconds * 1_000;
    const capability = encryptShareCapability({
      url: mediaURL.toString(),
      headers,
      expiresAt,
    });
    const baseURL = publicShareBaseURL(req);
    const shareURL = new URL("/api/share/stream", baseURL);
    shareURL.searchParams.set("cap", capability);
    return res.status(200).json({
      url: shareURL.toString(),
      expiresAt: new Date(expiresAt).toISOString(),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Could not create share link";
    return res.status(400).json({ error: message });
  }
}
