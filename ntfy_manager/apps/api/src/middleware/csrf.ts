import type { NextFunction, Request, Response } from "express";

/**
 * CSRF guard for the cookie-authenticated API.
 *
 * The session lives in a cookie (and, through Ingress, in the configured
 * default credentials), so a foreign web page must not be able to make the
 * browser send a state-changing request. Two checks for every method that
 * changes state:
 *
 *  1. Fetch Metadata: browsers send `Sec-Fetch-Site`. `cross-site` (and
 *     `same-site`, which is a sibling host) is refused.
 *  2. Custom header: the panel's own client sends `X-Requested-With`. A page on
 *     another origin cannot add a custom header without a CORS preflight, and
 *     this API answers no preflight (`cors({ origin: false })`).
 *
 * Safe methods (GET, HEAD, OPTIONS) change nothing and pass.
 */
export const CSRF_HEADER = "x-requested-with";
export const CSRF_HEADER_VALUE = "ntfy-admin";

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

export function csrfGuard(req: Request, res: Response, next: NextFunction): void {
  if (SAFE_METHODS.has(req.method)) {
    next();
    return;
  }
  const site = req.headers["sec-fetch-site"];
  if (typeof site === "string" && site !== "same-origin" && site !== "none") {
    res.status(403).json({ error: "csrf_blocked", message: "Cross-site request refused." });
    return;
  }
  if (req.headers[CSRF_HEADER] !== CSRF_HEADER_VALUE) {
    res.status(403).json({ error: "csrf_blocked", message: "Missing request header." });
    return;
  }
  next();
}
