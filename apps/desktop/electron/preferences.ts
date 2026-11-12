import fs from 'node:fs';
import path from 'node:path';
import type { DesktopPreferences, DesktopRouteMemory } from '../src/types/electron';

const FILE = 'desktop-preferences.json';
const DESTINATIONS = new Set([
  '/world',
  '/focus',
  '/projects',
  '/people',
  '/library',
  '/context',
  '/operations',
  '/settings',
  '/terminal',
  '/office',
  '/attention',
  '/insights',
]);

export const DEFAULT_PREFERENCES: DesktopPreferences = {
  version: 1,
  onboardingComplete: false,
  theme: 'system',
  motion: 'system',
  routes: {},
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function safeRoute(value: unknown, workspace: string): DesktopRouteMemory | null {
  if (typeof value !== 'string' || value.length > 1024) return null;
  try {
    const url = new URL(value, 'http://desktop.invalid');
    if (url.origin !== 'http://desktop.invalid' || !DESTINATIONS.has(url.pathname)) return null;
    const params = new URLSearchParams();
    params.set('workspace', workspace);
    for (const key of ['project', 'thread'] as const) {
      const item = url.searchParams.get(key);
      if (item && /^[\w.@-]{1,256}$/.test(item)) params.set(key, item);
    }
    return { pathname: url.pathname, search: `?${params.toString()}` };
  } catch {
    return null;
  }
}

export function validatePreferences(value: unknown): DesktopPreferences {
  if (!isRecord(value) || value.version !== 1) return { ...DEFAULT_PREFERENCES, routes: {} };
  const routes: Record<string, DesktopRouteMemory> = {};
  if (isRecord(value.routes)) {
    for (const [workspace, route] of Object.entries(value.routes)) {
      if (!path.isAbsolute(workspace) || workspace.length > 4096) continue;
      const safe = safeRoute(
        isRecord(route) ? `${String(route.pathname ?? '')}${String(route.search ?? '')}` : route,
        workspace,
      );
      if (safe) routes[workspace] = safe;
    }
  }
  return {
    version: 1,
    onboardingComplete: value.onboardingComplete === true,
    theme: value.theme === 'meadow' || value.theme === 'dusk' ? value.theme : 'system',
    motion: value.motion === 'reduced' ? 'reduced' : 'system',
    routes,
  };
}

/** Desktop-owned user preferences, independent of the renderer's ephemeral port. */
export class DesktopPreferenceStore {
  private readonly file: string;
  private current: DesktopPreferences;

  constructor(userData: string) {
    fs.mkdirSync(userData, { recursive: true, mode: 0o700 });
    this.file = path.join(userData, FILE);
    this.current = this.readFile();
  }

  read(): DesktopPreferences {
    return structuredClone(this.current);
  }

  set(patch: unknown): DesktopPreferences {
    if (!isRecord(patch)) return this.read();
    const candidate = { ...this.current, ...patch, version: 1 };
    const validated = validatePreferences(candidate);
    const temp = `${this.file}.${process.pid}.tmp`;
    try {
      fs.writeFileSync(temp, `${JSON.stringify(validated, null, 2)}\n`, { mode: 0o600 });
      fs.renameSync(temp, this.file);
      this.current = validated;
    } catch (error) {
      try {
        fs.rmSync(temp, { force: true });
      } catch {
        /* best effort */
      }
      throw error;
    }
    return this.read();
  }

  private readFile(): DesktopPreferences {
    try {
      return validatePreferences(JSON.parse(fs.readFileSync(this.file, 'utf8')) as unknown);
    } catch {
      return { ...DEFAULT_PREFERENCES, routes: {} };
    }
  }
}
