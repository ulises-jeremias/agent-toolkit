import { useCallback, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useSubMutation } from '../../data/commands';
import { useMcpProviders } from '../../data/catalog';
import { envelopeText, errorMessage, type McpProviderInfo } from '../../lib/api';
import {
  Button,
  ButtonRow,
  Dialog,
  EmptyState,
  Mono,
  Panel,
  QueryView,
  StatusBadge,
  Table,
  useActionReceipt,
} from '../../ui';
import styles from './mcpProviders.module.css';
import type { McpSecretStatus } from '../../types/electron';

type ReviewAction = 'configure' | 'validate' | 'probe' | 'remove';
interface ReviewState {
  action: ReviewAction;
  provider: McpProviderInfo;
}

function actionTitle(action: ReviewAction, provider: McpProviderInfo): string {
  const name = provider.display_name || provider.id;
  switch (action) {
    case 'configure':
      return `Configure ${name}`;
    case 'validate':
      return `Validate ${name}`;
    case 'probe':
      return `Probe ${name}`;
    case 'remove':
      return `Remove ${name}`;
  }
}

function actionDescription(action: ReviewAction, configPath: string) {
  switch (action) {
    case 'configure':
      return (
        <>
          Record this provider as enabled in Agent Toolkit&apos;s MCP registry at <Mono>{configPath}</Mono>. Setup does
          not store secret values, install packages, change coding-tool configuration, or start the provider.
        </>
      );
    case 'validate':
      return 'Check required environment variable names, the pinned template, and local runtime prerequisites. This does not change configuration or reveal secret values.';
    case 'probe':
      return 'Run the provider health check. It checks the local executable and may invoke its built-in --help response with a five-second timeout. It does not start an MCP session or change configuration.';
    case 'remove':
      return (
        <>
          Remove this provider from Agent Toolkit&apos;s configuration at <Mono>{configPath}</Mono>. This does not
          delete environment variables or edit other tools&apos; configuration files.
        </>
      );
  }
}

