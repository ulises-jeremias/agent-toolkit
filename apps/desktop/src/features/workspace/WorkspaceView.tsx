import { useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useSubMutation, useSubQuery } from '../../data/commands';
import { envelopeText, errorMessage, recoveryHint } from '../../lib/api';
import {
  Button,
  ButtonRow,
  CommandReport,
  Dialog,
  Grid,
  KeyValue,
  PageHeader,
  Panel,
  QueryView,
  Stack,
  StatusBadge,
  type Tone,
  useActionReceipt,
} from '../../ui';
import { FilesPanel } from './FilesPanel';
import { parseProjectListMessage } from '../world/model/parseProjects';

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
 * Files panel uses typed GET /api/v1/files (not CLI parsing).
 */
export default function WorkspaceView() {
  const [params] = useSearchParams();
  const focusFiles = params.get('panel') === 'files';
  const focusProjects = params.get('panel') === 'projects';
  const projectPanel = useRef<HTMLDivElement>(null);
  const context = useSubQuery('workspace', 'context');
  const projects = useSubQuery('project', 'list');
  const budget = useSubQuery('workspace', 'budget');
  const validation = useSubQuery('workspace', 'validate', undefined, { failureIsData: true });
  const personas = useSubQuery('workspace', 'personas');
  const profiles = useSubQuery('workspace', 'profiles');
  const projectMutation = useSubMutation('project', 'add', { invalidates: ['workspace'] });
  const projectReceipt = useActionReceipt('Project linked');
  const [candidate, setCandidate] = useState<string | null>(null);
  const [pickerError, setPickerError] = useState<string | null>(null);

  const path = budget.data?.data['workspace'];
  const linkedProjects = projects.data ? parseProjectListMessage(envelopeText(projects.data)) : [];
  const candidateName = candidate?.split(/[\\/]/).filter(Boolean).at(-1) ?? '';
  const previousTarget = linkedProjects.find((project) => project.name === candidateName)?.target;

  useEffect(() => {
    if (focusProjects) projectPanel.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, [focusProjects]);

  const chooseProject = async () => {
    setPickerError(null);
    if (!window.atk) {
      setPickerError('The native folder picker is available in Agent Toolkit Desktop.');
      return;
    }
    try {
      const selected = await window.atk.projectChooseDirectory(path ?? '');
      if (selected) setCandidate(selected);
    } catch (error) {
      setPickerError(`${errorMessage(error)} ${recoveryHint(error)}`);
    }
  };

  const confirmProject = () => {
    if (!candidate || !path) return;
    projectMutation.mutate(
      { arg: candidate, workspace: path },
      {
        ...projectReceipt,
        onSuccess: (result) => {
          projectReceipt.onSuccess(result);
          setCandidate(null);
        },
      },
    );
  };

  return (
    <>
      <PageHeader
        eyebrow="Workspace"
        title={path ? (path.split('/').filter(Boolean).pop() ?? path) : 'Workspace'}
        lede={path}
      />
      <Stack>
        {focusFiles ? <FilesPanel /> : null}
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
        {!focusFiles ? <FilesPanel /> : null}
        <Panel tone="notice" title="Agent start context" meta="What an agent sees when it starts here">
          <QueryView query={context} loading="Reading start context" errorTitle="Could not read the start context">
            {(envelope) => <CommandReport envelope={envelope} label="Session context" />}
          </QueryView>
        </Panel>
        <div ref={projectPanel}>
          <Panel
            title="Projects"
            meta={
              linkedProjects.length
                ? `${linkedProjects.length} linked project${linkedProjects.length === 1 ? '' : 's'}`
                : 'Give each real project its own place in the world'
            }
            actions={
              <Button onClick={() => void chooseProject()} disabled={!path}>
                Link existing folder
              </Button>
            }
          >
            <p>
              Choose a repository already on this computer. Agent Toolkit will add a workspace link; it will not copy or
              change files inside the repository.
            </p>
            {pickerError ? <p role="alert">{pickerError}</p> : null}
            <QueryView query={projects} loading="Listing projects" errorTitle="Could not list projects">
              {(envelope) => <CommandReport envelope={envelope} label="Projects" />}
            </QueryView>
          </Panel>
        </div>
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
      <Dialog
        open={candidate !== null}
        onClose={() => setCandidate(null)}
        title="Review project link"
        description="This creates or updates a project entry in the current workspace. The repository itself stays where it is."
        footer={
          <ButtonRow>
            <Button variant="ghost" onClick={() => setCandidate(null)}>
              Cancel
            </Button>
            <Button
              variant="primary"
              onClick={confirmProject}
              busy={projectMutation.isPending}
              busyLabel="Linking…"
              disabled={!path || !candidateName}
            >
              Link {candidateName || 'project'}
            </Button>
          </ButtonRow>
        }
      >
        {pickerError ? <p role="alert">{pickerError}</p> : null}
        {projectMutation.error ? (
          <p role="alert">
            {errorMessage(projectMutation.error)} {recoveryHint(projectMutation.error)}
          </p>
        ) : null}
        <Button
          variant="ghost"
          onClick={() => {
            projectMutation.reset();
            void chooseProject();
          }}
          disabled={projectMutation.isPending}
        >
          Choose another folder
        </Button>
        <KeyValue
          items={[
            { label: 'Project', value: candidateName || 'Unknown folder' },
            { label: 'Repository folder', value: candidate ?? '—', mono: true },
            {
              label: 'Workspace link',
              value: candidateName ? `${path ?? 'workspace'}/projects/${candidateName}` : '—',
              mono: true,
            },
            {
              label: 'Existing link',
              value: previousTarget ? `${previousTarget} will be replaced` : 'None; a new link will be created',
            },
          ]}
        />
        {previousTarget ? (
          <p role="status">
            The old repository remains untouched; only its workspace symlink and project entry will point to the
            selected folder.
          </p>
        ) : null}
      </Dialog>
    </>
  );
}
