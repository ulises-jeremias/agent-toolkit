// @vitest-environment node
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  listBackendCandidates,
  parseVersionOutput,
  probeDesktopGate,
  resolveBackendPin,
  selectBackendBinary,
  type BackendCandidate,
  type CandidateInputs,
  type ProbeOptions,
  type RunBinary,
} from './backend-binary';

const inputs = (overrides: Partial<CandidateInputs> & { files?: string[] } = {}): CandidateInputs => {
  const files = new Set(overrides.files ?? []);
  return {
    env: {},
    resourcesPath: '',
    stagedDir: '/app/resources/bin',
    platform: 'linux',
    exists: (file) => files.has(file),
    realpath: (file) => file,
    ...overrides,
  };
};

describe('listBackendCandidates', () => {
  it('uses ATK_BACKEND_BIN alone, even when it does not exist', () => {
    expect(
      listBackendCandidates(
        inputs({ env: { ATK_BACKEND_BIN: '/opt/atk/agent-toolkit', PATH: '/usr/bin' }, files: ['/usr/bin/agent-toolkit'] }),
      ),
    ).toEqual([{ path: '/opt/atk/agent-toolkit', source: 'env', authoritative: true }]);
  });

  it('uses the bundled backend alone in a packaged app', () => {
    expect(
      listBackendCandidates(
        inputs({
          resourcesPath: '/opt/App/resources',
          env: { PATH: '/usr/bin' },
          files: ['/opt/App/resources/bin/agent-toolkit', '/usr/bin/agent-toolkit'],
        }),
      ),
    ).toEqual([{ path: '/opt/App/resources/bin/agent-toolkit', source: 'bundled', authoritative: true }]);
  });

  it('orders staged before PATH entries, in PATH order, de-duplicated by realpath', () => {
    const result = listBackendCandidates(
      inputs({
        resourcesPath: '/electron/resources',
        env: { PATH: '/usr/bin::/home/u/.local/bin:/bin' },
        files: [
          '/app/resources/bin/agent-toolkit',
          '/usr/bin/agent-toolkit',
          '/home/u/.local/bin/agent-toolkit',
          '/bin/agent-toolkit',
        ],
        realpath: (file) => (file === '/bin/agent-toolkit' ? '/usr/bin/agent-toolkit' : file),
      }),
    );
    expect(result).toEqual([
      { path: '/app/resources/bin/agent-toolkit', source: 'staged', authoritative: false },
      { path: '/usr/bin/agent-toolkit', source: 'path', authoritative: false },
      { path: '/home/u/.local/bin/agent-toolkit', source: 'path', authoritative: false },
    ]);
  });

  it('resolves relative PATH entries to absolute paths', () => {
    const rel = path.join('some', 'bin');
    const abs = path.resolve(rel, 'agent-toolkit');
    expect(listBackendCandidates(inputs({ env: { PATH: rel }, files: [abs] }))).toEqual([
      { path: abs, source: 'path', authoritative: false },
    ]);
  });
});

