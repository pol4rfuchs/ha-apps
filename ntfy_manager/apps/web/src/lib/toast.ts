type ToastKind = "success" | "error" | "info" | "warn";

let counter = 0;

export type ToastItem = {
  id: number;
  kind: ToastKind;
  message: string;
};

type Listener = (items: ToastItem[]) => void;

const items: ToastItem[] = [];
const listeners = new Set<Listener>();

function notify() {
  for (const l of listeners) l([...items]);
}

export const toast = {
  push(kind: ToastKind, message: string, ttlMs = 3500) {
    const id = ++counter;
    items.unshift({ id, kind, message });
    if (items.length > 8) items.length = 8;
    notify();
    setTimeout(() => {
      const idx = items.findIndex((i) => i.id === id);
      if (idx !== -1) {
        items.splice(idx, 1);
        notify();
      }
    }, ttlMs);
  },
  success: (m: string) => toast.push("success", m),
  error: (m: string) => toast.push("error", m, 5000),
  info: (m: string) => toast.push("info", m),
  warn: (m: string) => toast.push("warn", m),
  subscribe(l: Listener) {
    listeners.add(l);
    l([...items]);
    return () => {
      listeners.delete(l);
    };
  }
};
