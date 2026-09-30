import { useEffect, useId, useRef, useState, type ReactNode, type RefObject } from 'react';
import { Button, type ButtonVariant } from './primitives';
import styles from './ui.module.css';

function restoreFocus(returnFocus: { current: HTMLElement | null }): void {
  const target = returnFocus.current;
  returnFocus.current = null;
  if (target?.isConnected) target.focus();
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
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const descriptionId = useId();
  const returnFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      returnFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      dialog.showModal();
      initialFocus?.current?.focus();
    } else if (!open && dialog.open) {
      dialog.close();
      restoreFocus(returnFocus);
    }
  }, [open, initialFocus]);

  // Escape (or any native close) while the parent still says open.
  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    const handleClose = () => {
      if (returnFocus.current === null) return;
      restoreFocus(returnFocus);
      onClose();
    };
    dialog.addEventListener('close', handleClose);
    return () => dialog.removeEventListener('close', handleClose);
  }, [onClose]);

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
