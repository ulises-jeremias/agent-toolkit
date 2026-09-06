module desktop_engine

import os
import x.json2
import crypto.sha256
import agent_toolkit_core

// SkillEntry mirrors catalogs/skill-catalog.yaml shape — super-potent: triggers, origin, products, kind.
pub struct SkillEntry {
pub mut:
	id          string
	name        string
	domain      string
	description string
	stability   string
	triggers    string
	origin_type string // first-party | upstream
	products    []string
	kind        string // skill | pack
}

// SkillStats is domain/stability aggregation for potent management.
pub struct SkillStats {
pub:
	total        int
	by_domain    map[string]int
	by_stability map[string]int
	by_origin    map[string]int
	installed    int
}

// SkillReceiptInfo is provenance-aware receipt for a skill (mirrors core InstallReceipt).
pub struct SkillReceiptInfo {
pub:
	skill_id     string
	installed    bool
	installed_at string
	version      string
	product      string
	artifacts    []string
	digest       string
	receipt_path string
}

// SkillProvenanceInfo mirrors .provenance.json per skill.
pub struct SkillProvenanceInfo {
pub:
	skill_id         string
	source_file      string
	source_digest    string
	generated_digest string
	verified         bool
	detail           string
}

// BuildDiagnostic mirrors schemas validation error.
pub struct BuildDiagnostic {
pub:
	path    string
	message string
	code    string
}

// skills_catalog returns the catalog supplied by the resolved toolkit root.
// A missing or unreadable catalog is an empty catalog. The UI must explain that
// the catalog is unavailable instead of inventing capability entries.
pub fn (mut e Engine) skills_catalog() []SkillEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	env := resolve_env()
	mut entries := []SkillEntry{}
	if data_file_exists(env, 'catalogs/skill-catalog.yaml') {
		text := data_file_read(env, 'catalogs/skill-catalog.yaml') or { '' }
		if text.len > 0 {
			lines := text.split_into_lines()
			mut cur := SkillEntry{}
			mut in_triggers := false
			for line in lines {
				t := line.trim_space()
				if t.starts_with('- id:') {
					if cur.id != '' {
						if cur.origin_type == '' {
							cur.origin_type = 'first-party'
						}
						if cur.kind == '' {
							cur.kind = 'skill'
						}
						entries << cur
					}
					cur = SkillEntry{
						id: t.all_after(':').trim_space()
					}
					in_triggers = false
				} else if t.starts_with('name:') && cur.id != '' && cur.name == '' {
					cur.name = t.all_after(':').trim_space()
				} else if t.starts_with('domain:') && cur.id != '' && cur.domain == '' {
					cur.domain = t.all_after(':').trim_space()
				} else if t.starts_with('description:') && cur.id != '' && cur.description == '' {
					raw := t.all_after(':').trim_space()
					cur.description = raw.trim("'").trim('"')
				} else if t.starts_with('stability:') && cur.id != '' && cur.stability == '' {
					cur.stability = t.all_after(':').trim_space()
				} else if t.starts_with('triggers:') && cur.id != '' {
					cur.triggers = t.all_after(':').trim_space().trim('[').trim(']').trim("'").trim('"')
					in_triggers = true
				} else if t.starts_with('origin:') && cur.id != '' {
					cur.origin_type = t.all_after(':').trim_space()
				} else if t.starts_with('kind:') && cur.id != '' {
					cur.kind = t.all_after(':').trim_space()
				} else if in_triggers && t.starts_with('- ') && cur.id != '' {
					cur.triggers += ' ' + t.all_after('-').trim_space()
				}
			}
			if cur.id != '' {
				if cur.origin_type == '' {
					cur.origin_type = 'first-party'
				}
				if cur.kind == '' {
					cur.kind = 'skill'
				}
				entries << cur
			}
		}
	}
	return entries
}

struct SkillsScored {
	entry SkillEntry
	score int
}

