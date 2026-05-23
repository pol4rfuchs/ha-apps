import { useEffect, useState } from "react";
import { Copy, ExternalLink } from "lucide-react";
import { ntfy, ntfyErrorText } from "../lib/ntfy";
import { toast } from "../lib/toast";

export default function ServerPage({
  refreshKey,
  ntfyUrl,
  user
}: {
  refreshKey: number;
  ntfyUrl: string | null;
  user: string | null;
}) {
  const [healthy, setHealthy] = useState<boolean | null>(null);
  const [version, setVersion] = useState("—");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let stop = false;
    setError(null);
    Promise.all([ntfy.health(), ntfy.version()])
      .then(([h, v]) => {
        if (stop) return;
        setHealthy(h.data?.healthy === true);
        setVersion(v.data?.version ?? "—");
      })
      .catch((err) => !stop && setError(ntfyErrorText(err)));
    return () => {
      stop = true;
    };
  }, [refreshKey]);

  const haYaml = `rest_command:
  ntfy_notify:
    url: "${ntfyUrl ?? "http://homeassistant.local:4280"}/{{ topic }}"
    method: POST
    headers:
      Authorization: "Bearer YOUR_TOKEN_HERE"
      Title: "{{ title | default('') }}"
      Priority: "{{ priority | default('3') }}"
      Tags: "{{ tags | default('') }}"
    payload: "{{ message }}"
    content_type: "text/plain"`;

  return (
    <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
      <div className="card">
        <div className="card-header">
          <h3 className="font-bold">Server</h3>
          {healthy !== null && (
            <span className={`badge ${healthy ? "badge-ok" : "badge-bad"}`}>
              {healthy ? "Healthy" : "Unhealthy"}
            </span>
          )}
        </div>
        <div className="card-body space-y-2">
          {error && <div className="text-bad text-sm">{error}</div>}
          <KV k="Base URL" v={ntfyUrl ?? "—"} mono />
          <KV k="Version" v={version} mono />
          <KV k="Admin user" v={user ?? "—"} mono />
          <KV k="Auth mode" v="HTTP via cookie session" />
          <a
            href={ntfyUrl ?? "#"}
            target="_blank"
            rel="noreferrer"
            className="btn btn-ghost text-xs mt-2"
          >
            <ExternalLink className="h-3.5 w-3.5" /> Open ntfy web UI
          </a>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h3 className="font-bold">Home Assistant Snippet</h3>
          <button
            onClick={() => {
              navigator.clipboard.writeText(haYaml).then(() => toast.success("Copied"));
            }}
            className="btn btn-ghost text-xs"
          >
            <Copy className="h-3.5 w-3.5" /> Copy
          </button>
        </div>
        <div className="card-body">
          <div className="text-xs text-muted mb-2">
            Paste into <span className="font-mono">configuration.yaml</span> for{" "}
            <span className="font-mono">rest_command</span>:
          </div>
          <pre className="codeblock">{haYaml}</pre>
          <div className="text-xs text-muted mt-2">
            Replace <span className="font-mono">YOUR_TOKEN_HERE</span> with a token
            from the Tokens tab.
          </div>
        </div>
      </div>
    </div>
  );
}

function KV({ k, v, mono }: { k: string; v: string; mono?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3 py-2 border-b border-white/5 last:border-0">
      <span className="text-xs font-extrabold uppercase tracking-wider text-muted">
        {k}
      </span>
      <span
        className={`text-sm font-semibold truncate text-right ${mono ? "font-mono" : ""}`}
      >
        {v}
      </span>
    </div>
  );
}
