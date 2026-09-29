import { ConfirmButton, EnvelopePanel, MutationResult, useExecuteMutation, useSubApiQuery } from '../shared';
import { Panel } from '../../components/ui';

/**
 * Library — what capabilities can I discover/install/configure?
 * Skills, plugins, and MCP servers from the backend catalog; installs run the
 * real backend operations behind an explicit two-step confirm.
 */
export default function Library() {
  const skillsList = useSubApiQuery('skills', 'list');
  const plugins = useSubApiQuery('plugin', 'list');
  const mcp = useSubApiQuery('mcp', 'health');
  const install = useExecuteMutation('/api/v1/install');

  return (
    <>
      <h1>Library</h1>
      <EnvelopePanel title="Skills catalog" query={skillsList} />
      <EnvelopePanel title="Plugins" query={plugins} />
      <EnvelopePanel title="MCP servers" query={mcp} />
      <Panel
        title="Installs"
        actions={
          <ConfirmButton
            label="Install profiles"
            confirmLabel="Confirm install"
            disabled={install.isPending}
            onConfirm={() => install.mutate()}
          />
        }
      >
        <p>Runs the backend install for detected tools. Update and uninstall live in Settings.</p>
        <MutationResult result={install.data} error={install.error instanceof Error ? install.error : undefined} />
      </Panel>
    </>
  );
}
