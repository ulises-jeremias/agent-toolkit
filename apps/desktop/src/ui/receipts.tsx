import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { errorMessage, recoveryHint, type CommandEnvelope } from '../lib/api';
import { Button, type Tone } from './primitives';
import styles from './ui.module.css';

/**
 * Receipts: the record that an action happened and what came of it. They are
 * toasts on screen, but failures stay until dismissed and every receipt of the
 * session is kept for later review, so nothing is only ever a flash.
 */
export interface Receipt {
  id: string;
  tone: Tone;
  title: string;
  detail?: string;
  at: number;
}

export type ReceiptInput = Omit<Receipt, 'id' | 'at'>;

interface ReceiptsValue {
  /** Every receipt of this session, newest first (bounded). */
  history: readonly Receipt[];
  push: (input: ReceiptInput) => string;
  dismiss: (id: string) => void;
}

const ReceiptsContext = createContext<ReceiptsValue | null>(null);

export function useReceipts(): ReceiptsValue {
  const value = useContext(ReceiptsContext);
  if (!value) throw new Error('useReceipts must be used inside <ReceiptsProvider>');
  return value;
}

const HISTORY_LIMIT = 50;
const VISIBLE_LIMIT = 4;
export const RECEIPT_DISMISS_MS = 6_000;

function firstLine(text: string): string {
  const line = text.split('\n').find((candidate) => candidate.trim() !== '') ?? '';
  return line.length > 160 ? `${line.slice(0, 157)}…` : line;
}

/** onSuccess/onError handlers that file a receipt for a mutation. */
export function useActionReceipt(title: string) {
  const { push } = useReceipts();
  return useMemo(
    () => ({
      onSuccess: (result?: CommandEnvelope | unknown) => {
        const message =
          typeof result === 'object' && result !== null && 'message' in result && typeof result.message === 'string'
            ? firstLine(result.message)
            : undefined;
        push({ tone: 'ok', title, detail: message || undefined });
      },
      onError: (error: unknown) => {
        push({
          tone: 'err',
          title: `${title} failed`,
          detail: `${firstLine(errorMessage(error))} ${recoveryHint(error)}`,
        });
      },
    }),
    [push, title],
  );
}

let counter = 0;

export function ReceiptsProvider({ children }: { children: ReactNode }) {
  const [history, setHistory] = useState<Receipt[]>([]);
  const [visible, setVisible] = useState<string[]>([]);

  const dismiss = useCallback((id: string) => {
    setVisible((ids) => ids.filter((candidate) => candidate !== id));
  }, []);

  const push = useCallback(
    (input: ReceiptInput) => {
      counter += 1;
      const receipt: Receipt = { ...input, id: `receipt-${counter}`, at: Date.now() };
      const recoveredFailureIds =
        input.tone === 'ok'
          ? new Set(
              history
                .filter((item) => item.tone === 'err' && item.title === `${input.title} failed`)
                .map((item) => item.id),
            )
          : new Set<string>();
      setHistory((items) => [receipt, ...items].slice(0, HISTORY_LIMIT));
      setVisible((ids) => {
        const active = ids.filter((id) => !recoveredFailureIds.has(id));
        const persistent = active.filter((id) => {
          const previous = history.find((item) => item.id === id);
          return previous?.tone === 'err' || previous?.tone === 'warn';
        });
        return [receipt.id, ...persistent].slice(0, VISIBLE_LIMIT);
      });
      return receipt.id;
    },
    [history],
  );

  const value = useMemo(() => ({ history, push, dismiss }), [history, push, dismiss]);
  const byId = new Map(history.map((receipt) => [receipt.id, receipt]));
  const shown = visible.map((id) => byId.get(id)).filter((receipt): receipt is Receipt => receipt !== undefined);

  return (
    <ReceiptsContext.Provider value={value}>
      {children}
      <section aria-label="Receipts">
        <ol className={styles.receipts} aria-live="polite" aria-relevant="additions">
          {shown.map((receipt) => (
            <ReceiptItem key={receipt.id} receipt={receipt} onDismiss={dismiss} />
          ))}
        </ol>
      </section>
    </ReceiptsContext.Provider>
  );
}

function ReceiptItem({ receipt, onDismiss }: { receipt: Receipt; onDismiss: (id: string) => void }) {
  const [held, setHeld] = useState(false);
  const persistent = receipt.tone === 'err' || receipt.tone === 'warn';
  useEffect(() => {
    if (persistent || held) return;
    const timer = setTimeout(() => onDismiss(receipt.id), RECEIPT_DISMISS_MS);
    return () => clearTimeout(timer);
  }, [persistent, held, receipt.id, onDismiss]);

  const time = new Date(receipt.at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  return (
    <li
      className={styles.receipt}
      data-tone={receipt.tone}
      role={receipt.tone === 'err' ? 'alert' : undefined}
      onMouseEnter={() => setHeld(true)}
      onMouseLeave={() => setHeld(false)}
      onFocus={() => setHeld(true)}
      onBlur={() => setHeld(false)}
    >
      <p className={styles.receiptTitle}>{receipt.title}</p>
      <Button variant="ghost" size="sm" onClick={() => onDismiss(receipt.id)} aria-label={`Dismiss: ${receipt.title}`}>
        Dismiss
      </Button>
      {receipt.detail ? <p className={styles.receiptDetail}>{receipt.detail}</p> : null}
      <p className={styles.receiptMeta}>
        <time dateTime={new Date(receipt.at).toISOString()}>{time}</time>
      </p>
    </li>
  );
}
