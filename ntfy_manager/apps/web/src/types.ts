export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR";

export type LogEntry = {
  id: string;
  level: LogLevel;
  source: string;
  message: string;
  meta?: unknown;
  createdAt: string;
};
