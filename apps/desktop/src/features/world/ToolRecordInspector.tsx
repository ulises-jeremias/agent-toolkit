import type { ToolEnabled, ToolInfo } from '../../lib/api';
import { Button, ErrorState, KeyValue, LoadingState, Mono, Panel, Stack, StatusBadge, type Tone } from '../../ui';
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
  /** Opens Library's reviewed install flow for this tool. */
  onReviewInstall?: () => void;
  /** Visible Back control — returns to project interior or world. */
  onBack: () => void;
  backLabel?: string;
  onRetry?: () => void;
}

/**
 * Cozy Pixel World inspector for one coding tool. Renders only fields the tools
 * payload already has: id, detected, configured, enabled, verified, install_hint.
 */
export function ToolRecordInspector({
  toolId,
  tool,
  isPending,
  error,
  onReviewInstall,
  onBack,
  backLabel = 'Back',
  onRetry,
}: ToolRecordInspectorProps) {
  const hint = tool?.install_hint?.trim() ?? '';

  return (
    <Panel
      tone="notice"
      title="Coding tool"
      meta={toolId}
      actions={
        <Button type="button" onClick={onBack} aria-label={backLabel}>
          Back
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
                  label: 'Toolkit capabilities',
                  value: hint ? 'Available for reviewed install' : 'Not offered by Toolkit',
                },
              ]}
            />
            {hint ? (
              onReviewInstall ? (
                <>
                  <p className={styles.detailEmpty}>
                    Review exact destinations and file changes before Toolkit writes user configuration.
                  </p>
                  <Button variant="primary" onClick={onReviewInstall}>
                    Review installation in Library
                  </Button>
                </>
              ) : (
                <p className={styles.detailEmpty}>No reviewed installation flow is available from this inspector.</p>
              )
            ) : null}
          </Stack>
        )}
      </div>
    </Panel>
  );
}
