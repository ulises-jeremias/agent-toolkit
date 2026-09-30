import { useSubQuery } from '../../data/commands';
import { CommandReport, Grid, KeyValue, PageHeader, Panel, QueryView, Stack, StatusBadge, type Tone } from '../../ui';

function riskTone(risk: string | undefined): Tone {
  switch (risk?.toUpperCase()) {
    case 'LOW':
      return 'ok';
    case 'MEDIUM':
      return 'warn';
    case 'HIGH':
      return 'err';
    default:
      return 'idle';
  }
}

/**
 * Workspace: what is this workspace and what does it contain?
 * Reads the real `workspace` and `project` subcommands. Their output is CLI
 * text until Phase 2 gives them typed responses; structured fields the
 * server already returns (budget, violation counts) are shown as data.
 */
export default function WorkspaceView() {
  const context = useSubQuery('workspace', 'context');
  const projects = useSubQuery('project', 'list');
  const budget = useSubQuery('workspace', 'budget');
  const validation = useSubQuery('workspace', 'validate', undefined, { failureIsData: true });
  const personas = useSubQuery('workspace', 'personas');
  const profiles = useSubQuery('workspace', 'profiles');

  const path = budget.data?.data['workspace'];

  return (
    <>
      <PageHeader
        eyebrow="Workspace"
        title={path ? (path.split('/').filter(Boolean).pop() ?? path) : 'Workspace'}
        lede={path}
      />
      <Stack>
        <Grid>
          <Panel title="Context budget" meta="How much this workspace adds to every agent's context">
            <QueryView query={budget} loading="Measuring context" errorTitle="Could not measure the context budget">
              {(envelope) => (
                <KeyValue
                  items={[
                    {
                      label: 'Risk',
                      value: (
                        <StatusBadge
                          tone={riskTone(envelope.data['risk'])}
                          label={envelope.data['risk'] ?? 'Unknown'}
                        />
                      ),
                    },
                    {
                      label: 'Estimated tokens',
                      value: envelope.data['estimated_tokens']
                        ? Number(envelope.data['estimated_tokens']).toLocaleString()
                        : '—',
                    },
                    {
                      label: 'Characters',
                      value: envelope.data['total_chars'] ? Number(envelope.data['total_chars']).toLocaleString() : '—',
                    },
                    { label: 'Target', value: envelope.data['target'] ?? '—' },
                  ]}
                />
              )}
            </QueryView>
          </Panel>
          <Panel
            title="Validation"
            meta="Packs, loops, personas, profiles, knowledge and jobs"
            actions={
              validation.data ? (
                <StatusBadge
                  tone={validation.data.ok ? 'ok' : 'err'}
                  label={
                    validation.data.ok
                      ? 'Valid'
                      : `${validation.data.data['errors'] ?? 'Some'} ${validation.data.data['errors'] === '1' ? 'violation' : 'violations'}`
                  }
                />
              ) : null
            }
          >
            <QueryView query={validation} loading="Validating workspace" errorTitle="Could not validate the workspace">
              {(envelope) => (
                <CommandReport envelope={{ ...envelope, ok: true }} label="Validation output" hideFields={['errors']} />
              )}
            </QueryView>
          </Panel>
        </Grid>
        <Panel tone="manila" title="Session context" meta="What an agent sees when it starts here">
          <QueryView query={context} loading="Reading session context" errorTitle="Could not read the session context">
            {(envelope) => <CommandReport envelope={envelope} label="Session context" />}
          </QueryView>
        </Panel>
        <Panel title="Projects">
          <QueryView query={projects} loading="Listing projects" errorTitle="Could not list projects">
            {(envelope) => <CommandReport envelope={envelope} label="Projects" />}
          </QueryView>
        </Panel>
        <Grid>
          <Panel
            title="Personas"
            meta={personas.data?.data['count'] ? `${personas.data.data['count']} available` : undefined}
          >
            <QueryView query={personas} loading="Listing personas" errorTitle="Could not list personas">
              {(envelope) => <CommandReport envelope={envelope} label="Personas" hideFields={['count']} />}
            </QueryView>
          </Panel>
          <Panel
            title="Profiles"
            meta={profiles.data?.data['count'] ? `${profiles.data.data['count']} available` : undefined}
          >
            <QueryView query={profiles} loading="Listing profiles" errorTitle="Could not list profiles">
              {(envelope) => <CommandReport envelope={envelope} label="Profiles" hideFields={['count']} />}
            </QueryView>
          </Panel>
        </Grid>
      </Stack>
    </>
  );
}
