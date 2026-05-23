import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { env } from "../env.js";

/**
 * Stateless authenticated-encryption for the session cookie.
 *
 * We don't run a database — instead we put the user's ntfy credentials directly
 * into an encrypted cookie.  The cookie is HMAC-authenticated (AES-GCM) with a
 * key derived from JWT_SECRET.  Server has zero state per session.
 */

// Derive a stable 32-byte key from JWT_SECRET (any length string).
const KEY = createHash("sha256").update(env.JWT_SECRET).digest();
const ALGO = "aes-256-gcm";

export type SessionPayload = {
  /** "basic" | "bearer" | "none" */
  authType: "basic" | "bearer" | "none";
  /** Display name shown in the UI ("admin", "*", etc.) */
  username: string;
  /** Pre-built Authorization header value. Empty for "none". */
  authHeader: string;
  /** Issued-at (unix seconds) */
  iat: number;
  /** Expires-at (unix seconds) */
  exp: number;
};

export function encryptSession(payload: SessionPayload): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv(ALGO, KEY, iv);
  const plain = Buffer.from(JSON.stringify(payload), "utf8");
  const enc = Buffer.concat([cipher.update(plain), cipher.final()]);
  const tag = cipher.getAuthTag();
  // Encoding: <iv:12><tag:16><ciphertext:n>, base64url
  return Buffer.concat([iv, tag, enc]).toString("base64url");
}

export function decryptSession(token: string): SessionPayload | null {
  try {
    const buf = Buffer.from(token, "base64url");
    if (buf.length < 12 + 16 + 1) return null;
    const iv = buf.subarray(0, 12);
    const tag = buf.subarray(12, 28);
    const ct = buf.subarray(28);
    const decipher = createDecipheriv(ALGO, KEY, iv);
    decipher.setAuthTag(tag);
    const dec = Buffer.concat([decipher.update(ct), decipher.final()]);
    const payload = JSON.parse(dec.toString("utf8")) as SessionPayload;
    if (typeof payload.exp !== "number") return null;
    if (Date.now() / 1000 >= payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

/** Build a Basic-auth header from user/pass. */
export function basicAuthHeader(user: string, pass: string): string {
  const b64 = Buffer.from(`${user}:${pass}`, "utf8").toString("base64");
  return `Basic ${b64}`;
}

/** Build a Bearer header. */
export function bearerAuthHeader(token: string): string {
  return `Bearer ${token}`;
}
