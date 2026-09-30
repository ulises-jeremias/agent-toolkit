import { useCallback, useState } from 'react';
import { useBackend, useSelfcheck } from '../../data/backend';
import { useReport } from '../../data/commands';
import { useCreateJob, useJob, useJobLiveLines, useJobLog } from '../../data/jobs';
import { useLiveStatus } from '../../data/live';
import { useTerminalSessions } from '../../data/terminal';
import { ApiClient, isTerminalJobStatus, requireOk } from '../../lib/api';
import { jobCommandLine } from '../../lib/format';
import { useSessionContext } from '../../shell/useSessionContext';
import type { HarnessSwitchResult } from '../../types/electron';
import {
  Button,
  ButtonRow,
  CommandReport,
  ConfirmAction,
  EmptyState,
  ErrorState,
  KeyValue,
  LoadingState,
  Mono,
  PageHeader,
  Panel,
  QueryView,
  Report,
  Stack,
  StatusBadge,
  Table,
  jobTone,
  selfcheckTone,
  useActionReceipt,
} from '../../ui';
import { writeOnboardingComplete } from './complete';
import styles from './onboarding.module.css';
import {
  agentProviderModelApiAvailable,
  backendIsReady,
  codingAgentDiscoveryAvailable,
  harnessIsChosen,
  harnessNeedsCreate,
  ONBOARDING_STEPS,
  STEP_LABELS,
  type OnboardingStep,
} from './steps';

export function Onboarding({ onComplete }: { onComplete: () => void }) {
  const { backend } = useBackend();
  const { setContext } = useSessionContext();
  const [step, setStep] = useState<OnboardingStep>('ready');
  const ready = backendIsReady(backend);

  const go = (next: OnboardingStep) => setStep(next);
  const finish = () => {
    const harnessPath = backend?.harness?.path;
    if (harnessPath && harnessIsChosen(backend.harness)) {
      setContext({ workspace: harnessPath });
    }
    writeOnboardingComplete();
    onComplete();
  };

  return (
    <div className={styles.frame} data-onboarding={step}>
      <header className={styles.chrome}>
        <span className={styles.mark} aria-hidden="true">
          A
        </span>
        <span>
          <span className={styles.brand}>Agent Toolkit</span>
          <span className={styles.brandSub}>First run</span>
        </span>
      </header>
      <div className={styles.page}>
        <ol className={styles.steps} aria-label="Setup steps">
          {ONBOARDING_STEPS.map((id, index) => {
            const current = id === step;
            const done = ONBOARDING_STEPS.indexOf(step) > index;
            return (
              <li key={id} className={styles.step} data-current={current} data-done={done}>
                <span className={styles.index}>{String(index + 1).padStart(2, '0')}</span>
                {STEP_LABELS[id]}
              </li>
            );
          })}
        </ol>
        {step === 'ready' ? <ReadyStep ready={ready} backend={backend} onContinue={() => go('harness')} /> : null}
        {step === 'harness' ? (
          <HarnessStep backend={backend} onBack={() => go('ready')} onContinue={() => go('tools')} />
        ) : null}
        {step === 'tools' ? <ToolsStep onBack={() => go('harness')} onContinue={() => go('agent')} /> : null}
        {step === 'agent' ? <AgentStep onBack={() => go('tools')} onContinue={() => go('work')} /> : null}
        {step === 'work' ? <WorkStep onBack={() => go('agent')} onFinish={finish} /> : null}
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
    <>
      <PageHeader
        eyebrow="Welcome"
        title="A workstation for coding agents"
        lede="This window talks to a local agent-toolkit backend. You will choose a harness, see what this machine can prove about coding tools, and start one real command."
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
    </>
  );
}

function HarnessStep({
  backend,
  onBack,
  onContinue,
}: {
  backend: ReturnType<typeof useBackend>['backend'];
  onBack: () => void;
  onContinue: () => void;
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
      // Fresh client: the React one still points at the previous port until render.
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
        eyebrow="Harness"
        title="Where should work live?"
        lede="The default is ~/.ai-workspace. Desktop never creates that folder unless you confirm."
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
              <p>This folder already exists. Continue uses it in place; nothing is copied or overwritten.</p>
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
            onClick={onContinue}
          >
            Continue
          </Button>
        </ButtonRow>
      </Stack>
    </>
  );
}

