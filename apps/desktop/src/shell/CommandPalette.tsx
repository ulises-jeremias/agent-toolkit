import { useEffect, useId, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { rankEntries, type PaletteEntry } from '../lib/palette';
import { Dialog, Kbd } from '../ui';
import styles from './shell.module.css';

export interface PaletteCommand extends PaletteEntry {
  keys?: readonly string[];
  /** Why the command cannot run right now; shown instead of running it. */
  disabledReason?: string;
  run: () => void;
}

/**
 * Mod+K. A combobox over every shell command: filter by typing, move with the
 * arrow keys, run with Enter. Commands come from the shell so the palette
 * never knows about domain logic.
 */
export function CommandPalette({
  open,
  onClose,
  commands,
}: {
  open: boolean;
  onClose: () => void;
  commands: readonly PaletteCommand[];
}) {
  const [query, setQuery] = useState('');
  const [index, setIndex] = useState(0);
  const [wasOpen, setWasOpen] = useState(open);
  const inputRef = useRef<HTMLInputElement>(null);
  const listId = useId();
  const optionId = (i: number) => `${listId}-option-${i}`;

  if (open !== wasOpen) {
    setWasOpen(open);
    if (open) {
      setQuery('');
      setIndex(0);
    }
  }

  const results = useMemo(() => rankEntries(commands, query), [commands, query]);
  const current = results.length === 0 ? -1 : Math.min(index, results.length - 1);

  useEffect(() => {
    if (current >= 0) document.getElementById(`${listId}-option-${current}`)?.scrollIntoView({ block: 'nearest' });
  }, [current, listId]);

  const runAt = (i: number) => {
    const command = results[i];
    if (!command || command.disabledReason) return;
    onClose();
    command.run();
  };

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (results.length === 0) return;
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setIndex((current + 1) % results.length);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setIndex((current - 1 + results.length) % results.length);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      runAt(current);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Command palette"
      initialFocus={inputRef}
      footer={
        <p className={styles.paletteHint}>
          <Kbd keys={['↑', '↓']} /> move <Kbd keys={['Enter']} /> run <Kbd keys={['Esc']} /> close
        </p>
      }
    >
      <input
        ref={inputRef}
        className={styles.paletteInput}
        type="text"
        role="combobox"
        aria-label="Search commands"
        aria-expanded="true"
        aria-controls={listId}
        aria-autocomplete="list"
        aria-activedescendant={current >= 0 ? optionId(current) : undefined}
        placeholder="Go to, open, run…"
        value={query}
        onChange={(event) => {
          setQuery(event.target.value);
          setIndex(0);
        }}
        onKeyDown={onKeyDown}
        autoComplete="off"
        spellCheck={false}
      />
      <ul id={listId} className={styles.paletteList} role="listbox" aria-label="Commands">
        {results.map((command, i) => (
          // Selection normally stays on the input (aria-activedescendant);
          // options are focusable only so a pointer user can land on one.
          <li
            key={command.id}
            id={optionId(i)}
            role="option"
            tabIndex={-1}
            aria-selected={i === current}
            aria-disabled={command.disabledReason ? true : undefined}
            className={styles.paletteOption}
            onMouseMove={() => setIndex(i)}
            onClick={() => runAt(i)}
            onKeyDown={(event) => {
              if (event.key === 'Enter') runAt(i);
            }}
          >
            <span className={styles.paletteLabel}>{command.label}</span>
            <span className={styles.paletteGroup}>{command.disabledReason ?? command.group}</span>
            {command.keys ? <Kbd keys={command.keys} /> : null}
          </li>
        ))}
      </ul>
      {results.length === 0 ? <p className={styles.paletteEmpty}>No command matches “{query}”.</p> : null}
    </Dialog>
  );
}
