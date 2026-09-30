import type { ProjectRecord } from './types';

/**
 * Transitional adapter: `project list` currently puts names only in the
 * human message (`[ok] name -> target`). Not a second backend — mirrors the
 * known V format until serve returns structured rows.
 */
const LINE = /^\s*\[(ok|broken)]\s+(\S+)\s+->\s+(.+?)\s*$/;

export function parseProjectListMessage(message: string): ProjectRecord[] {
  const projects: ProjectRecord[] = [];
  for (const raw of message.split(/\r?\n/)) {
    const match = LINE.exec(raw);
    if (!match) continue;
    const status = match[1] === 'broken' ? 'broken' : 'ok';
    const name = match[2] ?? '';
    const target = (match[3] ?? '').trim();
    if (!name) continue;
    projects.push({ name, target, status });
  }
  projects.sort((a, b) => a.name.localeCompare(b.name));
  return projects;
}
