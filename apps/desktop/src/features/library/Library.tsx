import { useState } from 'react';
import { useOperation, useReport, useSubQuery } from '../../data/commands';
import {
  Button,
  CommandReport,
  ConfirmAction,
  Grid,
  KeyValue,
  PageHeader,
  Panel,
  QueryView,
  Stack,
  StatusBadge,
  useActionReceipt,
} from '../../ui';

/**
 * Library: what capabilities are installed and healthy?
 * Inventory counts, the skills catalog, plugin drift and MCP servers from
 * the backend; installing runs the real backend operation after a confirm.
 */
export default function Library() {
  const inventory = useReport('inventory');
  const skills = useSubQuery('skills', 'list');
  const plugins = useSubQuery('plugin', 'check', undefined, { failureIsData: true });
  const mcp = useSubQuery('mcp', 'list');
  const [probeMcp, setProbeMcp] = useState(false);
  const mcpHealth = useSubQuery('mcp', 'health', undefined, { enabled: probeMcp, failureIsData: true });
  const install = useOperation('install');
  const installReceipt = useActionReceipt('Profiles installed');

  // A failed check still reports drift=0; only a successful check can say "in sync".
  const drift = plugins.data?.ok ? plugins.data.data['drift'] : undefined;

  return (
    <>
      <PageHeader
        eyebrow="Library"
        title="Capabilities"
        lede="Skills, agents, plugins and MCP servers this toolkit distributes."
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
        <Panel title="Inventory">
          <QueryView query={inventory} loading="Counting capabilities" errorTitle="Could not read the inventory">
            {(envelope) => (
              <KeyValue
                items={[
                  { label: 'Skills', value: envelope.data['skill_count'] ?? '—' },
                  { label: 'Domains', value: envelope.data['domain_count'] ?? '—' },
                  { label: 'Agents', value: envelope.data['agent_count'] ?? '—' },
                  { label: 'Products', value: envelope.data['product_count'] ?? '—' },
                  { label: 'Toolkit root', value: envelope.data['root'] ?? '—', mono: true },
                ]}
              />
            )}
          </QueryView>
        </Panel>
        <Grid>
          <Panel
            title="Plugins"
            meta="Generated plugin bundles compared with their sources"
            actions={
              drift !== undefined ? (
                <StatusBadge
                  tone={drift === '0' ? 'ok' : 'warn'}
                  label={drift === '0' ? 'In sync' : `${drift} drifted`}
                />
              ) : null
            }
          >
            <QueryView query={plugins} loading="Checking plugins" errorTitle="Could not check plugins">
              {(envelope) => <CommandReport envelope={envelope} label="Plugin check" hideFields={['drift', 'mode']} />}
            </QueryView>
          </Panel>
          <Panel
            title="MCP servers"
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
              {(envelope) => <CommandReport envelope={envelope} label="MCP servers" />}
            </QueryView>
            {probeMcp ? (
              <QueryView query={mcpHealth} loading="Probing MCP servers" errorTitle="Health check failed">
                {(envelope) => <CommandReport envelope={envelope} label="MCP health" />}
              </QueryView>
            ) : null}
          </Panel>
        </Grid>
        <Panel
          title="Skills catalog"
          meta={inventory.data?.data['skill_count'] ? `${inventory.data.data['skill_count']} skills` : undefined}
        >
          <QueryView query={skills} loading="Loading the skills catalog" errorTitle="Could not load the skills catalog">
            {(envelope) => <CommandReport envelope={envelope} label="Skills catalog" />}
          </QueryView>
        </Panel>
      </Stack>
    </>
  );
}
