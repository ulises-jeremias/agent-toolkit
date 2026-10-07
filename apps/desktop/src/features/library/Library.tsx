import { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAgents, useInstallReceipts, useProviders, useTools } from '../../data/catalog';
import { useReport, useSubQuery } from '../../data/commands';
import { requireClient, useBackend } from '../../data/backend';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  envelopeText,
  errorMessage,
  requireOk,
  type CommandEnvelope,
  type CopilotProjectInstallResponse,
  type ToolEnabled,
  type ToolInfo,
} from '../../lib/api';
import { invalidateDomains, OPERATION_EFFECTS } from '../../lib/query/invalidation';
import { parsePluginBundles, parseSkillCatalog } from '../../lib/reports';
import { parseProjectListMessage } from '../world/model';
import {
  Button,
  ButtonRow,
  Dialog,
  EmptyState,
  Grid,
  KeyValue,
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

const INSTALL_TARGETS = [
  { id: 'claude-code', label: 'Claude Code' },
  { id: 'cursor', label: 'Cursor' },
  { id: 'opencode', label: 'OpenCode' },
  { id: 'windsurf', label: 'Windsurf' },
  { id: 'pi', label: 'Pi' },
  { id: 'muse-code', label: 'Muse Code' },
] as const;

const ARTIFACT_STATUS_ORDER: Record<string, number> = {
  missing: 0,
  replaced: 1,
  modified: 2,
  unavailable: 3,
  unchanged: 4,
};

function reviewedTargets(preview: CommandEnvelope | null): string[] {
  return (preview?.data['targets'] ?? '').split(',').filter(Boolean).sort();
}

function sameTargets(selected: readonly string[], preview: CommandEnvelope | null): boolean {
  const reviewed = reviewedTargets(preview);
  return reviewed.length === selected.length && selected.every((target, index) => target === reviewed[index]);
}

function receiptDate(value: string): string {
  const time = Date.parse(value);
  return Number.isNaN(time)
    ? 'Date unavailable'
    : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(time);
}

function artifactStatus(value: string): { tone: Tone; label: string } {
  switch (value) {
    case 'unchanged':
      return { tone: 'ok', label: 'unchanged' };
    case 'modified':
      return { tone: 'warn', label: 'edited since install' };
    case 'missing':
      return { tone: 'err', label: 'missing' };
    case 'replaced':
      return { tone: 'err', label: 'replaced by symlink' };
    default:
      return { tone: 'warn', label: 'could not verify' };
  }
}

function artifactSummary(artifacts: readonly { status: string }[]): string {
  const counts = new Map<string, number>();
  for (const artifact of artifacts) counts.set(artifact.status, (counts.get(artifact.status) ?? 0) + 1);
  return [...counts]
    .map(([status, count]) => `${count} ${status === 'unchanged' ? status : artifactStatus(status).label}`)
    .join(' · ');
}

function orderedArtifacts<T extends { status: string; path: string }>(artifacts: readonly T[]): T[] {
  return [...artifacts].sort(
    (a, b) =>
      (ARTIFACT_STATUS_ORDER[a.status] ?? ARTIFACT_STATUS_ORDER.unavailable!) -
        (ARTIFACT_STATUS_ORDER[b.status] ?? ARTIFACT_STATUS_ORDER.unavailable!) || a.path.localeCompare(b.path),
  );
}

/**
 * Library: the capability room the world opens for shared/project knowledge.
 * Catalog vs this machine. Memory is a different place and is omitted when
 * GET /api/v1/memory is gone — this inspector does not invent a memory UI.
 * Running and marketplace install counts stay unknown unless the API reports them.
 */
export default function Library() {
  const [searchParams, setSearchParams] = useSearchParams();
  const requestedInstallTarget = searchParams.get('install_target');
  const handledInstallTarget = useRef<string | null>(null);
  const handledInstallReview = useRef(false);
  const { client, backend } = useBackend();
  const { context } = useSessionContext();
  const workspacePath = context.workspace || backend?.harness?.path || '';
  const inventory = useReport('inventory');
  const catalogRoot = inventory.data?.data['root'];
  const tools = useTools();
  const receipts = useInstallReceipts();
  const agents = useAgents();
  const providers = useProviders();
  const projectsQuery = useSubQuery('project', 'list');
  const projects = useMemo(
    () => (projectsQuery.data ? parseProjectListMessage(envelopeText(projectsQuery.data)) : []),
    [projectsQuery.data],
  );
  const queryClient = useQueryClient();
  const skills = useSubQuery('skills', 'list');
  const plugins = useSubQuery('plugin', 'check', undefined, { failureIsData: true });
  const install = useMutation({
    mutationFn: async (targets: string[]) => requireOk(await requireClient(client).installReviewed(targets)),
    onSettled: () => invalidateDomains(queryClient, OPERATION_EFFECTS.install),
  });
  const uninstall = useMutation({
    mutationFn: async (reviewToken: string) => requireOk(await requireClient(client).uninstallReviewed(reviewToken)),
    onSettled: () => invalidateDomains(queryClient, OPERATION_EFFECTS.uninstall),
  });
  const [installPreview, setInstallPreview] = useState<CommandEnvelope | null>(null);
  const [selectedTargets, setSelectedTargets] = useState<string[]>([]);
  const [uninstallPreview, setUninstallPreview] = useState<CommandEnvelope | null>(null);
  const [copilotProject, setCopilotProject] = useState('');
  const [copilotAction, setCopilotAction] = useState<'install' | 'remove'>('install');
  const [copilotReview, setCopilotReview] = useState<CopilotProjectInstallResponse | null>(null);
  const [copilotError, setCopilotError] = useState<string | null>(null);
  const previewCopilot = useMutation({
    mutationFn: ({
      workspace,
      project,
      action,
    }: {
      workspace: string;
      project: string;
      action: 'install' | 'remove';
    }) => requireClient(client).copilotProjectInstallPreview(workspace, project, action),
    onSuccess: (result) => {
      setCopilotReview(result);
      setCopilotError(null);
    },
    onError: (error) => setCopilotError(`The read-only review failed; no file was written. ${errorMessage(error)}`),
  });
  const applyCopilot = useMutation({
    mutationFn: ({
      workspace,
      project,
      action,
      reviewToken,
    }: {
      workspace: string;
      project: string;
      action: 'install' | 'remove';
      reviewToken: string;
    }) => requireClient(client).copilotProjectInstallReviewed(workspace, project, action, reviewToken),
    onSettled: async () => {
      await invalidateDomains(queryClient, OPERATION_EFFECTS.install);
      await queryClient.invalidateQueries({ queryKey: ['copilot-project-removal-preview', workspacePath] });
    },
    onSuccess: (result) => {
      setCopilotReview(result);
      setCopilotError(result.ok ? null : result.message);
    },
    onError: (error) => {
      setCopilotError(
        `The action outcome could not be confirmed. Review the project again to check its current file and receipt state. ${errorMessage(error)}`,
      );
      setCopilotReview((current) => (current ? { ...current, status: 'stale-review' } : current));
    },
  });
  const previewInstall = useMutation({
    mutationFn: (targets?: string[]) => requireClient(client).installPreview(targets),
    onSuccess: (response) => {
      setInstallPreview(response);
      if (selectedTargets.length === 0 || !sameTargets(selectedTargets, response)) {
        setSelectedTargets(reviewedTargets(response));
      }
    },
  });
  const previewUninstall = useMutation({
    mutationFn: () => requireClient(client).uninstallPreview(),
    onSuccess: setUninstallPreview,
  });
  useEffect(() => {
    if (searchParams.get('install_review') !== '1') {
      handledInstallReview.current = false;
      return;
    }
    if (handledInstallReview.current) return;
    handledInstallReview.current = true;
    setInstallPreview(null);
    previewInstall.mutate();
    setSearchParams(
      (current) => {
        const next = new URLSearchParams(current);
        next.delete('install_review');
        return next;
      },
      { replace: true },
    );
  }, [previewInstall, searchParams, setSearchParams]);
  useEffect(() => {
    if (!requestedInstallTarget) {
      handledInstallTarget.current = null;
      return;
    }
    if (!INSTALL_TARGETS.some((target) => target.id === requestedInstallTarget)) return;
    if (handledInstallTarget.current === requestedInstallTarget) return;
    handledInstallTarget.current = requestedInstallTarget;
    setInstallPreview(null);
    setSelectedTargets([requestedInstallTarget]);
    previewInstall.mutate([requestedInstallTarget]);
    setSearchParams(
      (current) => {
        const next = new URLSearchParams(current);
        next.delete('install_target');
        return next;
      },
      { replace: true },
    );
  }, [previewInstall, requestedInstallTarget, setSearchParams]);
  const installReceipt = useActionReceipt('Toolkit capabilities installed');
  const uninstallReceipt = useActionReceipt('Toolkit files removed');

  const drift = plugins.data?.ok ? plugins.data.data['drift'] : undefined;
  const skillRows = skills.data ? parseSkillCatalog(envelopeText(skills.data)) : [];
  const pluginRows = plugins.data ? parsePluginBundles(envelopeText(plugins.data)) : [];
  const selectedCopilotProject = projects.find((project) => project.name === copilotProject && project.status === 'ok');
  const copilotRemovalPreview = useQuery({
    queryKey: ['copilot-project-removal-preview', workspacePath, selectedCopilotProject?.name ?? ''],
    queryFn: () => {
      if (!selectedCopilotProject) throw new Error('Choose a linked project before checking its receipt.');
      return requireClient(client).copilotProjectInstallPreview(workspacePath, selectedCopilotProject.name, 'remove');
    },
    enabled: Boolean(workspacePath && selectedCopilotProject),
  });
  const canReviewCopilotRemoval = Boolean(
    copilotRemovalPreview.data && copilotRemovalPreview.data.status !== 'no-receipt',
  );

  const reviewCopilotProject = (action: 'install' | 'remove') => {
    if (!workspacePath || !selectedCopilotProject) return;
    setCopilotAction(action);
    setCopilotReview(null);
    setCopilotError(null);
    applyCopilot.reset();
    previewCopilot.mutate({ workspace: workspacePath, project: selectedCopilotProject.name, action });
  };

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
        open={copilotReview !== null || previewCopilot.isPending || previewCopilot.isError}
        closeDisabled={applyCopilot.isPending}
        onClose={() => {
          if (applyCopilot.isPending) return;
          setCopilotReview(null);
          setCopilotError(null);
          previewCopilot.reset();
          applyCopilot.reset();
        }}
        title={copilotAction === 'install' ? 'Review GitHub Copilot setup' : 'Review GitHub Copilot removal'}
        description={
          copilotAction === 'install'
            ? "This installs Agent Toolkit's repository-scoped Copilot instructions in one linked project. It does not launch an agent or change user-level tools. Existing project instructions are preserved."
            : 'This removes only the unchanged instructions file recorded in the selected project receipt. Any file edited since installation is preserved.'
        }
        size="normal"
        footer={
          <ButtonRow>
            <Button
              disabled={applyCopilot.isPending}
              onClick={() => {
                setCopilotReview(null);
                setCopilotError(null);
                previewCopilot.reset();
                applyCopilot.reset();
              }}
            >
              Close
            </Button>
            {copilotReview?.status === 'stale-review' ? (
              <Button
                variant="secondary"
                disabled={previewCopilot.isPending}
                onClick={() => reviewCopilotProject(copilotAction)}
              >
                Review again
              </Button>
            ) : null}
            {copilotReview?.status === (copilotAction === 'install' ? 'ready' : 'ready-remove') ? (
              <Button
                variant="primary"
                disabled={applyCopilot.isPending || !copilotReview.review_token || !selectedCopilotProject}
                busy={applyCopilot.isPending}
                busyLabel={copilotAction === 'install' ? 'Installing instructions…' : 'Removing instructions…'}
                onClick={() => {
                  if (!workspacePath || !selectedCopilotProject || !copilotReview.review_token) return;
                  applyCopilot.mutate({
                    workspace: workspacePath,
                    project: selectedCopilotProject.name,
                    action: copilotAction,
                    reviewToken: copilotReview.review_token,
                  });
                }}
              >
                {copilotAction === 'install' ? 'Install reviewed instructions' : 'Remove reviewed instructions'}
              </Button>
            ) : null}
          </ButtonRow>
        }
      >
        {previewCopilot.isPending ? (
          <p role="status">
            {copilotAction === 'install'
              ? 'Checking the linked repository and destination…'
              : 'Checking receipt ownership and file state…'}
          </p>
        ) : null}
        {copilotError ? <p role="alert">{copilotError}</p> : null}
        {copilotReview ? (
          <>
            <p role={copilotReview.ok ? 'status' : 'alert'}>{copilotReview.message}</p>
            <KeyValue
              items={[
                { label: 'Project', value: copilotReview.project },
                {
                  label: 'Destination',
                  value: selectedCopilotProject
                    ? `${selectedCopilotProject.target.replace(/\\/g, '/')}/${copilotReview.path}`
                    : copilotReview.path,
                },
                {
                  label: copilotAction === 'install' ? 'Files to add' : 'Files to remove',
                  value: copilotReview.status === 'ready' || copilotReview.status === 'ready-remove' ? '1' : '0',
                },
              ]}
            />
            {copilotReview.status === 'ready' && copilotReview.content ? (
              <details className={styles.copilotFilePreview}>
                <summary>Review file contents</summary>
                <pre className={styles.installPreview} aria-label="Copilot instructions file contents">
                  {copilotReview.content}
                </pre>
              </details>
            ) : null}
          </>
        ) : null}
      </Dialog>

      <Dialog
        open={installPreview !== null || previewInstall.isError}
        onClose={() => {
          setInstallPreview(null);
          setSelectedTargets([]);
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
                setSelectedTargets([]);
                previewInstall.reset();
              }}
            >
              Cancel
            </Button>
            <Button
              variant="secondary"
              disabled={selectedTargets.length === 0 || previewInstall.isPending || install.isPending}
              busy={previewInstall.isPending}
              busyLabel="Updating preview…"
              onClick={() => {
                setInstallPreview(null);
                previewInstall.mutate(selectedTargets);
              }}
            >
              Preview selected targets
            </Button>
            <Button
              variant="primary"
              disabled={!installPreview?.ok || !sameTargets(selectedTargets, installPreview) || install.isPending}
              busy={install.isPending}
              busyLabel="Installing…"
              onClick={() =>
                install.mutate(selectedTargets, {
                  ...installReceipt,
                  onSuccess: (result) => {
                    installReceipt.onSuccess?.(result);
                    setInstallPreview(null);
                    setSelectedTargets([]);
                  },
                })
              }
            >
              Install reviewed targets
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
            <fieldset className={styles.targetPicker}>
              <legend>Where should Toolkit capabilities be installed?</legend>
              <p>Choose only tools you use. The preview must match this selection before installation is enabled.</p>
              <p>GitHub Copilot installs are repository-scoped and are not included in this user-level installer.</p>
              <div className={styles.targetGrid}>
                {INSTALL_TARGETS.map((target) => (
                  <label key={target.id}>
                    <input
                      type="checkbox"
                      disabled={previewInstall.isPending || install.isPending}
                      checked={selectedTargets.includes(target.id)}
                      onChange={(event) => {
                        setSelectedTargets((current) =>
                          event.target.checked
                            ? [...current, target.id].sort()
                            : current.filter((value) => value !== target.id),
                        );
                      }}
                    />
                    <span>{target.label}</span>
                    {reviewedTargets(installPreview).includes(target.id) ? <small>in preview</small> : null}
                  </label>
                ))}
              </div>
              {!sameTargets(selectedTargets, installPreview) ? (
                <p role="status">Selection changed. Update the preview before applying.</p>
              ) : null}
            </fieldset>
            <pre className={styles.installPreview} aria-label="Installation preview">
              {installPreview.message}
            </pre>
          </>
        ) : null}
      </Dialog>
      <Dialog
        open={uninstallPreview !== null || previewUninstall.isError}
        closeDisabled={uninstall.isPending}
        onClose={() => {
          if (uninstall.isPending) return;
          setUninstallPreview(null);
          previewUninstall.reset();
        }}
        title="Review Toolkit file removal"
        description="This removes unchanged files owned by Agent Toolkit, as recorded in installation receipts. Files you edited after installation and merged settings are preserved. Review every path before confirming."
        size="wide"
        footer={
          <ButtonRow>
            <Button
              disabled={uninstall.isPending}
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
              onClick={() => {
                const reviewToken = uninstallPreview?.data['review_token'];
                if (!reviewToken) return;
                uninstall.mutate(reviewToken, {
                  ...uninstallReceipt,
                  onSuccess: (result) => {
                    uninstallReceipt.onSuccess?.(result);
                    setUninstallPreview(null);
                  },
                });
              }}
            >
              Remove reviewed files
            </Button>
          </ButtonRow>
        }
      >
        {previewUninstall.isError ? <p role="alert">{errorMessage(previewUninstall.error)}</p> : null}
        {uninstall.isError ? (
          <div role="alert">
            <p>{errorMessage(uninstall.error)}</p>
            <Button
              disabled={uninstall.isPending || previewUninstall.isPending}
              onClick={() => {
                setUninstallPreview(null);
                uninstall.reset();
                previewUninstall.mutate();
              }}
            >
              Refresh removal plan
            </Button>
          </div>
        ) : null}
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
          <Panel title="GitHub Copilot" meta="Repository instructions">
            <p>
              Add the Agent Toolkit Copilot instructions to one linked project. The Library previews the exact file and
              keeps existing repository instructions untouched.
            </p>
            {projectsQuery.isError ? (
              <p role="alert">Could not load linked projects: {errorMessage(projectsQuery.error)}</p>
            ) : null}
            {copilotRemovalPreview.isError && selectedCopilotProject ? (
              <p role="alert">
                Could not check Agent Toolkit&apos;s receipt for {selectedCopilotProject.name}:{' '}
                {errorMessage(copilotRemovalPreview.error)}
              </p>
            ) : null}
            {!workspacePath ? (
              <p role="status">Choose a workspace in Settings before configuring project instructions.</p>
            ) : null}
            {projectsQuery.isSuccess && projects.length === 0 ? (
              <EmptyState title="No linked projects yet.">
                Link a repository in Workspace, then set up Copilot here.
              </EmptyState>
            ) : null}
            {projects.length > 0 ? (
              <div className={styles.projectInstall}>
                <label htmlFor="copilot-project">Project</label>
                <select
                  id="copilot-project"
                  value={copilotProject}
                  onChange={(event) => setCopilotProject(event.target.value)}
                >
                  <option value="">Choose a linked project</option>
                  {projects.map((project) => (
                    <option key={project.name} value={project.name} disabled={project.status !== 'ok'}>
                      {project.name}
                      {project.status !== 'ok' ? ' · unavailable' : ''}
                    </option>
                  ))}
                </select>
                <ButtonRow>
                  <Button
                    variant="primary"
                    disabled={
                      !workspacePath || !selectedCopilotProject || previewCopilot.isPending || applyCopilot.isPending
                    }
                    busy={previewCopilot.isPending && copilotAction === 'install'}
                    busyLabel="Reviewing project…"
                    onClick={() => reviewCopilotProject('install')}
                  >
                    Review project setup
                  </Button>
                  {canReviewCopilotRemoval ? (
                    <Button
                      variant="secondary"
                      disabled={
                        !workspacePath || !selectedCopilotProject || previewCopilot.isPending || applyCopilot.isPending
                      }
                      busy={previewCopilot.isPending && copilotAction === 'remove'}
                      busyLabel="Checking receipt…"
                      onClick={() => reviewCopilotProject('remove')}
                    >
                      Review removal
                    </Button>
                  ) : null}
                </ButtonRow>
              </div>
            ) : null}
          </Panel>
          <Panel
            title="Installation evidence"
            meta={receipts.data ? `${receipts.data.receipts.length} receipts` : undefined}
            actions={
              <Button size="sm" variant="secondary" busy={receipts.isFetching} onClick={() => void receipts.refetch()}>
                Refresh evidence
              </Button>
            }
          >
            <QueryView
              query={receipts}
              loading="Reading installation receipts"
              errorTitle="Could not read installation evidence"
            >
              {(response) =>
                response.receipts.length === 0 ? (
                  <EmptyState title="No Toolkit capability installations recorded on this machine.">
                    Review an installation above to choose destinations. Existing files are never reported as installed
                    without a backend receipt. Receipt paths are checked against their recorded SHA-256 without
                    returning file contents.
                  </EmptyState>
                ) : (
                  <Table>
                    <thead>
                      <tr>
                        <th scope="col">Target</th>
                        <th scope="col">Product</th>
                        <th scope="col">Scope</th>
                        <th scope="col">Installed</th>
                        <th scope="col">Files</th>
                        <th scope="col">Receipt</th>
                      </tr>
                    </thead>
                    <tbody>
                      {response.receipts.map((receipt) => (
                        <tr key={`${receipt.target}/${receipt.product}`}>
                          <th scope="row">
                            {receipt.target === 'copilot-repository'
                              ? 'GitHub Copilot · repository'
                              : (INSTALL_TARGETS.find((target) => target.id === receipt.target)?.label ??
                                receipt.target)}
                          </th>
                          <td>
                            {receipt.target === 'copilot-repository' ? (
                              'Copilot instructions'
                            ) : (
                              <Mono>{receipt.product}</Mono>
                            )}
                          </td>
                          <td>
                            {receipt.scope.startsWith('project:') ? (
                              <details>
                                <summary>Project scope</summary>
                                <Mono>{receipt.scope.slice('project:'.length)}</Mono>
                              </details>
                            ) : (
                              receipt.scope
                            )}
                          </td>
                          <td>{receiptDate(receipt.installed_at)}</td>
                          <td>
                            {receipt.artifact_count} total · {receipt.created_count} created · {receipt.merged_count}{' '}
                            merged
                          </td>
                          <td>
                            <details>
                              <summary>File evidence · {artifactSummary(receipt.artifacts)}</summary>
                              <div
                                aria-label={`File evidence for ${receipt.product} on ${receipt.target}`}
                                className={styles.artifactList}
                                role="region"
                                tabIndex={-1}
                              >
                                <ul>
                                  {orderedArtifacts(receipt.artifacts).map((artifact) => {
                                    const state = artifactStatus(artifact.status);
                                    return (
                                      <li className={styles.artifactRow} key={artifact.path}>
                                        <div className={styles.artifactPath}>
                                          <Mono>{artifact.path}</Mono>
                                          <small>{artifact.ownership} by Toolkit</small>
                                        </div>
                                        <StatusBadge tone={state.tone} label={state.label} />
                                      </li>
                                    );
                                  })}
                                </ul>
                              </div>
                            </details>
                            <details>
                              <summary>Local receipt path</summary>
                              <Mono>{receipt.receipt_path}</Mono>
                            </details>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                )
              }
            </QueryView>
          </Panel>
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
