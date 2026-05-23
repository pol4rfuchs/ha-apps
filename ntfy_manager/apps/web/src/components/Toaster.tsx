import { useEffect, useState } from "react";
import { CheckCircle2, XCircle, AlertTriangle, Info } from "lucide-react";
import { toast, type ToastItem } from "../lib/toast";

const styles = {
  success: { ring: "border-ok/30", text: "text-ok", Icon: CheckCircle2 },
  error: { ring: "border-bad/30", text: "text-bad", Icon: XCircle },
  warn: { ring: "border-warn/30", text: "text-warn", Icon: AlertTriangle },
  info: { ring: "border-info/30", text: "text-info", Icon: Info }
} as const;

export default function Toaster() {
  const [items, setItems] = useState<ToastItem[]>([]);
  useEffect(() => toast.subscribe(setItems), []);
  return (
    <div className="pointer-events-none fixed top-4 right-4 z-50 flex flex-col gap-2 w-[340px] max-w-[calc(100vw-2rem)]">
      {items.map((it) => {
        const s = styles[it.kind];
        const Icon = s.Icon;
        return (
          <div
            key={it.id}
            className={`pointer-events-auto card border ${s.ring} bg-panel/95 backdrop-blur px-4 py-3 flex items-start gap-3`}
          >
            <Icon className={`h-5 w-5 mt-0.5 flex-none ${s.text}`} />
            <div className="text-sm font-semibold leading-snug">{it.message}</div>
          </div>
        );
      })}
    </div>
  );
}