// skills_search performs fuzzy searchable filtering over the real catalog.
pub fn (mut e Engine) skills_search(query string, domain_filter string) []SkillEntry {
	cat := e.skills_catalog()
	q := query.trim_space().to_lower()
	d := domain_filter.trim_space().to_lower()
	if q == '' && d == '' {
		return cat.clone()
	}
	mut scored := []SkillsScored{}
	for s in cat {
		if d != '' && d != 'all' && s.domain.to_lower() != d {
			continue
		}
		if q == '' {
			scored << SkillsScored{
				entry: s
				score: 1000
			}
			continue
		}
		best := skill_best_score(q, s)
		if best >= 0 {
			scored << SkillsScored{
				entry: s
				score: best
			}
		}
	}
	scored.sort_with_compare(fn (a &SkillsScored, b &SkillsScored) int {
		if a.score > b.score {
			return -1
		}
		if a.score < b.score {
			return 1
		}
		if a.entry.id < b.entry.id {
			return -1
		}
		if a.entry.id > b.entry.id {
			return 1
		}
		return 0
	})
	mut out := []SkillEntry{}
	for sc in scored {
		out << sc.entry
	}
	return out
}

// skills_search_advanced is the super-potent variant with stability/origin filtering.
pub fn (mut e Engine) skills_search_advanced(query string, domain string, stability string, origin string) []SkillEntry {
	base := e.skills_search(query, domain)
	if stability == '' && origin == '' {
		return base
	}
	mut out := []SkillEntry{}
	for s in base {
		if stability != '' && s.stability.to_lower() != stability.to_lower() {
			continue
		}
		if origin != '' && s.origin_type.to_lower() != origin.to_lower() {
			continue
		}
		out << s
	}
	return out
}

fn skill_fuzzy_score(query string, target string) int {
	if query.len == 0 {
		return 1000
	}
	q := query.to_lower()
	t := target.to_lower()
	if t == q {
		return 10000
	}
	if t.contains(q) {
		return 9000 - t.len
	}
	mut qi := 0
	mut score := 0
	mut consecutive := 0
	mut last_match := -1
	for ti, ch in t {
		if qi < q.len && ch == q[qi] {
			score += 10
			if last_match == ti - 1 {
				score += 5
				consecutive++
			}
			if ti == 0 || t[ti - 1] == `/` || t[ti - 1] == ` ` || t[ti - 1] == `-` || t[ti - 1] == `_` || t[ti - 1] == `:` {
				score += 8
			}
			last_match = ti
			qi++
			if qi == q.len {
				break
			}
		}
	}
	if qi != q.len {
		return -1
	}
	score -= t.len / 10
	score += consecutive * 3
	return score
}

fn skill_best_score(query string, s SkillEntry) int {
	mut best := -1
	for field in [s.id, s.name, s.domain, s.description, s.triggers, s.origin_type] {
		sc := skill_fuzzy_score(query, field)
		if sc > best {
			best = sc
		}
	}
	return best
}

pub fn (mut e Engine) skill_detail(id string) !SkillEntry {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if id == '' {
		return error('skill id empty')
	}
	for s in e.skills_catalog() {
		if s.id == id {
			return s
		}
	}
	return error('skill not found: ${id}')
}

pub fn (mut e Engine) skills_installed() []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	raw := snap.data['installed_skills'] or { '' }
	if raw == '' {
		return []string{}
	}
	return raw.split(',').map(it.trim_space()).filter(it != '')
}

// skills_installed_detailed returns full entries for installed skills.
pub fn (mut e Engine) skills_installed_detailed() []SkillEntry {
	ids := e.skills_installed()
	if ids.len == 0 {
		return []SkillEntry{}
	}
	cat := e.skills_catalog()
	mut out := []SkillEntry{}
	for s in cat {
		if s.id in ids {
			out << s
		}
	}
	return out
}

