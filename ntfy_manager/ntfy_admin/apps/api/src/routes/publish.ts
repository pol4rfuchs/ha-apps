import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { ntfyPublish } from "../ntfy/client.js";
import { audit } from "../services/logger.js";

export const publishRouter = Router();

publishRouter.use(requireAuth);

publishRouter.post("/", async (req, res) => {
  const schema = z.object({
    topic: z.string().min(1),
    message: z.string(),
    title: z.string().optional(),
    priority: z.coerce.number().min(1).max(5).optional(),
    tags: z.string().optional(),
    click: z.string().optional()
  });
  const body = schema.parse(req.body);

  const headers: Record<string, string> = {};
  if (body.title) headers["Title"] = body.title;
  if (body.priority) headers["Priority"] = String(body.priority);
  if (body.tags) headers["Tags"] = body.tags;
  if (body.click) headers["Click"] = body.click;

  const r = await ntfyPublish(body.topic, body.message, headers, req.session);

  audit(
    r.ok ? "INFO" : "WARN",
    "publish",
    `POST /${body.topic} → ${r.status}`,
    { topic: body.topic, priority: body.priority }
  );

  res.status(r.status || 502).json({ ok: r.ok, data: r.data, status: r.status });
});
