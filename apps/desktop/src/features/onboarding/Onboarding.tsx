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
  const { backend } = useBackend();
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
        {step === 'ready' ? <ReadyStep ready={ready} backend={backend} onContinue={() => setStep('harness')} /> : null}
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
  onContinue,
}: {
  ready: boolean;
  backend: ReturnType<typeof useBackend>['backend'];
  onContinue: () => void;
}) {
  return (
    <div className={styles.desk}>
      <div className={styles.blotter}>
        <PageHeader
          eyebrow="Welcome desk"
          title="A world for coding agents"
          lede="Sit at the desk. The backend is real. Next you choose a folder, then you enter the world: each project is a house, shared knowledge and tools live as places — never fake scenery."
        />
        <Stack>
          <Panel tone="manila" title="Backend" meta={ready ? 'Ready' : 'Starting'}>
            {backend ? (
              <KeyValue
                items={[
                  {
                    label: 'Status',
                    value: <StatusBadge tone={ready ? 'ok' : 'info'} label={backend.status} live={!ready} />,
                  },
                  { label: 'Version', value: backend.version ?? 'Unknown' },
                  ...(backend.detail ? [{ label: 'Detail', value: backend.detail }] : []),
                ]}
              />
            ) : (
              <LoadingState label="Waiting for the supervisor" />
            )}
            {!ready && backend?.status !== 'failed' && backend?.status !== 'crashed' ? (
              <LoadingState label="Waiting for the backend" />
            ) : null}
            {backend?.status === 'failed' || backend?.status === 'crashed' ? (
              <ErrorState title={`Backend ${backend.status}`} error={new Error(backend.detail ?? backend.status)} />
            ) : null}
          </Panel>
          <ButtonRow>
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
        <PixelDesk />
        <p className={styles.caption}>Desk · lamp · folder</p>
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
        <Panel tone="manila" title="Default harness" meta={harness?.source ?? 'unknown'}>
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
                No harness folder is present. Creating it writes an empty directory, restarts the backend there, then
                runs <Mono>agent-toolkit workspace init</Mono>.
              </p>
              <p className={styles.preview}>
                <span className={styles.previewLabel}>Command</span>
                <Mono>agent-toolkit workspace init --dir {defaultPath}</Mono>
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

/** Original 32×32 pixel tools: desk, sage plant, brass lamp, manila folder. No characters. */
function PixelDesk() {
  return (
    <svg className={styles.pixelDesk} viewBox="0 0 32 32" width="160" height="160" aria-hidden="true">
      <rect width="32" height="32" fill="var(--surface-sunken)" />
      <rect x="4" y="3" width="24" height="14" fill="var(--surface-panel)" />
      <rect x="6" y="5" width="3" height="5" fill="var(--status-ok-fg)" />
      <rect x="5" y="10" width="5" height="2" fill="var(--status-ok-bg)" />
      <rect x="6" y="12" width="3" height="2" fill="var(--border-strong)" />
      <rect x="22" y="4" width="2" height="6" fill="var(--accent-brass-strong)" />
      <rect x="21" y="3" width="4" height="2" fill="var(--accent-brass-fill)" />
      <rect x="20" y="10" width="6" height="2" fill="var(--accent-brass)" />
      <rect x="10" y="11" width="10" height="6" fill="var(--surface-manila)" />
      <rect x="10" y="10" width="4" height="2" fill="var(--status-warn-fg)" />
      <rect x="12" y="13" width="6" height="1" fill="var(--border-default)" />
      <rect x="2" y="18" width="28" height="10" fill="var(--surface-manila-strong)" />
      <rect x="4" y="19" width="24" height="6" fill="var(--surface-manila)" />
      <rect x="23" y="20" width="4" height="1" fill="var(--accent-brass-fill)" />
      <rect x="23" y="21" width="1" height="4" fill="var(--accent-brass-strong)" />
      <rect x="0" y="28" width="32" height="4" fill="var(--border-strong)" />
    </svg>
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
