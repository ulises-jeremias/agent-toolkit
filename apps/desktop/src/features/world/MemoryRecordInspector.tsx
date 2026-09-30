import type { MemoryEntry, MemoryReadResponse } from '../../lib/api';
import { Button, ErrorState, KeyValue, LoadingState, Mono, Panel, Stack } from '../../ui';
import styles from './world.module.css';

export interface MemoryRecordInspectorProps {
  path: string;
  /** Fixture or live GET /api/v1/memory/file response. */
  data?: MemoryReadResponse;
  error?: Error | null;
  isPending?: boolean;
  /** Visible Back control — returns to project interior or world. */
  onBack: () => void;
  backLabel?: string;
  onRetry?: () => void;
}

/** Paper Co. inspector for one memory file — real read payload only. */
export function MemoryRecordInspector({
  path,
  data,
  error,
  isPending,
  onBack,
  backLabel = 'Back',
  onRetry,
}: MemoryRecordInspectorProps) {
  const entry = data?.entry;

  return (
    <Panel
      tone="manila"
      title="Memory record"
      meta={path}
      actions={
        <Button type="button" onClick={onBack} aria-label={backLabel}>
          Back
        </Button>
      }
    >
      <div className={styles.detailInspector} role="region" aria-label={`Memory record ${path}`}>
        {isPending ? (
          <LoadingState label={`Reading ${path}`} />
        ) : error ? (
          <ErrorState title="Could not read this memory file" error={error} onRetry={onRetry} />
        ) : entry ? (
          <Stack>
            <KeyValue
              items={[
                { label: 'Title', value: entry.title || '—' },
                { label: 'Kind', value: entry.kind || '—' },
                { label: 'Id', value: <Mono>{entry.id}</Mono> },
                { label: 'File', value: <Mono>{entry.provenance.file || '—'}</Mono> },
                { label: 'Project', value: entry.provenance.project || '—' },
                { label: 'Author', value: entry.provenance.author || '—' },
                { label: 'Timestamp', value: entry.provenance.timestamp || '—' },
                { label: 'Agent', value: entry.provenance.agent || '—' },
                {
                  label: 'Tags',
                  value: entry.tags.length > 0 ? entry.tags.join(', ') : '—',
                },
              ]}
            />
            <MemoryBody entry={entry} />
          </Stack>
        ) : (
          <ErrorState title="Could not read this memory file" error={new Error('Empty memory-file response')} />
        )}
      </div>
    </Panel>
  );
}

function MemoryBody({ entry }: { entry: MemoryEntry }) {
  const body = entry.body;
  const snippet = entry.snippet;
  if (body.length > 0) {
    return (
      <pre className={styles.detailBody} aria-label="Memory body">
        {body}
      </pre>
    );
  }
  if (snippet.length > 0) {
    return (
      <pre className={styles.detailBody} aria-label="Memory snippet">
        {snippet}
      </pre>
    );
  }
  // Empty body stays empty — do not invent placeholder prose.
  return (
    <p className={styles.detailEmpty} aria-label="Memory body">
      Body is empty.
    </p>
  );
}
