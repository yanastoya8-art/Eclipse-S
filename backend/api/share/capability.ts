import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";

export interface ShareCapability {
  url: string;
  headers: Record<string, string>;
  expiresAt: number;
}

const SENSITIVE_HEADERS = new Set(["authorization", "cookie", "proxy-authorization", "x-api-key", "x-auth-token"]);
const ALLOWED_HEADERS = new Set(["authorization", "cookie", "referer", "user-agent", "origin", "accept", "x-api-key", "x-auth-token"]);

function encryptionKey(): Buffer {
  const secret = process.env.BLOB_READ_WRITE_TOKEN?.trim();
  if (!secret) throw new Error("Blob storage is not configured");
  return createHash("sha256").update(secret, "utf8").digest();
}

function isPrivateIPv4(address: string): boolean {
  const p = address.split(".").map(Number);
  if (p.length !== 4 || p.some((v) => !Number.isInteger(v) || v < 0 || v > 255)) return true;
  const [a, b] = p;
  return a === 0 || a === 10 || a === 127 || a >= 224 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) ||
    (a === 192 && b === 0) ||
    (a === 198 && (b === 18 || b === 19));
}

function isPrivateAddress(address: string): boolean {
  if (isIP(address) === 4) return isPrivateIPv4(address);
  if (isIP(address) === 6) {
    const value = address.toLowerCase();
    if (value.startsWith("::ffff:")) {
      const mapped = value.slice(7);
      // Dotted IPv4-mapped addresses can be classified precisely. Reject
      // hexadecimal mapped forms conservatively to avoid IPv4-mapped SSRF.
      if (isIP(mapped) === 4) return isPrivateIPv4(mapped);
      return true;
    }
    return value === "::" || value === "::1" ||
      value.startsWith("fc") || value.startsWith("fd") ||
      value.startsWith("fe8") || value.startsWith("fe9") ||
      value.startsWith("fea") || value.startsWith("feb") ||
      value.startsWith("ff");
  }
  return true;
}

export async function validatePublicMediaURL(raw: string): Promise<URL> {
  let url: URL;
  try { url = new URL(raw); } catch { throw new Error("Invalid media URL"); }
  if (url.protocol !== "https:" || !url.hostname || url.username || url.password) {
    throw new Error("Only public HTTPS media URLs are supported");
  }
  const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (hostname === "localhost" || hostname.endsWith(".localhost") ||
      hostname.endsWith(".local") || hostname.endsWith(".internal") ||
      hostname.endsWith(".test") || hostname.endsWith(".invalid")) {
    throw new Error("Private media hosts are not allowed");
  }
  if (isIP(hostname)) {
    if (isPrivateAddress(hostname)) throw new Error("Private media addresses are not allowed");
    return url;
  }
  const addresses = await lookup(hostname, { all: true, verbatim: true });
  if (!addresses.length || addresses.some((entry) => isPrivateAddress(entry.address))) {
    throw new Error("Media host resolves to a private or unsupported address");
  }
  return url;
}

export function sanitizeProviderHeaders(input: unknown): Record<string, string> {
  if (!input || typeof input !== "object" || Array.isArray(input)) return {};
  const output: Record<string, string> = {};
  for (const [rawName, rawValue] of Object.entries(input as Record<string, unknown>)) {
    const name = rawName.trim();
    const lower = name.toLowerCase();
    if (!ALLOWED_HEADERS.has(lower) || typeof rawValue !== "string" ||
        rawValue.length > 8_192 || /[\r\n]/.test(rawValue)) continue;
    output[name] = rawValue;
  }
  return output;
}

export function headersForTarget(
  headers: Record<string, string>,
  originalURL: string,
  targetURL: string,
): Record<string, string> {
  if (new URL(originalURL).origin === new URL(targetURL).origin) return headers;
  return Object.fromEntries(
    Object.entries(headers).filter(([name]) => !SENSITIVE_HEADERS.has(name.toLowerCase())),
  );
}

export function encryptShareCapability(payload: ShareCapability): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", encryptionKey(), iv);
  const encrypted = Buffer.concat([
    cipher.update(JSON.stringify(payload), "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [iv, tag, encrypted].map((part) => part.toString("base64url")).join(".");
}

export function decryptShareCapability(token: string): ShareCapability {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid share capability");
  const [iv, tag, ciphertext] = parts.map((part) => Buffer.from(part, "base64url"));
  if (iv.length !== 12 || tag.length !== 16 || ciphertext.length > 32_768) {
    throw new Error("Invalid share capability");
  }
  const decipher = createDecipheriv("aes-256-gcm", encryptionKey(), iv);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  const value = JSON.parse(plaintext.toString("utf8")) as ShareCapability;
  if (!value || typeof value.url !== "string" ||
      !value.headers || typeof value.headers !== "object" ||
      !Number.isFinite(value.expiresAt) || value.expiresAt <= Date.now()) {
    throw new Error("Share link expired or invalid");
  }
  return value;
}

export function publicShareBaseURL(req: { headers: Record<string, string | string[] | undefined> }): string {
  const hostValue = process.env.VERCEL_PROJECT_PRODUCTION_URL ||
    process.env.VERCEL_URL ||
    req.headers["x-forwarded-host"] ||
    req.headers.host;
  const host = Array.isArray(hostValue) ? hostValue[0] : hostValue;
  if (!host || !/^[a-z0-9.-]+(?::\d+)?$/i.test(host)) {
    throw new Error("Public share host is unavailable");
  }
  return `https://${host}`;
}
