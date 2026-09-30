import { SHORTCUTS } from '../lib/shortcuts';
import { Button, Dialog, Kbd, Table } from '../ui';
import { DESTINATIONS } from './destinations';

function describe(id: string, fallback: string): string {
  const match = /^goto(\d)$/.exec(id);
  const destination = match ? DESTINATIONS[Number(match[1]) - 1] : undefined;
  return destination ? `Go to ${destination.label}` : fallback;
}

/** Mod+/. Every global chord, from the same table the handler uses. */
export function ShortcutMap({ open, onClose }: { open: boolean; onClose: () => void }) {
  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Keyboard shortcuts"
      description="These work on every destination, including while a terminal has focus. Every other key, such as Ctrl+C, goes to the terminal."
      footer={<Button onClick={onClose}>Close</Button>}
    >
      <Table>
        <thead>
          <tr>
            <th scope="col">Keys</th>
            <th scope="col">Action</th>
          </tr>
        </thead>
        <tbody>
          {SHORTCUTS.map((shortcut) => (
            <tr key={shortcut.id}>
              <td>
                <Kbd keys={shortcut.keys} />
              </td>
              <td>{describe(shortcut.id, shortcut.description)}</td>
            </tr>
          ))}
        </tbody>
      </Table>
    </Dialog>
  );
}
