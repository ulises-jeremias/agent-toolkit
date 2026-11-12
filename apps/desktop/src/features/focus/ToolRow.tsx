import { useState } from 'react';
import { PixelIcon } from '../../ui';
import { TOOL_ICON, TOOL_VERB, TOOL_VERB_ACTIVE } from './labels';
import type { ToolItem, ToolState } from './timeline';
import styles from './focus.module.css';

const STATE_NOTE: Record<ToolState, string> = {
  running: '',
  'awaiting-approval': 'waiting for you',
  ok: '',
  failed: 'failed',
  denied: 'you said no',
  cancelled: 'stopped',
};

function text(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function field(input: unknown, key: string): unknown {
  return typeof input === 'object' && input !== null ? (input as Record<string, unknown>)[key] : undefined;
}

/** A before/after pair from an edit call, as removed and added lines. */
function EditPreview({ before, after }: { before: string; after: string }) {
  return (
    <pre className={styles.diffPreview} aria-label="Change preview">
      {before.split('\n').map((line, index) => (
        <span key={`r${index}`} data-change="removed">
          {`- ${line}\n`}
        </span>
      ))}
      {after.split('\n').map((line, index) => (
        <span key={`a${index}`} data-change="added">
          {`+ ${line}\n`}
        </span>
      ))}
    </pre>
  );
}

export function ToolDetail({ item }: { item: ToolItem }) {
  const command = text(field(item.input, 'command'));
  const before = text(field(item.input, 'old_string'));
  const after = text(field(item.input, 'new_string'));
  const content = text(field(item.input, 'content'));
  const known = command !== null || (before !== null && after !== null) || content !== null;
  return (
    <div className={styles.toolDetail}>
      {command ? <pre className={styles.toolCode}>{command}</pre> : null}
      {before !== null && after !== null ? <EditPreview before={before} after={after} /> : null}
      {content ? <EditPreview before="" after={content} /> : null}
      {!known && item.input !== undefined && item.input !== null ? (
        <pre className={styles.toolCode}>{JSON.stringify(item.input, null, 2)}</pre>
      ) : null}
      {item.output ? (
        <pre className={styles.toolOutput} data-state={item.state}>
          {item.output}
        </pre>
      ) : null}
      {item.truncated ? <p className={styles.toolNote}>Output shortened. The middle was left out.</p> : null}
      {item.children.length > 0 ? (
        <ul className={styles.toolChildren}>
          {item.children.map((child) => (
            <li key={child.key}>
              <ToolRow item={child} />
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

export function ToolRow({ item }: { item: ToolItem }) {
  const [open, setOpen] = useState(false);
  const active = item.state === 'running' || item.state === 'awaiting-approval';
  const verb = active ? TOOL_VERB_ACTIVE[item.toolKind] : TOOL_VERB[item.toolKind];
  const note = STATE_NOTE[item.state];
  const steps = item.children.length;
  return (
    <div className={styles.tool} data-state={item.state}>
      <button type="button" className={styles.toolHead} aria-expanded={open} onClick={() => setOpen((value) => !value)}>
        <span className={styles.toolIcon}>
          <PixelIcon name={TOOL_ICON[item.toolKind]} size={12} />
        </span>
        <span className={styles.toolVerb}>{verb}</span>
        <span className={styles.toolTitle}>{item.title}</span>
        {steps > 0 ? <span className={styles.toolNoteInline}>{steps === 1 ? '1 step' : `${steps} steps`}</span> : null}
        {note ? <span className={styles.toolNoteInline}>{note}</span> : null}
        {item.state === 'running' ? <span className={styles.spinner} aria-label="In progress" /> : null}
      </button>
      {open ? <ToolDetail item={item} /> : null}
    </div>
  );
}
