"use client";

/**
 * Upload dialog — open/close state.
 *
 * Simpler than `LoginModalContext`: no URL push, no history, no
 * return-to. The upload dialog is a purely in-app modal that does not
 * correspond to a route. Opening it does not change the URL; closing
 * it does not revert anything.
 *
 * State contract
 *   `isOpen` — whether `<UploadDialog>` should call
 *              `dialog.showModal()`. The dialog component owns the
 *              sync effect.
 *   `open`   — called by the header Upload button, the dock central
 *              `+`, and any future surface that triggers upload.
 *   `close`  — called by the X button, the "Open my space" CTA,
 *              backdrop click, or Escape (when the flow is not in an
 *              active stage — see `upload-dialog.tsx`).
 *
 * Flow reset — coordinated in the dialog
 *   `close()` only flips `isOpen` to `false`. The flow reset is
 *   performed by `UploadDialog`'s native `close` listener, so both
 *   user-initiated and programmatic closes reset. Keeping the reset
 *   out of this context prevents `open/close` from becoming coupled
 *   to the flow lifecycle — a UI flag should not need to know what a
 *   pipeline is.
 *
 * Placement
 *   Mounted inside `(app)/layout.tsx`, alongside `<UploadDialog>`.
 *   The dialog renders over the shell (not inside `main`), so it sits
 *   as a sibling of `<SpaceShell>` rather than a child.
 */
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";

type UploadDialogContextValue = {
  isOpen: boolean;
  open: () => void;
  close: () => void;
};

const UploadDialogContext = createContext<UploadDialogContextValue | null>(
  null,
);

export function UploadDialogProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const open = useCallback(() => setIsOpen(true), []);
  const close = useCallback(() => setIsOpen(false), []);
  const value = useMemo<UploadDialogContextValue>(
    () => ({ isOpen, open, close }),
    [isOpen, open, close],
  );
  return (
    <UploadDialogContext.Provider value={value}>
      {children}
    </UploadDialogContext.Provider>
  );
}

export function useUploadDialog(): UploadDialogContextValue {
  const ctx = useContext(UploadDialogContext);
  if (ctx === null) {
    throw new Error("useUploadDialog must be used inside <UploadDialogProvider>.");
  }
  return ctx;
}
