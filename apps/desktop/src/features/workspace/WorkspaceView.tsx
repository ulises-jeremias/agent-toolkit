import { EnvelopePanel, MutationResult, useSubApiMutation, useSubApiQuery } from '../shared';
import { Panel } from '../../components/ui';
import styles from '../../components/ui.module.css';

/**
 * Workspace — what did the work actually produce/change?
 * Session context, personas, validation, and budget via the workspace proxy.
 * Only subcommands the server actually routes are offered; the server allows
 * GET solely for list/info, so everything else runs as an explicit POST action.
 */
export default function WorkspaceView() {
  const info = useSubApiQuery('workspace', 'info');
  const personas = useSubApiMutation('workspace', 'personas');
  const context = useSubApiMutation('workspace', 'context');
  const validate = useSubApiMutation('workspace', 'validate');
  const budget = useSubApiMutation('workspace', 'budget');

  const actions = [
    { key: 'personas', label: 'List personas', mutation: personas },
    { key: 'context', label: 'Read session context', mutation: context },
    { key: 'validate', label: 'Validate workspace', mutation: validate },
    { key: 'budget', label: 'Analyze context budget', mutation: budget },
  ] as const;

  const anyResult = actions.some(({ mutation }) => mutation.data ?? mutation.error);

  return (
    <>
      <h1>Workspace</h1>
      <EnvelopePanel title="Workspace info" query={info} />
      <Panel
        title="Session actions"
        actions={
          <>
            {actions.map(({ key, label, mutation }) => (
              <button
                key={key}
                type="button"
                className={styles.button}
                disabled={mutation.isPending}
                onClick={() => mutation.mutate({})}
              >
                {mutation.isPending ? 'Running…' : label}
              </button>
            ))}
          </>
        }
      >
        {!anyResult && <p>Run an action to see the backend result here.</p>}
        {actions.map(({ key, mutation }) => (
          <MutationResult
            key={key}
            result={mutation.data}
            error={mutation.error instanceof Error ? mutation.error : undefined}
          />
        ))}
      </Panel>
    </>
  );
}
