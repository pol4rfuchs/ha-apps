import { useEffect, useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { ntfy, ntfyErrorText, type NtfyAccount } from "../lib/ntfy";
import { toast } from "../lib/toast";
import PermBadge from "../components/PermBadge";

const PERMS = ["read-write", "read-only", "write-only", "deny-all"] as const;

export default function ReservationsPage({
  refreshKey,
  search,
  currentUser
}: {
  refreshKey: number;
  search: string;
  currentUser: string | null;
}) {
  const [account, setAccount] = useState<NtfyAccount | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [topic, setTopic] = useState("");
  const [everyone, setEveryone] = useState<(typeof PERMS)[number]>("deny-all");
  const [busy, setBusy] = useState(false);

  async function reload() {
    setError(null);
    try {
      const r = await ntfy.account();
      if (r.ok && r.data) setAccount(r.data);
      else setError(`HTTP ${r.status}`);
    } catch (err) {
      setError(ntfyErrorText(err));
    }
  }

  useEffect(() => {
    reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refreshKey]);

  const list = (account?.reservations ?? []).filter(
    (r) => !search || r.topic.toLowerCase().includes(search.toLowerCase())
  );

  async function add() {
    if (!topic.trim()) return toast.error("Enter a topic");
    setBusy(true);
    try {
      const r = await ntfy.addReservation(topic.trim(), everyone);
      if (r.ok) {
        toast.success(`Reserved "${topic}"`);
        setTopic("");
        reload();
      } else toast.error(`HTTP ${r.status}`);
    } catch (err) {
      toast.error(ntfyErrorText(err));
    } finally {
      setBusy(false);
    }
  }

  async function remove(t: string) {
    if (!confirm(`Delete reservation for "${t}"?`)) return;
    try {
      const r = await ntfy.deleteReservation(t);
      if (r.ok) {
        toast.success(`Reservation "${t}" deleted`);
        reload();
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
            Reservations{" "}
            {account?.reservations && (
              <span className="text-muted font-mono text-xs ml-1">
                ({account.reservations.length})
              </span>
            )}
          </h3>
          <span className="text-xs text-muted font-mono">
            {currentUser ?? "—"}
          </span>
        </div>
        {error ? (
          <div className="card-body">
            <div className="empty text-bad">Error: {error}</div>
          </div>
        ) : !account ? (
          <div className="card-body">
            <div className="empty">Loading…</div>
          </div>
        ) : !list.length ? (
          <div className="card-body">
            <div className="empty">No topic reservations for this account.</div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Topic</th>
                  <th>Owner permission</th>
                  <th>Everyone else</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {list.map((r) => (
                  <tr key={r.topic}>
                    <td className="font-mono">{r.topic}</td>
                    <td>
                      <PermBadge permission={r.owner_permission ?? "read-write"} />
                    </td>
                    <td>
                      <PermBadge permission={r.everyone_permission ?? "deny-all"} />
                    </td>
                    <td>
                      <button
                        onClick={() => remove(r.topic)}
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
          <h3 className="font-bold">Reserve Topic</h3>
        </div>
        <div className="card-body space-y-3">
          <div>
            <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
              Topic
            </label>
            <input
              className="input font-mono"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder="ha-alerts"
            />
          </div>
          <div>
            <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
              Everyone else
            </label>
            <select
              className="select"
              value={everyone}
              onChange={(e) =>
                setEveryone(e.target.value as (typeof PERMS)[number])
              }
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
            <Plus className="h-4 w-4" /> Reserve
          </button>
          <div className="text-[11px] text-muted leading-relaxed">
            ntfy expects <span className="font-mono">{`{topic, everyone}`}</span> in
            the request body — owner is always read-write.
          </div>
        </div>
      </div>
    </div>
  );
}
