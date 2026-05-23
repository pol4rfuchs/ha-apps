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
  const initials = (user ?? "AD").slice(0, 2).toUpperCase();
  return (
    <div className="sticky top-0 z-20 backdrop-blur bg-bg/70 border-b border-white/10">
      <div className="flex items-center gap-3 px-4 py-3 lg:px-6 lg:py-4">
        <button
          onClick={onOpenMobileNav}
          className="lg:hidden btn btn-ghost h-9 w-9 p-0 grid place-items-center"
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
        <button onClick={onRefresh} className="btn btn-ghost">
          <RefreshCw className="h-4 w-4" /> Refresh
        </button>
        <button onClick={onQuickSend} className="btn btn-primary">
          <Send className="h-4 w-4" /> Quick Send
        </button>
        <div className="h-9 w-9 rounded-full bg-gradient-to-br from-brand to-brand2 grid place-items-center text-xs font-extrabold border border-white/10">
          {initials}
        </div>
      </div>
    </div>
  );
}
