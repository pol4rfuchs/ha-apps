import { X } from "lucide-react";
import type { ReactNode } from "react";

export default function Modal({
  open,
  onClose,
  title,
  children,
  footer,
  width = "max-w-md"
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  width?: string;
}) {
  if (!open) return null;
  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center bg-black/70 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className={`card w-full ${width} mx-4 bg-panel`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="card-header">
          <h3 className="text-base font-bold">{title}</h3>
          <button
            onClick={onClose}
            className="p-1 rounded-lg hover:bg-white/5 text-muted"
            aria-label="Close"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="card-body space-y-4">{children}</div>
        {footer && (
          <div className="px-5 py-4 border-t border-white/10 flex justify-end gap-2">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
