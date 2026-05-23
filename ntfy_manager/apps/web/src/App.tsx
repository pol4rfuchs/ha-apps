import { useEffect, useState } from "react";
import { api } from "./lib/api";
import LoginPage from "./pages/LoginPage";
import OverviewPage from "./pages/OverviewPage";
import SendPage from "./pages/SendPage";
import UsersPage from "./pages/UsersPage";
import TokensPage from "./pages/TokensPage";
import AclPage from "./pages/AclPage";
import ReservationsPage from "./pages/ReservationsPage";
import ServerPage from "./pages/ServerPage";
import MessagesPage from "./pages/MessagesPage";
import DebugPage from "./pages/DebugPage";
import Sidebar, { type ViewKey, VIEWS } from "./components/Sidebar";
import TopBar from "./components/TopBar";
import Toaster from "./components/Toaster";
import { toast } from "./lib/toast";
import Modal from "./components/Modal";

type ConfigResp = {
  appName: string;
  version: string;
  ntfyBaseUrl: string;
  defaultTopics: string[];
  allowOverride: boolean;
  defaultAuthType: "basic" | "bearer" | "none";
  session: {
    username: string;
    authType: string;
    expiresAt: string;
  } | null;
};

function getView(): ViewKey {
  const h = (location.hash || "#overview").replace("#", "");
  if (VIEWS.find((v) => v.key === h)) return h as ViewKey;
  return "overview";
}

export default function App() {
  const [config, setConfig] = useState<ConfigResp | null>(null);
  const [loading, setLoading] = useState(true);
  const [view, setView] = useState<ViewKey>(getView());
  const [search, setSearch] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);
  const [mobileNav, setMobileNav] = useState(false);

  async function loadConfig() {
    setLoading(true);
    try {
      const c = await api<ConfigResp>("/config");
      setConfig(c);
    } catch {
      setConfig({
        appName: "ntfy HAOS Admin Panel",
        version: "0.2.0",
        ntfyBaseUrl: "",
        defaultTopics: [],
        allowOverride: true,
        defaultAuthType: "basic",
        session: null
      });
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadConfig();
  }, []);

  useEffect(() => {
    const onHash = () => setView(getView());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  // Reset filter when switching views
  useEffect(() => {
    setSearch("");
  }, [view]);

  function selectView(k: ViewKey) {
    location.hash = `#${k}`;
    setView(k);
    setMobileNav(false);
  }

  async function logout() {
    try {
      await api("/auth/logout", { method: "POST" });
    } catch {
      /* ignore */
    }
    toast.info("Logged out");
    setConfig((c) => (c ? { ...c, session: null } : c));
    location.hash = "#overview";
  }

  if (loading) {
    return (
      <div className="min-h-screen grid place-items-center">
        <div className="text-muted text-sm">Loading…</div>
      </div>
    );
  }

  if (!config?.session) {
    return (
      <>
        <Toaster />
        <LoginPage onSuccess={loadConfig} />
      </>
    );
  }

  const user = config.session.username;
  const ntfyUrl = config.ntfyBaseUrl;

  return (
    <>
      <Toaster />
      <div className="min-h-screen flex">
        <Sidebar
          current={view}
          onSelect={selectView}
          user={user}
          ntfyUrl={ntfyUrl}
          version={config.version}
          onLogout={logout}
        />

        {/* Mobile nav drawer */}
        <Modal
          open={mobileNav}
          onClose={() => setMobileNav(false)}
          title="Navigation"
          width="max-w-xs"
        >
          <div className="flex flex-col gap-1">
            {VIEWS.map((v) => (
              <button
                key={v.key}
                onClick={() => selectView(v.key)}
                className={`flex items-center gap-2 px-3 py-2.5 rounded-xl text-left text-sm font-bold ${
                  v.key === view ? "bg-brand/30 border border-brand/40" : "hover:bg-white/5"
                }`}
              >
                {v.icon}
                {v.label}
              </button>
            ))}
            <button
              onClick={logout}
              className="btn btn-ghost mt-2 justify-center text-xs"
            >
              Logout
            </button>
          </div>
        </Modal>

        <main className="flex-1 min-w-0">
          <TopBar
            view={view}
            search={search}
            onSearchChange={setSearch}
            onRefresh={() => setRefreshKey((k) => k + 1)}
            onQuickSend={() => selectView("send")}
            onOpenMobileNav={() => setMobileNav(true)}
            user={user}
          />
          <div className="p-4 lg:p-6 space-y-6">
            {view === "overview" && (
              <OverviewPage
                refreshKey={refreshKey}
                ntfyUrl={ntfyUrl}
                user={user}
              />
            )}
            {view === "send" && <SendPage />}
            {view === "users" && (
              <UsersPage
                refreshKey={refreshKey}
                search={search}
                currentUser={user}
              />
            )}
            {view === "tokens" && <TokensPage ntfyUrl={ntfyUrl} />}
            {view === "acl" && <AclPage refreshKey={refreshKey} search={search} />}
            {view === "reservations" && (
              <ReservationsPage
                refreshKey={refreshKey}
                search={search}
                currentUser={user}
              />
            )}
            {view === "server" && (
              <ServerPage
                refreshKey={refreshKey}
                ntfyUrl={ntfyUrl}
                user={user}
              />
            )}
            {view === "messages" && (
              <MessagesPage
                search={search}
                defaultTopics={config.defaultTopics}
              />
            )}
            {view === "debug" && (
              <DebugPage
                refreshKey={refreshKey}
                defaultTopics={config.defaultTopics}
              />
            )}
          </div>
        </main>
      </div>
    </>
  );
}
