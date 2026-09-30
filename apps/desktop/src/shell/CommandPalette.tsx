import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useBackend } from '../data/backend';
import { useTerminalSessions } from '../data/terminal';
import { setThemePreference, type ThemePreference } from '../design/theme';
import { Dialog, Kbd, TextInput, VisuallyHidden } from '../ui';
import { requestOnboardingReplay } from '../features/onboarding/complete';
import { filterCommands, PALETTE_COMMANDS, SHORTCUTS, type PaletteCommand } from './commands';
import { DESTINATIONS } from './destinations';
import { useSessionContext } from './useSessionContext';
import styles from './shell.module.css';

export const OPEN_PALETTE_EVENT = 'atk:open-palette';

export function openCommandPalette(): void {
  window.dispatchEvent(new Event(OPEN_PALETTE_EVENT));
}

function isPaletteChord(event: KeyboardEvent): boolean {
  return (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k' && !event.altKey;
}

/**
 * Global command palette (Ctrl/Cmd+K). Runs navigation and a few session
 * actions; destination-specific work stays on those screens.
 */
export function CommandPalette() {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState(0);
  const [shortcuts, setShortcuts] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();
  const { href } = useSessionContext();
  const { restartBackend } = useBackend();
  const terminals = useTerminalSessions();

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (isPaletteChord(event)) {
        event.preventDefault();
        setOpen(true);
        setShortcuts(false);
        return;
      }
      if (event.key === '?' && !event.metaKey && !event.ctrlKey && !event.altKey) {
        const target = event.target;
        if (target instanceof HTMLElement) {
          const tag = target.tagName;
          if (tag === 'INPUT' || tag === 'TEXTAREA' || target.isContentEditable) return;
        }
        event.preventDefault();
        setOpen(true);
        setShortcuts(true);
        setQuery('');
      }
    };
    const onOpen = () => {
      setOpen(true);
      setShortcuts(false);
    };
    window.addEventListener('keydown', onKey);
    window.addEventListener(OPEN_PALETTE_EVENT, onOpen);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener(OPEN_PALETTE_EVENT, onOpen);
    };
  }, []);

  useEffect(() => {
    if (!open) {
      setQuery('');
      setSelected(0);
      setShortcuts(false);
    }
  }, [open]);

  const matches = useMemo(() => filterCommands(PALETTE_COMMANDS, query), [query]);
  const active = matches[Math.min(selected, Math.max(matches.length - 1, 0))];

  useEffect(() => {
    setSelected(0);
  }, [query]);

  const run = (command: PaletteCommand | undefined) => {
    if (!command) return;
    if (command.id === 'help:shortcuts') {
      setShortcuts(true);
      return;
    }
    setOpen(false);
    if (command.id.startsWith('go:')) {
      const target = command.id.slice(3);
      if (target === 'world-knowledge') {
        navigate(href('/world'));
        return;
      }
      if (target === 'world-terminal') {
        navigate(href('/terminal'));
        return;
      }
      navigate(href(target));
      return;
    }
    switch (command.id) {
      case 'session:new-terminal':
        navigate(href('/terminal'));
        terminals.setCreating(true);
        break;
      case 'session:start-job':
        navigate(href('/operations'));
        break;
      case 'session:restart-backend':
        void restartBackend();
        break;
      case 'session:replay-onboarding':
        requestOnboardingReplay();
        break;
      case 'appearance:paper':
      case 'appearance:ink':
      case 'appearance:system':
        setThemePreference(command.id.slice('appearance:'.length) as ThemePreference);
        break;
      default:
        break;
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => setOpen(false)}
      title={shortcuts ? 'Keyboard shortcuts' : 'Commands'}
      description={
        shortcuts
          ? 'Bindings that work anywhere in the shell. Destination-specific shortcuts stay on those screens.'
          : 'Go to a destination or run a session action. Type to filter.'
      }
      initialFocus={inputRef}
      size="wide"
      footer={
        shortcuts ? (
          <p className={styles.paletteHint}>
            Press <Kbd keys={['Ctrl', 'K']} /> to search commands
          </p>
        ) : (
          <p className={styles.paletteHint}>
            <Kbd keys={['↑']} /> <Kbd keys={['↓']} /> move · <Kbd keys={['Enter']} /> run · <Kbd keys={['Esc']} /> close
          </p>
        )
      }
    >
      {shortcuts ? (
        <table className={styles.shortcutTable}>
          <caption>
            <VisuallyHidden>Shortcut map</VisuallyHidden>
          </caption>
          <tbody>
            {SHORTCUTS.map((row) => (
              <tr key={row.action}>
                <th scope="row">{row.action}</th>
                <td>
                  <Kbd keys={row.keys} />
                </td>
              </tr>
            ))}
            {DESTINATIONS.map((destination) => (
              <tr key={destination.path}>
                <th scope="row">Go to {destination.label}</th>
                <td>
                  <Kbd keys={['Ctrl', 'K']} /> then type {destination.label}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        <div className={styles.palette}>
          <TextInput
            ref={inputRef}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === 'ArrowDown') {
                event.preventDefault();
                setSelected((index) => Math.min(index + 1, matches.length - 1));
              } else if (event.key === 'ArrowUp') {
                event.preventDefault();
                setSelected((index) => Math.max(index - 1, 0));
              } else if (event.key === 'Enter') {
                event.preventDefault();
                run(active);
              }
            }}
            placeholder="Go to… or start a session"
            aria-label="Filter commands"
            aria-controls="command-palette-list"
            aria-activedescendant={active ? `command-${active.id}` : undefined}
            autoComplete="off"
          />
          <ul id="command-palette-list" className={styles.paletteList} role="listbox" aria-label="Commands">
            {matches.length === 0 ? (
              <li className={styles.paletteEmpty}>No commands match.</li>
            ) : (
              matches.map((command) => (
                <li key={command.id} role="none">
                  <button
                    id={`command-${command.id}`}
                    type="button"
                    role="option"
                    aria-selected={command.id === active?.id}
                    className={styles.paletteItem}
                    onClick={() => run(command)}
                  >
                    <span className={styles.paletteGroup}>{command.group}</span>
                    <span className={styles.paletteTitle}>{command.title}</span>
                    {command.hint ? <span className={styles.paletteItemHint}>{command.hint}</span> : null}
                    {command.keys ? <Kbd keys={command.keys} /> : null}
                  </button>
                </li>
              ))
            )}
          </ul>
        </div>
      )}
    </Dialog>
  );
}
