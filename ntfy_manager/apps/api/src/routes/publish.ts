import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { ntfyPublish } from "../ntfy/client.js";
import { audit } from "../services/logger.js";

export const publishRouter = Router();

// Title, tags and click travel as HTTP headers. A header cannot hold line breaks
// or other control characters (that would let a value inject further headers), so
// such input is refused with 400. Text outside plain ASCII (umlauts, emoji) is
// sent RFC 2047 encoded, which ntfy decodes; sending it raw makes fetch() throw.
const noControlChars = (v: string) => !/[\u0000-\u001f\u007f]/.test(v);
const headerText = z.string().refine(noControlChars, "must not contain control characters");
const toHeader = (v: string) =>
  /[^\u0020-\u007e]/.test(v) ? `=?UTF-8?B?${Buffer.from(v, "utf8").toString("base64")}?=` : v;

publishRouter.use(requireAuth);

publishRouter.post("/", async (req, res) => {
  const schema = z.object({
    topic: z.string().min(1),
    message: z.string(),
    title: headerText.optional(),
    priority: z.coerce.number().min(1).max(5).optional(),
    // The panel sends a comma separated string; API clients may send a JSON array.
    tags: z
      .union([headerText, z.array(headerText)])
      .optional()
      .transform((v) => (Array.isArray(v) ? v.join(",") : v)),
    click: headerText.optional()
  });
  const body = schema.parse(req.body);

  const headers: Record<string, string> = {};
  if (body.title) headers["Title"] = toHeader(body.title);
  if (body.priority) headers["Priority"] = String(body.priority);
  if (body.tags) headers["Tags"] = toHeader(body.tags);
  if (body.click) headers["Click"] = toHeader(body.click);

  const r = await ntfyPublish(body.topic, body.message, headers, req.session);

  audit(
    r.ok ? "INFO" : "WARN",
    "publish",
    `POST /${body.topic} → ${r.status}`,
    { topic: body.topic, priority: body.priority }
  );

  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});