describe('selectBackendBinary', () => {
  /** Scripted binaries: path -> { version output, serve support }. */
  const scripted = (table: Record<string, { version?: string; serve?: boolean; versionExit?: number }>): RunBinary =>
    async (bin, args) => {
      const entry = table[bin];
      if (!entry) return { code: null, stdout: '', stderr: '', error: 'spawn ENOENT' };
      if (args[0] === '--version') {
        return { code: entry.versionExit ?? 0, stdout: entry.version ? `agent-toolkit ${entry.version}\n` : '', stderr: '', error: null };
      }
      return entry.serve === false
        ? { code: 1, stdout: '', stderr: 'Unknown command: serve\n', error: null }
        : { code: 0, stdout: 'Usage: agent-toolkit serve [--host HOST]\n', stderr: '', error: null };
    };
  const options = (run: RunBinary, overrides: Partial<ProbeOptions> = {}): ProbeOptions => ({
    pin: null,
    run,
    cwd: undefined,
    isExecutable: () => true,
    ...overrides,
  });
  const pathCandidate = (file: string): BackendCandidate => ({ path: file, source: 'path', authoritative: false });

  it('falls through PATH candidates to the first compatible one and records rejections', async () => {
    const result = await selectBackendBinary(
      [pathCandidate('/usr/bin/agent-toolkit'), pathCandidate('/home/u/.local/bin/agent-toolkit')],
      options(
        scripted({
          '/usr/bin/agent-toolkit': { version: '1.16.0', serve: false },
          '/home/u/.local/bin/agent-toolkit': { version: '1.35.0' },
        }),
      ),
    );
    expect(result).toEqual({
      ok: true,
      binary: { path: '/home/u/.local/bin/agent-toolkit', source: 'path', version: '1.35.0' },
      rejected: [
        {
          path: '/usr/bin/agent-toolkit',
          source: 'path',
          version: '1.16.0',
          reason: 'too old: has no `serve` command (`serve --help`: Unknown command: serve)',
        },
      ],
    });
  });

  it('explains every rejection when nothing is compatible', async () => {
    const result = await selectBackendBinary(
      [pathCandidate('/usr/bin/agent-toolkit')],
      options(scripted({ '/usr/bin/agent-toolkit': { version: '1.16.0', serve: false } })),
    );
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.problem).toBe('binary-rejected');
    expect(result.message).toBe(
      'No compatible agent-toolkit backend. Rejected /usr/bin/agent-toolkit (path, 1.16.0): too old: has no `serve` command (`serve --help`: Unknown command: serve). Set ATK_BACKEND_BIN to a current agent-toolkit build, or put one first on PATH.',
    );
  });

  it('rejects a major that differs from the pin, naming the pin source', async () => {
    const result = await selectBackendBinary(
      [pathCandidate('/b/agent-toolkit')],
      options(scripted({ '/b/agent-toolkit': { version: '1.35.0' } }), {
        pin: { major: '2', version: '2.0.0', source: 'backend-version.json' },
      }),
    );
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.rejected[0]?.reason).toBe(
      'major 1 does not match this Desktop build, which needs major 2 (backend-version.json = 2.0.0)',
    );
  });

  it('stops at a rejected authoritative candidate instead of trying PATH', async () => {
    const result = await selectBackendBinary(
      [{ path: '/opt/App/resources/bin/agent-toolkit', source: 'bundled', authoritative: true }, pathCandidate('/b/agent-toolkit')],
      options(scripted({ '/b/agent-toolkit': { version: '1.35.0' } }), {
        isExecutable: (file) => file !== '/opt/App/resources/bin/agent-toolkit',
      }),
    );
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.rejected).toHaveLength(1);
    expect(result.message).toContain('not an executable file');
    expect(result.message).toContain('reinstall Agent Toolkit Desktop');
  });

  it('reports no-backend when there are no candidates', async () => {
    const result = await selectBackendBinary([], options(scripted({})));
    expect(result).toMatchObject({ ok: false, problem: 'no-backend' });
  });

  it('rejects a binary whose --version fails or prints no version', async () => {
    const failing = await selectBackendBinary(
      [pathCandidate('/a/agent-toolkit')],
      options(scripted({ '/a/agent-toolkit': { version: '1.0.0', versionExit: 2 } })),
    );
    expect(failing.ok || failing.rejected[0]?.reason).toContain('`--version` failed (exit 2');
    const silent = await selectBackendBinary([pathCandidate('/a/agent-toolkit')], options(scripted({ '/a/agent-toolkit': {} })));
    expect(silent.ok || silent.rejected[0]?.reason).toContain('printed no version');
  });
});

describe('parseVersionOutput', () => {
  it('extracts the trailing semver token', () => {
    expect(parseVersionOutput('agent-toolkit 1.35.0\n')).toBe('1.35.0');
    expect(parseVersionOutput('agent-toolkit v2.0.0-rc.1')).toBe('2.0.0-rc.1');
    expect(parseVersionOutput('Unknown command')).toBeNull();
  });
});

describe('resolveBackendPin', () => {
  let dir = '';
  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-pin-'));
  });
  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('prefers ATK_EXPECTED_BACKEND_MAJOR, then backend-version.json, else null', () => {
    fs.writeFileSync(path.join(dir, 'backend-version.json'), JSON.stringify({ version: 'v1.36.2' }));
    expect(resolveBackendPin({ ATK_EXPECTED_BACKEND_MAJOR: 'v2' }, [dir])).toEqual({
      major: '2',
      version: '2',
      source: 'ATK_EXPECTED_BACKEND_MAJOR',
    });
    expect(resolveBackendPin({}, [dir])).toEqual({ major: '1', version: '1.36.2', source: 'backend-version.json' });
    expect(resolveBackendPin({}, [path.join(dir, 'missing')])).toBeNull();
  });
});

describe('probeDesktopGate', () => {
  const servers: http.Server[] = [];
  afterEach(async () => {
    await Promise.all(servers.splice(0).map((server) => new Promise((r) => server.close(r))));
  });

  const serve = (handler: http.RequestListener): Promise<string> =>
    new Promise((resolve) => {
      const server = http.createServer(handler);
      servers.push(server);
      server.listen(0, '127.0.0.1', () => {
        const address = server.address();
        resolve(`http://127.0.0.1:${typeof address === 'object' && address ? address.port : 0}`);
      });
    });

  it('detects a gate-aware serve (422 on the empty job body) as present', async () => {
    let seen: http.IncomingHttpHeaders = {};
    const url = await serve((req, res) => {
      seen = req.headers;
      res.writeHead(422);
      res.end('{"ok":false,"error":"cmd is required"}');
    });
    expect(await probeDesktopGate(url)).toBe('present');
    expect(seen['sec-fetch-site']).toBe('cross-site');
    expect(seen['x-atk-desktop']).toBe('1');
  });

  it('detects a pre-gate serve (403 cross-site) as missing', async () => {
    const url = await serve((_req, res) => {
      res.writeHead(403);
      res.end('{"ok":false,"error":"cross-site request forbidden"}');
    });
    expect(await probeDesktopGate(url)).toBe('missing');
  });

  it('is inconclusive when serve is unreachable', async () => {
    expect(await probeDesktopGate('http://127.0.0.1:1', 500)).toBe('unknown');
  });
});
