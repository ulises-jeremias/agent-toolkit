import { useState } from 'react';
import styles from './operations.module.css';

/**
 * Job log lines with a per-line copy action (the #1103 copy-a-line
 * acceptance). Uses the same clipboard path and failure copy as the
 * Person start dialog: a real `navigator.clipboard.writeText`, a
 * visible confirmation, and a manual-copy fallback message when the
 * clipboard is unavailable or rejects.
 */
export function LogLines({ lines, label }: { lines: readonly string[]; label: string }) {
  const [copiedIndex, setCopiedIndex] = useState<number | null>(null);
  const [copyError, setCopyError] = useState<string | null>(null);

  const copyLine = async (line: string, index: number) => {
    if (!navigator.clipboard?.writeText) {
      setCopiedIndex(null);
      setCopyError('Clipboard access is unavailable. Select the line above to copy it.');
      return;
    }
    try {
      await navigator.clipboard.writeText(line);
      setCopiedIndex(index);
      setCopyError(null);
    } catch {
      setCopiedIndex(null);
      setCopyError('Could not copy the line. Select the text above and copy it manually.');
    }
  };

  return (
    <div>
      <div className={styles.logLines} aria-label={label}>
        {lines.map((line, index) => (
          <div key={index} className={styles.logLine}>
            <span className={styles.logLineText}>{line === '' ? ' ' : line}</span>
            <button
              type="button"
              className={styles.copyLineButton}
              aria-label={`Copy log line ${index + 1}`}
              onClick={() => void copyLine(line, index)}
            >
              Copy
            </button>
          </div>
        ))}
      </div>
      {copiedIndex !== null ? (
        <p role="status" className={styles.copyStatus}>
          Line {copiedIndex + 1} copied to clipboard.
        </p>
      ) : null}
      {copyError ? <p className={styles.copyStatus}>{copyError}</p> : null}
    </div>
  );
}
