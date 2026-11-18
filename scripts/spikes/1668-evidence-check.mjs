// Gate 0 evidence checker. Validates claims, not artifact authenticity.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const JOURNEYS = Array.from({ length: 10 }, (_, i) => `D${String(i + 1).padStart(2, '0')}`);
const LEVELS = new Set(['P', 'S', 'R', 'M', 'U']);
const OUTCOMES = new Set(['pass', 'fail', 'blocked', 'unverified']);
// Validate provenance syntax only; checksum matching to the actual installer
// remains an independent packaged-host acceptance requirement.
const SOURCE_SHA = /^[a-f0-9]{40}$/i;
const PACKAGE_CHECKSUM = /(?:^|\\s|[+;,])sha256:([a-f0-9]{64})(?=$|\\s|[;,])/i;
const REQUIRED = ['execution_id', 'toolkit_sha', 'package_version', 'platform', 'provider', 'workspace', 'timestamp_utc', 'steps_to_reproduce', 'observed', 'expected', 'tested_by'];

function validUtcTimestamp(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(value)) return false;
  const time = Date.parse(value);
  // Date.parse normalizes impossible calendar dates (for example February 30).
  // A normalized timestamp must not be treated as evidence of a real event.
  return Number.isFinite(time) && new Date(time).toISOString().slice(0, 19) === value.slice(0, 19);
}

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
      if (!SOURCE_SHA.test(row.toolkit_sha ?? '')) errors.push(`${prefix}: toolkit_sha must be a full 40-character Git SHA`);
      if (!PACKAGE_CHECKSUM.test(row.package_version ?? '')) errors.push(`${prefix}: package_version must include a full sha256 installer checksum`);
      // Non-empty arrays alone are not evidence: [null], [""], and template markers
      // must not qualify as packaged runs. This checks shape, not authenticity.
      for (const field of ['logs', 'screenshots']) {
        if (!Array.isArray(row[field]) || !row[field].length || row[field].some(ref => typeof ref !== 'string' || !ref.trim() || ref.includes('<'))) {
          errors.push(`${prefix}: packaged pass requires concrete ${field} references`);
        }
      }
      if (!validUtcTimestamp(row.timestamp_utc)) errors.push(`${prefix}: timestamp_utc must be valid UTC ISO-8601`);
    }
    journeys[id].evidence++;
    if (row.outcome === 'pass' && row.evidence_level === 'P' && !errors.some(e => e.startsWith(`${prefix}:`))) journeys[id].status = 'packaged-pass';
    else if (journeys[id].status !== 'packaged-pass' && row.outcome === 'fail') journeys[id].status = 'fail';
    else if (journeys[id].status === 'unverified' && row.outcome === 'blocked') journeys[id].status = 'blocked';
  }
  // A set of individually passing journeys is not a coherent installed build.
  // Only one exact package/source/platform AND uninterrupted execution can qualify a baseline.
  const qualifying = rows.filter(row => row && !Array.isArray(row) && row.outcome === 'pass' && row.evidence_level === 'P');
  const groups = new Map();
  for (const row of qualifying) {
    const key = JSON.stringify([row.toolkit_sha, row.package_version, row.platform, row.execution_id]);
    if (!groups.has(key)) groups.set(key, new Set());
    groups.get(key).add(row.journey_id);
  }
  const required = JOURNEYS.slice(0, 7);
  // A failed, blocked or unverified observation in the same uninterrupted trial
  // vetoes that trial, even when another row claims a packaged pass. Retests
  // must use a new execution_id rather than cherry-picking successful rows.
  const coherent = [...groups.entries()].some(([key, ids]) => {
    if (!required.every(id => ids.has(id))) return false;
    const [sha, pkg, platform, execution] = JSON.parse(key);
    // D01-D07 are an ordered uninterrupted journey. A complete set of IDs
    // with D07 timestamped before D03 is not evidence of that journey.
    // Equal timestamps are permitted because capture precision is seconds.
    const trialRows = rows.filter(row => row && !Array.isArray(row) &&
      required.includes(row.journey_id) && row.toolkit_sha === sha &&
      row.package_version === pkg && row.platform === platform &&
      row.execution_id === execution && row.outcome === 'pass' &&
      row.evidence_level === 'P');
    const times = required.map(id => trialRows.filter(row => row.journey_id === id));
    if (times.some(matches => matches.length !== 1)) return false;
    const ordered = times.map(matches => Date.parse(matches[0].timestamp_utc));
    if (ordered.some((time, index) => index > 0 && time < ordered[index - 1])) return false;
    // A single field trial must not silently switch the tested project or
    // active provider mid-task. D02 discovery may enumerate other providers;
    // D03-D07 must describe the same coding session context.
    const sessionRows = rows.filter(row => row && !Array.isArray(row) &&
      ['D03', 'D04', 'D05', 'D06', 'D07'].includes(row.journey_id) &&
      row.toolkit_sha === sha && row.package_version === pkg &&
      row.platform === platform && row.execution_id === execution &&
      row.outcome === 'pass' && row.evidence_level === 'P');
    if (new Set(sessionRows.map(row => row.workspace)).size !== 1 ||
        new Set(sessionRows.map(row => row.provider)).size !== 1 ||
        new Set(sessionRows.map(row => row.test_task)).size !== 1 ||
        sessionRows.some(row => typeof row.test_task !== 'string' || !row.test_task.trim() || row.test_task.includes('<'))) return false;
    return !rows.some(row => row && !Array.isArray(row) && required.includes(row.journey_id) &&
      row.toolkit_sha === sha && row.package_version === pkg && row.platform === platform &&
      row.execution_id === execution && (row.outcome !== 'pass' || row.evidence_level !== 'P'));
  });
  return { errors, journeys, releaseReady: errors.length === 0 && coherent && required.every(id => journeys[id].status === 'packaged-pass') };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const result = inspectEvidence(JSON.parse(readFileSync(process.argv[2], 'utf8')));
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    if (!result.releaseReady) process.exitCode = 1;
  } catch (error) {
    process.stderr.write(`Evidence validation failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
