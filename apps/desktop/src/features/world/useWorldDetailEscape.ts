import { useEffect } from 'react';

/**
 * Escape leaves the current world overlay (memory/tool detail, or project
 * interior when the caller wires that). Ignores Escape while a native dialog
 * is open (e.g. install confirm). Caller decides the back target.
 */
export function useWorldDetailEscape(onBack: () => void, active: boolean): void {
  useEffect(() => {
    if (!active) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      if (event.defaultPrevented) return;
      const target = event.target;
      if (target instanceof Element && target.closest('dialog[open]')) return;
      event.preventDefault();
      onBack();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [active, onBack]);
}
