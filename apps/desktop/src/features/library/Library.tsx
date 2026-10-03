import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useAgents, useProviders, useTools } from '../../data/catalog';
import { useOperation, useReport, useSubQuery } from '../../data/commands';
import { requireClient, useBackend } from '../../data/backend';
import { envelopeText, errorMessage, type CommandEnvelope, type ToolEnabled, type ToolInfo } from '../../lib/api';
import { parsePluginBundles, parseSkillCatalog } from '../../lib/reports';
import {
  Button,
  ButtonRow,
  Dialog,
  EmptyState,
  Grid,
  Mono,
  PageHeader,
  Panel,
  QueryView,
  Stack,
  StatusBadge,
  Table,
  useActionReceipt,
  type Tone,
} from '../../ui';
import styles from './library.module.css';
import { McpProvidersPanel } from './McpProvidersPanel';

function yesNo(value: boolean): { tone: Tone; label: string } {
  return value ? { tone: 'ok', label: 'yes' } : { tone: 'idle', label: 'no' };
}

function enabledBadge(value: ToolEnabled): { tone: Tone; label: string } {
  if (value === 'true') return { tone: 'ok', label: 'true' };
  if (value === 'false') return { tone: 'idle', label: 'false' };
  return { tone: 'idle', label: 'unknown' };
}

function toolSummary(tools: readonly ToolInfo[]): string {
  const detected = tools.filter((tool) => tool.detected).length;
  const configured = tools.filter((tool) => tool.configured).length;
  const verified = tools.filter((tool) => tool.verified).length;
  return `${tools.length} catalog · ${detected} detected · ${configured} configured · ${verified} verified`;
}

function installSummary(preview: CommandEnvelope): string {
  const targets = Number(preview.data['tools_ok'] ?? 0);
  const files = Number(preview.data['files_written'] ?? 0);
  return `${targets} ${targets === 1 ? 'tool target' : 'tool targets'} reviewed · ${files} ${files === 1 ? 'file' : 'files'} to write or merge`;
}

/**
 * Library: the capability room the world opens for shared/project knowledge.
 * Catalog vs this machine. Memory is a different place and is omitted when
 * GET /api/v1/memory is gone — this inspector does not invent a memory UI.
 * Running and marketplace install counts stay unknown unless the API reports them.
 */
