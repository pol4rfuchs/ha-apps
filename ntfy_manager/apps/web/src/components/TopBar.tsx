import { Search, RefreshCw, Send, Menu } from "lucide-react";
import type { ViewKey } from "./Sidebar";

const TITLES: Record<ViewKey, { path: string; title: string }> = {
  overview: { path: "Console / Overview", title: "Overview" },
  send: { path: "Console / Send", title: "Send Notification" },
  users: { path: "Console / Users", title: "User Management" },
  tokens: { path: "Console / Tokens", title: "API Tokens" },
  acl: { path: "Console / ACL", title: "Access Control" },
  reservations: { path: "Console / Reservations", title: "Topic Reservations" },
  server: { path: "Console / Server", title: "Server Information" },
  messages: { path: "Console / Messages", title: "Message Browser" },
  debug: { path: "Console / Debug", title: "Debug & API Log" }
};

export default function TopBar({
  view,
  search,
  onSearchChange,
  onRefresh,
  onQuickSend,
  onOpenMobileNav,
  user
}: {
  view: ViewKey;
  search: string;
  onSearchChange: (v: string) => void;
  onRefresh: () => void;
  onQuickSend: () => void;
  onOpenMobileNav: () => void;
  user: string | null;
}) {
  const t = TITLES[view];
  // Sessions that fall back to add-on config defaults (bearer token, basic
  // defaults, anonymous) carry placeholder usernames like "(token)" —
  // slicing those gives nonsense initials like "(T". Show a neutral
  // service-account marker instead for any placeholder-style name.
  const isPlaceholder = !!user && user.startsWith("(") && user.endsWith(")");
  const initials = isPlaceholder ? "•" : (user ?? "AD").slice(0, 2).toUpperCase();
  return (
    <div className="sticky top-0 z-20 backdrop-blur bg-bg/70 border-b border-white/10">
      <div className="flex items-center gap-3 px-4 py-3 lg:px-6 lg:py-4">
        <button
          onClick={onOpenMobileNav}
          aria-label="Menu" className="lg:hidden shrink-0 btn btn-ghost h-9 w-9 p-0 grid place-items-center"
        >
          <Menu className="h-4 w-4" />
        </button>
        <div className="min-w-0 flex-1">
          <div className="text-[11px] font-extrabold tracking-wider text-muted uppercase truncate">
            {t.path}
          </div>
          <div className="text-lg lg:text-xl font-extrabold leading-tight truncate">
            {t.title}
          </div>
        </div>
        <div className="hidden md:flex items-center gap-2 rounded-xl border border-white/10 bg-black/30 px-3 py-2 w-64">
          <Search className="h-4 w-4 text-muted" />
          <input
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Filter current view…"
            className="flex-1 bg-transparent text-sm font-semibold outline-none placeholder:text-muted/70"
          />
        </div>
        <button onClick={onRefresh} aria-label="Refresh" className="btn btn-ghost shrink-0">
          <RefreshCw className="h-4 w-4" /> <span className="hidden sm:inline">Refresh</span>
        </button>
        <button onClick={onQuickSend} aria-label="Quick Send" className="btn btn-primary shrink-0">
          <Send className="h-4 w-4" /> <span className="hidden sm:inline">Quick Send</span>
        </button>
        <div
          title={user ?? undefined}
          className="h-9 w-9 shrink-0 rounded-full bg-linear-to-br from-brand to-brand2 grid place-items-center text-xs font-extrabold border border-white/10"
        >
          {initials}
        </div>
      </div>
    </div>
  );
}
