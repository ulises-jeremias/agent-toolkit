import { useCallback, useState } from 'react';
import { useNavigate } from 'react-router';
import { useBackend } from '../../data/backend';
import { ApiClient, requireOk } from '../../lib/api';
import { HOME_PATH } from '../../shell/home';
import { withContext } from '../../shell/sessionContext';
import { useSessionContext } from '../../shell/useSessionContext';
import type { HarnessSwitchResult } from '../../types/electron';
import {
  Button,
  ButtonRow,
  ConfirmAction,
  ErrorState,
  KeyValue,
  LoadingState,
  Mono,
  PageHeader,
  Panel,
  Stack,
  StatusBadge,
  useActionReceipt,
} from '../../ui';
import { writeOnboardingComplete } from './complete';
import styles from './onboarding.module.css';
import { backendIsReady, harnessIsChosen, harnessNeedsCreate, type OnboardingStep } from './steps';

export function Onboarding({ onComplete }: { onComplete: () => void }) {
  const navigate = useNavigate();
  const { backend, restartBackend } = useBackend();
  const { setContext, context } = useSessionContext();
  const [step, setStep] = useState<OnboardingStep>('ready');
  const ready = backendIsReady(backend);

  const finish = () => {
    const harnessPath = backend?.harness?.path;
    const workspace = harnessPath && harnessIsChosen(backend.harness) ? harnessPath : context.workspace;
    if (workspace) setContext({ workspace });
    writeOnboardingComplete();
    navigate(withContext(HOME_PATH, { ...context, workspace }), { replace: true });
    onComplete();
  };

  return (
    <div className={styles.frame} data-onboarding={step}>
      <header className={styles.masthead}>
        <span className={styles.mark} aria-hidden="true">
          A
        </span>
        <span>
          <span className={styles.brand}>Agent Toolkit</span>
          <span className={styles.brandSub}>Welcome desk</span>
        </span>
      </header>
      <div className={styles.board}>
        <ol className={styles.rail} aria-label="Desk">
          <li className={styles.railItem} data-current={step === 'ready'}>
            The desk
          </li>
          <li className={styles.railItem} data-current={step === 'harness'}>
            The folder
          </li>
        </ol>
        {step === 'ready' ? (
          <ReadyStep
            ready={ready}
            backend={backend}
            restartBackend={restartBackend}
            onContinue={() => setStep('harness')}
          />
        ) : null}
        {step === 'harness' ? (
          <HarnessStep backend={backend} onBack={() => setStep('ready')} onEnterWorld={finish} />
        ) : null}
      </div>
    </div>
  );
}

