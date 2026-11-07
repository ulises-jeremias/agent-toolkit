import { readFileSync } from 'node:fs';

// Gate 0 evidence validator; this is NOT a provider test or a release sign-off.
export const JOURNEYS = Array.from({ length: 10 }, (_, i) => `D${String(i + 1).padStart(2, '0')}`);
const LEVELS = new Set(['P', 'S', 'R', 'M', 'U']);
const OUTCOMES = new Set(['pass', 'fail', 'blocked', 'unverified']);
const PLACEHOLDER = /^(?:<[^>]+>|todo|tbd|unknown|n\/a|none|placeholder|test|example|dummy)$/i;
const meaningful = value => typeof value === 'string' && value.trim() !== '' && !PLACEHOLDER.test(value.trim());

export function validateLedger(rows) {
  const errors = [];
  if (!Array.isArray(rows)) return ['ledger must be a JSON array'];
  for (const [index, row] of rows.entries()) {
    const at = `row ${index + 1}`;
    if (!row || typeof row !== 'object' || Array.isArray(row)) { errors.push(`${at}: expected object`); continue; }
    if (!JOURNEYS.includes(row.journey_id)) errors.push(`${at}: invalid journey_id`);
    if (!LEVELS.has(row.evidence_level)) errors.push(`${at}: invalid evidence_level`);
    if (!OUTCOMES.has(row.outcome)) errors.push(`${at}: invalid outcome`);
    if (row.outcome === 'pass' && row.evidence_level === 'U') errors.push(`${at}: unverified evidence cannot pass`);
    if (row.evidence_level === 'P') {
      for (const field of ['toolkit_sha', 'package_version', 'platform', 'provider', 'timestamp_utc', 'steps_to_reproduce', 'observed', 'tested_by']) {
        if (!meaningful(row[field])) errors.push(`${at}: P evidence missing ${field}`);
      }
      if (!Array.isArray(row.logs) || row.logs.length === 0 || !row.logs.every(meaningful)) errors.push(`${at}: P evidence needs non-placeholder redacted artifact references in logs`);
      if (typeof row.timestamp_utc === 'string' && (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(row.timestamp_utc) || Number.isNaN(Date.parse(row.timestamp_utc)))) errors.push(`${at}: timestamp_utc must be valid UTC ISO-8601`);
      if (typeof row.toolkit_sha === 'string' && !/^[a-f0-9]{40}$/i.test(row.toolkit_sha)) errors.push(`${at}: invalid toolkit_sha`);
    }
  }
  return errors;
}

export function packagedGateStatus(rows) {
  const errors = validateLedger(rows);
  if (errors.length) return { ready: false, errors };
  const missing = JOURNEYS.slice(0, 7).filter(id => !rows.some(row => row.journey_id === id && row.outcome === 'pass' && row.evidence_level === 'P'));
  return { ready: missing.length === 0, missing };
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  try {
    const rows = JSON.parse(readFileSync(process.argv[2], 'utf8'));
    const status = packagedGateStatus(rows);
    console.log(JSON.stringify(status, null, 2));
    if (!status.ready) process.exitCode = 1;
  } catch (error) {
    console.error(`invalid ledger: ${error.message}`);
    process.exitCode = 1;
  }
}
