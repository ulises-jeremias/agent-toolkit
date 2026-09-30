import type { SelfcheckStatus } from '../lib/api';
import type { Tone } from './primitives';

export function jobTone(status: string): Tone {
  switch (status) {
    case 'completed':
      return 'ok';
    case 'failed':
    case 'rejected':
      return 'err';
    case 'canceled':
      return 'warn';
    case 'running':
    case 'queued':
      return 'info';
    default:
      return 'idle';
  }
}

export function selfcheckTone(status: SelfcheckStatus): Tone {
  return status;
}
