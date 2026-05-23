import { z } from "zod";

const EnvSchema = z.object({
  NODE_ENV: z.string().default("production"),
  API_PORT: z.coerce.number().default(3000),
  JWT_SECRET: z.string().min(24),
  SESSION_COOKIE_NAME: z.string().default("ntfy_admin_token"),
  LOG_LEVEL: z.string().default("info"),

  // ntfy connection (from add-on options)
  NTFY_BASE_URL: z.string().url(),
  NTFY_AUTH_TYPE: z.enum(["none", "basic", "bearer"]).default("none"),
  NTFY_USERNAME: z.string().optional().default(""),
  NTFY_PASSWORD: z.string().optional().default(""),
  NTFY_BEARER_TOKEN: z.string().optional().default(""),
  NTFY_DEFAULT_TOPICS: z.string().optional().default(""),
  ALLOW_LOGIN_OVERRIDE: z
    .string()
    .default("true")
    .transform((v) => v === "true" || v === "1")
});

export const env = EnvSchema.parse(process.env);
export const isProd = env.NODE_ENV === "production";

// Strip trailing slash so all path joins are consistent
export const NTFY_BASE = env.NTFY_BASE_URL.replace(/\/+$/, "");

export const DEFAULT_TOPICS = env.NTFY_DEFAULT_TOPICS
  ? env.NTFY_DEFAULT_TOPICS.split(",")
      .map((t) => t.trim())
      .filter(Boolean)
  : [];

export function hasDefaultCredentials(): boolean {
  if (env.NTFY_AUTH_TYPE === "basic") {
    return !!(env.NTFY_USERNAME && env.NTFY_PASSWORD);
  }
  if (env.NTFY_AUTH_TYPE === "bearer") {
    return !!env.NTFY_BEARER_TOKEN;
  }
  return env.NTFY_AUTH_TYPE === "none";
}
