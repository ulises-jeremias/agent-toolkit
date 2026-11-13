import { useCallback, useState } from 'react';
import { useNavigate } from 'react-router';
import { useBackend } from '../../data/backend';
import { useFocusBridge, useFocusProviders } from '../../data/focus';
import { useLinkProject, useProjects } from '../../data/projects';
import { ApiClient, requireOk } from '../../lib/api';
import { HOME_PATH } from '../../shell/home';
import { withContext } from '../../shell/sessionContext';
import { useSessionContext } from '../../shell/useSessionContext';
import type { HarnessSwitchResult } from '../../types/electron';
import { Button, PixelIcon } from '../../ui';
import { providerBlocker } from '../focus/labels';
import { writeOnboardingComplete } from './complete';
import styles from './onboarding.module.css';
import { backendIsReady, harnessIsChosen, harnessNeedsCreate } from './steps';

type StepState = 'done' | 'current' | 'waiting';

function Step({
  number,
  title,
  state,
  children,
}: {
  number: number;
  title: string;
  state: StepState;
  children: React.ReactNode;
}) {
  return (
    <li className={styles.step} data-state={state} aria-current={state === 'current' ? 'step' : undefined}>
      <span className={styles.stepMark} aria-hidden="true">
        {state === 'done' ? <PixelIcon name="check" size={12} /> : number}
      </span>
      <div className={styles.stepBody}>
        <h2 className={styles.stepTitle}>
          {title}
          {state === 'done' ? <span className={styles.srOnly}> (done)</span> : null}
        </h2>
        {children}
      </div>
    </li>
  );
}

/**
 * First run: a workspace folder, one repository, and a coding agent. Every
 * row shows what is actually true on this machine; nothing is assumed.
 */
