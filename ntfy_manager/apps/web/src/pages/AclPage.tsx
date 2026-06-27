import { useEffect, useMemo, useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { ntfy, ntfyErrorText, type NtfyUser } from "../lib/ntfy";
import { toast } from "../lib/toast";
import PermBadge from "../components/PermBadge";

type Row = { username: string; role?: string; topic: string; permission: string };

const PERMS = ["read-write", "read-only", "write-only", "deny-all"] as const;

export default function AclPage({
  refreshKey,
  search
}: {
  refreshKey: number;
  search: string;
}) {
  const [users, setUsers] = useState<NtfyUser[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  // form state
  const [user, setUser] = useState("");
  const [topic, setTopic] = useState("");
  const [perm, setPerm] = useState<(typeof PERMS)[number]>("read-only");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let stop = false;
    setError(null);
    ntfy
      .users()
      .then((r) => {
        if (stop) return;
        if (r.ok && Array.isArray(r.data)) setUsers(r.data);
        else setError(`HTTP ${r.status}`);
      })
      .catch((err) => !stop && setError(ntfyErrorText(err)));
    return () => {
      stop = true;
    };
  }, [refreshKey]);

  const rows = useMemo<Row[]>(() => {
    if (!users) return [];
    const out: Row[] = [];
    for (const u of users) {
      if (!u.grants?.length) continue;
      for (const g of u.grants) {
        out.push({
          username: u.username,
          role: u.role,
          topic: g.topic,
          permission: g.permission
        });
      }
    }
    return out;
  }, [users]);

  const filtered = rows.filter(
    (r) =>
      !search ||
      r.username.toLowerCase().includes(search.toLowerCase()) ||
      r.topic.toLowerCase().includes(search.toLowerCase())
  );

  const userOptions = (users ?? [])
    .filter((u) => u.role !== "admin" || u.username === "*")
    .map((u) => u.username);

  async function add() {
    if (!user) return toast.error("Select a user");
    if (!topic.trim()) return toast.error("Enter a topic");
    setBusy(true);
    try {
      const r = await ntfy.setAccess(user, topic.trim(), perm);
      if (r.ok) {
        toast.success(`ACL saved: ${user} → ${topic} [${perm}]`);
        setTopic("");
        // reload
        const u = await ntfy.users();
        if (u.ok && Array.isArray(u.data)) setUsers(u.data);
      } else toast.error(`HTTP ${r.status}`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    } finally {
      setBusy(false);
    }
  }

  async function remove(username: string, topic: string) {
    if (!confirm(`Delete ACL rule?\n${username} / ${topic}`)) return;
    try {
      const r = await ntfy.deleteAccess(username, topic);
      if (r.ok) {
        toast.success(`ACL removed`);
        const u = await ntfy.users();
        if (u.ok && Array.isArray(u.data)) setUsers(u.data);
      } else toast.error(`HTTP ${r.status}`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    }
  }

  return (
    <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
      <div className="xl:col-span-2 card">
        <div className="card-header">
          <h3 className="font-bold">
            Access Rules{" "}
            {rows.length > 0 && (
              <span className="text-muted font-mono text-xs ml-1">
                ({rows.length})
              </span>
            )}
          </h3>
        </div>
        {error ? (
          <div className="card-body">
            <div className="empty text-bad">Error: {error}</div>
          </div>
        ) : !users ? (
          <div className="card-body">
            <div className="empty">Loading…</div>
          </div>
        ) : !filtered.length ? (
          <div className="card-body">
            <div className="empty">
              No ACL entries. Access governed by{" "}
              <span className="font-mono ml-1">auth-default-access</span> in server config.
            </div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Role</th>
                  <th>Topic</th>
                  <th>Permission</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((r, i) => (
                  <tr key={i}>
                    <td className="font-mono">{r.username}</td>
                    <td>
                      <span className={`badge ${r.role === "admin" ? "badge-info" : ""}`}>
                        {r.role ?? "user"}
                      </span>
                    </td>
                    <td className="font-mono">{r.topic}</td>
                    <td>
                      <PermBadge permission={r.permission} />
                    </td>
                    <td>
                      <button
                        onClick={() => remove(r.username, r.topic)}
                        className="btn btn-danger text-xs py-1.5 px-2.5"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="card">
        <div className="card-header">
          <h3 className="font-bold">Add Rule</h3>
        </div>
        <div className="card-body space-y-3">
          <div>
            <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
              User
            </label>
            <select className="select" value={user} onChange={(e) => setUser(e.target.value)}>
              <option value="">— select user —</option>
              <option value="*">* (anonymous)</option>
              {userOptions
                .filter((n) => n !== "*")
                .map((n) => (
                  <option key={n} value={n}>
                    {n}
                  </option>
                ))}
            </select>
          </div>
          <div>
            <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
              Topic (supports * wildcard, e.g. ha-*)
            </label>
            <input
              className="input font-mono"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder="ha-* or ha-notify"
            />
          </div>
          <div>
            <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
              Permission
            </label>
            <select
              className="select"
              value={perm}
              onChange={(e) => setPerm(e.target.value as (typeof PERMS)[number])}
            >
              {PERMS.map((p) => (
                <option key={p} value={p}>
                  {p}
                </option>
              ))}
            </select>
          </div>
          <button
            onClick={add}
            disabled={busy}
            className="btn btn-primary w-full justify-center disabled:opacity-50"
          >
            <Plus className="h-4 w-4" /> Save Rule
          </button>
        </div>
      </div>
    </div>
  );
}