// skills_stats returns aggregated counts — super-potent management.
pub fn (mut e Engine) skills_stats() SkillStats {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	cat := e.skills_catalog()
	mut by_domain := map[string]int{}
	mut by_stab := map[string]int{}
	mut by_origin := map[string]int{}
	for s in cat {
		by_domain[s.domain]++
		by_stab[s.stability]++
		by_origin[s.origin_type]++
	}
	installed := e.skills_installed().len
	return SkillStats{
		total: cat.len
		by_domain: by_domain
		by_stability: by_stab
		by_origin: by_origin
		installed: installed
	}
}

// skills_domains returns distinct 14 domains sorted.
pub fn (mut e Engine) skills_domains() []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	cat := e.skills_catalog()
	mut set := map[string]bool{}
	for s in cat {
		set[s.domain] = true
	}
	mut out := []string{}
	for k, _ in set {
		out << k
	}
	out.sort()
	return out
}

// skills_by_domain returns map domain -> entries.
pub fn (mut e Engine) skills_by_domain() map[string][]SkillEntry {
	cat := e.skills_catalog()
	mut m := map[string][]SkillEntry{}
	for s in cat {
		m[s.domain] << s
	}
	return m
}

// install_skill records the skill as selected in configuration state.
// Selection is configuration truth only: it is NOT an installation and writes
// no receipt or provenance evidence (S7 evidence truth). Receipts exist only
// when the core installer deploys real artifacts.
pub fn (mut e Engine) install_skill(id string) !u64 {
	if id == '' {
		return error('skill id empty')
	}
	_ := e.skill_detail(id)!
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('install-skill')
	cur := repo.snapshot().data['installed_skills'] or { '' }
	mut set := cur.split(',').map(it.trim_space()).filter(it != '')
	if id !in set {
		set << id
	}
	tx.set('installed_skills', set.join(','))
	tx.set('skills_count', set.len.str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// install_skills bulk-selects skills — configuration truth only, no receipts.
pub fn (mut e Engine) install_skills(ids []string) !u64 {
	if ids.len == 0 {
		return error('no skills selected')
	}
	for id in ids {
		_ := e.skill_detail(id)!
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('install-skills-bulk')
	cur := repo.snapshot().data['installed_skills'] or { '' }
	mut set := cur.split(',').map(it.trim_space()).filter(it != '')
	for id in ids {
		if id !in set {
			set << id
		}
	}
	tx.set('installed_skills', set.join(','))
	tx.set('skills_count', set.len.str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// install_skill_preview returns diff preview without mutating (dry-run).
pub fn (mut e Engine) install_skill_preview(id string) TargetDiff {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	installed := e.skills_installed()
	if id in installed {
		return TargetDiff{
			added: []string{}
			removed: []string{}
			modified: [id]
		}
	}
	return TargetDiff{
		added: [id]
		removed: []string{}
		modified: []string{}
	}
}

// toggle_skill installs if not installed else removes — one-click management.
pub fn (mut e Engine) toggle_skill(id string) !u64 {
	if id in e.skills_installed() {
		return e.remove_skill(id)!
	}
	return e.install_skill(id)!
}

pub fn (mut e Engine) remove_skill(id string) !u64 {
	if id == '' {
		return error('skill id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	cur := repo.snapshot().data['installed_skills'] or { '' }
	mut set := cur.split(',').map(it.trim_space()).filter(it != '')
	idx := set.index(id)
	if idx >= 0 {
		set.delete(idx)
	}
	mut tx := repo.begin('remove-skill')
	tx.set('installed_skills', set.join(','))
	tx.set('skills_count', set.len.str())
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

// skill_receipt returns real receipt evidence for a skill: the artifact
// records of core install receipts whose deployed artifacts include the
// skill's SKILL.md. Returns none when no real receipt covers the skill —
// selection alone is never receipt evidence.
pub fn (mut e Engine) skill_receipt(id string) ?SkillReceiptInfo {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	name := id.all_after('/')
	if name == '' {
		return none
	}
	needle := '/skills/${name}/SKILL.md'
	for r in agent_toolkit_core.list_install_receipts('') {
		for a in r.artifacts {
			if a.path.contains(needle) {
				return SkillReceiptInfo{
					skill_id: id
					installed: id in e.skills_installed()
					installed_at: r.installed_at
					version: r.version
					product: r.product
					digest: a.digest
					receipt_path: os.join_path(agent_toolkit_core.default_receipt_dir(),
						agent_toolkit_core.receipt_filename(r.target, r.product))
				}
			}
		}
	}
	return none
}

// skill_provenance returns real provenance evidence for a skill from the
// bundled plugins manifests (ADR-022). Returns none when no manifest records
// the skill — never a fabricated fallback.
pub fn (mut e Engine) skill_provenance(id string) ?SkillProvenanceInfo {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	name := id.all_after('/')
	if name == '' {
		return none
	}
	needle := '/skills/${name}/'
	for p in e.provenance_catalog() {
		if p.artifact_path.contains(needle) && p.artifact_path.ends_with('/SKILL.md') {
			return SkillProvenanceInfo{
				skill_id: id
				source_file: p.source_file
				source_digest: p.source_digest
				generated_digest: p.generated_digest
				verified: p.verified
				detail: p.detail
			}
		}
	}
	return none
}

// verify_skill_receipts checks that every selected skill still resolves in the
// catalog (real drift check). Selection without catalog backing is a genuine
// defect worth reporting; receipts are no longer fabricated to satisfy this.
pub fn (mut e Engine) verify_skill_receipts() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	for id in e.skills_installed() {
		if _ := e.skill_detail(id) {
			continue
		} else {
			diags << BuildDiagnostic{
				path: 'skills/${id}/SKILL.md'
				message: 'selected skill missing from resolved catalog'
				code: 'catalog_missing'
			}
		}
	}
	return diags
}

pub fn (mut e Engine) build_check() []BuildDiagnostic {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut diags := []BuildDiagnostic{}
	// real drift check: every selected skill must still resolve in the catalog
	for d in e.verify_skill_receipts() {
		diags << d
	}
	// stability warning for beta selections — real catalog metadata
	installed := e.skills_installed()
	for sid in installed {
		if detail := e.skill_detail(sid) {
			if detail.stability == 'beta' {
				diags << BuildDiagnostic{
					path: 'skills/${sid}/SKILL.md'
					message: 'beta stability — verify before production'
					code: 'beta_stability'
				}
			}
		} else {
			continue
		}
	}
	return diags
}

// skills_catalog_digest computes a real SHA-256 over canonical catalog
// material (sorted domain/id pairs). It replaces the former string-length
// sum that was labeled a digest. No engine lock is taken here:
// skills_catalog() locks internally (sync.Mutex is not reentrant).
fn (mut e Engine) skills_catalog_digest() string {
	mut ids := []string{}
	for s in e.skills_catalog() {
		ids << '${s.domain}/${s.id}'
	}
	ids.sort()
	return sha256.hexhash(ids.join('\n'))
}

pub fn (mut e Engine) build_preview() string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	cat := e.skills_catalog()
	digest := e.skills_catalog_digest()
	stats := e.skills_stats()
	return 'plugins-digest:${digest}:${cat.len}:installed=${stats.installed}'
}

// build_preview_detailed returns structured digest with provenance (ADR-022).
pub fn (mut e Engine) build_preview_detailed() string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	cat := e.skills_catalog()
	digest := e.skills_catalog_digest()
	snap := e.repo.snapshot()
	receipts := snap.data.keys().filter(it.starts_with('receipt:skill:')).len
	return json2.encode({
		'digest':     'plugins-digest:${digest}:${cat.len}'
		'receipts':   receipts.str()
		'provenance': 'catalogs/skill-catalog.yaml'
	},
		escape_unicode: true
	)
}