export function Onboarding({ onComplete }: { onComplete: () => void }) {
  const navigate = useNavigate();
  const { backend, restartBackend } = useBackend();
  const { setContext, context } = useSessionContext();
  const bridge = useFocusBridge();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const ready = backendIsReady(backend);
  const down = backend?.status === 'failed' || backend?.status === 'crashed';
  const harness = backend?.harness ?? null;
  const hasWorkspace = harnessIsChosen(harness);
  const needsCreate = harnessNeedsCreate(harness);
  const defaultPath = harness?.defaultPath ?? '~/.ai-workspace';
  const workspace = hasWorkspace && harness ? harness.path : '';

  const projects = useProjects(workspace, { enabled: ready && hasWorkspace });
  const link = useLinkProject(workspace);
  const providers = useFocusProviders();
  const linked = (projects.data?.projects ?? []).filter((project) => project.status === 'ok');
  const agents = providers.data ?? [];
  const readyAgent = agents.find((provider) => providerBlocker(provider) === null);

  const applySwitch = useCallback(
    async (operation: () => Promise<HarnessSwitchResult>) => {
      setBusy(true);
      setError(null);
      try {
        const result = await operation();
        if (!result.ok) {
          if (result.error !== 'cancelled') setError(result.message);
          return;
        }
        const latest = await waitForReadyBackend();
        if (harnessIsChosen(latest.harness) && latest.harness) setContext({ workspace: latest.harness.path });
        if (!latest.url) throw new Error('The local service restarted without an address.');
        // Idempotent: adds the workspace scaffold only where files are missing.
        requireOk(await new ApiClient(latest.url).sub('workspace', 'init', {}));
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : String(cause));
      } finally {
        setBusy(false);
      }
    },
    [setContext],
  );

  const finish = () => {
    if (workspace) setContext({ workspace });
    writeOnboardingComplete();
    const next = { ...context, workspace: workspace || context.workspace };
    const project = linked[0]?.name;
    // With a repository and an agent ready, the next thing to do is describe a task.
    const target = project && readyAgent ? `/focus?project=${encodeURIComponent(project)}` : HOME_PATH;
    navigate(withContext(target, next), { replace: true });
    onComplete();
  };

  const workspaceState: StepState = hasWorkspace ? 'done' : 'current';
  const projectState: StepState = !hasWorkspace ? 'waiting' : linked.length > 0 ? 'done' : 'current';
  const agentState: StepState = readyAgent ? 'done' : hasWorkspace && linked.length > 0 ? 'current' : 'waiting';

  return (
    <main className={styles.frame}>
      <div className={styles.sheet}>
        <header className={styles.head}>
          <span className={styles.mark} aria-hidden="true">
            A
          </span>
          <div>
            <h1 className={styles.title}>Set up Agent Toolkit</h1>
            <p className={styles.lede}>
              A local workspace for coding with agents. It needs a folder for its own notes, a repository to work on,
              and a coding agent you are signed in to.
            </p>
          </div>
        </header>

        {!ready ? (
          <div className={styles.service} role="status" data-tone={down ? 'err' : undefined}>
            {down ? (
              <>
                <p>
                  <strong>The local service did not start.</strong> Nothing in your folders was changed.
                </p>
                {backend?.detail ? <p className={styles.detail}>{backend.detail}</p> : null}
                <Button variant="secondary" onClick={() => void restartBackend()}>
                  Restart the local service
                </Button>
              </>
            ) : (
              <p>Starting the local service…</p>
            )}
          </div>
        ) : null}

        <ol className={styles.steps}>
          <Step number={1} title="Workspace folder" state={workspaceState}>
            {hasWorkspace ? (
              <p className={styles.path}>{workspace}</p>
            ) : (
              <>
                <p className={styles.note}>
                  Sessions, notes and project links are kept here. Your repositories stay where they are.
                </p>
                <div className={styles.actions}>
                  {needsCreate ? (
                    <Button
                      variant="primary"
                      disabled={!ready || !window.atk}
                      busy={busy}
                      busyLabel="Creating…"
                      onClick={() => void applySwitch(() => window.atk!.harnessSet(defaultPath, { create: true }))}
                    >
                      Create {defaultPath}
                    </Button>
                  ) : null}
                  <Button
                    variant={needsCreate ? 'ghost' : 'primary'}
                    disabled={!ready || busy || !window.atk}
                    onClick={() => void applySwitch(() => window.atk!.harnessChoose())}
                  >
                    Use an existing folder
                  </Button>
                </div>
              </>
            )}
          </Step>

          <Step number={2} title="A repository to work on" state={projectState}>
            {linked.length > 0 ? (
              <ul className={styles.list}>
                {linked.map((project) => (
                  <li key={project.name}>
                    <strong>{project.name}</strong>
                    <span className={styles.path}>{project.target}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className={styles.note}>Pick the folder of a repository you already have. It is linked, not copied.</p>
            )}
            <div className={styles.actions}>
              <Button
                variant={linked.length > 0 ? 'ghost' : hasWorkspace ? 'primary' : 'secondary'}
                disabled={!hasWorkspace || !ready}
                busy={link.isPending}
                busyLabel="Linking…"
                onClick={() => link.mutate()}
              >
                {linked.length > 0 ? 'Link another repository' : 'Choose a repository folder'}
              </Button>
            </div>
            {link.error ? (
              <p className={styles.error} role="alert">
                {link.error.message}
              </p>
            ) : null}
          </Step>

          <Step number={3} title="A coding agent" state={agentState}>
            {providers.isLoading ? (
              <p className={styles.note}>Checking which agents are installed and signed in…</p>
            ) : null}
            <ul className={styles.list}>
              {agents.map((provider) => {
                const blocker = providerBlocker(provider);
                return (
                  <li key={provider.id} data-ready={blocker === null || undefined}>
                    <strong>{provider.label}</strong>
                    <span>{blocker ?? provider.authDetail}</span>
                  </li>
                );
              })}
            </ul>
            {!providers.isLoading && !readyAgent ? (
              <p className={styles.note}>
                Install Claude Code, run <code>claude auth login</code> in a terminal, then check again. You can also
                continue and do this later.
              </p>
            ) : null}
            <div className={styles.actions}>
              <Button
                variant="ghost"
                busy={providers.isFetching}
                busyLabel="Checking…"
                onClick={() => {
                  void bridge?.providers({ refresh: true }).then(() => providers.refetch());
                }}
              >
                Check again
              </Button>
            </div>
          </Step>
        </ol>

        {error ? (
          <p className={styles.error} role="alert">
            {error}
          </p>
        ) : null}

        <footer className={styles.foot}>
          <Button
            variant="primary"
            disabled={!hasWorkspace || busy || !ready}
            title={hasWorkspace ? undefined : 'Choose a workspace folder first'}
            onClick={finish}
          >
            {linked.length > 0 && readyAgent ? 'Start working' : 'Open Agent Toolkit'}
          </Button>
          {hasWorkspace && (linked.length === 0 || !readyAgent) ? (
            <span className={styles.note}>You can link repositories and sign in to agents later.</span>
          ) : null}
        </footer>
      </div>
    </main>
  );
}

async function waitForReadyBackend() {
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    const latest = window.atk ? await window.atk.backendStatus() : null;
    if (latest?.status === 'ready' && latest.url) return latest;
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error('The local service did not come back after the folder change.');
}
