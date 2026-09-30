import { useEffect, useLayoutEffect, useRef } from 'react';
import { matchShortcut, type ShortcutId } from '../lib/shortcuts';

export type ShortcutHandlers = Partial<Record<ShortcutId, () => void>>;

/**
 * One capture-phase listener for every global chord, so it runs before
 * xterm or any input sees the key. While a modal dialog is open only
 * Escape (native) applies; chords would stack dialogs.
 */
export function useGlobalShortcuts(handlers: ShortcutHandlers): void {
  const latest = useRef(handlers);
  useLayoutEffect(() => {
    latest.current = handlers;
  });

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.defaultPrevented || event.repeat) return;
      const id = matchShortcut(event);
      if (!id) return;
      if (document.querySelector('dialog[open]')) return;
      const handler = latest.current[id];
      if (!handler) return;
      event.preventDefault();
      event.stopPropagation();
      handler();
    };
    window.addEventListener('keydown', onKeyDown, { capture: true });
    return () => window.removeEventListener('keydown', onKeyDown, { capture: true });
  }, []);
}
