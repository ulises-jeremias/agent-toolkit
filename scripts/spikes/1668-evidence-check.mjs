// Gate 0 evidence checker. Validates claims, not artifact authenticity.
import { readFileSync } from 'node:fs';

export const JOURNEYS = Array.from({ length: 10 }, (_, i) => `D${String(i + 1).padStart(2, '0')}`);
const LEVELS = new Set(['P', 'S', 'R', 'M', 'U']);
const OUTCOMES = new Set(['pass', 'fail', 'blocked', 'unverified']);
const REQUIRED = ['toolkit_sha', 'package_version', 'platform', 'provider', 'workspace', 'timestamp_utc', 'steps_to_reproduce', 'observed', 'expected', 'tested_by'];

export function inspectEvidence(rows) {
  const errors = [];
  if (!Array.isArray(rows)) return { errors: ['expected JSON array of evidence rows'], releaseReady: false, journeys: {} };
  const journeys = Object.fromEntries(JOURNEYS.map(id => [id, { status: 'unverified', evidence: 0 }]));
  for (const [index, row] of rows.entries()) {
    const prefix = `row ${index + 1}`;
    if (!row || typeof row !== 'object' || Array.isArray(row)) { errors.push(`${prefix}: expected object`); continue; }
    const id = row.journey_id;
    if (!JOURNEYS.includes(id)) { errors.push(`${prefix}: unknown journey_id`); continue; }
    if (!OUTCOMES.has(row.outcome) || !LEVELS.has(row.evidence_level)) { errors.push(`${prefix}: invalid outcome/evidence_level`); continue; }
    if (row.mission !== 1667) errors.push(`${prefix}: mission must be 1667`);
    if (row.outcome === 'pass' && row.evidence_level === 'U') errors.push(`${prefix}: unverified evidence cannot pass`);
    if (row.evidence_level === 'P' && row.outcome === 'pass') {
      for (const field of REQUIRED) if (typeof row[field] !== 'string' || !row[field].trim() || row[field].includes('<')) errors.push(`${prefix}: missing concrete ${field}`);
      if (!Array.isArray(row.logs) || !row.logs.length) errors.push(`${prefix}: packaged pass requires log references`);
      if (!Array.isArray(row.screenshots) || !row.screenshots.length) errors.push(`${prefix}: packaged pass requires screenshot references`);
      if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(row.timestamp_utc ?? '') || Number.isNaN(Date.parse(row.timestamp_utc))) errors.push(`${prefix}: timestamp_utc must be valid UTC ISO-8601`);
    }
    journeys[id].evidence++;
    if (row.outcome === 'pass' && row.evidence_level === 'P' && !errors.some(e => e.startsWith(`${prefix}:`))) journeys[id].status = 'packaged-pass';
    else if (journeys[id].status !== 'packaged-pass' && row.outcome === 'fail') journeys[id].status = 'fail';
    else if (journeys[id].status === 'unverified' && row.outcome === 'blocked') journeys[id].status = 'blocked';
  }
  // A set of individually passing journeys is not a coherent installed build.
  // Only one exact package/source/platform combination can qualify a baseline.
  const qualifying = rows.filter(row => row && !Array.isArray(row) && row.outcome === 'pass' && row.evidence_level === 'P');
  const groups = new Map();
  for (const row of qualifying) {
    const key = JSON.stringify([row.toolkit_sha, row.package_version, row.platform]);
    if (!groups.has(key)) groups.set(key, new Set());
    groups.get(key).add(row.journey_id);
  }
  const required = JOURNEYS.slice(0, 7);
  const coherent = [...groups.values()].some(ids => required.every(id => ids.has(id)));
  return { errors, journeys, releaseReady: errors.length === 0 && coherent && required.every(id => journeys[id].status === 'packaged-pass') };
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  try {
    const result = inspectEvidence(JSON.parse(readFileSync(process.argv[2], 'utf8')));
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    if (!result.releaseReady) process.exitCode = 1;
  } catch (error) {
    process.stderr.write(`Evidence validation failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
