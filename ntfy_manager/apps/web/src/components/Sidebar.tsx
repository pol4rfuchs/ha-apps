import {
  Activity,
  Send,
  Users,
  KeyRound,
  Shield,
  Bookmark,
  Settings,
  Inbox,
  Bug,
  LogOut
} from "lucide-react";
import type { ReactNode } from "react";

export type ViewKey =
  | "overview"
  | "send"
  | "users"
  | "tokens"
  | "acl"
  | "reservations"
  | "server"
  | "messages"
  | "debug";

export const VIEWS: {
  key: ViewKey;
  label: string;
  icon: ReactNode;
  small?: string;
}[] = [
  { key: "overview", label: "Overview", icon: <Activity className="h-4 w-4" />, small: "LIVE" },
  { key: "send", label: "Send", icon: <Send className="h-4 w-4" />, small: "POST" },
  { key: "users", label: "Users", icon: <Users className="h-4 w-4" />, small: "RBAC" },
  { key: "tokens", label: "Tokens", icon: <KeyRound className="h-4 w-4" />, small: "API" },
  { key: "acl", label: "Access Control", icon: <Shield className="h-4 w-4" />, small: "ACL" },
  { key: "reservations", label: "Reservations", icon: <Bookmark className="h-4 w-4" />, small: "RES" },
  { key: "server", label: "Server", icon: <Settings className="h-4 w-4" />, small: "CFG" },
  { key: "messages", label: "Messages", icon: <Inbox className="h-4 w-4" />, small: "POLL" },
  { key: "debug", label: "Debug", icon: <Bug className="h-4 w-4" />, small: "DBG" }
];

export default function Sidebar({
  current,
  onSelect,
  user,
  ntfyUrl,
  version,
  onLogout
}: {
  current: ViewKey;
  onSelect: (k: ViewKey) => void;
  user: string | null;
  ntfyUrl: string | null;
  version: string;
  onLogout: () => void;
}) {
  return (
    <aside className="hidden lg:flex flex-col w-72 sticky top-0 h-screen border-r border-white/10 bg-bg2/60 backdrop-blur p-4">
      {/* Brand */}
      <div className="flex items-center gap-3 px-2 py-3">
        <div className="h-9 w-9 rounded-xl bg-gradient-to-br from-brand to-brand2 grid place-items-center shadow-soft">
          <Activity className="h-5 w-5" />
        </div>
        <div>
          <div className="text-sm font-extrabold leading-tight">ntfy Admin</div>
          <div className="text-[11px] text-muted font-semibold">HAOS Console</div>
        </div>
      </div>

      {/* Connection box */}
      <div className="card mx-1 my-3 px-3 py-3">
        <div className="text-[10px] uppercase tracking-wider text-muted font-extrabold">Connection</div>
        <div className="mt-1.5 flex items-center gap-2">
          <span className={`h-2 w-2 rounded-full ${user ? "bg-ok" : "bg-bad"}`} />
          <span className="text-sm font-bold">{user ?? "offline"}</span>
        </div>
        <div className="mt-1 break-all text-[11px] font-mono text-muted">
          {ntfyUrl ?? "—"}
        </div>
      </div>

      {/* Nav */}
      <nav className="flex flex-col gap-1.5 mt-2 px-1">
        <div className="px-2 py-1 text-[10px] font-extrabold tracking-widest text-muted uppercase">
          Console
        </div>
        {VIEWS.map((v) => {
          const active = v.key === current;
          return (
            <button
              key={v.key}
              onClick={() => onSelect(v.key)}
              className={`flex items-center gap-2.5 px-3 py-2.5 rounded-xl border text-left transition text-sm font-bold ${
                active
                  ? "bg-gradient-to-r from-brand/40 to-brand2/20 border-brand/40"
                  : "border-transparent hover:bg-white/5 hover:border-white/10"
              }`}
            >
              <span
                className={`h-7 w-7 rounded-lg grid place-items-center border ${
                  active ? "border-brand/60 bg-brand/20" : "border-white/10 bg-white/5"
                }`}
              >
                {v.icon}
              </span>
              <span className="flex-1">{v.label}</span>
              {v.small && (
                <span className="font-mono text-[10px] px-2 py-0.5 rounded-full border border-white/10 bg-black/30 text-muted">
                  {v.small}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      <div className="mt-auto" />

      {/* Footer */}
      <div className="card mx-1 mt-3 px-3 py-3 space-y-2">
        <div className="flex items-center justify-between text-[11px]">
          <span className="text-muted font-extrabold uppercase tracking-wider">Version</span>
          <span className="font-mono">{version}</span>
        </div>
        <div className="flex items-center justify-between text-[11px]">
          <span className="text-muted font-extrabold uppercase tracking-wider">User</span>
          <span className="font-mono">{user ?? "—"}</span>
        </div>
        <button
          onClick={onLogout}
          className="btn btn-ghost w-full justify-center text-xs py-2 mt-1"
        >
          <LogOut className="h-3.5 w-3.5" /> Logout
        </button>
      </div>
    </aside>
  );
}
