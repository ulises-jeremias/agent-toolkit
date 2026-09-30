import { describe, expect, it } from 'vitest';
import {
  mcpStatusTone,
  parseDiffRows,
  parseDoctorChecks,
  parseInsightsTools,
  parseMcpProviders,
  parsePluginBundles,
  parseSkillCatalog,
} from './reports';

describe('parseDoctorChecks', () => {
  it('reads category headers and check icons without inventing rows', () => {
    const rows = parseDoctorChecks(`
agent-toolkit doctor

── Engine ──
  ✓  engine                         v
  ✓  version                        1.36.0

── Toolkit root ──
  ✗  root                           not found (set AGENT_TOOLKIT_ROOT)
  ⚠  offline                        AGENT_TOOLKIT_OFFLINE set
`);
    expect(rows).toEqual([
      { category: 'engine', name: 'engine', status: 'ok', detail: 'v' },
      { category: 'engine', name: 'version', status: 'ok', detail: '1.36.0' },
      { category: 'toolkit root', name: 'root', status: 'err', detail: 'not found (set AGENT_TOOLKIT_ROOT)' },
      { category: 'toolkit root', name: 'offline', status: 'warn', detail: 'AGENT_TOOLKIT_OFFLINE set' },
    ]);
  });

  it('returns empty when the text is not a doctor report', () => {
    expect(parseDoctorChecks('{"ok":true}')).toEqual([]);
  });
});

describe('parseSkillCatalog', () => {
  it('groups skills by domain and keeps catalog existence distinct from install', () => {
    const rows = parseSkillCatalog(`
Available skills

── review ──
  ✓  code-reviewer                            — Quality review
  ✗  missing-skill

── security ──
  ✓  threat-modeling

Total: 3 skill(s) across 2 domain(s)
`);
    expect(rows).toEqual([
      { domain: 'review', name: 'code-reviewer', inCatalog: true, description: 'Quality review' },
      { domain: 'review', name: 'missing-skill', inCatalog: false, description: '' },
      { domain: 'security', name: 'threat-modeling', inCatalog: true, description: '' },
    ]);
  });
});

describe('parseMcpProviders', () => {
  it('reads the CLI table and keeps CLI status words', () => {
    const rows = parseMcpProviders(`
Available MCP providers

  Provider          Status        Required env vars
  ------------------------------------------------
  github            ✓ configured  GITHUB_TOKEN
  clickup             not setup   CLICKUP_API_TOKEN
  slack             - disabled    SLACK_BOT_TOKEN

Run: agent-toolkit mcp setup <provider>
`);
    expect(rows).toEqual([
      { provider: 'github', status: 'configured', env: 'GITHUB_TOKEN' },
      { provider: 'clickup', status: 'not setup', env: 'CLICKUP_API_TOKEN' },
      { provider: 'slack', status: 'disabled', env: 'SLACK_BOT_TOKEN' },
    ]);
  });
});

describe('parseInsightsTools', () => {
  it('reads session counts and leaves cost out when the wrap has none', () => {
    const rows = parseInsightsTools(`Insights — all (pure V, --no-llm fallback active: true)
- opencode: 3 sessions (ok)
- cursor: 0 sessions (no_data)
- claude: 12 sessions (ok)
Total: 15 sessions across 8 tools
`);
    expect(rows).toEqual([
      { tool: 'opencode', sessions: '3', status: 'ok' },
      { tool: 'cursor', sessions: '0', status: 'no_data' },
      { tool: 'claude', sessions: '12', status: 'ok' },
    ]);
  });
});

describe('parsePluginBundles', () => {
  it('lists bundle names from section headings', () => {
    expect(parsePluginBundles('── core ──\n  ✓ ok\n── agents ──\n').map((row) => row.name)).toEqual(['core', 'agents']);
  });
});

describe('parseDiffRows', () => {
  it('reads product→target verdicts', () => {
    expect(
      parseDiffRows(`agent-toolkit diff
  ✓  ~ core → claude-code: no changes
  ✗  forge → cursor: compile failed (missing)
`),
    ).toEqual([
      { product: 'core', target: 'claude-code', result: 'no changes', ok: true },
      { product: 'forge', target: 'cursor', result: 'compile failed (missing)', ok: false },
    ]);
  });
});

describe('mcpStatusTone', () => {
  it('maps CLI status words without treating unknown as healthy', () => {
    expect(mcpStatusTone('configured')).toBe('ok');
    expect(mcpStatusTone('not setup')).toBe('idle');
    expect(mcpStatusTone('disabled')).toBe('warn');
    expect(mcpStatusTone('unknown')).toBe('idle');
  });
});
