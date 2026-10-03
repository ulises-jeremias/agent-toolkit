import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import { requireClient, useBackend } from '../data/backend';
import { useSubQuery } from '../data/commands';
import { useTerminalSessions } from '../data/terminal';
import { setThemePreference } from '../design/theme';
import { takeNextNeedsMe } from '../features/office/attention';
import { useAttention } from '../features/office/useAttention';
import { requestOnboardingReplay } from '../features/onboarding/complete';
import { parseProjectListMessage } from '../features/world/model';
import { projectWorldCommands, resolveProjectWorldJump, resolveWorldJump } from '../features/world/worldJumps';
import { envelopeText } from '../lib/api';
import { Button, Dialog, Kbd, TextInput, VisuallyHidden } from '../ui';
import { filterCommands, PALETTE_COMMANDS, personCommands, SHORTCUTS, type PaletteCommand } from './commands';
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
  const restartCancelRef = useRef<HTMLButtonElement>(null);
  const [restartConfirmOpen, setRestartConfirmOpen] = useState(false);
  const navigate = useNavigate();
  const { context, href } = useSessionContext();
  const { client, restartBackend } = useBackend();
  const terminals = useTerminalSessions();
  const attention = useAttention();
  const projectsQuery = useSubQuery('project', 'list');
  const peopleQuery = useQuery({
    queryKey: ['people', context.workspace],
    queryFn: () => requireClient(client).people(context.workspace),
    enabled: client !== null && Boolean(context.workspace),
    staleTime: 15_000,
  });

  const projectCommands = useMemo((): readonly PaletteCommand[] => {
    if (!projectsQuery.isSuccess || !projectsQuery.data) return [];
    const names = parseProjectListMessage(envelopeText(projectsQuery.data)).map((row) => row.name);
    return projectWorldCommands(names);
  }, [projectsQuery.data, projectsQuery.isSuccess]);

  const peoplePaletteCommands = useMemo(
    () => personCommands(peopleQuery.data?.people ?? [], terminals.sessions),
    [peopleQuery.data, terminals.sessions],
  );

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

  const catalog = useMemo(
    () => [...PALETTE_COMMANDS, ...projectCommands, ...peoplePaletteCommands],
    [peoplePaletteCommands, projectCommands],
  );
  const matches = useMemo(() => filterCommands(catalog, query), [catalog, query]);
  const active = matches[Math.min(selected, Math.max(matches.length - 1, 0))];

  useEffect(() => {
    setSelected(0);
  }, [query]);

  const run = (command: PaletteCommand | undefined) => {
    if (!command) return;
    const action = command.action;
    if (action.type === 'help') {
      setShortcuts(true);
      return;
    }
    setOpen(false);
    switch (action.type) {
      case 'navigate':
        navigate(href(action.path));
        return;
      case 'workspace-switch':
        navigate(href('/settings', { panel: 'harness' }));
        return;
      case 'world-jump': {
        if (action.target === 'world-knowledge') {
          navigate(href('/library'));
          return;
        }
        const jump = resolveWorldJump(action.target);
        if (jump) navigate(href(jump.path, jump.extra));
        return;
      }
      case 'world-project': {
        const jump = resolveProjectWorldJump(action.projectName);
        if (jump) navigate(href(jump.path, jump.extra));
        return;
      }
      case 'person': {
        if (action.intent === 'start') {
          navigate(href('/people', { person: action.personId, start: '1' }));
        } else if (action.intent === 'session') {
          const session = terminals.sessions.find(
            (candidate) => candidate.personId === action.personId && candidate.exitCode === null,
          );
          navigate(session ? href('/terminal', { pty: session.id }) : href('/people', { person: action.personId }));
        } else {
          navigate(href('/people', { person: action.personId }));
        }
        return;
      }
      case 'session':
        switch (action.intent) {
          case 'new-terminal':
            navigate(href('/terminal'));
            terminals.setCreating(true);
            return;
          case 'start-job':
            navigate(href('/operations', { dialog: 'start-job' }));
            return;
          case 'run-loop':
            navigate(href('/operations', { dialog: 'run-loop' }));
            return;
          case 'start-swarm':
            navigate(href('/operations', { dialog: 'start-swarm' }));
            return;
          case 'next-needs-me': {
            const next = takeNextNeedsMe(attention.targets);
            navigate(next ? next.href : href('/office'));
            return;
          }
          case 'restart-backend':
            setRestartConfirmOpen(true);
            return;
          case 'replay-onboarding':
            requestOnboardingReplay();
            return;
        }
        return;
      case 'theme':
        setThemePreference(action.theme);
        return;
    }
  };

  return (
    <>
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
              <Kbd keys={['↑']} /> <Kbd keys={['↓']} /> move · <Kbd keys={['Enter']} /> run · <Kbd keys={['Esc']} />{' '}
              close
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
                matches.map((item) => (
                  <li key={item.id} role="none">
                    <button
                      id={`command-${item.id}`}
                      type="button"
                      role="option"
                      aria-selected={item.id === active?.id}
                      className={styles.paletteItem}
                      onClick={() => run(item)}
                    >
                      <span className={styles.paletteGroup}>{item.group}</span>
                      <span className={styles.paletteTitle}>{item.title}</span>
                      {item.hint ? <span className={styles.paletteItemHint}>{item.hint}</span> : null}
                      {item.keys ? <Kbd keys={item.keys} /> : null}
                    </button>
                  </li>
                ))
              )}
            </ul>
          </div>
        )}
      </Dialog>
      <Dialog
        open={restartConfirmOpen}
        onClose={() => setRestartConfirmOpen(false)}
        title="Restart the local backend?"
        description="Current API requests or jobs may be interrupted. Desktop will reconnect when the backend is ready."
        initialFocus={restartCancelRef}
        footer={
          <>
            <Button ref={restartCancelRef} variant="ghost" onClick={() => setRestartConfirmOpen(false)}>
              Cancel
            </Button>
            <Button
              variant="danger"
              onClick={() => {
                setRestartConfirmOpen(false);
                void restartBackend();
              }}
            >
              Restart backend
            </Button>
          </>
        }
      />
    </>
  );
}
