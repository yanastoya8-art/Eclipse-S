export interface Env {
  SHARES: R2Bucket;
  SHARE_ADMIN_TOKEN: string;
  SHARE_ENCRYPTION_KEY: string;
  PUBLIC_BASE_URL: string;
}

type ShareDescriptor = {
  sourceURL: string;
  headers: Record<string, string>;
  expiresAt: number;
};

type Capability =
  | { kind: "source"; id: string; url: string; exp: number }
  | { kind: "file"; key: string; filename: string; mime: string; exp: number }
  | { kind: "upload"; id: string; key: string; filename: string; mime: string; exp: number };

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const MAX_UPLOAD_BYTES = 95 * 1024 * 1024;
const MAX_MANIFEST_BYTES = 2 * 1024 * 1024;
const MAX_LIFETIME_SECONDS = 7 * 24 * 60 * 60;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function fromBase64url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(normalized + "=".repeat((4 - normalized.length % 4) % 4));
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function cryptoKey(env: Env): Promise<CryptoKey> {
  const raw = Uint8Array.from(atob(env.SHARE_ENCRYPTION_KEY), (c) => c.charCodeAt(0));
  if (raw.byteLength !== 32) throw new Error("SHARE_ENCRYPTION_KEY must be a base64-encoded 32-byte key");
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

async function seal(env: Env, value: unknown): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    await cryptoKey(env),
    encoder.encode(JSON.stringify(value)),
  );
  const combined = new Uint8Array(iv.length + encrypted.byteLength);
  combined.set(iv);
  combined.set(new Uint8Array(encrypted), iv.length);
  return base64url(combined);
}

async function unseal<T>(env: Env, token: string): Promise<T | null> {
  try {
    const bytes = fromBase64url(token);
    if (bytes.length < 29 || bytes.length > 24_000) return null;
    const clear = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: bytes.slice(0, 12) },
      await cryptoKey(env),
      bytes.slice(12),
    );
    return JSON.parse(decoder.decode(clear)) as T;
  } catch {
    return null;
  }
}

function authorized(request: Request, env: Env): boolean {
  const supplied = request.headers.get("authorization") ?? "";
  const expected = `Bearer ${env.SHARE_ADMIN_TOKEN}`;
  if (supplied.length !== expected.length) return false;
  let mismatch = 0;
  for (let i = 0; i < supplied.length; i++) mismatch |= supplied.charCodeAt(i) ^ expected.charCodeAt(i);
  return mismatch === 0;
}

function safeUpstream(raw: string): URL | null {
  try {
    const url = new URL(raw);
    if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) return null;
    const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
    if (!host || host === "localhost" || host.endsWith(".localhost") ||
        host.endsWith(".local") || host.endsWith(".internal") ||
        host === "metadata.google.internal" || host === "169.254.169.254" ||
        host === "0.0.0.0" || host === "::1" || host.startsWith("fc") ||
        host.startsWith("fd") || host.startsWith("fe80:") ||
        /^10\./.test(host) || /^127\./.test(host) || /^192\.168\./.test(host) ||
        /^172\.(1[6-9]|2\d|3[01])\./.test(host)) return null;
    return url;
  } catch {
    return null;
  }
}

function expiry(seconds: unknown): number {
  const requested = typeof seconds === "number" && Number.isFinite(seconds) ? Math.floor(seconds) : 24 * 60 * 60;
  return Date.now() + Math.max(60, Math.min(requested, MAX_LIFETIME_SECONDS)) * 1000;
}

async function capabilityURL(env: Env, path: string, value: Capability): Promise<string> {
  const token = await seal(env, value);
  return `${env.PUBLIC_BASE_URL.replace(/\/$/, "")}${path}/${token}`;
}

async function readJSON(request: Request): Promise<Record<string, unknown> | null> {
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > 64 * 1024) return null;
  try {
    const value = await request.json() as Record<string, unknown>;
    return value && typeof value === "object" && !Array.isArray(value) ? value : null;
  } catch {
    return null;
  }
}

function safeHeaders(value: unknown): Record<string, string> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const entries = Object.entries(value as Record<string, unknown>);
  if (entries.length > 24) return null;
  const result: Record<string, string> = {};
  for (const [rawName, rawValue] of entries) {
    const name = rawName.trim();
    if (!/^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,64}$/.test(name) ||
        typeof rawValue !== "string" || rawValue.length > 8_192 ||
        /^(host|content-length|connection|transfer-encoding|range|accept-encoding)$/i.test(name)) return null;
    result[name] = rawValue;
  }
  return result;
}

