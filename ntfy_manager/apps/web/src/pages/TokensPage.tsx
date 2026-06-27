import { useState } from "react";
import { Plus, Copy, ExternalLink, Info } from "lucide-react";
import { ntfy, ntfyErrorText } from "../lib/ntfy";
import { toast } from "../lib/toast";
import { copyToClipboard } from "../lib/clipboard";
import Modal from "../components/Modal";

export default function TokensPage({ ntfyUrl }: { ntfyUrl: string | null }) {
  const [open, setOpen] = useState(false);
  const [lastToken, setLastToken] = useState<string | null>(null);

  function openNtfy() {
    if (ntfyUrl) window.open(ntfyUrl, "_blank");
  }

  return (
    <>
      <div className="card">
        <div className="card-header">
          <h3 className="font-bold">API Tokens</h3>
          <div className="flex gap-2">
            <button onClick={openNtfy} className="btn btn-ghost text-xs">
              <ExternalLink className="h-3.5 w-3.5" /> Open ntfy web UI
            </button>
            <button onClick={() => setOpen(true)} className="btn btn-primary text-xs">
              <Plus className="h-3.5 w-3.5" /> Create token
            </button>
          </div>
        </div>
        <div className="card-body space-y-4">
          <div className="flex gap-3 p-4 rounded-xl border border-info/30 bg-info/5 text-sm">
            <Info className="h-5 w-5 flex-none text-info mt-0.5" />
            <div className="text-muted">
              ntfy's REST API does not expose tokens for listing across all users.
              Create new tokens here, or manage existing ones inside the ntfy web UI
              under <span className="font-mono">Account → Access tokens</span>.
            </div>
          </div>

          {lastToken && (
            <div className="p-4 rounded-xl border border-ok/30 bg-ok/5">
              <div className="text-xs font-extrabold uppercase tracking-wider text-ok mb-2">
                Token created — save it now
              </div>
              <div className="flex items-center gap-2">
                <code className="flex-1 font-mono text-sm break-all">{lastToken}</code>
                <button
                  onClick={() => {
                    copyToClipboard(lastToken).then((ok) => {
                      if (ok) toast.success("Token copied");
                      else toast.error("Copy failed — select and copy manually");
                    });
                  }}
                  className="btn btn-ghost text-xs"
                >
                  <Copy className="h-3.5 w-3.5" /> Copy
                </button>
              </div>
              <div className="text-[11px] text-muted mt-2">
                This is the only time the token will be displayed.
              </div>
            </div>
          )}
        </div>
      </div>

      <CreateTokenModal
        open={open}
        onClose={() => setOpen(false)}
        onCreated={(t) => setLastToken(t)}
      />
    </>
  );
}

function CreateTokenModal({
  open,
  onClose,
  onCreated
}: {
  open: boolean;
  onClose: () => void;
  onCreated: (t: string) => void;
}) {
  const [label, setLabel] = useState("");
  const [expires, setExpires] = useState(""); // yyyy-mm-dd
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    try {
      const exp = expires ? Math.floor(new Date(expires).getTime() / 1000) : undefined;
      const r = await ntfy.createToken(label || undefined, exp);
      if (r.ok && r.data?.token) {
        toast.success("Token created");
        onCreated(r.data.token);
        setLabel("");
        setExpires("");
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
      open={open}
      onClose={onClose}
      title="Create API Token"
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
          Label (optional)
        </label>
        <input
          className="input"
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          placeholder="Home Assistant"
        />
      </div>
      <div>
        <label className="text-xs font-extrabold uppercase tracking-wider text-muted block mb-1.5">
          Expiry (optional)
        </label>
        <input
          type="date"
          className="input"
          value={expires}
          onChange={(e) => setExpires(e.target.value)}
        />
      </div>
    </Modal>
  );
}
