import { useEffect, useId, useRef, useState, type ReactNode, type RefObject } from 'react';
import { Button, type ButtonVariant } from './primitives';
import styles from './ui.module.css';

/** A control inside a closing dialog must not keep focus: a focused text field swallows the palette shortcut. */
function blurWithin(dialog: HTMLDialogElement): void {
  const active = document.activeElement;
  if (active instanceof HTMLElement && dialog.contains(active)) active.blur();
}

function restoreFocus(returnFocus: { current: HTMLElement | null }): void {
  const target = returnFocus.current;
  returnFocus.current = null;
  if (!target?.isConnected) return;
  // Focus must not land in a dialog that is closed (its controls are hidden).
  const owner = target.closest('dialog');
  if (owner && !owner.open) return;
  target.focus();
}

/**
 * Modal built on native `<dialog>.showModal()`: the top layer makes the rest
 * of the document inert (focus cannot leave), Escape closes it, and focus is
 * returned to whatever held it before opening.
 */
export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  size = 'normal',
  initialFocus,
  closeDisabled = false,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: ReactNode;
  children?: ReactNode;
  footer?: ReactNode;
  size?: 'normal' | 'wide';
  /** Element to focus on open; defaults to the first focusable control. */
  initialFocus?: RefObject<HTMLElement | null>;
  /** Prevent Escape from dismissing a modal while a destructive action is running. */
  closeDisabled?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const descriptionId = useId();
  const returnFocus = useRef<HTMLElement | null>(null);

  // Runs on every render, not only when `open` changes: the native dialog can
  // close on its own (Escape) while the parent still says open. Opening again
  // must then reopen it, even though the prop did not change.
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      // Never return focus into another dialog: opened from the palette, the
      // previous focus was the palette's own filter, and restoring into it
      // would leave a text field focused, which swallows the palette shortcut.
      const active = document.activeElement;
      returnFocus.current = active instanceof HTMLElement && !active.closest('dialog') ? active : null;
      dialog.showModal();
      initialFocus?.current?.focus();
    } else if (!open && dialog.open) {
      blurWithin(dialog);
      dialog.close();
      restoreFocus(returnFocus);
    }
  });

  // Escape (or any native close) while the parent still says open.
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    const handleClose = () => {
      // The native close event is queued: if the dialog was reopened before it ran,
      // this event is stale and must not close the new session.
      if (dialog.open) return;
      blurWithin(dialog);
      if (returnFocus.current !== null) restoreFocus(returnFocus);
      onClose();
    };
    dialog.addEventListener('close', handleClose);
    return () => dialog.removeEventListener('close', handleClose);
  }, [onClose]);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    const handleCancel = (event: Event) => {
      // Keep Escape under React state control. Letting the browser close the
      // native dialog first can race the next render and reopen a still-owned
      // dialog before its queued `close` event reaches the parent.
      event.preventDefault();
      if (!closeDisabled) onClose();
    };
    dialog.addEventListener('cancel', handleCancel);
    return () => dialog.removeEventListener('cancel', handleCancel);
  }, [closeDisabled, onClose]);

  return (
    <dialog
      ref={ref}
      className={styles.dialog}
      data-size={size}
      aria-labelledby={titleId}
      aria-describedby={description ? descriptionId : undefined}
    >
      {open ? (
        <div className={styles.dialogForm}>
          <header className={styles.dialogHeader}>
            <h2 id={titleId} className={styles.dialogTitle}>
              {title}
            </h2>
          </header>
          <div className={styles.dialogBody}>
            {description ? <p id={descriptionId}>{description}</p> : null}
            {children}
          </div>
          {footer ? <footer className={styles.dialogFooter}>{footer}</footer> : null}
        </div>
      ) : null}
    </dialog>
  );
}

/**
 * A button that asks before acting. The dialog names the consequence; the
 * cancel button takes initial focus so Enter never confirms by accident.
 */
export function ConfirmAction({
  label,
  title,
  description,
  confirmLabel,
  onConfirm,
  variant = 'danger',
  triggerVariant,
  size = 'md',
  disabled,
  busy,
  children,
}: {
  label: string;
  title: string;
  description: ReactNode;
  confirmLabel: string;
  onConfirm: () => void;
  variant?: ButtonVariant;
  triggerVariant?: ButtonVariant;
  size?: 'sm' | 'md';
  disabled?: boolean;
  busy?: boolean;
  children?: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const cancelRef = useRef<HTMLButtonElement>(null);
  return (
    <>
      <Button
        variant={triggerVariant ?? (variant === 'danger' ? 'secondary' : variant)}
        size={size}
        disabled={disabled}
        busy={busy}
        busyLabel={`${label}…`}
        onClick={() => setOpen(true)}
        aria-haspopup="dialog"
      >
        {label}
      </Button>
      <Dialog
        open={open}
        onClose={() => setOpen(false)}
        title={title}
        description={description}
        initialFocus={cancelRef}
        footer={
          <>
            <Button ref={cancelRef} variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button
              variant={variant}
              onClick={() => {
                setOpen(false);
                onConfirm();
              }}
            >
              {confirmLabel}
            </Button>
          </>
        }
      >
        {children}
      </Dialog>
    </>
  );
}
