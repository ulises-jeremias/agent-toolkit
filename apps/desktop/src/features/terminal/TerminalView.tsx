import { useTerminals } from '../../data/terminals';
import { Button, EmptyState, PageHeader, Panel } from '../../ui';

/**
 * Terminal: the page header for the terminal dock. The sessions themselves
 * render in the shell's persistent dock, which fills this destination, so
 * leaving and coming back never restarts an xterm.
 */
export default function TerminalView() {
  const terminals = useTerminals();

  if (!terminals.available) {
    return (
      <>
        <PageHeader eyebrow="Terminal" title="Terminal" />
        <Panel title="Unavailable in the browser">
          <EmptyState title="Interactive terminals need the Desktop app.">
            They run through node-pty in the Electron main process. Start Desktop with <code>pnpm dev:electron</code>.
          </EmptyState>
        </Panel>
      </>
    );
  }

  return (
    <PageHeader
      eyebrow="Terminal"
      title="Sessions"
      lede="Sessions keep running while you work elsewhere; the dock shows them on every destination."
      actions={
        <Button variant="primary" onClick={() => terminals.setNewSessionOpen(true)}>
          New session
        </Button>
      }
    />
  );
}
