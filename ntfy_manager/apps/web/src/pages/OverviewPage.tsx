import { useEffect, useState } from "react";
import { Activity, Clock, MessageSquare, Users as UsersIcon, ServerCog } from "lucide-react";
import { ntfy, ntfyErrorText } from "../lib/ntfy";
import { toast } from "../lib/toast";

type OverviewResp = Awaited<ReturnType<typeof ntfy.overview>>;

export default function OverviewPage({
  refreshKey,
  ntfyUrl,
  user
}: {
  refreshKey: number;
  ntfyUrl: string | null;
  user: string | null;
}) {
  const [data, setData] = useState<OverviewResp | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [connectedAt] = useState(() => Date.now());
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), 1000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    let stop = false;
    setError(null);
    ntfy
      .overview()
      .then((d) => {
        if (!stop) setData(d);
      })
      .catch((err) => {
        if (!stop) {
          const msg = ntfyErrorText(err);
          setError(msg);
          toast.error("Overview: " + msg);
        }
      });
    return () => {
      stop = true;
    };
  }, [refreshKey]);

  const healthy = data?.health?.data?.healthy === true;
  const version = data?.version?.data?.version ?? "—";
  const messages = (data?.stats?.data as any)?.messages ?? "—";
  const users = data?.users?.count ?? "—";
  const admins = data?.users?.admins ?? 0;

  const uptime = formatUptime(Math.floor((Date.now() - connectedAt) / 1000));
  void tick;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <Kpi
          title="Server Health"
          value={
            <span className="flex items-center gap-2">
              <span
                className={`h-2.5 w-2.5 rounded-full ${
                  healthy ? "bg-ok" : "bg-bad"
                }`}
              />
              {healthy ? "Healthy" : "Unhealthy"}
            </span>
          }
          meta={`v${version}`}
          icon={<Activity className="h-4 w-4" />}
        />
        <Kpi
          title="Connected"
          value={uptime}
          meta={`since ${new Date(connectedAt).toLocaleTimeString()}`}
          icon={<Clock className="h-4 w-4" />}
        />
        <Kpi
          title="Messages"
          value={String(messages)}
          meta="lifetime"
          icon={<MessageSquare className="h-4 w-4" />}
        />
        <Kpi
          title="Users"
          value={String(users)}
          meta={`${admins} admin${admins === 1 ? "" : "s"}`}
          icon={<UsersIcon className="h-4 w-4" />}
        />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        <div className="card">
          <div className="card-header">
            <h3 className="font-bold">System Status</h3>
            <span className={`badge ${healthy ? "badge-ok" : "badge-bad"}`}>
              {healthy ? "OK" : "ATTENTION"}
            </span>
          </div>
          <div className="card-body space-y-2">
            <Row label="HTTP API (/v1/health)" status={data?.health?.ok ?? false} extra="" />
            <Row
              label="Auth store (/v1/users)"
              status={data?.users?.ok ?? false}
              extra={`${data?.users?.count ?? "?"} users`}
            />
            <Row
              label="Stats (/v1/stats)"
              status={data?.stats?.ok ?? false}
              extra={messages === "—" ? "no data" : `${messages} msgs`}
            />
            <Row
              label="Version (/v1/version)"
              status={data?.version?.ok ?? false}
              extra={`v${version}`}
            />
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="font-bold">Connection</h3>
            <ServerCog className="h-4 w-4 text-muted" />
          </div>
          <div className="card-body space-y-2">
            <KV k="Base URL" v={ntfyUrl ?? "—"} mono />
            <KV k="User" v={user ?? "—"} mono />
            <KV k="Auth mode" v="HTTP Basic / Bearer (via cookie)" />
            {error && <KV k="Last error" v={error} mono />}
          </div>
        </div>
      </div>
    </div>
  );
}

function Kpi({
  title,
  value,
  meta,
  icon
}: {
  title: string;
  value: React.ReactNode;
  meta?: string;
  icon?: React.ReactNode;
}) {
  return (
    <div className="card p-5">
      <div className="text-[11px] font-extrabold uppercase tracking-wider text-muted flex items-center gap-2">
        {icon} {title}
      </div>
      <div className="mt-2 text-2xl font-extrabold">{value}</div>
      {meta && <div className="text-xs text-muted font-mono mt-1">{meta}</div>}
    </div>
  );
}

function Row({
  label,
  status,
  extra
}: {
  label: string;
  status: boolean;
  extra: string;
}) {
  return (
    <div className="flex items-center justify-between py-2 border-b border-white/5 last:border-0">
      <div className="flex items-center gap-2.5 text-sm font-semibold">
        <span className={`h-2 w-2 rounded-full ${status ? "bg-ok" : "bg-bad"}`} />
        {label}
      </div>
      <div className="flex items-center gap-2 text-xs">
        <span className={`badge ${status ? "badge-ok" : "badge-bad"}`}>
          {status ? "OK" : "FAIL"}
        </span>
        {extra && <span className="text-muted font-mono">{extra}</span>}
      </div>
    </div>
  );
}

function KV({ k, v, mono }: { k: string; v: string; mono?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3 py-2 border-b border-white/5 last:border-0">
      <span className="text-xs font-extrabold uppercase tracking-wider text-muted">{k}</span>
      <span className={`text-sm font-semibold truncate ${mono ? "font-mono" : ""}`}>{v}</span>
    </div>
  );
}

function formatUptime(secs: number): string {
  if (secs < 60) return `${secs}s`;
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  if (m < 60) return `${m}m ${s}s`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}m`;
}
