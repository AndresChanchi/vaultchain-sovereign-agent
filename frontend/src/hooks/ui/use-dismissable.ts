/**
 * Dismiss-on-outside-click + dismiss-on-Escape for popovers.
 *
 * Returns a ref that must be attached to the popover container. When
 * `open` is true and the user clicks outside the ref (or presses
 * Escape), `onDismiss` is invoked. `onDismiss` can change every
 * render — the effect re-subscribes only when `open` toggles.
 *
 * Why the ref-and-latest pattern
 *   `onDismiss` is almost always an inline arrow (`() => setOpen(false)`),
 *   so its identity changes on every render. If it were a dependency
 *   of the `useEffect`, the listeners would be re-attached on every
 *   render while the popover is open — noisy and unnecessary. Storing
 *   the latest callback in a ref keeps the effect stable.
 *
 * Reusability
 *   Two consumers today: `SpaceAccountCard` (sidebar) and
 *   `SpaceAccountAvatar` (header mobile). Any future popover —
 *   `LanguagePicker`, a wallet switcher, a filter menu — uses the
 *   same hook. Extracting it prevents three inline copies of the
 *   click-outside handler drifting out of sync.
 */
import { useEffect, useRef } from "react";

export function useDismissable(open: boolean, onDismiss: () => void) {
  const ref = useRef<HTMLDivElement>(null);
  const onDismissRef = useRef(onDismiss);
  onDismissRef.current = onDismiss;

  useEffect(() => {
    if (!open) return;

    const handlePointer = (event: MouseEvent) => {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        onDismissRef.current();
      }
    };
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onDismissRef.current();
      }
    };

    document.addEventListener("mousedown", handlePointer);
    document.addEventListener("keydown", handleKey);
    return () => {
      document.removeEventListener("mousedown", handlePointer);
      document.removeEventListener("keydown", handleKey);
    };
  }, [open]);

  return ref;
}
