import { useBackend } from '../data/backend';
import { useLiveStatus, type LiveStatus } from '../data/live';
import type { BackendState } from '../types/electron';
import { StatusBadge, type Tone } from '../ui';
import styles from './shell.module.css';

export interface IndicatorState {
  tone: Tone;
  label: string;
  detail: string;
  live: boolean;
}

function clock(epochMs: number): string {
  return new Date(epochMs).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

/** Pure mapping so the wording of every state is testable. */
export function indicatorState(backend: BackendState | null, status: LiveStatus): IndicatorState {
  if (backend && (backend.status === 'crashed' || backend.status === 'failed' || backend.status === 'stopped')) {
    return {
      tone: 'err',
      label: backend.status === 'stopped' ? 'Backend stopped' : 'Backend down',
      detail: status.lastHealthyAt ? `Last answer at ${clock(status.lastHealthyAt)}` : 'No answer yet',
      live: false,
    };
  }
  if (backend?.status === 'starting') {
    return { tone: 'idle', label: 'Starting backend', detail: 'Waiting for the first answer', live: false };
  }
  if (status.connection === 'offline') {
    return {
      tone: 'err',
      label: 'Offline',
      detail: status.lastHealthyAt
        ? `Showing data from ${clock(status.lastHealthyAt)}`
        : 'The backend has not answered',
      live: false,
    };
  }
  if (status.connection === 'connecting') {
    return { tone: 'idle', label: 'Connecting', detail: 'Waiting for the backend', live: false };
  }
  switch (status.streams.state) {
    case 'reconnecting':
      return {
        tone: 'warn',
        label: 'Reconnecting',
        detail: status.streams.nextRetryAt
          ? `Live output resumes by ${clock(status.streams.nextRetryAt)}`
          : 'Live output paused',
        live: false,
      };
    case 'live':
    case 'connecting':
      return {
        tone: 'ok',
        label: 'Live',
        detail: `${status.streams.streams} job ${status.streams.streams === 1 ? 'stream' : 'streams'} open`,
        live: true,
      };
    default:
      break;
  }
  switch (status.bus.state) {
    case 'reconnecting':
      return {
        tone: 'warn',
        label: 'Reconnecting',
        detail: status.bus.nextRetryAt
          ? `Event stream resumes by ${clock(status.bus.nextRetryAt)}`
          : 'Event stream paused',
        live: false,
      };
    case 'live':
    case 'connecting':
      return { tone: 'ok', label: 'Live', detail: 'Event stream open', live: true };
    default:
      return { tone: 'ok', label: 'Connected', detail: 'No running jobs', live: false };
  }
}

export function LiveIndicator() {
  const { backend } = useBackend();
  const state = indicatorState(backend, useLiveStatus());
  return (
    <div className={styles.indicator} role="status" aria-live="polite">
      <StatusBadge tone={state.tone} label={state.label} live={state.live} />
      <span className={styles.indicatorDetail}>{state.detail}</span>
    </div>
  );
}

/** Shown above content whenever what is on screen may be out of date. */
export function StaleNotice() {
  const { backend, restartBackend } = useBackend();
  const status = useLiveStatus();
  const down = backend && (backend.status === 'crashed' || backend.status === 'failed' || backend.status === 'stopped');
  if (backend?.status === 'version-mismatch') {
    return (
      <div className={styles.notice} data-tone="warn" role="alert">
        <p>
          {backend.detail ??
            `Backend ${backend.version ?? 'of unknown version'} does not match this Desktop build. Some actions may fail.`}
        </p>
      </div>
    );
  }
  if (!down && status.connection !== 'offline') return null;
  const since = status.lastHealthyAt ? ` from ${clock(status.lastHealthyAt)}` : '';
  const cause = down
    ? `The backend ${backend.status === 'stopped' ? 'is stopped' : `${backend.status}: ${backend.detail ?? 'no detail reported'}`}.`
    : 'The backend is not answering.';
  return (
    <div className={styles.notice} data-tone="err" role="alert">
      <p>
        {cause} What you see is the last known state{since}; actions will fail until it answers.
      </p>
      {window.atk ? (
        <button type="button" className={styles.noticeButton} onClick={() => void restartBackend()}>
          Restart backend
        </button>
      ) : null}
    </div>
  );
}
