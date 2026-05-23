import { useEffect, useState } from "react";
import { Inbox, RefreshCw, Eraser, Settings } from "lucide-react";
import { ntfy, ntfyErrorText, type NtfyMessage } from "../lib/ntfy";
import { toast } from "../lib/toast";
import Modal from "../components/Modal";
import { getTopicsString, saveTopics } from "../lib/topics";

const SINCE_OPTIONS = [
  { v: "10m", label: "Last 10m" },
  { v: "1h", label: "Last 1h" },
  { v: "6h", label: "Last 6h" },
  { v: "24h", label: "Last 24h" },
  { v: "7d", label: "Last 7 days" },
  { v: "all", label: "All cached" }
];
const LIMIT_OPTIONS = [25, 50, 100, 250, 500];

export default function MessagesPage({
  search,
  defaultTopics
}: {
  search: string;
  defaultTopics: string[];
}) {
  const [topic, setTopic] = useState(getTopicsString(defaultTopics));
  const [since, setSince] = useState("24h");
  const [limit, setLimit] = useState(50);
  const [messages, setMessages] = useState<NtfyMessage[]>([]);
  const [errors, setErrors] = useState<{ topic: string; status: number }[]>([]);
  const [busy, setBusy] = useState(false);
  const [topicModal, setTopicModal] = useState(false);

  async function poll() {
    if (!topic.trim()) {
      toast.error("At least one topic required");
      return;
    }
    setBusy(true);
    try {
      const res = await ntfy.messages(topic, since, limit);
      setMessages(res.messages);
      setErrors(res.errors);
      if (res.count === 0 && res.errors.length === 0) toast.info("No cached messages");
      else toast.success(`${res.count} messages`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    } finally {
      setBusy(false);
    }
  }

  function clear() {
    setMessages([]);
    setErrors([]);
  }

  // Initial fetch on mount
  useEffect(() => {
    poll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const filtered = !search
    ? messages
    : messages.filter((m) => {
        const haystack = `${m.topic ?? ""} ${m.title ?? ""} ${m.message ?? ""} ${
          m.tags?.join(",") ?? ""
        }`.toLowerCase();
        return haystack.includes(search.toLowerCase());
      });

  const topicCount = new Set(messages.map((m) => m.topic).filter(Boolean)).size;
  const highCount = messages.filter((m) => (m.priority ?? 0) >= 4).length;
  const lastTime = messages[0]?.time
    ? new Date(messages[0].time * 1000).toLocaleTimeString()
    : "—";

  return (
    <>
      <div className="card">
        <div className="card-header">
          <h3 className="font-bold flex items-center gap-2">
            <Inbox className="h-4 w-4" /> Message Browser
          </h3>
          <div className="flex gap-2">
            <button onClick={() => setTopicModal(true)} className="btn btn-ghost text-xs">
              <Settings className="h-3.5 w-3.5" /> Topics
            </button>
            <button onClick={clear} className="btn btn-ghost text-xs">
              <Eraser className="h-3.5 w-3.5" /> Clear
            </button>
            <button onClick={poll} disabled={busy} className="btn btn-primary text-xs">
              <RefreshCw className={`h-3.5 w-3.5 ${busy ? "animate-spin" : ""}`} />
              {busy ? "Fetching…" : "Fetch"}
            </button>
          </div>
        </div>
        <div className="card-body space-y-3">
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-3">
            <div className="lg:col-span-2">
              <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
                Topics (comma separated)
              </label>
              <input
                className="input font-mono"
                value={topic}
                onChange={(e) => setTopic(e.target.value)}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
                  Limit
                </label>
                <select
                  className="select"
                  value={limit}
                  onChange={(e) => setLimit(Number(e.target.value))}
                >
                  {LIMIT_OPTIONS.map((n) => (
                    <option key={n} value={n}>
                      {n}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
                  Since
                </label>
                <select
                  className="select"
                  value={since}
                  onChange={(e) => setSince(e.target.value)}
                >
                  {SINCE_OPTIONS.map((s) => (
                    <option key={s.v} value={s.v}>
                      {s.label}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <Stat label="Total" value={messages.length} />
            <Stat label="Topics" value={topicCount} cls="text-info" />
            <Stat label="High prio" value={highCount} cls="text-warn" />
            <Stat label="Latest" value={lastTime} small cls="text-ok" />
          </div>

          {errors.length > 0 && (
            <div className="space-y-1">
              {errors.map((e, i) => (
                <div
                  key={i}
                  className="text-xs text-bad font-mono px-3 py-2 rounded-lg border border-bad/30 bg-bad/5"
                >
                  {e.topic} → HTTP {e.status}
                </div>
              ))}
            </div>
          )}

          <div className="space-y-2 max-h-[600px] overflow-y-auto pr-1">
            {!filtered.length ? (
              <div className="empty">No messages.</div>
            ) : (
              filtered.map((m, i) => <MessageCard key={i} m={m} />)
            )}
          </div>
        </div>
      </div>

      <Modal
        open={topicModal}
        onClose={() => setTopicModal(false)}
        title="Topic Settings"
        footer={
          <>
            <button className="btn btn-ghost" onClick={() => setTopicModal(false)}>
              Cancel
            </button>
            <button
              className="btn btn-primary"
              onClick={() => {
                saveTopics(topic);
                toast.success("Topics saved");
                setTopicModal(false);
              }}
            >
              Save
            </button>
          </>
        }
      >
        <div className="text-sm text-muted">
          These topics will be used by both the Message Browser and the Debug page's SSE
          monitor.  Stored locally in your browser.
        </div>
        <div>
          <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
            Topics
          </label>
          <input
            className="input font-mono"
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
          />
        </div>
      </Modal>
    </>
  );
}

function Stat({
  label,
  value,
  cls,
  small
}: {
  label: string;
  value: number | string;
  cls?: string;
  small?: boolean;
}) {
  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.04] px-3 py-2.5">
      <div className="text-[10px] font-extrabold uppercase tracking-wider text-muted">
        {label}
      </div>
      <div
        className={`font-mono font-extrabold ${cls ?? ""} ${small ? "text-sm" : "text-xl"}`}
      >
        {value}
      </div>
    </div>
  );
}

function MessageCard({ m }: { m: NtfyMessage }) {
  const prio = m.priority ?? 3;
  const prioCls =
    prio >= 5 ? "badge-bad" : prio >= 4 ? "badge-warn" : prio <= 2 ? "badge-info" : "";
  const time = m.time ? new Date(m.time * 1000).toLocaleString() : "?";
  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.03] p-3 space-y-1.5">
      <div className="flex items-center gap-2 flex-wrap">
        <span className="chip">{m.topic ?? "?"}</span>
        <span className={`badge ${prioCls}`}>prio {prio}</span>
        {m.title && <span className="text-sm font-extrabold">{m.title}</span>}
        <span className="ml-auto text-[11px] text-muted font-mono">{time}</span>
      </div>
      {m.message && <div className="text-sm whitespace-pre-wrap">{m.message}</div>}
      {m.tags && m.tags.length > 0 && (
        <div className="flex gap-1.5 flex-wrap">
          {m.tags.map((t) => (
            <span key={t} className="chip">
              {t}
            </span>
          ))}
        </div>
      )}
      {m.click && (
        <div className="text-xs text-info font-mono break-all">↗ {m.click}</div>
      )}
      {m.attachment && (
        <div className="text-xs text-muted font-mono">📎 {m.attachment.name}</div>
      )}
    </div>
  );
}