function ReadyStep({
  ready,
  backend,
  restartBackend,
  onContinue,
}: {
  ready: boolean;
  backend: ReturnType<typeof useBackend>['backend'];
  restartBackend: ReturnType<typeof useBackend>['restartBackend'];
  onContinue: () => void;
}) {
  const [restarting, setRestarting] = useState(false);
  const [restartError, setRestartError] = useState<Error | null>(null);
  const unavailable = backend?.status === 'failed' || backend?.status === 'crashed';

  const retryBackend = async () => {
    setRestarting(true);
    setRestartError(null);
    try {
      await restartBackend();
    } catch (cause) {
      setRestartError(cause instanceof Error ? cause : new Error(String(cause)));
    } finally {
      setRestarting(false);
    }
  };

  return (
    <div className={styles.desk}>
      <div className={styles.blotter}>
        <PageHeader
          eyebrow="Welcome desk"
          title="A world for coding agents"
          lede="Choose where your workspace lives, then explore it as a valley: each project has a house, and shared capabilities have places of their own."
        />
        <Stack>
          <Panel tone="notice" title="Backend" meta={unavailable ? 'Needs restart' : ready ? 'Ready' : 'Starting'}>
            {backend ? (
              <KeyValue
                items={[
                  {
                    label: 'Status',
                    value: <StatusBadge tone={ready ? 'ok' : 'info'} label={backend.status} live={!ready} />,
                  },
                  { label: 'Version', value: backend.version ?? 'Unknown' },
                ]}
              />
            ) : (
              <LoadingState label="Waiting for the supervisor" />
            )}
            {!ready && backend?.status !== 'failed' && backend?.status !== 'crashed' ? (
              <LoadingState label="Waiting for the backend" />
            ) : null}
            {unavailable ? (
              <>
                <ErrorState
                  title={`Backend ${backend.status}`}
                  error={
                    new Error(
                      backend.status === 'crashed'
                        ? 'The local service stopped unexpectedly.'
                        : 'The local service could not start.',
                    )
                  }
                  guidance="Your workspace has not been changed. Restart the local service and try again."
                />
                {backend.detail ? (
                  <details className={styles.diagnostics}>
                    <summary>Technical details</summary>
                    <Mono>{backend.detail}</Mono>
                  </details>
                ) : null}
                {restartError ? <ErrorState title="Restart failed" error={restartError} /> : null}
              </>
            ) : null}
          </Panel>
          <ButtonRow>
            {unavailable && window.atk ? (
              <Button
                variant="secondary"
                disabled={restarting}
                busy={restarting}
                busyLabel="Restarting backend…"
                onClick={() => void retryBackend()}
              >
                Restart backend
              </Button>
            ) : null}
            <Button
              variant="primary"
              disabled={!ready}
              title={ready ? undefined : 'The backend is not ready yet'}
              onClick={onContinue}
            >
              Continue
            </Button>
          </ButtonRow>
        </Stack>
      </div>
      <aside className={styles.pixelWrap}>
        <WelcomeValley />
        <p className={styles.caption}>Projects are houses · shared tools have a home</p>
      </aside>
    </div>
  );
}

function HarnessStep({
  backend,
  onBack,
  onEnterWorld,
}: {
  backend: ReturnType<typeof useBackend>['backend'];
  onBack: () => void;
  onEnterWorld: () => void;
}) {
  const { setContext } = useSessionContext();
  const receipt = useActionReceipt('Harness ready');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const harness = backend?.harness ?? null;
  const chosen = harnessIsChosen(harness);
  const needsCreate = harnessNeedsCreate(harness);
  const defaultPath = harness?.defaultPath ?? '~/.ai-workspace';

  const afterRooted = useCallback(async () => {
    const latest = await waitForReadyBackend();
    const path = latest.harness?.path ?? defaultPath;
    if (harnessIsChosen(latest.harness)) {
      setContext({ workspace: path });
    }
    if (!latest.url) {
      throw new Error('Backend became ready without a URL.');
    }
    try {
      requireOk(await new ApiClient(latest.url).sub('workspace', 'init', {}));
      receipt.onSuccess({ message: `Workspace files in ${path}` });
    } catch (cause) {
      setError(cause instanceof Error ? cause : new Error(String(cause)));
    }
  }, [defaultPath, receipt, setContext]);

  const applySwitch = useCallback(
    async (op: () => Promise<HarnessSwitchResult>) => {
      if (!window.atk) {
        setError(new Error('Choosing a harness needs the Desktop app.'));
        return;
      }
      setBusy(true);
      setError(null);
      try {
        const result = await op();
        if (!result.ok) {
          if (result.error === 'cancelled') return;
          setError(new Error(result.message));
          return;
        }
        await afterRooted();
      } catch (cause) {
        setError(cause instanceof Error ? cause : new Error(String(cause)));
      } finally {
        setBusy(false);
      }
    },
    [afterRooted],
  );

  return (
    <>
      <PageHeader
        eyebrow="The folder"
        title="Where should work live?"
        lede="The default is ~/.ai-workspace. Desktop never creates that folder unless you confirm. After this, you enter the world."
      />
      <Stack>
        <Panel tone="notice" title="Default harness" meta={harness?.source ?? 'unknown'}>
          <KeyValue
            items={[
              { label: 'Default', value: defaultPath, mono: true },
              { label: 'In use', value: harness?.path ?? 'Not resolved yet', mono: Boolean(harness?.path) },
              { label: 'Source', value: harness?.source ?? '—' },
              ...(harness?.notice ? [{ label: 'Notice', value: harness.notice }] : []),
            ]}
          />
          {needsCreate ? (
            <>
              <p>
                No harness folder is present. Desktop creates the folder after confirmation and prepares it as your
                workspace. Existing files are left in place.
              </p>
              <p className={styles.preview}>
                <span className={styles.previewLabel}>Workspace folder</span>
                <Mono>{defaultPath}</Mono>
              </p>
              <ConfirmAction
                label="Create harness"
                triggerVariant="primary"
                variant="primary"
                title="Create the default harness?"
                description={`Creates ${defaultPath} and scaffolds a workspace there. Existing files are left in place.`}
                confirmLabel="Create harness"
                busy={busy}
                onConfirm={() => void applySwitch(() => window.atk!.harnessSet(defaultPath, { create: true }))}
              />
            </>
          ) : (
            <>
              <p>This folder already exists. Entering the world uses it in place; nothing is copied or overwritten.</p>
              {harness?.source === 'user' ? (
                <Button
                  variant="ghost"
                  disabled={busy}
                  busy={busy}
                  busyLabel="Switching harness…"
                  onClick={() => void applySwitch(() => window.atk!.harnessReset())}
                >
                  Use default
                </Button>
              ) : null}
            </>
          )}
        </Panel>
        <Panel title="Use a different existing folder">
          <p>The native picker only accepts a folder that already exists. Desktop will not create a custom path.</p>
          <Button
            disabled={busy}
            busy={busy}
            busyLabel="Switching harness…"
            onClick={() => void applySwitch(() => window.atk!.harnessChoose())}
          >
            Choose folder
          </Button>
        </Panel>
        {error ? <ErrorState title="Harness setup failed" error={error} /> : null}
        <ButtonRow>
          <Button variant="ghost" onClick={onBack}>
            Back
          </Button>
          <Button
            variant="primary"
            disabled={!chosen || busy || !backendIsReady(backend)}
            title={chosen ? undefined : 'Create or choose a harness first'}
            onClick={onEnterWorld}
          >
            Enter the world
          </Button>
        </ButtonRow>
      </Stack>
    </>
  );
}