async function fetchUpstream(url: URL, headers: Record<string, string>, request: Request): Promise<Response> {
  let current = url;
  for (let hop = 0; hop <= 5; hop++) {
    if (!safeUpstream(current.toString())) return new Response("Blocked upstream destination", { status: 403 });
    const outgoing = new Headers(headers);
    for (const name of ["range", "if-range", "if-none-match", "if-modified-since", "accept"]) {
      const value = request.headers.get(name);
      if (value) outgoing.set(name, value);
    }
    if (hop > 0 && current.origin !== url.origin) {
      outgoing.delete("authorization");
      outgoing.delete("cookie");
      outgoing.delete("proxy-authorization");
    }
    const response = await fetch(current, { method: "GET", headers: outgoing, redirect: "manual" });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get("location");
      if (!location || hop === 5) return new Response("Too many upstream redirects", { status: 502 });
      const next = new URL(location, current);
      if (!safeUpstream(next.toString())) return new Response("Blocked redirect destination", { status: 403 });
      current = next;
      continue;
    }
    return response;
  }
  return new Response("Upstream redirect failed", { status: 502 });
}

async function rewriteManifest(env: Env, text: string, id: string, exp: number, base: URL): Promise<string> {
  const rewrite = async (reference: string): Promise<string> => {
    const resolved = new URL(reference, base);
    if (!safeUpstream(resolved.toString())) throw new Error("Playlist contains a blocked resource URL");
    return capabilityURL(env, "/v1/r", {
      kind: "source", id, url: resolved.toString(), exp,
    });
  };

  const lines = text.split(/\r?\n/);
  const output: string[] = [];
  for (const line of lines) {
    if (!line.trim()) { output.push(line); continue; }
    if (line.trimStart().startsWith("#")) {
      const matches = [...line.matchAll(/URI="([^"]+)"/g)];
      let rewritten = line;
      for (const match of matches) {
        const replacement = await rewrite(match[1]);
        rewritten = rewritten.replace(`URI="${match[1]}"`, `URI="${replacement}"`);
      }
      output.push(rewritten);
    } else {
      output.push(await rewrite(line.trim()));
    }
  }
  return output.join("\n");
}

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,PUT,OPTIONS",
      "access-control-allow-headers": "authorization,content-type,range,if-range",
      "access-control-max-age": "86400",
    }});
  }
  if (url.pathname === "/health" && request.method === "GET") return json({ ok: true, service: "eclipse-share" });

  if (url.pathname === "/v1/shares" && request.method === "POST") {
    if (!authorized(request, env)) return json({ error: "Unauthorized" }, 401);
    const body = await readJSON(request);
    if (!body || typeof body.url !== "string") return json({ error: "A source URL is required" }, 400);
    const source = safeUpstream(body.url);
    const headers = safeHeaders(body.headers);
    if (!source || !headers) return json({ error: "Invalid source URL or request headers" }, 400);
    const id = crypto.randomUUID();
    const exp = expiry(body.expiresInSeconds);
    const descriptor: ShareDescriptor = { sourceURL: source.toString(), headers, expiresAt: exp };
    await env.SHARES.put(`shares/${id}.json`, await seal(env, descriptor));
    const shareUrl = await capabilityURL(env, "/v1/r", {
      kind: "source", id, url: source.toString(), exp,
    });
    return json({ url: shareUrl, expiresAt: new Date(exp).toISOString() }, 201);
  }

  if (url.pathname === "/v1/uploads" && request.method === "POST") {
    if (!authorized(request, env)) return json({ error: "Unauthorized" }, 401);
    const body = await readJSON(request);
    if (!body || typeof body.filename !== "string" || body.filename.length > 180) {
      return json({ error: "A valid filename is required" }, 400);
    }
    const id = crypto.randomUUID();
    const exp = expiry(body.expiresInSeconds);
    const mime = typeof body.mimeType === "string" && body.mimeType.length < 128
      ? body.mimeType : "application/octet-stream";
    const key = `files/${id}`;
    const uploadUrl = await capabilityURL(env, "/v1/u", {
      kind: "upload", id, key, filename: body.filename.replace(/[\\/\r\n]/g, "_"), mime, exp,
    });
    const fileUrl = await capabilityURL(env, "/v1/f", {
      kind: "file", key, filename: body.filename.replace(/[\\/\r\n]/g, "_"), mime, exp,
    });
    return json({ uploadUrl, fileUrl, expiresAt: new Date(exp).toISOString(), maximumBytes: MAX_UPLOAD_BYTES }, 201);
  }

  if (url.pathname.startsWith("/v1/u/") && request.method === "PUT") {
    const token = url.pathname.slice("/v1/u/".length);
    const cap = await unseal<Capability>(env, token);
    if (!cap || cap.kind !== "upload" || cap.exp < Date.now()) return json({ error: "Invalid or expired upload link" }, 403);
    const length = Number(request.headers.get("content-length") ?? "0");
    if (!length || length > MAX_UPLOAD_BYTES) return json({ error: "Upload must include Content-Length and be no larger than 95 MiB" }, 413);
    await env.SHARES.put(cap.key, request.body, {
      httpMetadata: { contentType: cap.mime, contentDisposition: `attachment; filename*=UTF-8''${encodeURIComponent(cap.filename)}` },
      customMetadata: { expiresAt: String(cap.exp), shareId: cap.id },
    });
    return json({ ok: true, bytes: length });
  }

  if (url.pathname.startsWith("/v1/f/") && request.method === "GET") {
    const cap = await unseal<Capability>(env, url.pathname.slice("/v1/f/".length));
    if (!cap || cap.kind !== "file" || cap.exp < Date.now()) return new Response("Link expired or invalid", { status: 403 });
    const object = await env.SHARES.get(cap.key, { range: request.headers });
    if (!object) return new Response("File not found", { status: 404 });
    if (object.customMetadata?.expiresAt && Number(object.customMetadata.expiresAt) < Date.now()) {
      await env.SHARES.delete(cap.key);
      return new Response("Link expired", { status: 410 });
    }
    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("etag", object.httpEtag);
    headers.set("accept-ranges", "bytes");
    headers.set("cache-control", "private, no-store");
    headers.set("content-disposition", `attachment; filename*=UTF-8''${encodeURIComponent(cap.filename)}`);
    headers.set("access-control-allow-origin", "*");
    const partial = request.headers.has("range") && !!object.range;
    if (partial && object.range) {
      headers.set("content-range", `bytes ${object.range.offset}-${object.range.offset + object.range.length - 1}/${object.size}`);
      headers.set("content-length", String(object.range.length));
    } else {
      headers.set("content-length", String(object.size));
    }
    return new Response(object.body, { status: partial ? 206 : 200, headers });
  }

  if (url.pathname.startsWith("/v1/r/") && request.method === "GET") {
    const cap = await unseal<Capability>(env, url.pathname.slice("/v1/r/".length));
    if (!cap || cap.kind !== "source" || cap.exp < Date.now()) return new Response("Link expired or invalid", { status: 403 });
    const raw = await env.SHARES.get(`shares/${cap.id}.json`);
    if (!raw) return new Response("Share not found", { status: 404 });
    const descriptor = await unseal<ShareDescriptor>(env, await raw.text());
    if (!descriptor || descriptor.expiresAt < Date.now()) return new Response("Share expired", { status: 410 });
    const source = safeUpstream(cap.url);
    if (!source) return new Response("Blocked source", { status: 403 });
    const upstream = await fetchUpstream(source, descriptor.headers, request);
    const contentType = upstream.headers.get("content-type") ?? "";
    const isManifest = /mpegurl/i.test(contentType) || source.pathname.toLowerCase().endsWith(".m3u8");
    if (isManifest && upstream.ok) {
      const body = await upstream.text();
      if (body.length > MAX_MANIFEST_BYTES) return new Response("Manifest too large to rewrite", { status: 502 });
      try {
        const rewritten = await rewriteManifest(env, body, cap.id, cap.exp, source);
        return new Response(rewritten, { status: upstream.status, headers: {
          "content-type": "application/vnd.apple.mpegurl",
          "cache-control": "private, no-store",
          "access-control-allow-origin": "*",
        }});
      } catch {
        return new Response("Unable to safely rewrite playlist", { status: 502 });
      }
    }
    const headers = new Headers();
    for (const name of ["content-type", "content-length", "content-range", "accept-ranges", "etag", "last-modified"]) {
      const value = upstream.headers.get(name);
      if (value) headers.set(name, value);
    }
    headers.set("cache-control", "private, no-store");
    headers.set("access-control-allow-origin", "*");
    return new Response(upstream.body, { status: upstream.status, headers });
  }

  return json({ error: "Not found" }, 404);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await route(request, env);
    } catch {
      return json({ error: "Share service error" }, 500);
    }
  },
};
