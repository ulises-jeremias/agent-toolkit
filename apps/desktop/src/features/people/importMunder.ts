import type { Person } from '../../lib/api';

export interface MunderReview {
  person: Person;
  ignored: string[];
}

const mapped = new Set([
  'spec',
  'id',
  'name',
  'role',
  'goal',
  'provider',
  'model',
  'skills',
  'mcp_servers',
  'character',
  'accent',
  'capabilities',
  'budget',
  'isolation',
  // Canonical Munder Difflin hire@1 field names (src/shared/hire.ts):
  // `description` is consumed below as role/goal fallback, `mcpServers`,
  // `isolate` and `tokenCap` map onto the Person model. `commandFlags`,
  // `author` and `homepage` deliberately stay unmapped: they are disclosed
  // in the review's ignored list, never executed or stored.
  'description',
  'mcpServers',
  'isolate',
  'tokenCap',
]);

function textField(value: unknown, field: string, required = false): string | undefined {
  if (value === undefined || value === null || value === '') {
    if (required) throw new Error(`${field} is required`);
    return undefined;
  }
  if (typeof value !== 'string') throw new Error(`${field} must be text`);
  return value.trim();
}

function refs(value: unknown, field: string): string[] | undefined {
  if (value === undefined) return undefined;
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    throw new Error(`${field} must be a list of references`);
  }
  return value;
}

function slug(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

export function reviewMunderHire(raw: string): MunderReview {
  if (raw.length > 65536) throw new Error('Import file is too large');
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    throw new Error('Import file is not valid JSON');
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Import must be an object');
  const hire = value as Record<string, unknown>;
  if (hire.spec !== 'munder-difflin/hire@1') throw new Error('Expected munder-difflin/hire@1');
  const name = textField(hire.name, 'Name', true)!;
  // Canonical hires carry `description`, not `role`; real gallery manifests
  // (for example jim-pr-reviewer) have no role at all. Fall back to the
  // description so a genuine hire imports instead of failing, and let the
  // reviewer adjust the derived role before saving.
  const role = textField(hire.role, 'Role') ?? textField(hire.description, 'Description');
  if (!role) throw new Error('Role or description is required');
  const goal = textField(hire.goal, 'Goal') ?? textField(hire.description, 'Description');
  if (!goal) throw new Error('Goal or description is required');
  const sourceId = textField(hire.id, 'ID');
  const id = slug(sourceId || name);
  const roleId = slug(role);
  if (!id || !roleId) throw new Error('Name and role need letters or numbers');
  let isolation = textField(hire.isolation, 'Isolation');
  if (isolation && !['inherited', 'worktree', 'session'].includes(isolation)) {
    throw new Error('Isolation is not supported; review the source before importing');
  }
  if (hire.isolate !== undefined) {
    if (typeof hire.isolate !== 'boolean') throw new Error('Isolate must be true or false');
    if (!isolation) isolation = hire.isolate ? 'worktree' : 'inherited';
  }
  let budget: Person['budget'];
  if (hire.budget !== undefined) {
    if (!hire.budget || typeof hire.budget !== 'object' || Array.isArray(hire.budget)) {
      throw new Error('Budget must be an object');
    }
    const sourceBudget = hire.budget as Record<string, unknown>;
    budget = {};
    for (const key of ['max_tokens', 'max_cost_usd', 'max_seconds'] as const) {
      const amount = sourceBudget[key];
      if (amount === undefined) continue;
      if (typeof amount !== 'number' || !Number.isFinite(amount)) throw new Error(`Budget ${key} must be a number`);
      budget[key] = amount;
    }
  }
  let tokenCapIgnored = false;
  if (hire.tokenCap !== undefined) {
    if (typeof hire.tokenCap !== 'number' || !Number.isInteger(hire.tokenCap) || hire.tokenCap <= 0) {
      throw new Error('Token cap must be a positive whole number');
    }
    if (hire.tokenCap > 1_000_000_000) {
      // Person budgets cap at 1e9; never clamp silently.
      tokenCapIgnored = true;
    } else {
      // An explicit budget.max_tokens wins; tokenCap only fills the gap.
      budget = { max_tokens: hire.tokenCap, ...(budget ?? {}) };
    }
  }
  const character = textField(hire.character, 'Character');
  const accent = textField(hire.accent, 'Accent');
  const sourceRef = sourceId && /^[a-zA-Z0-9][a-zA-Z0-9._:/-]*$/.test(sourceId) ? sourceId : undefined;
  const person: Person = {
    spec: 'agent-toolkit/person@1',
    id,
    name,
    role: roleId,
    goal,
    archived: false,
    preferred_provider: textField(hire.provider, 'Provider'),
    preferred_model: textField(hire.model, 'Model'),
    skills: refs(hire.skills, 'Skills'),
    mcp_servers: refs(hire.mcp_servers ?? hire.mcpServers, 'MCP servers'),
    capabilities: refs(hire.capabilities, 'Capabilities'),
    isolation: isolation as Person['isolation'],
    budget,
    import_source: {
      spec: 'munder-difflin/hire@1',
      id: sourceRef,
      review_required: true,
      auto_spawn: false,
      auto_install: false,
      live_sync: false,
      original_character: character,
      original_accent: accent,
    },
  };
  const ignored = Object.keys(hire).filter((key) => !mapped.has(key));
  // `description` is only consumed as the role/goal fallback; when explicit
  // role and goal are present it has no Person home and must be disclosed.
  if (hire.description !== undefined && hire.role !== undefined && hire.goal !== undefined) {
    ignored.push('description');
  }
  if (tokenCapIgnored) ignored.push('tokenCap (exceeds the Toolkit budget limit; set a budget after importing)');
  if (sourceId && !sourceRef) ignored.push('id (source reference is not portable)');
  if (hire.budget && typeof hire.budget === 'object' && !Array.isArray(hire.budget)) {
    for (const key of Object.keys(hire.budget)) {
      if (!['max_tokens', 'max_cost_usd', 'max_seconds'].includes(key)) ignored.push(`budget.${key}`);
    }
  }
  return { person, ignored: ignored.sort() };
}
