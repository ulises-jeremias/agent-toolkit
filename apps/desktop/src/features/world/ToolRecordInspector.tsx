import type { ToolEnabled, ToolInfo } from '../../lib/api';
import { Button, ConfirmAction, ErrorState, KeyValue, LoadingState, Mono, Panel, Stack, StatusBadge, type Tone } from '../../ui';
import styles from './world.module.css';

function yesNo(value: boolean): { tone: Tone; label: string } {
  return value ? { tone: 'ok', label: 'yes' } : { tone: 'idle', label: 'no' };
}

function enabledBadge(value: ToolEnabled): { tone: Tone; label: string } {
  if (value === 'true') return { tone: 'ok', label: 'true' };
  if (value === 'false') return { tone: 'idle', label: 'false' };
  return { tone: 'idle', label: 'unknown' };
}

export interface ToolRecordInspectorProps {
  toolId: string;
  /** Row from GET /api/v1/tools — only catalog fields are shown. */
  tool?: ToolInfo | null;
  isPending?: boolean;
  error?: Error | null;
  /** Real POST /api/v1/install when install_hint is non-empty. Omit → hint is text only. */
  onInstall?: () => void;
  installBusy?: boolean;
  onClose: () => void;
  onRetry?: () => void;
}

/**
 * Paper Co. inspector for one coding tool. Renders only fields the tools
 * payload already has: id, detected, configured, enabled, verified, install_hint.
 */
export function ToolRecordInspector({
  toolId,
  tool,
  isPending,
  error,
  onInstall,
  installBusy,
  onClose,
  onRetry,
}: ToolRecordInspectorProps) {
  const hint = tool?.install_hint?.trim() ?? '';

  return (
    <Panel
      tone="manila"
      title="Coding tool"
      meta={toolId}
      actions={
        <Button type="button" onClick={onClose}>
          Close
        </Button>
      }
    >
      <div className={styles.detailInspector} role="region" aria-label={`Coding tool ${toolId}`}>
        {isPending ? (
          <LoadingState label="Reading tools catalog" />
        ) : error ? (
          <ErrorState title="Could not load tools catalog" error={error} onRetry={onRetry} />
        ) : !tool ? (
          <ErrorState
            title="Tool not in catalog"
            error={new Error(`GET /api/v1/tools has no row for ${toolId}`)}
            onRetry={onRetry}
          />
        ) : (
          <Stack>
            <KeyValue
              items={[
                { label: 'Id', value: <Mono>{tool.id}</Mono> },
                {
                  label: 'Detected',
                  value: <StatusBadge tone={yesNo(tool.detected).tone} label={yesNo(tool.detected).label} />,
                },
                {
                  label: 'Configured',
                  value: <StatusBadge tone={yesNo(tool.configured).tone} label={yesNo(tool.configured).label} />,
                },
                {
                  label: 'Enabled',
                  value: (
                    <StatusBadge tone={enabledBadge(tool.enabled).tone} label={enabledBadge(tool.enabled).label} />
                  ),
                },
                {
                  label: 'Verified',
                  value: <StatusBadge tone={yesNo(tool.verified).tone} label={yesNo(tool.verified).label} />,
                },
                {
                  label: 'Install hint',
                  value: hint ? <Mono>{hint}</Mono> : '—',
                },
              ]}
            />
            {hint ? (
              onInstall ? (
                <ConfirmAction
                  label="Install profiles"
                  triggerVariant="primary"
                  variant="primary"
                  title="Install tool profiles?"
                  description={`Runs the real install API (POST /api/v1/install). Hint from catalog: ${hint}`}
                  confirmLabel="Install"
                  busy={installBusy}
                  onConfirm={() => onInstall()}
                />
              ) : (
                <p className={styles.detailEmpty}>Install hint is text only — no install API wired.</p>
              )
            ) : null}
          </Stack>
        )}
      </div>
    </Panel>
  );
}
