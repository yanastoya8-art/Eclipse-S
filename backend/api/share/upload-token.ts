import { handleUpload } from "@vercel/blob/client";
import type { VercelRequest, VercelResponse } from "@vercel/node";

const MAX_UPLOAD_BYTES = 95 * 1024 * 1024;
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
    return res.status(503).json({ error: "blob_storage_not_configured" });
  }
  if (!allowRequest(clientAddress(req))) {
    res.setHeader("Retry-After", "60");
    return res.status(429).json({ error: "rate_limited" });
  }

  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    if (!body || body.type !== "blob.generate-client-token" ||
        typeof body.payload?.pathname !== "string") {
      return res.status(400).json({ error: "invalid_upload_request" });
    }

    const pathname = body.payload.pathname as string;
    if (pathname.length > 180 || !/^[A-Za-z0-9._-]+$/.test(pathname) ||
        pathname.startsWith(".") || pathname.includes("..")) {
      return res.status(400).json({ error: "invalid_filename" });
    }

    const result = await handleUpload({
      body,
      request: req,
      onBeforeGenerateToken: async (requestedPath) => {
        if (requestedPath !== pathname) throw new Error("Upload path mismatch");
        return {
          allowedContentTypes: [
            "video/*",
            "audio/*",
            "application/vnd.apple.mpegurl",
            "application/octet-stream",
          ],
          maximumSizeInBytes: MAX_UPLOAD_BYTES,
          addRandomSuffix: true,
          ttlDays: 1,
          cacheControlMaxAge: 60,
        };
      },
    });

    if (!("clientToken" in result)) return res.status(400).json({ error: "invalid_upload_event" });
    const tokenBody = result.clientToken.slice("vercel_blob_client_".length);
    const tokenSeparator = tokenBody.lastIndexOf("_");
    if (tokenSeparator <= 0) return res.status(500).json({ error: "invalid_blob_token" });
    return res.status(200).json({
      type: result.type,
      clientToken: result.clientToken,
      storeId: tokenBody.slice(0, tokenSeparator),
    });
  } catch {
    return res.status(400).json({ error: "upload_token_rejected" });
  }
}
