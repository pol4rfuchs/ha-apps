import { useEffect, useState } from "react";
import { LogIn, Activity } from "lucide-react";
import { api, HttpError } from "../lib/api";
import { toast } from "../lib/toast";

type StatusResp = {
  authenticated: boolean;
  username: string | null;
  authType: "basic" | "bearer" | "none" | null;
  allowOverride: boolean;
  ntfyBaseUrl: string;
  defaultAuthType: "basic" | "bearer" | "none";
  defaultUsername: string | null;
};

export default function LoginPage({ onSuccess }: { onSuccess: () => void }) {
  const [status, setStatus] = useState<StatusResp | null>(null);
  const [authType, setAuthType] = useState<"basic" | "bearer" | "none">("basic");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [bearer, setBearer] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api<StatusResp>("/auth/status")
      .then((s) => {
        setStatus(s);
        setAuthType(s.defaultAuthType);
        if (s.defaultUsername) setUsername(s.defaultUsername);
        // If defaults already authenticate us, skip the form.
        if (s.authenticated) onSuccess();
      })
      .catch(() => {
        // No defaults — stay on form
      });
  }, [onSuccess]);

  async function submit() {
    setBusy(true);
    try {
      const body =
        authType === "basic"
          ? { authType, username, password }
          : authType === "bearer"
          ? { authType, bearerToken: bearer }
          : { authType };
      await api("/auth/login", { method: "POST", body });
      toast.success("Connected ✓");
      onSuccess();
    } catch (err) {
      const msg =
        err instanceof HttpError
          ? err.status === 401
            ? "Wrong credentials"
            : err.status === 502
            ? "ntfy unreachable"
            : `HTTP ${err.status}`
          : "Login failed";
      toast.error(msg);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-screen grid place-items-center px-4">
      <div className="card w-full max-w-md bg-panel/90">
        <div className="px-6 pt-6 pb-2 flex items-center gap-3">
          <div className="h-10 w-10 rounded-xl bg-gradient-to-br from-brand to-brand2 grid place-items-center">
            <Activity className="h-5 w-5" />
          </div>
          <div>
            <div className="text-base font-extrabold">ntfy Admin Console</div>
            <div className="text-xs text-muted font-semibold">
              {status?.ntfyBaseUrl ?? "Connecting…"}
            </div>
          </div>
        </div>
        <div className="card-body space-y-4">
          <div>
            <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
              Authentication
            </label>
            <select
              className="select"
              value={authType}
              onChange={(e) =>
                setAuthType(e.target.value as "basic" | "bearer" | "none")
              }
            >
              <option value="basic">HTTP Basic (username + password)</option>
              <option value="bearer">Bearer token</option>
              <option value="none">Anonymous (read-only servers)</option>
            </select>
          </div>

          {authType === "basic" && (
            <>
              <div>
                <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
                  Username
                </label>
                <input
                  className="input"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  autoFocus
                />
              </div>
              <div>
                <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
                  Password
                </label>
                <input
                  type="password"
                  className="input"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && submit()}
                />
              </div>
            </>
          )}

          {authType === "bearer" && (
            <div>
              <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
                Bearer token
              </label>
              <input
                type="password"
                className="input font-mono"
                value={bearer}
                onChange={(e) => setBearer(e.target.value)}
                placeholder="tk_…"
              />
            </div>
          )}

          <button
            disabled={busy}
            onClick={submit}
            className="btn btn-primary w-full justify-center disabled:opacity-50"
          >
            <LogIn className="h-4 w-4" />
            {busy ? "Connecting…" : "Connect"}
          </button>

          <div className="text-[11px] text-muted text-center">
            Credentials are encrypted & stored in an httpOnly cookie. Server-side
            defaults from add-on options are used if you skip this form.
          </div>
        </div>
      </div>
    </div>
  );
}
