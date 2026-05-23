import { useEffect, useRef, useState } from "react";
import { Bug, Play, Square, Trash2, RefreshCw } from "lucide-react";
import { api } from "../lib/api";
import { toast } from "../lib/toast";
import { getTopicsString } from "../lib/topics";
import type { LogEntry } from "../types";

type SseState =
  | "IDLE"
  | "CONNECTING"
  | "CONNECTED"
  | "DISCONNECTED"
  | "RECONNECTING"
  | "STOPPED";

export default function DebugPage({
  refreshKey,
  defaultTopics
}: {
  refreshKey: number;
  defaultTopics: string[];
}) {
  // ── SSE state ──────────────────────────────────────────────────────────
  const [topics, setTopics] = useState(getTopicsString(defaultTopics));
  const [state, setState] = useState<SseState>("IDLE");
  const [counters, setCounters] = useState({
    connects: 0,
    disconnects: 0,
    reconnects: 0,
    msgs: 0
  });
  const [sseLog, setSseLog] = useState<{ t: string; kind: string; text: string }[]>([]);
  const sourceRef = useRef<EventSource | null>(null);
  const intentionalStopRef = useRef(false);
  const reconnectTimerRef = useRef<number | null>(null);

  function pushLog(kind: string, text: string) {
    setSseLog((prev) =>
      [{ t: new Date().toLocaleTimeString(), kind, text }, ...prev].slice(0, 200)
    );
  }

  function buildUrl(): string {
    const t = topics
      .split(",")
      .map((x) => x.trim())
      .filter(Boolean)
      .join(",");
    return `/api/ntfy/stream?topic=${encodeURIComponent(t)}`;
  }

  function start(reconnect = false) {
    if (!topics.trim()) {
      toast.error("At least one topic required");
      return;
    }
    if (reconnectTimerRef.current) {
      window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
    intentionalStopRef.current = false;

    setState(reconnect ? "RECONNECTING" : "CONNECTING");
    if (reconnect) {
      setCounters((c) => ({ ...c, reconnects: c.reconnects + 1 }));
      pushLog("warn", `Reconnect attempt`);
    } else {
      pushLog("info", `Opening stream: ${buildUrl()}`);
    }

    const es = new EventSource(buildUrl(), { withCredentials: true });
    sourceRef.current = es;

    es.onopen = () => {
      setState("CONNECTED");
      setCounters((c) => ({ ...c, connects: c.connects + 1 }));
      pushLog("ok", "Stream opened ✓");
    };

    es.onmessage = (ev) => {
      try {
        const data = JSON.parse(ev.data);
        if (data.event === "keepalive" || ev.data === "keepalive") {
          pushLog("info", "keepalive ♥");
          return;
        }
        setCounters((c) => ({ ...c, msgs: c.msgs + 1 }));
        pushLog(
          "ok",
          `📨 [${data.topic ?? "?"}] ${data.message ?? "(no body)"}` +
            (data.title ? ` | ${data.title}` : "") +
            (data.priority ? ` | prio:${data.priority}` : "")
        );
      } catch {
        pushLog("info", `RAW: ${ev.data}`);
      }
    };

    es.onerror = () => {
      es.close();
      sourceRef.current = null;
      if (intentionalStopRef.current) {
        setState("STOPPED");
        pushLog("warn", "Stream stopped by user");
        return;
      }
      setState("DISCONNECTED");
      setCounters((c) => ({ ...c, disconnects: c.disconnects + 1 }));
      pushLog("err", "Stream closed — reconnecting in 5s");
      reconnectTimerRef.current = window.setTimeout(() => start(true), 5000);
    };
  }

  function stop() {
    intentionalStopRef.current = true;
    if (reconnectTimerRef.current) {
      window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
    sourceRef.current?.close();
    sourceRef.current = null;
    setState("STOPPED");
    pushLog("warn", "Monitoring stopped by user");
  }

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      intentionalStopRef.current = true;
      sourceRef.current?.close();
      if (reconnectTimerRef.current) window.clearTimeout(reconnectTimerRef.current);
    };
  }, []);

  // ── Audit log feed ─────────────────────────────────────────────────────
  const [logs, setLogs] = useState<LogEntry[]>([]);

  async function reloadLogs() {
    try {
      const r = await api<{ logs: LogEntry[] }>("/logs?limit=200");
      setLogs(r.logs);
    } catch {
      /* ignore */
    }
  }
  async function clearLogs() {
    if (!confirm("Clear in-memory audit log?")) return;
    try {
      await api("/logs", { method: "DELETE" });
      setLogs([]);
      toast.success("Cleared");
    } catch {
      toast.error("Failed to clear");
    }
  }

  useEffect(() => {
    reloadLogs();
  }, [refreshKey]);

  const stateBadge: Record<SseState, string> = {
    IDLE: "",
    CONNECTING: "badge-info",
    CONNECTED: "badge-ok",
    DISCONNECTED: "badge-bad",
    RECONNECTING: "badge-warn",
    STOPPED: ""
  };

  return (
    <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
      {/* ── SSE Monitor ─────────────────────────────────────────────────── */}
      <div className="card">
        <div className="card-header">
          <h3 className="font-bold flex items-center gap-2">
            <Bug className="h-4 w-4" /> SSE Monitor
          </h3>
          <span className={`badge ${stateBadge[state]}`}>{state}</span>
        </div>
        <div className="card-body space-y-3">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <Stat label="Connects" value={counters.connects} cls="text-ok" />
            <Stat label="Disconnects" value={counters.disconnects} cls="text-bad" />
            <Stat label="Reconnects" value={counters.reconnects} cls="text-warn" />
            <Stat label="Messages" value={counters.msgs} cls="text-info" />
          </div>
          <div className="flex flex-wrap gap-2">
            <input
              className="input font-mono flex-1 min-w-[200px]"
              value={topics}
              onChange={(e) => setTopics(e.target.value)}
              placeholder="ha-alerts,ha-info,…"
            />
            {state === "CONNECTED" || state === "CONNECTING" || state === "RECONNECTING" ? (
              <button onClick={stop} className="btn btn-danger text-xs">
                <Square className="h-3.5 w-3.5" /> Stop
              </button>
            ) : (
              <button onClick={() => start()} className="btn btn-primary text-xs">
                <Play className="h-3.5 w-3.5" /> Connect
              </button>
            )}
          </div>
          <div className="rounded-xl border border-white/10 bg-black/40 p-2 max-h-[280px] overflow-y-auto space-y-1">
            {!sseLog.length ? (
              <div className="empty">Not monitoring. Click Connect to open the stream.</div>
            ) : (
              sseLog.map((e, i) => (
                <div key={i} className="text-xs font-mono px-2 py-1 leading-snug flex gap-2">
                  <span className="text-muted">{e.t}</span>
                  <span
                    className={
                      e.kind === "ok"
                        ? "text-ok"
                        : e.kind === "err"
                        ? "text-bad"
                        : e.kind === "warn"
                        ? "text-warn"
                        : "text-info"
                    }
                  >
                    [SSE]
                  </span>
                  <span className="break-all">{e.text}</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* ── Audit Log ───────────────────────────────────────────────────── */}
      <div className="card">
        <div className="card-header">
          <h3 className="font-bold">Audit Log (in-memory)</h3>
          <div className="flex gap-2">
            <button onClick={reloadLogs} className="btn btn-ghost text-xs">
              <RefreshCw className="h-3.5 w-3.5" />
            </button>
            <button onClick={clearLogs} className="btn btn-ghost text-xs">
              <Trash2 className="h-3.5 w-3.5" /> Clear
            </button>
          </div>
        </div>
        <div className="card-body">
          <div className="rounded-xl border border-white/10 bg-black/40 p-2 max-h-[400px] overflow-y-auto space-y-1">
            {!logs.length ? (
              <div className="empty">No log entries yet.</div>
            ) : (
              logs.map((l) => (
                <div
                  key={l.id}
                  className="text-xs font-mono px-2 py-1 leading-snug flex gap-2"
                >
                  <span className="text-muted">
                    {new Date(l.createdAt).toLocaleTimeString()}
                  </span>
                  <span
                    className={
                      l.level === "ERROR"
                        ? "text-bad"
                        : l.level === "WARN"
                        ? "text-warn"
                        : l.level === "INFO"
                        ? "text-ok"
                        : "text-muted"
                    }
                  >
                    [{l.level}]
                  </span>
                  <span className="text-info">{l.source}</span>
                  <span className="break-all">{l.message}</span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({
  label,
  value,
  cls
}: {
  label: string;
  value: number;
  cls?: string;
}) {
  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.04] px-3 py-2">
      <div className="text-[10px] font-extrabold uppercase tracking-wider text-muted">
        {label}
      </div>
      <div className={`font-mono text-lg font-extrabold ${cls ?? ""}`}>{value}</div>
    </div>
  );
}
