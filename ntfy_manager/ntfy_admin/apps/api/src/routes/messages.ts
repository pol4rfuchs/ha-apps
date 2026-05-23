import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { ntfyStream } from "../ntfy/client.js";
import { audit } from "../services/logger.js";

export const messagesRouter = Router();

messagesRouter.use(requireAuth);

/**
 * GET /api/ntfy/messages?topic=ha-alerts,ha-info&since=24h&limit=50
 *
 * Polls each topic once (poll=1) and returns a flat, sorted array.  This is the
 * Message Browser endpoint.
 */
messagesRouter.get("/", async (req, res) => {
  const schema = z.object({
    topic: z.string().min(1),
    since: z.string().default("24h"),
    limit: z.coerce.number().min(1).max(500).default(50)
  });
  const q = schema.parse(req.query);

  const topics = q.topic
    .split(",")
    .map((t) => t.trim())
    .filter(Boolean);

  if (!topics.length) {
    res.status(400).json({ error: "no_topics" });
    return;
  }

  const all: any[] = [];
  const errors: { topic: string; status: number; message?: string }[] = [];

  await Promise.all(
    topics.map(async (topic) => {
      const url = `/${encodeURIComponent(topic)}/json?poll=1&since=${encodeURIComponent(
        q.since
      )}&limit=${q.limit}`;
      try {
        const r = await ntfyStream(url, { session: req.session });
        if (!r.ok) {
          errors.push({ topic, status: r.status });
          return;
        }
        const text = await r.text();
        for (const line of text.split("\n")) {
          const t = line.trim();
          if (!t) continue;
          try {
            all.push(JSON.parse(t));
          } catch {
            /* ignore malformed line */
          }
        }
      } catch (e) {
        errors.push({
          topic,
          status: 0,
          message: e instanceof Error ? e.message : String(e)
        });
      }
    })
  );

  all.sort((a, b) => (b?.time ?? 0) - (a?.time ?? 0));

  audit("DEBUG", "messages", `Polled ${topics.length} topics → ${all.length} msgs, ${errors.length} errors`);

  res.json({
    ok: true,
    messages: all,
    errors,
    topicCount: topics.length,
    count: all.length
  });
});
