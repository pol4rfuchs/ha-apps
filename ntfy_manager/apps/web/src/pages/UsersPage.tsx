import { useEffect, useState } from "react";
import { Plus, KeyRound, Trash2 } from "lucide-react";
import { ntfy, ntfyErrorText, type NtfyUser } from "../lib/ntfy";
import { toast } from "../lib/toast";
import Modal from "../components/Modal";

export default function UsersPage({
  refreshKey,
  search,
  currentUser
}: {
  refreshKey: number;
  search: string;
  currentUser: string | null;
}) {
  const [users, setUsers] = useState<NtfyUser[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [pwOpen, setPwOpen] = useState<{ user: string } | null>(null);

  useEffect(() => {
    let stop = false;
    setError(null);
    ntfy
      .users()
      .then((r) => {
        if (stop) return;
        if (r.ok && Array.isArray(r.data)) setUsers(r.data.filter((u) => u.username !== "*"));
        else setError(`HTTP ${r.status}`);
      })
      .catch((err) => !stop && setError(ntfyErrorText(err)));
    return () => {
      stop = true;
    };
  }, [refreshKey]);

  const filtered =
    users?.filter(
      (u) => !search || u.username.toLowerCase().includes(search.toLowerCase())
    ) ?? [];

  async function refresh() {
    const r = await ntfy.users();
    if (r.ok && Array.isArray(r.data)) setUsers(r.data.filter((u) => u.username !== "*"));
  }

  async function deleteUser(u: string) {
    if (!confirm(`Delete user "${u}"? This cannot be undone.`)) return;
    try {
      const r = await ntfy.deleteUser(u);
      if (r.ok) {
        toast.success(`Deleted ${u}`);
        refresh();
      } else toast.error(`HTTP ${r.status}`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    }
  }

  return (
    <>
      <div className="card">
        <div className="card-header">
          <h3 className="font-bold">
            Users{" "}
            {users && (
              <span className="text-muted font-mono text-xs ml-1">
                ({users.length})
              </span>
            )}
          </h3>
          <button
            onClick={() => setCreateOpen(true)}
            className="btn btn-primary text-xs"
          >
            <Plus className="h-3.5 w-3.5" /> Create User
          </button>
        </div>
        {error ? (
          <div className="card-body">
            <div className="empty text-bad">Error: {error}</div>
          </div>
        ) : !users ? (
          <div className="card-body">
            <div className="empty">Loading users…</div>
          </div>
        ) : !filtered.length ? (
          <div className="card-body">
            <div className="empty">No users found.</div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Role</th>
                  <th>Grants</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((u) => (
                  <tr key={u.username}>
                    <td>
                      <span className="font-mono">{u.username}</span>
                      {u.username === currentUser && (
                        <span className="text-muted text-[11px] ml-1">(you)</span>
                      )}
                    </td>
                    <td>
                      <span
                        className={`badge ${u.role === "admin" ? "badge-info" : ""}`}
                      >
                        {u.role}
                      </span>
                    </td>
                    <td className="text-muted font-mono text-xs">
                      {u.grants?.length ?? 0}
                    </td>
                    <td>
                      <div className="flex gap-2 flex-wrap">
                        {u.role !== "admin" && (
                          <button
                            onClick={() => setPwOpen({ user: u.username })}
                            className="btn btn-ghost text-xs py-1.5 px-2.5"
                          >
                            <KeyRound className="h-3.5 w-3.5" /> Change PW
                          </button>
                        )}
                        {u.username !== currentUser && u.role !== "admin" && (
                          <button
                            onClick={() => deleteUser(u.username)}
                            className="btn btn-danger text-xs py-1.5 px-2.5"
                          >
                            <Trash2 className="h-3.5 w-3.5" /> Delete
                          </button>
                        )}
                        {u.role === "admin" && u.username !== currentUser && (
                          <span className="text-muted text-[11px]">
                            managed via config
                          </span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <CreateUserModal
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onCreated={refresh}
      />
      <ChangePwModal
        target={pwOpen?.user ?? null}
        onClose={() => setPwOpen(null)}
      />
    </>
  );
}

function CreateUserModal({
  open,
  onClose,
  onCreated
}: {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [u, setU] = useState("");
  const [p, setP] = useState("");
  const [role, setRole] = useState<"user" | "admin">("user");
  const [busy, setBusy] = useState(false);

  async function submit() {
    if (!u || !p) {
      toast.error("Username and password required");
      return;
    }
    setBusy(true);
    try {
      const r = await ntfy.createUser(u, p, role);
      if (r.ok) {
        toast.success(`Created ${u}`);
        setU("");
        setP("");
        setRole("user");
        onClose();
        onCreated();
      } else toast.error(`HTTP ${r.status}`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Create User"
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={submit} disabled={busy}>
            Create
          </button>
        </>
      }
    >
      <div>
        <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
          Username
        </label>
        <input className="input" value={u} onChange={(e) => setU(e.target.value)} />
      </div>
      <div>
        <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
          Password
        </label>
        <input
          type="password"
          className="input"
          value={p}
          onChange={(e) => setP(e.target.value)}
        />
      </div>
      <div>
        <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
          Role
        </label>
        <select
          className="select"
          value={role}
          onChange={(e) => setRole(e.target.value as "user" | "admin")}
        >
          <option value="user">user</option>
          <option value="admin">admin</option>
        </select>
      </div>
    </Modal>
  );
}

function ChangePwModal({
  target,
  onClose
}: {
  target: string | null;
  onClose: () => void;
}) {
  const [pw, setPw] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit() {
    if (!target || !pw) {
      toast.error("Password required");
      return;
    }
    setBusy(true);
    try {
      const r = await ntfy.changePassword(target, pw);
      if (r.ok) {
        toast.success(`Password changed for ${target}`);
        setPw("");
        onClose();
      } else toast.error(`HTTP ${r.status}`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open={!!target}
      onClose={onClose}
      title={`Change password — ${target ?? ""}`}
      footer={
        <>
          <button className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={submit} disabled={busy}>
            Save
          </button>
        </>
      }
    >
      <div>
        <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
          New password
        </label>
        <input
          type="password"
          className="input"
          value={pw}
          onChange={(e) => setPw(e.target.value)}
        />
      </div>
    </Modal>
  );
}
