import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.js";
import { clearLogs, getLogs } from "../services/logger.js";

export const logsRouter = Router();

logsRouter.use(requireAuth);

logsRouter.get("/", (req, res) => {
  const schema = z.object({
    level: z.enum(["DEBUG", "INFO", "WARN", "ERROR"]).optional(),
    limit: z.coerce.number().min(1).max(500).default(100)
  });
  const q = schema.parse(req.query);
  res.json({ logs: getLogs(q) });
});

logsRouter.delete("/", (_req, res) => {
  clearLogs();
  res.json({ ok: true });
});
