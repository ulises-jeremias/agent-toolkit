import { useState } from 'react';
import { useAgents, useProviders, useTools } from '../../data/catalog';
import { useOperation, useReport, useSubQuery } from '../../data/commands';
import { envelopeText, type ToolEnabled, type ToolInfo } from '../../lib/api';
import { mcpStatusTone, parseMcpProviders, parsePluginBundles, parseSkillCatalog } from '../../lib/reports';
import {
  Button,
  ConfirmAction,
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

/**
 * Library: what can I use or add?
 * Catalog, detected, configured, verified and running stay distinct.
 * Running is not on the tools API, so it is omitted rather than guessed.
 */
export default function Library() {
  const inventory = useReport('inventory');
  const catalogRoot = inventory.data?.data['root'];
  const tools = useTools();
  const agents = useAgents();
  const providers = useProviders();
  const skills = useSubQuery('skills', 'list');
  const plugins = useSubQuery('plugin', 'check', undefined, { failureIsData: true });
  const mcp = useSubQuery('mcp', 'list');
  const [probeMcp, setProbeMcp] = useState(false);
  const mcpHealth = useSubQuery('mcp', 'health', undefined, { enabled: probeMcp, failureIsData: true });
  const install = useOperation('install');
  const installReceipt = useActionReceipt('Profiles installed');

  const drift = plugins.data?.ok ? plugins.data.data['drift'] : undefined;
  const skillRows = skills.data ? parseSkillCatalog(envelopeText(skills.data)) : [];
  const mcpRows = mcp.data ? parseMcpProviders(envelopeText(mcp.data)) : [];
  const pluginRows = plugins.data ? parsePluginBundles(envelopeText(plugins.data)) : [];

  return (
    <>
      <PageHeader
        eyebrow="Library"
        title="What can I use"
        lede={
          catalogRoot
            ? `This catalog is the toolkit tree at ${catalogRoot}. Detected, configured and verified are this machine. Running is unknown here.`
            : 'Catalog is what the toolkit ships. Detected, configured and verified are this machine. Running is unknown here.'
        }
        actions={
          <ConfirmAction
            label="Install profiles"
            triggerVariant="primary"
            variant="primary"
            title="Install tool profiles?"
            description="Runs agent-toolkit install: writes the toolkit's skills, agents and rules into the coding tools it detects on this machine."
            confirmLabel="Install"
            busy={install.isPending}
            onConfirm={() => install.mutate(undefined, installReceipt)}
          />
        }
      />
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
          <Panel title="Personas" meta={agents.data ? `${agents.data.agents.length} in catalog` : undefined}>
            <QueryView query={agents} loading="Loading personas" errorTitle="Could not list personas">
              {(response) =>
                response.agents.length === 0 ? (
                  <EmptyState title="No personas in the catalog.">The agents tree was empty or unavailable.</EmptyState>
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
                            <StatusBadge tone={envelope.ok ? 'ok' : 'warn'} label={envelope.ok ? 'checked' : 'drift'} />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                )
              }
            </QueryView>
          </Panel>
          <Panel
            title="MCP servers"
            meta="Catalog vs configured. Running is unknown until a probe."
            actions={
              <Button
                size="sm"
                onClick={() => (probeMcp ? void mcpHealth.refetch() : setProbeMcp(true))}
                busy={mcpHealth.isFetching}
                busyLabel="Probing…"
              >
                Check health
              </Button>
            }
          >
            <QueryView query={mcp} loading="Listing MCP servers" errorTitle="Could not list MCP servers">
              {(envelope) =>
                mcpRows.length === 0 ? (
                  <EmptyState title="No MCP providers as a table.">
                    {envelope.data['count'] ? `${envelope.data['count']} in catalog; rows unknown.` : envelope.message}
                  </EmptyState>
                ) : (
                  <Table>
                    <thead>
                      <tr>
                        <th scope="col">Provider</th>
                        <th scope="col">Status</th>
                        <th scope="col">Required env</th>
                      </tr>
                    </thead>
                    <tbody>
                      {mcpRows.map((row) => (
                        <tr key={row.provider}>
                          <th scope="row">
                            <Mono>{row.provider}</Mono>
                          </th>
                          <td>
                            <StatusBadge tone={mcpStatusTone(row.status)} label={row.status} />
                          </td>
                          <td>
                            <Mono>{row.env || '—'}</Mono>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                )
              }
            </QueryView>
            {probeMcp ? (
              <QueryView query={mcpHealth} loading="Probing MCP servers" errorTitle="Health check failed">
                {(envelope) => (
                  <p>
                    {envelope.ok
                      ? 'Health probe finished. Running is still unknown unless the probe named a live process.'
                      : envelope.message || 'Health probe failed.'}
                  </p>
                )}
              </QueryView>
            ) : (
              <p>Running is unknown until a health probe reports a live process.</p>
            )}
          </Panel>
        </Grid>

        <Panel
          title="Skills catalog"
          meta={
            skills.data?.data['count']
              ? `${skills.data.data['count']} in catalog · installed-in-tool unknown`
              : 'installed-in-tool unknown'
          }
        >
          <QueryView query={skills} loading="Loading the skills catalog" errorTitle="Could not load the skills catalog">
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
    </>
  );
}