export default function Library() {
  const { client } = useBackend();
  const inventory = useReport('inventory');
  const catalogRoot = inventory.data?.data['root'];
  const tools = useTools();
  const agents = useAgents();
  const providers = useProviders();
  const skills = useSubQuery('skills', 'list');
  const plugins = useSubQuery('plugin', 'check', undefined, { failureIsData: true });
  const install = useOperation('install');
  const uninstall = useOperation('uninstall');
  const [installPreview, setInstallPreview] = useState<CommandEnvelope | null>(null);
  const [uninstallPreview, setUninstallPreview] = useState<CommandEnvelope | null>(null);
  const previewInstall = useMutation({
    mutationFn: () => requireClient(client).installPreview(),
    onSuccess: setInstallPreview,
  });
  const previewUninstall = useMutation({
    mutationFn: () => requireClient(client).uninstallPreview(),
    onSuccess: setUninstallPreview,
  });
  const installReceipt = useActionReceipt('Toolkit capabilities installed');
  const uninstallReceipt = useActionReceipt('Toolkit files removed');

  const drift = plugins.data?.ok ? plugins.data.data['drift'] : undefined;
  const skillRows = skills.data ? parseSkillCatalog(envelopeText(skills.data)) : [];
  const pluginRows = plugins.data ? parsePluginBundles(envelopeText(plugins.data)) : [];

  return (
    <div className={styles.room}>
      <p className={styles.mark}>Cozy Pixel World · library board</p>
      <PageHeader
        surface="panel"
        eyebrow="Library"
        title="Library board"
        lede={
          catalogRoot
            ? `Shelves from ${catalogRoot}. Catalog, detected, configured and verified stay distinct. Memory is not this room. Running is unknown here.`
            : 'Inspector for catalog knowledge the world opens here. Memory is not this room. Running is unknown here.'
        }
        actions={
          <ButtonRow>
            <Button
              variant="secondary"
              busy={previewUninstall.isPending}
              busyLabel="Checking receipts…"
              onClick={() => {
                setUninstallPreview(null);
                previewUninstall.mutate();
              }}
            >
              Review removal
            </Button>
            <Button
              variant="primary"
              busy={previewInstall.isPending}
              busyLabel="Inspecting targets…"
              onClick={() => {
                setInstallPreview(null);
                previewInstall.mutate();
              }}
            >
              Review installation
            </Button>
          </ButtonRow>
        }
      />
      <Dialog
        open={installPreview !== null || previewInstall.isError}
        onClose={() => {
          setInstallPreview(null);
          previewInstall.reset();
        }}
        title="Review capability installation"
        description="This preview does not write files. Toolkit profiles, Agent Definitions, and complete Skills (including references) stay inside your user configuration; no elevated permissions or system files are involved. Existing user-owned files are preserved, and JSON settings merge without replacing existing keys."
        size="wide"
        footer={
          <ButtonRow>
            <Button
              onClick={() => {
                setInstallPreview(null);
                previewInstall.reset();
              }}
            >
              Cancel
            </Button>
            <Button
              variant="primary"
              disabled={!installPreview?.ok || install.isPending}
              busy={install.isPending}
              busyLabel="Installing…"
              onClick={() =>
                install.mutate(undefined, {
                  ...installReceipt,
                  onSuccess: (result) => {
                    installReceipt.onSuccess?.(result);
                    setInstallPreview(null);
                  },
                })
              }
            >
              Install reviewed files
            </Button>
          </ButtonRow>
        }
      >
        {previewInstall.isError ? <p role="alert">{errorMessage(previewInstall.error)}</p> : null}
        {installPreview ? (
          <>
            <p role="status">
              {installPreview.ok
                ? installSummary(installPreview)
                : 'The installer could not prepare a safe installation. Review the details below.'}
            </p>
            <pre className={styles.installPreview} aria-label="Installation preview">
              {installPreview.message}
            </pre>
          </>
        ) : null}
      </Dialog>
      <Dialog
        open={uninstallPreview !== null || previewUninstall.isError}
        onClose={() => {
          setUninstallPreview(null);
          previewUninstall.reset();
        }}
        title="Review Toolkit file removal"
        description="This removes unchanged files owned by Agent Toolkit, as recorded in installation receipts. Files you edited after installation and merged settings are preserved. Review every path before confirming."
        size="wide"
        footer={
          <ButtonRow>
            <Button
              onClick={() => {
                setUninstallPreview(null);
                previewUninstall.reset();
              }}
            >
              Keep files
            </Button>
            <Button
              variant="danger"
              disabled={!uninstallPreview?.ok || uninstall.isPending}
              busy={uninstall.isPending}
              busyLabel="Removing files…"
              onClick={() =>
                uninstall.mutate(undefined, {
                  ...uninstallReceipt,
                  onSuccess: (result) => {
                    uninstallReceipt.onSuccess?.(result);
                    setUninstallPreview(null);
                  },
                })
              }
            >
              Remove reviewed files
            </Button>
          </ButtonRow>
        }
      >
        {previewUninstall.isError ? <p role="alert">{errorMessage(previewUninstall.error)}</p> : null}
        {uninstallPreview ? (
          <>
            <p role="status">
              {uninstallPreview.ok
                ? 'No files have been removed. This is the receipt-based removal plan.'
                : 'No safe removal plan is available. Review the details below; nothing has been removed.'}
            </p>
            <pre className={styles.installPreview} aria-label="Removal preview">
              {uninstallPreview.message}
            </pre>
          </>
        ) : null}
      </Dialog>
      <div className={styles.shelves}>
        <Stack>
          <Panel title="Coding tools" meta={tools.data ? toolSummary(tools.data.tools) : undefined}>
            <QueryView query={tools} loading="Discovering coding tools" errorTitle="Could not list coding tools">
              {(response) =>
                response.tools.length === 0 ? (
                  <EmptyState title="No coding tools in the catalog." />
                ) : (
                  <Table>
                    <thead>
                      <tr>
                        <th scope="col">Tool</th>
                        <th scope="col">Detected</th>
                        <th scope="col">Configured</th>
                        <th scope="col">Enabled</th>
                        <th scope="col">Verified</th>
                        <th scope="col">Path</th>
                      </tr>
                    </thead>
                    <tbody>
                      {response.tools.map((tool) => {
                        const detected = yesNo(tool.detected);
                        const configured = yesNo(tool.configured);
                        const enabled = enabledBadge(tool.enabled);
                        const verified = yesNo(tool.verified);
                        return (
                          <tr key={tool.id}>
                            <th scope="row">
                              {tool.tool_name || tool.id}
                              {tool.reason ? <div>{tool.reason}</div> : null}
                            </th>
                            <td>
                              <StatusBadge tone={detected.tone} label={detected.label} />
                            </td>
                            <td>
                              <StatusBadge tone={configured.tone} label={configured.label} />
                            </td>
                            <td>
                              <StatusBadge tone={enabled.tone} label={enabled.label} />
                            </td>
                            <td>
                              <StatusBadge tone={verified.tone} label={verified.label} />
                            </td>
                            <td>
                              <Mono>{tool.resolved_path || tool.version || '—'}</Mono>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </Table>
                )
              }
            </QueryView>
          </Panel>

          <Grid>
            <Panel title="Agent definitions" meta={agents.data ? `${agents.data.agents.length} in catalog` : undefined}>
              <p className={styles.definitionsNote}>
                Reusable persona templates from the toolkit catalog. These are not configured People (workspace
                collaborators) and not running sessions.
              </p>
              <QueryView
                query={agents}
                loading="Loading agent definitions"
                errorTitle="Could not list agent definitions"
              >
                {(response) =>
                  response.agents.length === 0 ? (
                    <EmptyState title="No agent definitions in the catalog.">
                      The agents tree was empty or unavailable.
                    </EmptyState>
                  ) : (
                    <Table>
                      <thead>
                        <tr>
                          <th scope="col">Id</th>
                          <th scope="col">Kind</th>
                          <th scope="col">Description</th>
                        </tr>
                      </thead>
                      <tbody>
                        {response.agents.map((agent) => (
                          <tr key={agent.id}>
                            <th scope="row">
                              <Mono>{agent.id}</Mono>
                            </th>
                            <td>{agent.kind || 'Unknown'}</td>
                            <td>{agent.description || agent.name}</td>
                          </tr>
                        ))}
                      </tbody>
                    </Table>
                  )
                }
              </QueryView>
            </Panel>
            <Panel
              title="Swarm runners"
              meta={providers.data ? `${providers.data.providers.length} in catalog` : undefined}
            >
              <QueryView query={providers} loading="Listing swarm runners" errorTitle="Could not list swarm runners">
                {(response) =>
                  response.providers.length === 0 ? (
                    <EmptyState title="No swarm runners in the catalog." />
                  ) : (
                    <Table>
                      <thead>
                        <tr>
                          <th scope="col">Runner</th>
                          <th scope="col">Available</th>
                          <th scope="col">Version</th>
                        </tr>
                      </thead>
                      <tbody>
                        {response.providers.map((provider) => {
                          const available = yesNo(provider.available);
                          return (
                            <tr key={provider.id}>
                              <th scope="row">
                                <Mono>{provider.id}</Mono>
                              </th>
                              <td>
                                <StatusBadge tone={available.tone} label={available.label} />
                              </td>
                              <td>
                                <Mono>{provider.version || 'Unknown'}</Mono>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </Table>
                  )
                }
              </QueryView>
            </Panel>
          </Grid>

          <Grid>
            <Panel
              title="Plugins"
              meta="Generated plugin bundles compared with their sources"
              actions={
                drift !== undefined ? (
                  <StatusBadge
                    tone={drift === '0' ? 'ok' : 'warn'}
                    label={drift === '0' ? 'in sync' : `${drift} drifted`}
                  />
                ) : null
              }
            >
              <QueryView query={plugins} loading="Checking plugins" errorTitle="Could not check plugins">
                {(envelope) =>
                  pluginRows.length === 0 ? (
                    <EmptyState title="Plugin check returned no bundle names.">
                      {envelope.ok
                        ? 'Drift is unknown until the check lists bundles.'
                        : envelope.message || 'The check failed.'}
                    </EmptyState>
                  ) : (
                    <Table>
                      <thead>
                        <tr>
                          <th scope="col">Bundle</th>
                          <th scope="col">Check</th>
                        </tr>
                      </thead>
                      <tbody>
                        {pluginRows.map((row) => (
                          <tr key={row.name}>
                            <th scope="row">
                              <Mono>{row.name}</Mono>
                            </th>
                            <td>
                              <StatusBadge
                                tone={envelope.ok ? 'ok' : 'warn'}
                                label={envelope.ok ? 'checked' : 'drift'}
                              />
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </Table>
                  )
                }
              </QueryView>
            </Panel>
            <McpProvidersPanel />
          </Grid>

          <Panel
            title="Skills catalog"
            meta={
              skills.data?.data['count']
                ? `${skills.data.data['count']} in catalog · installed-in-tool unknown`
                : 'installed-in-tool unknown'
            }
          >
            <QueryView
              query={skills}
              loading="Loading the skills catalog"
              errorTitle="Could not load the skills catalog"
            >
              {() =>
                skillRows.length === 0 ? (
                  <EmptyState title="Skills catalog is not a table yet.">
                    Count is {skills.data?.data['count'] ?? 'unknown'}. Installed-in-tool stays unknown.
                  </EmptyState>
                ) : (
                  <Table>
                    <thead>
                      <tr>
                        <th scope="col">Skill</th>
                        <th scope="col">Domain</th>
                        <th scope="col">In catalog</th>
                        <th scope="col">Description</th>
                      </tr>
                    </thead>
                    <tbody>
                      {skillRows.map((row) => {
                        const catalog = yesNo(row.inCatalog);
                        return (
                          <tr key={`${row.domain}/${row.name}`}>
                            <th scope="row">
                              <Mono>{row.name}</Mono>
                            </th>
                            <td>{row.domain}</td>
                            <td>
                              <StatusBadge tone={catalog.tone} label={catalog.label} />
                            </td>
                            <td>{row.description || '—'}</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </Table>
                )
              }
            </QueryView>
          </Panel>
        </Stack>
      </div>
    </div>
  );
}
