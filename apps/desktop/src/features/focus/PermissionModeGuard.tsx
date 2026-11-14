import { useRef, useState, type ReactNode } from 'react';
import type { FocusPermissionMode } from '../../types/focus';
import { Button, Dialog } from '../../ui';

/** Require a deliberate second step before a provider receives unrestricted permissions. */
export function usePermissionModeGuard(
  current: FocusPermissionMode,
  providerLabel: string,
  cwd: string,
  apply: (mode: FocusPermissionMode) => void,
): { choose: (mode: FocusPermissionMode) => void; dialog: ReactNode } {
  const [pending, setPending] = useState<FocusPermissionMode | null>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);

  const choose = (mode: FocusPermissionMode) => {
    if (mode === 'bypass' && current !== 'bypass') {
      setPending(mode);
      return;
    }
    apply(mode);
  };

  const dialog = (
    <Dialog
      open={pending !== null}
      onClose={() => setPending(null)}
      title="Enable unrestricted access?"
      description={
        <>
          {providerLabel} will not ask before actions. Commands may read and change files anywhere your local account
          has access. The selected folder <code>{cwd}</code> is not a security boundary, and Agent Toolkit does not
          enforce an operating-system sandbox. Continue only for a trusted task when you can discard all file changes
          and side effects.
        </>
      }
      initialFocus={cancelRef}
      footer={
        <>
          <Button ref={cancelRef} variant="ghost" onClick={() => setPending(null)}>
            Keep current permissions
          </Button>
          <Button
            variant="danger"
            onClick={() => {
              if (pending) apply(pending);
              setPending(null);
            }}
          >
            Enable without asking
          </Button>
        </>
      }
    />
  );

  return { choose, dialog };
}
