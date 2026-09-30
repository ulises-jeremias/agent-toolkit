import { useState } from 'react';
import { useOperation } from '../../data/commands';
import { useBackend, useHealth, useHelp, useSelfcheck } from '../../data/backend';
import {
  setMotionPreference,
  setThemePreference,
  useAppearance,
  type MotionPreference,
  type ThemePreference,
} from '../../design/theme';
import {
  Button,
  ButtonRow,
  ConfirmAction,
  Grid,
  KeyValue,
  Mono,
  PageHeader,
  Panel,
  QueryView,
  Report,
  Stack,
  StatusBadge,
  Table,
  selfcheckTone,
  useActionReceipt,
  type Tone,
} from '../../ui';
import styles from './settings.module.css';

const THEMES: ReadonlyArray<{ value: ThemePreference; label: string; hint: string }> = [
  { value: 'system', label: 'System', hint: 'Follow the operating system' },
  { value: 'paper', label: 'Paper', hint: 'Warm light' },
  { value: 'ink', label: 'Ink', hint: 'Deliberate dark' },
];

const MOTION: ReadonlyArray<{ value: MotionPreference; label: string; hint: string }> = [
  { value: 'system', label: 'System', hint: 'Follow the operating system' },
  { value: 'reduced', label: 'Reduced', hint: 'No transitions or pulsing' },
];

function backendTone(status: string | undefined): Tone {
  switch (status) {
    case 'ready':
      return 'ok';
    case 'starting':
      return 'info';
    case 'version-mismatch':
      return 'warn';
    case undefined:
      return 'idle';
    default:
      return 'err';
  }
}

function Choice<T extends string>({
  legend,
  name,
  options,
  value,
  onChange,
}: {
  legend: string;
  name: string;
  options: ReadonlyArray<{ value: T; label: string; hint: string }>;
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <fieldset className={styles.choice}>
      <legend className={styles.legend}>{legend}</legend>
      {options.map((option) => (
        <label key={option.value} className={styles.option}>
          <input
            type="radio"
            name={name}
            value={option.value}
            checked={value === option.value}
            onChange={() => onChange(option.value)}
          />
          <span className={styles.optionLabel}>{option.label}</span>
          <span className={styles.optionHint}>{option.hint}</span>
        </label>
      ))}
    </fieldset>
  );
}

/** Settings: how is this Desktop configured? */
export default function Settings() {
  const appearance = useAppearance();
  const { backend, backendUrl, restartBackend } = useBackend();
  const health = useHealth();
  const selfcheck = useSelfcheck();
  const update = useOperation('update');
  const uninstall = useOperation('uninstall');
  const updateReceipt = useActionReceipt('Profiles updated');
  const uninstallReceipt = useActionReceipt('Profiles uninstalled');
  const [showHelp, setShowHelp] = useState(false);
  const help = useHelp({ enabled: showHelp });

  return (
    <>
      <PageHeader eyebrow="Settings" title="Desktop settings" />
      <Stack>
        <Panel title="Appearance">
          <div className={styles.choices}>
            <Choice
              legend="Theme"
              name="theme"
              options={THEMES}
              value={appearance.theme}
              onChange={setThemePreference}
            />
            <Choice
              legend="Motion"
              name="motion"
              options={MOTION}
              value={appearance.motion}
              onChange={setMotionPreference}
            />
          </div>
        </Panel>

        <Grid>
          <Panel
            title="Backend"
            meta="The agent-toolkit serve process this window talks to"
            actions={
              window.atk ? (
                <Button size="sm" onClick={() => void restartBackend()}>
                  Restart backend
                </Button>
              ) : null
            }
          >
            <KeyValue
              items={[
                {
                  label: 'Status',
                  value: backend ? (
                    <StatusBadge tone={backendTone(backend.status)} label={backend.status} />
                  ) : (
                    'Not supervised (browser dev)'
                  ),
                },
                { label: 'URL', value: backendUrl ?? 'Not connected', mono: backendUrl !== null },
                { label: 'Version', value: health.data?.version ?? backend?.version ?? 'Unknown' },
                ...(health.data?.commit ? [{ label: 'Commit', value: health.data.commit, mono: true }] : []),
                ...(backend
                  ? [
                      {
                        label: 'Harness',
                        value: backend.harness
                          ? `${backend.harness.path} (${backend.harness.source}${backend.harness.overrideVar ? ` via ${backend.harness.overrideVar}` : ''})`
                          : 'Not resolved yet',
                        mono: backend.harness !== null,
                      },
                    ]
                  : []),
                ...(backend?.harness?.notice
                  ? [
                      {
                        label: 'Harness notice',
                        value: backend.harness.notice,
                      },
                    ]
                  : []),
                ...(backend ? [{ label: 'Restarts', value: String(backend.restarts) }] : []),
                ...(backend?.detail ? [{ label: 'Detail', value: backend.detail }] : []),
              ]}
            />
          </Panel>
          <Panel title="Self-check">
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
        </Grid>

        <Panel title="Tool profiles" meta="Skills, agents and rules the toolkit manages inside each coding tool">
          <p>Update rewrites the managed files from the current toolkit version. Uninstall removes them.</p>
          <ButtonRow>
            <Button
              busy={update.isPending}
              busyLabel="Updating…"
              onClick={() => update.mutate(undefined, updateReceipt)}
            >
              Update profiles
            </Button>
          </ButtonRow>
          <div className={styles.danger}>
            <p className={styles.dangerTitle}>Remove</p>
            <ConfirmAction
              label="Uninstall profiles"
              triggerVariant="danger"
              variant="danger"
              title="Uninstall tool profiles?"
              description="Runs agent-toolkit uninstall: removes the toolkit-managed skills, agents and rules from every coding tool. Install them again from Library."
              confirmLabel="Uninstall"
              busy={uninstall.isPending}
              onConfirm={() => uninstall.mutate(undefined, uninstallReceipt)}
            />
          </div>
        </Panel>

        <Panel
          title="Command reference"
          meta="agent-toolkit help from this backend"
          actions={
            <Button size="sm" variant="ghost" onClick={() => setShowHelp((shown) => !shown)} aria-expanded={showHelp}>
              {showHelp ? 'Hide' : 'Show'}
            </Button>
          }
        >
          {showHelp ? (
            <QueryView query={help} loading="Loading help" errorTitle="Could not load help">
              {(text) => <Report text={text} label="Command reference" />}
            </QueryView>
          ) : null}
        </Panel>
      </Stack>
    </>
  );
}
