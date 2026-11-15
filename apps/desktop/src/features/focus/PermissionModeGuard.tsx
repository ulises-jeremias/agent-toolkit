import { useEffect, useRef, useState, type ReactNode } from 'react';
import type { FocusPermissionMode } from '../../types/focus';
import { Button, Dialog } from '../../ui';

/** Require a deliberate second step before a provider receives unrestricted permissions. */
export function usePermissionModeGuard(
  current: FocusPermissionMode,
  providerLabel: string,
  cwd: string,
  contextKey: string,
  apply: (mode: FocusPermissionMode) => void,
): { choose: (mode: FocusPermissionMode) => void; dialog: ReactNode } {
  const [pending, setPending] = useState<{ mode: FocusPermissionMode; key: string } | null>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);

  // Consent belongs to one exact provider/project/thread, never to a reused dialog.
  const key = JSON.stringify([contextKey, providerLabel, cwd]);
  useEffect(() => setPending(null), [key]);
  const confirmedPending = pending?.key === key ? pending : null;

  const choose = (mode: FocusPermissionMode) => {
    if (mode === 'bypass' && current !== 'bypass') {
      setPending({ mode, key });
      return;
    }
    apply(mode);
  };

  const dialog = (
    <Dialog
      open={confirmedPending !== null}
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
              if (confirmedPending) apply(confirmedPending.mode);
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