function ToolsStep({ onBack, onContinue }: { onBack: () => void; onContinue: () => void }) {
  const selfcheck = useSelfcheck();
  const [showDoctor, setShowDoctor] = useState(false);
  const doctor = useReport('doctor', { enabled: showDoctor });
  const discovery = codingAgentDiscoveryAvailable();

  return (
    <>
      <PageHeader
        eyebrow="Coding tools"
        title="What is on this machine?"
        lede="Per-CLI install state is only shown when the backend exposes it as typed data."
      />
      <Stack>
        <Panel tone="manila" title="Coding-agent CLIs">
          {discovery ? (
            <p>Discovery is available.</p>
          ) : (
            <EmptyState title="CLI detection is not available as a typed list.">
              Serve has no detected / configured / enabled / verified route yet. Guessing from doctor text would invent
              state. Open Doctor for the raw report, or continue.
            </EmptyState>
          )}
          <ButtonRow>
            <Button onClick={() => setShowDoctor(true)}>Open Doctor report</Button>
          </ButtonRow>
        </Panel>
        {showDoctor ? (
          <Panel title="Doctor" meta="Raw backend report">
            <QueryView query={doctor} loading="Running doctor" errorTitle="Doctor could not run">
              {(envelope) => <CommandReport envelope={envelope} label="Doctor report" failureLabel="Checks failing" />}
            </QueryView>
          </Panel>
        ) : null}
        <Panel title="Self-check" meta="Toolkit process health, not per-CLI install state">
          <QueryView query={selfcheck} loading="Running self-check" errorTitle="Self-check could not run">
            {(data) => (
              <Table>
                <thead>
                  <tr>
                    <th scope="col">Check</th>
                    <th scope="col">Result</th>
                    <th scope="col">Detail</th>
                  </tr>
                </thead>
                <tbody>
                  {data.checks.map((check) => (
                    <tr key={check.name}>
                      <th scope="row">
                        <Mono>{check.name}</Mono>
                      </th>
                      <td>
                        <StatusBadge tone={selfcheckTone(check.status)} label={check.status} />
                      </td>
                      <td>{check.detail}</td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            )}
          </QueryView>
        </Panel>
        <ButtonRow>
          <Button variant="ghost" onClick={onBack}>
            Back
          </Button>
          <Button variant="primary" onClick={onContinue}>
            Continue
          </Button>
        </ButtonRow>
      </Stack>
    </>
  );
}

function AgentStep({ onBack, onContinue }: { onBack: () => void; onContinue: () => void }) {
  const available = agentProviderModelApiAvailable();
  return (
    <>
      <PageHeader
        eyebrow="Agent"
        title="First agent"
        lede="Provider and model are configured only when serve exposes typed APIs for them."
      />
      <Stack>
        <Panel tone="manila" title="Provider and model">
          {available ? (
            <p>Typed agent setup is available.</p>
          ) : (
            <EmptyState title="No typed agent, provider or model API.">
              A picker here would be fiction. Start a real job or a terminal on the next step instead.
            </EmptyState>
          )}
        </Panel>
        <ButtonRow>
          <Button variant="ghost" onClick={onBack}>
            Back
          </Button>
          <Button variant="primary" onClick={onContinue}>
            Continue
          </Button>
        </ButtonRow>
      </Stack>
    </>
  );
}

function WorkStep({ onBack, onFinish }: { onBack: () => void; onFinish: () => void }) {
  const { context } = useSessionContext();
  const create = useCreateJob();
  const receipt = useActionReceipt('Job started');
  const terminals = useTerminalSessions();
  const [jobId, setJobId] = useState<string | null>(null);
  const [terminalError, setTerminalError] = useState<Error | null>(null);
  const job = useJob(jobId);
  const preview = 'agent-toolkit version';

  const startJob = () => {
    create.mutate(
      { cmd: 'version', workspace: context.workspace || undefined },
      {
        onSuccess: (started) => {
          receipt.onSuccess({ message: jobCommandLine(started) });
          setJobId(started.id);
        },
      },
    );
  };

  const openTerminal = async () => {
    setTerminalError(null);
    const session = await terminals.create({
      agent: 'first-run',
      cmd: '/bin/sh',
      cwd: context.workspace || undefined,
    });
    if (!session) setTerminalError(new Error('The terminal host did not create a session.'));
  };

  return (
    <>
      <PageHeader
        eyebrow="First work"
        title="Run something real"
        lede="A version job streams from the backend. A terminal opens a PTY that stays in the dock after you finish."
      />
      <Stack>
        <Panel tone="manila" title="Start a job" meta="Typed jobs API">
          <p className={styles.preview}>
            <span className={styles.previewLabel}>Command</span>
            <Mono>{preview}</Mono>
          </p>
          <Button
            variant="primary"
            busy={create.isPending}
            busyLabel="Starting job…"
            onClick={startJob}
            disabled={create.isPending}
          >
            Start version job
          </Button>
          {create.error ? <ErrorState title="The job did not start" error={create.error} /> : null}
          {jobId ? <FirstJobOutput jobId={jobId} /> : null}
        </Panel>
        <Panel title="Or open a terminal" meta={terminals.available ? 'PTY on this machine' : 'Unavailable'}>
          {terminals.available ? (
            <>
              <p>
                Opens <Mono>/bin/sh</Mono> in the dock. It stays after first-run ends.
              </p>
              <Button onClick={() => void openTerminal()} disabled={terminals.creating}>
                Open terminal
              </Button>
              {terminals.sessions.some((session) => session.agent === 'first-run') ? (
                <StatusBadge tone="ok" label="Session opened" />
              ) : null}
              {terminalError ? <ErrorState title="Could not open a terminal" error={terminalError} /> : null}
            </>
          ) : (
            <EmptyState title="Interactive terminals need the Desktop app." />
          )}
        </Panel>
        <ButtonRow>
          <Button variant="ghost" onClick={onBack}>
            Back
          </Button>
          <Button variant="primary" onClick={onFinish} disabled={!job && terminals.sessions.length === 0}>
            Finish and open Office
          </Button>
        </ButtonRow>
      </Stack>
    </>
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

function FirstJobOutput({ jobId }: { jobId: string }) {
  const job = useJob(jobId);
  const lines = useJobLiveLines(jobId);
  const log = useJobLog(jobId);
  const { streams } = useLiveStatus();
  if (!job) return <LoadingState label="Loading job" />;
  const done = isTerminalJobStatus(job.status);
  const streamed = lines.join('\n').trim();
  const persisted = (log.data ?? '').trim();
  // Fast jobs sometimes persist only a "[running]" placeholder; prefer the
  // SSE lines we already showed if they hold more of the real output.
  const text = streamed.length > persisted.length ? streamed : persisted || streamed;
  return (
    <section aria-label="Live output">
      <KeyValue
        items={[
          { label: 'Status', value: <StatusBadge tone={jobTone(job.status)} label={job.status} live={!done} /> },
          { label: 'Command', value: jobCommandLine(job), mono: true },
        ]}
      />
      {done ? (
        log.isPending ? (
          <LoadingState label="Loading log" />
        ) : log.isError ? (
          <ErrorState title="Could not load the log" error={log.error} />
        ) : (
          <Report text={text || 'The job wrote no output.'} label="Job log" />
        )
      ) : lines.length === 0 ? (
        <EmptyState title="No output yet.">
          {streams.state === 'reconnecting'
            ? 'Reconnecting; the log replays on reconnect.'
            : 'Lines appear as the job writes them.'}
        </EmptyState>
      ) : (
        <Report text={text ?? ''} label="Live output" />
      )}
    </section>
  );
}