export function McpProvidersPanel() {
  const providers = useMcpProviders();
  const [searchParams, setSearchParams] = useSearchParams();
  const handledRequest = useRef('');
  const requestedAction = searchParams.get('mcp_action');
  const requestedProvider = searchParams.get('mcp_provider');
  const [review, setReview] = useState<ReviewState | null>(null);
  const [resultText, setResultText] = useState('');
  const [routeError, setRouteError] = useState('');
  const [secretStatus, setSecretStatus] = useState<McpSecretStatus | null>(null);
  const [secretValues, setSecretValues] = useState<Record<string, string>>({});
  const [secretMessage, setSecretMessage] = useState('');
  const [secretBusy, setSecretBusy] = useState(false);
  const [restartBusy, setRestartBusy] = useState(false);
  const [pendingRestart, setPendingRestart] = useState(false);
  const [restartReview, setRestartReview] = useState(false);
  const setup = useSubMutation('mcp', 'setup');
  const doctor = useSubMutation('mcp', 'doctor');
  const health = useSubMutation('mcp', 'health');
  const uninstall = useSubMutation('mcp', 'uninstall');
  const configureReceipt = useActionReceipt('MCP provider configured');
  const removeReceipt = useActionReceipt('MCP provider removed');
  const resetSetup = setup.reset;
  const resetDoctor = doctor.reset;
  const resetHealth = health.reset;
  const resetUninstall = uninstall.reset;
  const pending = setup.isPending || doctor.isPending || health.isPending || uninstall.isPending;
  const configPath = providers.data?.config_path || '~/.config/agent-toolkit/mcp-config.json';

  const refreshSecretStatus = useCallback(async () => {
    if (!window.atk) {
      setSecretStatus({
        available: false,
        storage: 'Desktop only',
        names: [],
        error: 'Private credential storage is available only in the installed Desktop app.',
      });
      return;
    }
    try {
      setSecretStatus(await window.atk.mcpSecretStatus());
    } catch {
      setSecretStatus({
        available: false,
        storage: 'Unavailable',
        names: [],
        error: 'Credential storage could not be read.',
      });
    }
  }, []);

  useEffect(() => {
    void refreshSecretStatus();
  }, [refreshSecretStatus]);

  async function saveSecret(name: string) {
    const value = secretValues[name] ?? '';
    if (!window.atk) {
      setSecretMessage('Secure credential storage is available only in the Desktop app.');
      return;
    }
    setSecretBusy(true);
    setSecretMessage('');
    try {
      const result = await window.atk.mcpSecretSet(name, value);
      if (!result.ok) {
        setSecretMessage(result.message);
        return;
      }
      setSecretValues((current) => ({ ...current, [name]: '' }));
      setPendingRestart(true);
      setSecretMessage(
        `${name} was encrypted in ${secretStatus?.storage ?? 'the system credential store'}. Restart the backend to apply it.`,
      );
      await refreshSecretStatus();
    } catch {
      setSecretMessage('Could not save this credential. The value was not added to Toolkit configuration.');
    } finally {
      setSecretBusy(false);
    }
  }

  async function removeSecret(name: string) {
    if (!window.atk) return;
    setSecretBusy(true);
    setSecretMessage('');
    try {
      const result = await window.atk.mcpSecretRemove(name);
      if (result.ok) setPendingRestart(true);
      setSecretMessage(result.ok ? `${name} was removed. Restart the backend to apply the change.` : result.message);
      await refreshSecretStatus();
    } catch {
      setSecretMessage('Could not update the encrypted credential store.');
    } finally {
      setSecretBusy(false);
    }
  }

  async function restartBackend() {
    if (!window.atk) return;
    setRestartBusy(true);
    setSecretMessage('');
    try {
      const ready = await window.atk.backendRestart();
      if (ready) {
        setPendingRestart(false);
        await providers.refetch();
      }
      setSecretMessage(
        ready
          ? 'Backend restarted. MCP provider validation now uses the saved credentials.'
          : 'The backend did not become ready. Check Operations → Diagnostics, then retry the restart.',
      );
    } catch {
      setSecretMessage(
        'Backend restart failed. Your encrypted credential remains saved; inspect Diagnostics before retrying.',
      );
    } finally {
      setRestartBusy(false);
    }
  }

  function runReviewedAction() {
    if (!review) return;
    setResultText('');
    const body = { provider: review.provider.id, offline: review.action !== 'validate' };
    if (review.action === 'configure') {
      setup.mutate(body, {
        ...configureReceipt,
        onSuccess: (result) => {
          configureReceipt.onSuccess?.(result);
          setResultText(envelopeText(result));
        },
        onError: (error) => {
          configureReceipt.onError?.(error);
          setResultText(errorMessage(error));
        },
      });
    } else if (review.action === 'validate') {
      doctor.mutate(body, {
        onSuccess: (result) => setResultText(envelopeText(result)),
        onError: (error) => setResultText(errorMessage(error)),
      });
    } else if (review.action === 'probe') {
      health.mutate(body, {
        onSuccess: (result) => setResultText(envelopeText(result)),
        onError: (error) => setResultText(errorMessage(error)),
      });
    } else {
      uninstall.mutate(body, {
        ...removeReceipt,
        onSuccess: (result) => {
          removeReceipt.onSuccess?.(result);
          setResultText(envelopeText(result));
        },
        onError: (error) => {
          removeReceipt.onError?.(error);
          setResultText(errorMessage(error));
        },
      });
    }
  }

  const openReview = useCallback(
    (action: ReviewAction, provider: McpProviderInfo) => {
      resetSetup();
      resetDoctor();
      resetHealth();
      resetUninstall();
      setResultText('');
      setRouteError('');
      setReview({ action, provider });
    },
    [resetDoctor, resetHealth, resetSetup, resetUninstall],
  );

  function closeReview() {
    if (pending) return;
    setReview(null);
    setResultText('');
    setup.reset();
    doctor.reset();
    health.reset();
    uninstall.reset();
  }

  useEffect(() => {
    if (!requestedAction || !requestedProvider) {
      handledRequest.current = '';
      return;
    }
    if (requestedAction !== 'configure' || providers.isFetching) return;
    const request = `${requestedAction}:${requestedProvider}`;
    if (handledRequest.current === request) return;
    handledRequest.current = request;
    const clearRequest = () =>
      setSearchParams(
        (current) => {
          const next = new URLSearchParams(current);
          next.delete('mcp_action');
          next.delete('mcp_provider');
          return next;
        },
        { replace: true },
      );
    if (providers.isError || !providers.data?.ok) {
      clearRequest();
      setRouteError(
        'The MCP catalog could not be refreshed, so no provider review was opened. Retry discovery from the Library.',
      );
      return;
    }
    const provider = providers.data.providers.find((candidate) => candidate.id === requestedProvider);
    clearRequest();
    if (provider) {
      openReview('configure', provider);
    } else {
      setRouteError(
        `The requested MCP provider “${requestedProvider}” is no longer in the current catalog. Refresh the Library and try again.`,
      );
    }
  }, [
    openReview,
    providers.data,
    providers.isError,
    providers.isFetching,
    requestedAction,
    requestedProvider,
    setSearchParams,
  ]);

  const actionLabel =
    review?.action === 'configure'
      ? 'Save provider'
      : review?.action === 'remove'
        ? 'Remove provider'
        : review?.action === 'probe'
          ? 'Run probe'
          : 'Validate';

  return (
    <>
      <Panel title="MCP providers" meta="Reusable connections · secrets stay outside Toolkit configuration">
        <QueryView query={providers} loading="Discovering MCP providers" errorTitle="Could not list MCP providers">
          {(response) =>
            !response.ok ? (
              <EmptyState title="Could not discover MCP providers">
                {response.message || 'Check the local Agent Toolkit installation, then refresh the Library.'}
              </EmptyState>
            ) : response.providers.length === 0 ? (
              <EmptyState title="No MCP provider templates are available.">
                Provider templates are part of the Agent Toolkit installation. Refresh the Library after repairing the
                installation.
              </EmptyState>
            ) : (
              <Table>
                <thead>
                  <tr>
                    <th scope="col">Provider</th>
                    <th scope="col">Configuration</th>
                    <th scope="col">Required environment</th>
                    <th scope="col">Template</th>
                    <th scope="col">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {response.providers.map((provider) => (
                    <tr key={provider.id}>
                      <th scope="row">
                        {provider.display_name || provider.id}
                        <div className={styles.package}>
                          <Mono>{provider.package || provider.id}</Mono>
                        </div>
                      </th>
                      <td>
                        <StatusBadge
                          tone={provider.enabled ? 'ok' : provider.configured ? 'warn' : 'idle'}
                          label={provider.enabled ? 'enabled' : provider.configured ? 'disabled' : 'not configured'}
                        />
                      </td>
                      <td>
                        {provider.required_env.length === 0 ? (
                          <span>No secrets required</span>
                        ) : (
                          <div className={styles.envNames}>
                            {provider.required_env.map((name) => (
                              <span key={name}>
                                <Mono>{name}</Mono>
                                <StatusBadge
                                  tone={provider.missing_env.includes(name) ? 'warn' : 'ok'}
                                  label={provider.missing_env.includes(name) ? 'not in app environment' : 'available'}
                                />
                              </span>
                            ))}
                          </div>
                        )}
                      </td>
                      <td>
                        {!provider.template_available ? (
                          <StatusBadge tone="err" label="template missing" />
                        ) : !provider.template_is_pinned ? (
                          <StatusBadge tone="idle" label="unpinned" />
                        ) : provider.template_matches_pin ? (
                          <StatusBadge tone="ok" label="verified" />
                        ) : (
                          <StatusBadge tone="warn" label="template differs" />
                        )}
                        {provider.template_sha ? (
                          <div className={styles.package}>SHA {provider.template_sha}</div>
                        ) : null}
                      </td>
                      <td>
                        <div className={styles.actions}>
                          <Button size="sm" onClick={() => openReview('configure', provider)}>
                            {provider.enabled ? 'Review setup' : 'Configure'}
                          </Button>
                          <Button size="sm" onClick={() => openReview('validate', provider)}>
                            Validate
                          </Button>
                          <Button size="sm" onClick={() => openReview('probe', provider)}>
                            Probe
                          </Button>
                          {provider.configured ? (
                            <Button size="sm" variant="danger" onClick={() => openReview('remove', provider)}>
                              Remove
                            </Button>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            )
          }
        </QueryView>
        {routeError ? <p role="status">{routeError}</p> : null}
        <p className={styles.guidance}>
          Secret values are never returned by the backend. Configured means enabled in Agent Toolkit&apos;s registry,
          not connected to a coding tool or active session.
        </p>
        <section className={styles.credentials} aria-label="MCP credentials">
          <div className={styles.credentialsHeading}>
            <div>
              <h3>Private credentials</h3>
              <p>
                Values are encrypted with {secretStatus?.storage ?? 'the operating-system credential store'} and exposed
                only to the supervised Agent Toolkit backend after restart. They are never written to MCP configuration.
              </p>
            </div>
            {secretStatus?.available && pendingRestart ? (
              <Button size="sm" busy={restartBusy} busyLabel="Restarting…" onClick={() => setRestartReview(true)}>
                Restart backend to apply
              </Button>
            ) : null}
          </div>
          {!secretStatus ? <p role="status">Checking secure credential storage…</p> : null}
          {secretStatus && !secretStatus.available ? <p role="alert">{secretStatus.error}</p> : null}
          {Array.from(
            (providers.data?.ok ? providers.data.providers : [])
              .reduce((variables, provider) => {
                for (const name of provider.required_env) {
                  const providerNames = variables.get(name) ?? [];
                  providerNames.push(provider.display_name || provider.id);
                  variables.set(name, providerNames);
                }
                return variables;
              }, new Map<string, string[]>())
              .entries(),
          ).map(([name, providerNames]) => {
            const saved = secretStatus?.names.includes(name) ?? false;
            return (
              <div className={styles.credentialRow} key={name}>
                <label htmlFor={`mcp-secret-${name}`}>
                  <Mono>{name}</Mono>
                  <span className={styles.package}>Used by {providerNames.join(', ')}</span>
                </label>
                {saved ? (
                  <StatusBadge tone="ok" label="saved securely" />
                ) : (
                  <StatusBadge tone="idle" label="not saved" />
                )}
                <input
                  id={`mcp-secret-${name}`}
                  type="password"
                  autoComplete="new-password"
                  value={secretValues[name] ?? ''}
                  onChange={(event) => setSecretValues((current) => ({ ...current, [name]: event.target.value }))}
                  placeholder={saved ? 'Enter a new value to replace' : 'Enter credential'}
                  disabled={!secretStatus?.available || secretBusy}
                  aria-label={`Credential value for ${name}`}
                />
                <Button
                  size="sm"
                  disabled={!secretStatus?.available || secretBusy || !(secretValues[name] ?? '')}
                  onClick={() => void saveSecret(name)}
                >
                  Save securely
                </Button>
                {saved ? (
                  <Button size="sm" variant="danger" disabled={secretBusy} onClick={() => void removeSecret(name)}>
                    Remove
                  </Button>
                ) : null}
              </div>
            );
          })}
          {secretMessage ? <p role="status">{secretMessage}</p> : null}
        </section>
      </Panel>

      <Dialog
        open={review !== null}
        onClose={closeReview}
        title={review ? actionTitle(review.action, review.provider) : 'MCP provider'}
        description={review ? actionDescription(review.action, configPath) : undefined}
        size="wide"
        footer={
          <ButtonRow>
            <Button disabled={pending} onClick={closeReview}>
              Close
            </Button>
            <Button
              variant={review?.action === 'remove' ? 'danger' : 'primary'}
              disabled={
                review?.action === 'configure' &&
                (!review.provider.template_available ||
                  (review.provider.template_is_pinned && !review.provider.template_matches_pin))
              }
              busy={pending}
              onClick={runReviewedAction}
            >
              {pending ? 'Working…' : actionLabel}
            </Button>
          </ButtonRow>
        }
      >
        {review?.action === 'configure' ? (
          <section className={styles.review} aria-label="Configuration preview">
            <h3>Configuration preview</h3>
            <p>
              <strong>Will write:</strong> enable {review.provider.display_name || review.provider.id} in Agent
              Toolkit&apos;s MCP registry.
            </p>
            <p>
              <strong>Target:</strong> <Mono>{configPath}</Mono>
            </p>
            <p>
              <strong>Secret handling:</strong> only environment variable names are recorded; values are never read into
              this form or saved.
            </p>
            {review.provider.required_env.length > 0 ? (
              <div>
                <strong>Required environment</strong>
                <div className={styles.envNames}>
                  {review.provider.required_env.map((name) => (
                    <span key={name}>
                      <Mono>{name}</Mono>
                      <StatusBadge
                        tone={review.provider.missing_env.includes(name) ? 'warn' : 'ok'}
                        label={review.provider.missing_env.includes(name) ? 'not in app environment' : 'available'}
                      />
                    </span>
                  ))}
                </div>
              </div>
            ) : (
              <p>This provider does not declare required environment variables.</p>
            )}
            {review.provider.template_is_pinned && !review.provider.template_matches_pin ? (
              <p role="alert">
                The bundled template differs from its pinned digest. Do not configure this provider until the Toolkit
                installation is repaired.
              </p>
            ) : null}
            {!review.provider.template_available ? (
              <p role="alert">
                The provider template is missing. Repair the Toolkit installation before configuring it.
              </p>
            ) : null}
          </section>
        ) : null}
        {review?.action === 'remove' ? (
          <section className={styles.review} aria-label="Removal preview">
            <h3>Removal preview</h3>
            <p>
              Only the <Mono>{review.provider.id}</Mono> entry in this Toolkit configuration will be removed.
            </p>
            <p>Environment variables, installed programs, and configuration owned by other tools are untouched.</p>
          </section>
        ) : null}
        {review && review.action !== 'remove' && review.action !== 'configure' ? (
          <section className={styles.review} aria-label="Check preview">
            <h3>{review.action === 'probe' ? 'Probe scope' : 'Validation scope'}</h3>
            <p>
              {review.action === 'probe'
                ? 'This is a local executable health check only. It does not start the MCP server or connect it to a model.'
                : 'This reads local provider requirements and checks whether required environment variables are present.'}
            </p>
          </section>
        ) : null}
        {resultText ? (
          <pre className={styles.result} role="status">
            {resultText}
          </pre>
        ) : null}
        {setup.isError || doctor.isError || health.isError || uninstall.isError ? (
          <p role="alert">{errorMessage(setup.error || doctor.error || health.error || uninstall.error)}</p>
        ) : null}
      </Dialog>

      <Dialog
        open={restartReview}
        onClose={() => (restartBusy ? undefined : setRestartReview(false))}
        title="Restart the Desktop backend?"
        description="Saved MCP credentials are read only when the supervised backend starts."
        footer={
          <ButtonRow>
            <Button disabled={restartBusy} onClick={() => setRestartReview(false)}>
              Cancel
            </Button>
            <Button
              busy={restartBusy}
              onClick={() => {
                setRestartReview(false);
                void restartBackend();
              }}
            >
              Restart backend
            </Button>
          </ButtonRow>
        }
      >
        <section className={styles.review} aria-label="Backend restart impact">
          <h3>What will happen</h3>
          <p>The local API process will stop and start with the encrypted credentials available to it.</p>
          <p>
            Requests in progress may fail while it restarts. Desktop terminal sessions remain separate and are not
            stopped.
          </p>
          <p>No credentials are shown or written into MCP configuration.</p>
        </section>
      </Dialog>
    </>
  );
}
