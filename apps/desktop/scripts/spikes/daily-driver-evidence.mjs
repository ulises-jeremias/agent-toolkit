// Gate 0 evidence validation; never interprets mock/replay as packaged acceptance.
// This is an evidence-shape guard, NOT proof that a provider actually ran.
export const JOURNEYS = Object.freeze(Array.from({ length: 10 }, (_, i) => `D${String(i + 1).padStart(2, '0')}`));
const levels = new Set(['P', 'S', 'R', 'M', 'U']);
const outcomes = new Set(['pass', 'fail', 'blocked', 'unverified']);
const nonempty = (v) => typeof v === 'string' && v.trim().length > 0;

export function validateEvidence(rows) {
  if (!Array.isArray(rows)) return ['Evidence must be an array'];
  const errors = [];
  const seen = new Set();
  for (const [i, row] of rows.entries()) {
    const prefix = `row ${i + 1}`;
    if (!row || typeof row !== 'object' || Array.isArray(row)) {
      errors.push(`${prefix}: expected object`);
      continue;
    }
    if (!JOURNEYS.includes(row.journey_id)) errors.push(`${prefix}: unknown journey_id`);
    if (!outcomes.has(row.outcome)) errors.push(`${prefix}: invalid outcome`);
    if (!levels.has(row.evidence_level)) errors.push(`${prefix}: invalid evidence_level`);
    if (row.outcome === 'pass' && row.evidence_level !== 'P' && row.evidence_level !== 'S') {
      errors.push(`${prefix}: simulated/unverified evidence cannot pass a real-provider journey`);
    }
    if (row.evidence_level === 'P' || row.evidence_level === 'S') {
      for (const key of ['toolkit_sha', 'platform', 'provider', 'timestamp_utc', 'steps_to_reproduce', 'observed', 'tested_by']) {
        if (!nonempty(row[key])) errors.push(`${prefix}: missing ${key}`);
      }
      if (row.evidence_level === 'P' && !nonempty(row.package_version)) {
        errors.push(`${prefix}: packaged evidence requires package_version/checksum`);
      }
      if (!Array.isArray(row.logs) || row.logs.length === 0) {
        errors.push(`${prefix}: real-provider evidence requires a trace/log reference`);
      }
    }
    if (row.outcome === 'pass' && row.evidence_level === 'P') seen.add(row.journey_id);
  }
  return errors;
}

export function packagedGateStatus(rows) {
  const errors = validateEvidence(rows);
  const passed = new Set(Array.isArray(rows) ? rows.filter((r) => r?.outcome === 'pass' && r.evidence_level === 'P').map((r) => r.journey_id) : []);
  const missing = JOURNEYS.slice(0, 7).filter((id) => !passed.has(id));
  return { status: errors.length || missing.length ? 'unverified' : 'evidence-recorded-needs-human-review', missing, errors };
}
