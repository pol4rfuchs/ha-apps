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

/**
 * Resolve effective session for a request.
 *
 * Order:
 *   1. Encrypted cookie (interactive login)        — if present and valid
 *   2. Explicit logout flag                        — blocks fallback to defaults
 *   3. Add-on-config defaults (NTFY_USERNAME etc.) — if configured
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

  // 3) defaults?
  if (hasDefaultCredentials()) {
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
