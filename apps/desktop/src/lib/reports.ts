/**
 * Presentational mapping of known `serve` report lines into rows.
 * Typed GET catalogs (`/agents`, `/tools`) do not go through here.
 * When a format is not recognised the parser returns [] — callers show
 * unknown/empty, never invent rows, and do not dump the raw envelope.
 */

export interface DoctorRow {
  category: string;
  name: string;
  status: 'ok' | 'warn' | 'err';
  detail: string;
}

export interface SkillRow {
  domain: string;
  name: string;
  inCatalog: boolean;
  description: string;
}

export interface McpRow {
  provider: string;
  status: string;
  env: string;
}

export interface InsightsToolRow {
  tool: string;
  sessions: string;
  status: string;
}

export interface PluginBundleRow {
  name: string;
}

export interface DiffRow {
  product: string;
  target: string;
  result: string;
  ok: boolean;
}

const SECTION = /^──\s+(.+?)\s+──\s*$/;
const DOCTOR_CHECK = /^\s+([✓⚠✗])\s+(\S.*?)\s{2,}(\S.*)$/;
const SKILL_ROW = /^\s+([✓✗])\s+(\S+?)(?:\s{2,}(?:—\s*)?(.*))?$/;
const INSIGHTS_TOOL = /^-\s+(\S+):\s+(\S+)\s+sessions?\s+\(([^)]+)\)\s*$/i;
const DIFF_ROW = /^\s+(✓|✗)?\s*~?\s*(\S+)\s+→\s+(\S+):\s*(.*)$/;
const MCP_SEPARATOR = /^[\s-]+$/;

function iconStatus(icon: string): 'ok' | 'warn' | 'err' {
  if (icon === '✓') return 'ok';
  if (icon === '⚠') return 'warn';
  return 'err';
}

/** Doctor CLI lines (`  ✓  name  detail` under `── Category ──`). */
export function parseDoctorChecks(text: string): DoctorRow[] {
  const rows: DoctorRow[] = [];
  let category = 'doctor';
  for (const raw of text.split('\n')) {
    const section = raw.match(SECTION);
    if (section?.[1]) {
      category = section[1].trim().toLowerCase();
      continue;
    }
    const check = raw.match(DOCTOR_CHECK);
    if (!check) continue;
    const [, icon, name, detail] = check;
    if (!icon || !name || !detail) continue;
    rows.push({ category, name: name.trim(), status: iconStatus(icon), detail: detail.trim() });
  }
  return rows;
}

/** Skills catalog lines (`── domain ──` then `  ✓  name  — desc`). */
export function parseSkillCatalog(text: string): SkillRow[] {
  const rows: SkillRow[] = [];
  let domain = '';
  for (const raw of text.split('\n')) {
    const section = raw.match(SECTION);
    if (section?.[1]) {
      domain = section[1].trim();
      continue;
    }
    if (!domain) continue;
    const match = raw.match(SKILL_ROW);
    if (!match) continue;
    const [, icon, name, description] = match;
    if (!icon || !name) continue;
    if (name.startsWith('Total:')) continue;
    rows.push({
      domain,
      name,
      inCatalog: icon === '✓',
      description: (description ?? '').replace(/^—\s*/, '').trim(),
    });
  }
  return rows;
}

/**
 * MCP `list` table after the `---` rule.
 * Status words stay as the CLI wrote them (`not setup`, `configured`, `disabled`).
 */
export function parseMcpProviders(text: string): McpRow[] {
  const lines = text.split('\n');
  const start = lines.findIndex((line) => /^[\s]*-+[\s-]*$/.test(line) && line.includes('-'));
  if (start < 0) return [];
  const rows: McpRow[] = [];
  for (const raw of lines.slice(start + 1)) {
    if (SECTION.test(raw) || raw.trim() === '' || raw.trimStart().startsWith('Run:')) break;
    if (MCP_SEPARATOR.test(raw) && !/\S/.test(raw.replace(/-/g, ''))) continue;
    const trimmed = raw.trim();
    if (!trimmed) continue;
    const parts = trimmed.split(/\s{2,}/).filter(Boolean);
    if (parts.length < 2) continue;
    const provider = parts[0];
    if (!provider || provider.toLowerCase() === 'provider') continue;
    const status = (parts[1] ?? '').replace(/^[✓✗⚠-]\s*/, '').trim();
    const env = parts.slice(2).join(' ');
    rows.push({ provider, status: status || 'unknown', env });
  }
  return rows;
}

/** Insights `--no-llm` aggregate: `- opencode: 3 sessions (ok)`. Cost is omitted — the wrap has none. */
export function parseInsightsTools(text: string): InsightsToolRow[] {
  const rows: InsightsToolRow[] = [];
  for (const raw of text.split('\n')) {
    const match = raw.trim().match(INSIGHTS_TOOL);
    if (!match) continue;
    const [, tool, sessions, status] = match;
    if (!tool || !sessions || !status) continue;
    rows.push({ tool, sessions, status: status.trim() });
  }
  return rows;
}

/** Plugin check/sync headings (`── bundle ──`). */
export function parsePluginBundles(text: string): PluginBundleRow[] {
  const rows: PluginBundleRow[] = [];
  for (const raw of text.split('\n')) {
    const section = raw.match(SECTION);
    if (!section?.[1]) continue;
    rows.push({ name: section[1].trim() });
  }
  return rows;
}

/** Diff rows (`  ✓  ~ product → target: no changes`). */
export function parseDiffRows(text: string): DiffRow[] {
  const rows: DiffRow[] = [];
  for (const raw of text.split('\n')) {
    const match = raw.match(DIFF_ROW);
    if (!match) continue;
    const [, icon, product, target, result] = match;
    if (!product || !target) continue;
    rows.push({
      product,
      target,
      result: (result ?? '').trim() || 'unknown',
      ok: icon === '✓' || /no changes/i.test(result ?? ''),
    });
  }
  return rows;
}

export function mcpStatusTone(status: string): 'ok' | 'warn' | 'idle' | 'err' {
  const word = status.toLowerCase();
  if (word.includes('configured') || word === 'enabled') return 'ok';
  if (word.includes('disabled')) return 'warn';
  if (word.includes('not setup') || word.includes('unknown')) return 'idle';
  return 'idle';
}

export function insightsStatusTone(status: string): 'ok' | 'warn' | 'idle' | 'err' {
  switch (status) {
    case 'ok':
      return 'ok';
    case 'no_data':
      return 'idle';
    case 'unknown':
      return 'idle';
    default:
      return status.includes('err') ? 'err' : 'warn';
  }
}
