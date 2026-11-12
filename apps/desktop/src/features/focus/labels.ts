import type {
  FocusPermissionMode,
  FocusProviderStatus,
  FocusThread,
  FocusThreadStatus,
  FocusToolKind,
} from '../../types/focus';
import type { PixelIconName } from '../../ui';

export const MODE_OPTIONS: ReadonlyArray<{ id: FocusPermissionMode; label: string; hint: string }> = [
  { id: 'ask', label: 'Ask before changes', hint: 'Reads freely. Asks before editing files or running commands.' },
  { id: 'accept-edits', label: 'Edit without asking', hint: 'Edits files freely. Still asks before running commands.' },
  { id: 'plan', label: 'Plan only', hint: 'Explores and proposes a plan. Changes nothing until you approve it.' },
  {
    id: 'bypass',
    label: 'Never ask',
    hint: 'Runs everything without asking. Use only in a folder you can throw away.',
  },
];

export function modeLabel(mode: FocusPermissionMode): string {
  return MODE_OPTIONS.find((option) => option.id === mode)?.label ?? mode;
}

export const STATUS_LABEL: Record<FocusThreadStatus, string> = {
  idle: 'Ready',
  running: 'Working',
  'awaiting-approval': 'Needs your answer',
  interrupted: 'Stopped',
  error: 'Failed',
};

export const TOOL_ICON: Record<FocusToolKind, PixelIconName> = {
  command: 'terminal',
  edit: 'edit',
  read: 'file',
  search: 'search',
  web: 'web',
  agent: 'agent',
  other: 'dot',
};

export const TOOL_VERB: Record<FocusToolKind, string> = {
  command: 'Ran',
  edit: 'Edited',
  read: 'Read',
  search: 'Searched',
  web: 'Fetched',
  agent: 'Delegated',
  other: 'Used',
};

export const TOOL_VERB_ACTIVE: Record<FocusToolKind, string> = {
  command: 'Running',
  edit: 'Editing',
  read: 'Reading',
  search: 'Searching',
  web: 'Fetching',
  agent: 'Delegating',
  other: 'Using',
};

/** What an approval asks, in the user's words. */
export function approvalQuestion(providerLabel: string, kind: FocusToolKind, name: string): string {
  switch (kind) {
    case 'command':
      return `${providerLabel} wants to run a command`;
    case 'edit':
      return `${providerLabel} wants to change a file`;
    case 'web':
      return `${providerLabel} wants to reach the web`;
    case 'read':
      return `${providerLabel} wants to read a file`;
    default:
      return `${providerLabel} wants to use ${name}`;
  }
}

/** Why a provider cannot start a session right now, or null when it can. */
export function providerBlocker(provider: FocusProviderStatus): string | null {
  if (!provider.installed) return 'Not installed on this machine';
  if (!provider.capabilities.sessions) return 'Detected. Sessions here are not available for it yet';
  if (provider.auth === 'signed-out')
    return `${provider.authDetail}. Run \`${provider.signInHint ?? 'its login command'}\` in a terminal`;
  return null;
}

export function threadTitle(thread: Pick<FocusThread, 'title'>): string {
  return thread.title || 'New session';
}

export function relativeTime(iso: string, now = Date.now()): string {
  const seconds = Math.max(0, Math.round((now - Date.parse(iso)) / 1_000));
  if (seconds < 60) return 'now';
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.round(hours / 24);
  return days < 30 ? `${days}d` : new Date(iso).toLocaleDateString();
}
