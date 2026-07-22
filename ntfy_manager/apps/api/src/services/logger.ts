/**
 * In-memory ring buffer for audit logs.
 * Replaces the original Prisma-backed AuditLog table.  Logs survive add-on
 * restarts only as console output (Supervisor log).  In-memory entries are
 * cheap and let the UI render a Debug feed without a database.
 */

import { env } from "../env";

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR";

export type LogEntry = {
  id: string;
  level: LogLevel;
  source: string;
  message: string;
  meta?: unknown;
  createdAt: string;
};

const MAX_ENTRIES = 500;
const buffer: LogEntry[] = [];

// Numeric severity so we can compare against the configured minimum level.
// The in-memory buffer (used by the web UI's own Debug feed, which lets you
// filter interactively) always keeps every entry regardless of this
// threshold — only what's forwarded to console/stdout (and therefore the HA
// Supervisor log) is gated by it.
const LEVEL_PRIORITY: Record<LogLevel, number> = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3
};

function configuredThreshold(): number {
  const configured = env.LOG_LEVEL.toUpperCase() as LogLevel;
  return LEVEL_PRIORITY[configured] ?? LEVEL_PRIORITY.INFO;
}

export function audit(
  level: LogLevel,
  source: string,
  message: string,
  meta?: unknown
): LogEntry {
  const entry: LogEntry = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    level,
    source,
    message,
    meta,
    createdAt: new Date().toISOString()
  };
  buffer.unshift(entry);
  if (buffer.length > MAX_ENTRIES) buffer.length = MAX_ENTRIES;

  if (LEVEL_PRIORITY[level] >= configuredThreshold()) {
    const tag = `[${level} ${source}]`;
    if (level === "ERROR") console.error(tag, message, meta ?? "");
    else if (level === "WARN") console.warn(tag, message, meta ?? "");
    else console.log(tag, message, meta ?? "");
  }

  return entry;
}

export function getLogs(filter?: { level?: LogLevel; limit?: number }): LogEntry[] {
  const lvl = filter?.level;
  const limit = Math.min(Math.max(filter?.limit ?? 100, 1), MAX_ENTRIES);
  const out = lvl ? buffer.filter((e) => e.level === lvl) : buffer;
  return out.slice(0, limit);
}

export function clearLogs(): void {
  buffer.length = 0;
}

export const logger = {
  info: (msg: string, meta?: unknown) => audit("INFO", "runtime", msg, meta),
  warn: (msg: string, meta?: unknown) => audit("WARN", "runtime", msg, meta),
  error: (msg: string, meta?: unknown) => audit("ERROR", "runtime", msg, meta),
  debug: (msg: string, meta?: unknown) => audit("DEBUG", "runtime", msg, meta)
};