/** A quiet preview of real world assets; no projects or runtime activity are implied. */
function WelcomeValley() {
  return (
    <div
      className={styles.valleyScene}
      role="img"
      aria-label="A small preview of the pixel valley with a workspace hall, library, creek, bridge and trees"
    >
      <div className={styles.creek} />
      <img className={`${styles.sceneSprite} ${styles.sceneTreeWest}`} src="/world/tree-rune.png" alt="" />
      <img className={`${styles.sceneSprite} ${styles.sceneBlossom}`} src="/world/tree-blossom.png" alt="" />
      <img className={`${styles.sceneSprite} ${styles.sceneWorkspace}`} src="/world/landmark-workspace.png" alt="" />
      <img className={`${styles.sceneSprite} ${styles.sceneLibrary}`} src="/world/landmark-library.png" alt="" />
      <img className={`${styles.sceneSprite} ${styles.sceneBridge}`} src="/world/bridge.png" alt="" />
      <img className={`${styles.sceneSprite} ${styles.sceneTreeEast}`} src="/world/tree-round.png" alt="" />
      <img className={`${styles.sceneSprite} ${styles.sceneLantern}`} src="/world/lamp.png" alt="" />
      <span className={`${styles.sceneLabel} ${styles.sceneProjectLabel}`}>Workspace</span>
      <span className={`${styles.sceneLabel} ${styles.sceneLibraryLabel}`}>Library</span>
      <span className={styles.sceneLegend}>A semantic workspace, ready to explore</span>
    </div>
  );
}

async function waitForReadyBackend() {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    const latest = window.atk ? await window.atk.backendStatus() : null;
    if (latest?.status === 'ready' && latest.url) return latest;
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error('Backend did not become ready after the harness change.');
}
