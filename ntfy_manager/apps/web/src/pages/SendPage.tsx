import { useState } from "react";
import { Send, Eraser, Beaker } from "lucide-react";
import { ntfy, ntfyErrorText } from "../lib/ntfy";
import { toast } from "../lib/toast";

const PRIO_LABEL: Record<number, string> = {
  1: "min",
  2: "low",
  3: "default",
  4: "high",
  5: "max"
};

export default function SendPage() {
  const [topic, setTopic] = useState("ha-notify");
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [prio, setPrio] = useState(3);
  const [tags, setTags] = useState("");
  const [click, setClick] = useState("");
  const [busy, setBusy] = useState(false);

  async function send() {
    if (!topic.trim() || !message.trim()) {
      toast.error("Topic and message required");
      return;
    }
    setBusy(true);
    try {
      const res = await ntfy.publish({
        topic: topic.trim(),
        message,
        title: title || undefined,
        priority: prio,
        tags: tags || undefined,
        click: click || undefined
      });
      if (res.ok) toast.success("Message sent ✓");
      else toast.error(`HTTP ${res.status}`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    } finally {
      setBusy(false);
    }
  }

  function clear() {
    setTitle("");
    setTags("");
    setClick("");
    setMessage("");
    setTopic("ha-notify");
    setPrio(3);
  }

  function example() {
    setTopic("ha-notify");
    setTitle("Test Notification");
    setMessage("Hello from ntfy Admin Console!");
    setTags("house,test");
    setPrio(4);
    setClick("");
  }

  const tagList = tags
    .split(",")
    .map((t) => t.trim())
    .filter(Boolean)
    .slice(0, 6);

  return (
    <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
      <div className="xl:col-span-2 card">
        <div className="card-header">
          <h3 className="font-bold">Compose Notification</h3>
          <div className="flex gap-2">
            <button onClick={example} className="btn btn-ghost text-xs">
              <Beaker className="h-3.5 w-3.5" /> Load example
            </button>
            <button onClick={clear} className="btn btn-ghost text-xs">
              <Eraser className="h-3.5 w-3.5" /> Clear
            </button>
            <button
              onClick={send}
              disabled={busy}
              className="btn btn-primary text-xs disabled:opacity-50"
            >
              <Send className="h-3.5 w-3.5" /> Send
            </button>
          </div>
        </div>
        <div className="card-body space-y-3">
          <Field label="Topic">
            <input
              className="input"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
            />
          </Field>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div className="sm:col-span-2">
              <Field label="Title">
                <input
                  className="input"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                />
              </Field>
            </div>
            <Field label="Priority">
              <select
                className="select"
                value={prio}
                onChange={(e) => setPrio(Number(e.target.value))}
              >
                {[1, 2, 3, 4, 5].map((p) => (
                  <option key={p} value={p}>
                    {p} — {PRIO_LABEL[p]}
                  </option>
                ))}
              </select>
            </Field>
          </div>
          <Field label="Message">
            <textarea
              className="textarea"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Notification body…"
            />
          </Field>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <Field label="Tags (comma separated)">
              <input
                className="input"
                value={tags}
                onChange={(e) => setTags(e.target.value)}
                placeholder="tag1,tag2"
              />
            </Field>
            <Field label="Click URL">
              <input
                className="input"
                value={click}
                onChange={(e) => setClick(e.target.value)}
                placeholder="https://…"
              />
            </Field>
          </div>
          <button
            onClick={send}
            disabled={busy}
            className="btn btn-primary w-full justify-center disabled:opacity-50"
          >
            <Send className="h-4 w-4" /> {busy ? "Sending…" : "Send Notification"}
          </button>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h3 className="font-bold">Live Preview</h3>
          <span className="badge badge-info">prio {prio}</span>
        </div>
        <div className="card-body">
          <div className="rounded-xl border border-white/10 bg-white/[0.04] p-4 space-y-2">
            <div className="flex items-center gap-2">
              <div className="text-sm font-extrabold flex-1 truncate">
                {title || "(no title)"}
              </div>
              <span className="badge badge-info">prio {prio}</span>
            </div>
            <div className="flex flex-wrap gap-1.5">
              <span className="chip">{topic || "(topic)"}</span>
              {tagList.map((t) => (
                <span key={t} className="chip">
                  {t}
                </span>
              ))}
            </div>
            <div className="text-sm whitespace-pre-wrap text-muted">
              {message || "(no message)"}
            </div>
            {click && (
              <div className="text-xs text-info font-mono break-all">↗ {click}</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
        {label}
      </label>
      {children}
    </div>
  );
}
