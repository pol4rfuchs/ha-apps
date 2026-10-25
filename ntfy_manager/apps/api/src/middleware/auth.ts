import type { NextFunction, Request, Response } from "express";
import { env, hasDefaultCredentials } from "../env.js";
import {
  basicAuthHeader,
  bearerAuthHeader,
  decryptSession,
  type SessionPayload
} from "../services/auth.js";

declare global {
  namespace Express {
    interface Request {
      session?: SessionPayload;
    }
  }
}

/** Set after an explicit /logout call. Blocks falling back to add-on
 *  config defaults until a fresh /login happens or this cookie expires.
 *  Without this, logout was a no-op whenever default creds (e.g. the
 *  HA bearer token) were configured — the very next request would just
 *  re-authenticate via step 2 below. */
export const LOGGED_OUT_COOKIE_NAME = `${env.SESSION_COOKIE_NAME}_loggedout`;

/** Home Assistant Ingress proxies authenticated users from 172.30.32.2.
 *  nginx overwrites X-Real-IP with the real peer address and the API only
 *  listens on 127.0.0.1, so the header cannot be spoofed by clients. */
const INGRESS_PEERS = new Set(["172.30.32.2", "127.0.0.1", "::1"]);

function viaIngress(req: Request): boolean {
  const peer = req.headers["x-real-ip"];
  return typeof peer === "string" && INGRESS_PEERS.has(peer);
}

/**
 * Resolve effective session for a request.
 *
 * Order:
 *   1. Encrypted cookie (interactive login)        — if present and valid
 *   2. Explicit logout flag                        — blocks fallback to defaults
 *   3. Add-on-config defaults (NTFY_USERNAME etc.) — if configured, and only
 *      through Ingress: the optional direct port 8099 always needs a login,
 *      otherwise anyone on the LAN would act with the configured credentials
 *   4. null                                        — anonymous, blocked
 */
export function resolveSession(req: Request): SessionPayload | null {
  // 1) cookie?
  const raw = req.cookies?.[env.SESSION_COOKIE_NAME];
  if (raw) {
    const session = decryptSession(raw);
    if (session) return session;
  }

  // 2) explicitly logged out? then don't fall back to defaults.
  if (req.cookies?.[LOGGED_OUT_COOKIE_NAME]) {
    return null;
  }

  // 3) defaults? (Ingress only)
  if (hasDefaultCredentials() && viaIngress(req)) {
    const now = Math.floor(Date.now() / 1000);
    if (env.NTFY_AUTH_TYPE === "basic") {
      return {
        authType: "basic",
        username: env.NTFY_USERNAME || "(default)",
        authHeader: basicAuthHeader(env.NTFY_USERNAME, env.NTFY_PASSWORD),
        iat: now,
        exp: now + 3600
      };
    }
    if (env.NTFY_AUTH_TYPE === "bearer") {
      return {
        authType: "bearer",
        username: "(token)",
        authHeader: bearerAuthHeader(env.NTFY_BEARER_TOKEN),
        iat: now,
        exp: now + 3600
      };
    }
    // auth_type = none
    return {
      authType: "none",
      username: "(anonymous)",
      authHeader: "",
      iat: now,
      exp: now + 3600
    };
  }

  return null;
}

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const session = resolveSession(req);
  if (!session) {
    res.status(401).json({ error: "not_authenticated" });
    return;
  }
  req.session = session;
  next();
}

/**
 * Soft variant — populates req.session if available, but doesn't reject.
 * Used by status/info endpoints that work even when not logged in.
 */
export function attachSession(req: Request, _res: Response, next: NextFunction): void {
  const session = resolveSession(req);
  if (session) req.session = session;
  next();
}
