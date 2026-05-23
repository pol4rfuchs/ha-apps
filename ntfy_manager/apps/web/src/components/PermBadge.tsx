export default function PermBadge({ permission }: { permission?: string | null }) {
  const p = (permission ?? "").toLowerCase();
  const map: Record<string, string> = {
    "read-write": "badge-ok",
    "read-only": "badge-info",
    "write-only": "badge-warn",
    "deny-all": "badge-bad"
  };
  const cls = map[p] ?? "";
  return <span className={`badge ${cls}`}>{permission ?? "—"}</span>;
}
