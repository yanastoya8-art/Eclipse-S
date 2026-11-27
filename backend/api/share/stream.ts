import type { VercelRequest, VercelResponse } from "@vercel/node";
import { Readable } from "node:stream";
import {
  decryptShareCapability,
  encryptShareCapability,
  headersForTarget,
  publicShareBaseURL,
  validatePublicMediaURL,
} from "./capability";

const PLAYLIST_LIMIT_BYTES = 2 * 1024 * 1024;
const MAX_REDIRECTS = 5;

function firstQuery(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function requestHeaders(req: VercelRequest): Record<string, string> {
  const result: Record<string, string> = {};
  for (const name of ["range", "if-range", "if-none-match", "if-modified-since", "accept"]) {
    const value = req.headers[name];
    if (typeof value === "string" && value.length < 2_048) {
      result[name] = value;
    }
  }
  return result;
}

function copyResponseHeaders(upstream: Response, res: VercelResponse): void {
  for (const name of [
    "content-type", "content-length", "content-range", "accept-ranges",
    "etag", "last-modified", "content-disposition", "cache-control",
  ]) {
    const value = upstream.headers.get(name);
    if (value) res.setHeader(name, value);
  }
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Cache-Control", "no-store");
}

async function readLimited(body: ReadableStream<Uint8Array>, limit: number): Promise<Uint8Array> {
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      total += value.byteLength;
      if (total > limit) {
        await reader.cancel();
        throw new Error("HLS playlist exceeds the 2 MiB safety limit");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const output = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return output;
}

async function proxyResponse(
  initialURL: URL,
  originalURL: string,
  providerHeaders: Record<string, string>,
  req: VercelRequest,
): Promise<Response> {
  let target = initialURL;
  let headers = headersForTarget(providerHeaders, originalURL, target.toString());
  const incoming = requestHeaders(req);
  Object.assign(headers, incoming);

  for (let attempt = 0; attempt <= MAX_REDIRECTS; attempt += 1) {
    await validatePublicMediaURL(target.toString());
    const response = await fetch(target, {
      method: req.method === "HEAD" ? "HEAD" : "GET",
      headers,
      redirect: "manual",
      signal: AbortSignal.timeout(55_000),
    });
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      if (!location || attempt === MAX_REDIRECTS) {
        throw new Error("Upstream redirect limit reached");
      }
      const redirected = await validatePublicMediaURL(new URL(location, target).toString());
      headers = headersForTarget(headers, target.toString(), redirected.toString());
      target = redirected;
      continue;
    }
    return response;
  }
  throw new Error("Too many upstream redirects");
}

async function rewritePlaylist(
  source: string,
  currentURL: URL,
  capability: ReturnType<typeof decryptShareCapability>,
  baseURL: string,
): Promise<string> {
  const makePublicURL = async (raw: string): Promise<string> => {
    const reference = raw.trim();
    if (!reference || reference.startsWith("data:") || reference.startsWith("skd:")) return raw;
    const target = await validatePublicMediaURL(new URL(reference, currentURL).toString());
    const childHeaders = headersForTarget(
      capability.headers,
      capability.url,
      target.toString(),
    );
    const token = encryptShareCapability({
      url: target.toString(),
      headers: childHeaders,
      expiresAt: capability.expiresAt,
    });
    const publicURL = new URL("/api/share/stream", baseURL);
    publicURL.searchParams.set("cap", token);
    return publicURL.toString();
  };

  const lines = source.split(/\r?\n/);
  const output: string[] = [];
  for (const line of lines) {
    if (!line.trim()) {
      output.push(line);
      continue;
    }
    if (line.trimStart().startsWith("#")) {
      let rewritten = line;
      const matches = [...line.matchAll(/URI="([^"]+)"/g)];
      for (const match of matches) {
        const original = match[1];
        const replacement = await makePublicURL(original);
        rewritten = rewritten.replace(`URI="${original}"`, `URI="${replacement}"`);
      }
      output.push(rewritten);
    } else {
      output.push(await makePublicURL(line));
    }
  }
  return output.join("\n");
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Content-Type-Options", "nosniff");
  if (req.method !== "GET" && req.method !== "HEAD") {
    res.setHeader("Allow", "GET, HEAD");
    return res.status(405).end();
  }
  if (!process.env.BLOB_READ_WRITE_TOKEN?.trim()) {
    return res.status(503).json({ error: "share_service_not_configured" });
  }

  try {
    const token = firstQuery(req.query.cap);
    if (!token || token.length > 32_768) return res.status(400).json({ error: "invalid_share_link" });
    const capability = decryptShareCapability(token);
    const target = await validatePublicMediaURL(capability.url);
    const upstream = await proxyResponse(target, capability.url, capability.headers, req);
    copyResponseHeaders(upstream, res);
    res.status(upstream.status);

    const finalURL = upstream.url ? new URL(upstream.url) : target;
    const contentType = (upstream.headers.get("content-type") ?? "").toLowerCase();
    const isPlaylist = finalURL.pathname.toLowerCase().endsWith(".m3u8") ||
      contentType.includes("mpegurl") || contentType.includes("x-mpegurl");

    if (req.method === "HEAD" || !upstream.body || !upstream.ok) {
      if (req.method === "HEAD" || !upstream.body) return res.end();
      const stream = Readable.fromWeb(upstream.body as never);
      stream.on("error", () => res.destroy());
      return stream.pipe(res);
    }

    if (isPlaylist) {
      const bytes = await readLimited(upstream.body, PLAYLIST_LIMIT_BYTES);
      const playlist = new TextDecoder("utf-8").decode(bytes);
      const baseURL = publicShareBaseURL(req);
      const rewritten = await rewritePlaylist(playlist, finalURL, capability, baseURL);
      res.setHeader("Content-Type", "application/vnd.apple.mpegurl; charset=utf-8");
      res.setHeader("Content-Length", Buffer.byteLength(rewritten, "utf8"));
      return res.status(upstream.status).send(rewritten);
    }

    const stream = Readable.fromWeb(upstream.body as never);
    stream.on("error", () => res.destroy());
    return stream.pipe(res);
  } catch (error) {
    if (res.headersSent) return res.destroy();
    const message = error instanceof Error ? error.message : "Could not retrieve shared media";
    return res.status(400).json({ error: message });
  }
}
