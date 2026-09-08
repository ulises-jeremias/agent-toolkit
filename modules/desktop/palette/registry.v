module palette

// S4A (#1119) — shared typed action & entity registry core.
//
// One registry supplies palette/search results from authoritative Engine state:
// catalog truth (skills, agents, targets, providers, products, packs, loops),
// configuration truth (installed skills, enabled targets/providers), and
// runtime truth (jobs, swarm runs). It never fabricates rows: a fresh engine
// yields navigation + catalog entities only, and runtime rows appear only when
// real records exist. Availability is truthful — an unavailable entry always
// carries a reason (e.g. "no bundled profile installer for this target").
//
// Governing contracts:
// - docs/desktop/UX_ARCHITECTURE.md §Shared action and entity model
// - docs/desktop/TRUTH_LEDGER.md (catalog ≠ configuration ≠ runtime ≠ evidence)
// - AGENTS.md global invariants (no manufactured production state)

import desktop_engine
import desktop.nav

// EntityKind classifies what a registry entry points at.
pub enum EntityKind {
	navigation
	app
	skill
	agent
	target
	mcp_provider
	product
	pack
	loop_template
	doctor_check
	job
	swarm_run
}

// RegistryEntry is one typed entity in the registry. `id` is the canonical
// domain identity (skill `core/assistant`, target `claude-code`, provider
// `github`, job/swarm run id) — never a CLI flag string.
pub struct RegistryEntry {
pub:
	kind               EntityKind
	id                 string // canonical id
	workspace          string // workspace-scoped context ('' = global)
	label              string
	category           string
	keywords           string
	desc               string
	keys               string // shortcut hint (navigation rows)
	available          bool
	unavailable_reason string
	panel              nav.PanelId
}

// action_id returns the stable palette action id for the entry.
pub fn (e RegistryEntry) action_id() string {
	return match e.kind {
		.navigation { 'nav:${e.id}' }
		.app { 'app:${e.id}' }
		.skill { 'skill:${e.id}' }
		.agent { 'agent:${e.id}' }
		.target { 'target:${e.id}' }
		.mcp_provider { 'mcp:${e.id}' }
		.product { 'product:${e.id}' }
		.pack { 'pack:${e.id}' }
		.loop_template { 'loop:${e.id}' }
		.doctor_check { 'doctor:${e.id}' }
		.job { 'job:${e.id}' }
		.swarm_run { 'swarm_run:${e.id}' }
	}
}

// is_valid checks required registry fields.
pub fn (e RegistryEntry) is_valid() bool {
	return e.id != '' && e.label != '' && e.category != ''
}

// production_nav_panels is the shell destination order used by the palette
// (matches the production panel indices in cmd/agent-toolkit-desktop/main.v).
const production_nav_panels = [
	nav.PanelId.world_view,
	nav.PanelId.skills,
	nav.PanelId.agents,
	nav.PanelId.mcp,
	nav.PanelId.targets,
	nav.PanelId.doctor,
	nav.PanelId.jobs,
	nav.PanelId.loops,
	nav.PanelId.swarm,
	nav.PanelId.workspace,
	nav.PanelId.products,
	nav.PanelId.onboarding,
	nav.PanelId.insights,
]

// nav_labels are the product labels for navigation entries (the "Go to …"
// rows). Navigation destinations are product surfaces, not entities, so the
// labels live with the registry that owns those rows.
const nav_labels = {
	nav.PanelId.world_view: 'Go to World'
	nav.PanelId.skills:     'Go to Skills'
	nav.PanelId.agents:     'Go to Agents'
	nav.PanelId.mcp:        'Go to MCP'
	nav.PanelId.targets:    'Go to Targets'
	nav.PanelId.doctor:     'Go to Doctor'
	nav.PanelId.jobs:       'Go to Jobs'
	nav.PanelId.loops:      'Go to Loops'
	nav.PanelId.swarm:      'Go to Swarm'
	nav.PanelId.workspace:  'Go to Workspace'
	nav.PanelId.products:   'Go to Products'
	nav.PanelId.onboarding: 'Go to Onboarding'
	nav.PanelId.insights:   'Go to Insights'
}

// nav_descs are the navigation row descriptions.
const nav_descs = {
	nav.PanelId.world_view: 'Office floor, desks and handoffs'
	nav.PanelId.skills:     'Search and install skills'
	nav.PanelId.agents:     'Browse holistic and specialist'
	nav.PanelId.mcp:        'Providers and health'
	nav.PanelId.targets:    'Enable platforms'
	nav.PanelId.doctor:     'Fix checks'
	nav.PanelId.jobs:       'Live processes'
	nav.PanelId.loops:      'Missions and schedules — inner/outer'
	nav.PanelId.swarm:      'GOD mailbox, Herdr/tmux, pair/team/full, approvals spend/scope/destructive'
	nav.PanelId.workspace:  'Context and memory'
	nav.PanelId.products:   'Manage products/packs membership & digest'
	nav.PanelId.onboarding: 'Super-potent wizard: workspace, personas, capability, target, product'
	nav.PanelId.insights:   'Telemetry — cost ledger, tool waterfall, OTel spans, budgets spark, CI watcher'
}

// nav_keys are the global shortcut hints shown on navigation rows.
const nav_keys = {
	nav.PanelId.world_view: '1'
	nav.PanelId.skills:     '2'
	nav.PanelId.agents:     '3'
	nav.PanelId.mcp:        '4'
	nav.PanelId.targets:    '5'
	nav.PanelId.doctor:     '6'
	nav.PanelId.jobs:       '7'
	nav.PanelId.loops:      '8'
	nav.PanelId.swarm:      '9'
	nav.PanelId.workspace:  '0'
	nav.PanelId.products:   'p'
	nav.PanelId.onboarding: 'o'
	nav.PanelId.insights:   'i'
}

// nav_route_path returns the router deep-link path for a panel.
fn nav_route_path(panel nav.PanelId) string {
	for r in nav.default_routes() {
		if r.panel == panel {
			return r.path
		}
	}
	return '/${panel.str()}'
}

// trim_desc clamps a description to one palette line.
fn trim_desc(s string) string {
	mut out := s.trim_space()
	// rune-safe: byte slicing can split a multi-byte UTF-8 character
	if out.runes().len > 120 {
		out = out.runes()[..120].string() + '…'
	}
	return out
}

// Registry is the shared typed action & entity registry. It caches its
// derivation per Engine revision: `maybe_refresh` is cheap every frame and
// rebuilds entries only when the Engine state moved.
pub struct Registry {
mut:
	engine   &desktop_engine.Engine
	entries  []RegistryEntry
	actions  []PaletteAction
	revision u64
	builds   u64
	// Install injection seams for tests ('' = real user home / config
	// authority), mirroring InstallOptionsEngine's own injection design.
	install_home_dir    string
	install_receipt_dir string
	// S4D: the shell reports the current appearance through
	// observe_appearance (apply_appearance is the only mutation point), so
	// appearance-undo prechecks compare real values instead of assuming.
	observed_appearance string
	// S4D (#1119): session-local execution journal (newest first, bounded)
	// + undo sequence. Fresh session ⇒ empty journal. Never persisted.
	journal  []RecentAction
	undo_seq u64
}

// new_registry binds a registry to an Engine.
pub fn new_registry(mut engine &desktop_engine.Engine) &Registry {
	return &Registry{
		engine: engine
	}
}

// maybe_refresh rebuilds the registry when the Engine revision moved (or on
// first use). Cheap when unchanged: one revision read.
pub fn (mut r Registry) maybe_refresh() {
	rev := r.engine.revision()
	if r.builds > 0 && rev == r.revision {
		return
	}
	r.entries = r.build_entries()
	r.actions = entries_to_actions(r.entries)
	r.revision = rev
	r.builds++
}

// all_entries returns the current registry entries (rebuilding if stale).
pub fn (mut r Registry) all_entries() []RegistryEntry {
	r.maybe_refresh()
	return r.entries.clone()
}

// all_actions returns the current actions (rebuilding if stale).
pub fn (mut r Registry) all_actions() []PaletteAction {
	r.maybe_refresh()
	return r.actions.clone()
}

// ScoredAction pairs an action with its fuzzy score for cross-source merge.
pub struct ScoredAction {
pub:
	action PaletteAction
	score  int
}

// filter returns matching actions ranked by fuzzy score (empty query keeps
// the stable build order).
pub fn (mut r Registry) filter(query string) []PaletteAction {
	return r.scored_filter(query).map(it.action)
}

// scored_filter returns matching actions with scores so callers can merge
// with other row sources without re-scoring.
pub fn (mut r Registry) scored_filter(query string) []ScoredAction {
	r.maybe_refresh()
	q := query.trim_space()
	if q == '' {
		mut out := []ScoredAction{}
		for a in r.actions {
			out << ScoredAction{
				action: a
				score: 1000
			}
		}
		return out
	}
	mut out := []ScoredAction{}
	for a in r.actions {
		s := action_best_score(q, a)
		if s >= 0 {
			out << ScoredAction{
				action: a
				score: s
			}
		}
	}
	out.sort_with_compare(fn (a &ScoredAction, b &ScoredAction) int {
		if a.score > b.score {
			return -1
		}
		if a.score < b.score {
			return 1
		}
		if a.action.label < b.action.label {
			return -1
		}
		if a.action.label > b.action.label {
			return 1
		}
		return 0
	})
	return out
}

// build_entries derives registry entries from authoritative Engine state.
// Order: navigation, catalog entities (skills, agents, targets, providers,
// products, packs, loops, doctor), then runtime records (jobs, swarm runs).
fn (mut r Registry) build_entries() []RegistryEntry {
	mut out := []RegistryEntry{}
	mut engine := r.engine
	out << build_nav_entries()
	out << build_app_entries()
	out << build_skill_entries(mut engine)
	out << build_agent_entries(mut engine)
	out << build_target_entries(mut engine)
	out << build_mcp_entries(mut engine)
	out << build_product_entries(mut engine)
	out << build_pack_entries(mut engine)
	out << build_loop_entries(mut engine)
	out << build_doctor_entries(mut engine)
	out << build_job_entries(mut engine)
	out << build_swarm_entries(mut engine)
	return out
}

// build_app_entries derives the application-level entity (S4C): the app
// itself — appearance, updates, uninstall. This replaces the legacy static
// command rows with one coherent, discoverable Setup entity.
fn build_app_entries() []RegistryEntry {
	return [RegistryEntry{
		kind: .app
		id: 'agent-toolkit'
		label: 'Agent Toolkit — Setup'
		category: 'Application'
		keywords: 'agent toolkit setup application appearance theme update uninstall settings preferences'
		desc: 'Appearance · updates · integrations — Tab for actions'
		available: true
		panel: .onboarding
	}]
}

// build_nav_entries derives navigation destinations in shell order.
fn build_nav_entries() []RegistryEntry {
	mut out := []RegistryEntry{}
	for panel in production_nav_panels {
		path := nav_route_path(panel)
		out << RegistryEntry{
			kind: .navigation
			id: path
			label: nav_labels[panel]
			category: 'Navigation'
			keywords: '${path} ${panel.label()} ${panel.str()} go to open panel'
			desc: nav_descs[panel]
			keys: nav_keys[panel]
			available: true
			panel: panel
		}
	}
	return out
}

// build_skill_entries derives catalog skill entities. Availability is always
// true (a catalog skill is inspectable); install state comes from real
// configuration and is stated in the description, never invented.
fn build_skill_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	mut installed := map[string]bool{}
	for id in engine.skills_installed() {
		installed[id] = true
	}
	for s in engine.skills_catalog() {
		state := if installed[s.id] { 'installed' } else { 'not installed' }
		out << RegistryEntry{
			kind: .skill
			id: s.id
			label: if s.name != '' { s.name } else { s.id }
			category: 'Skills'
			keywords: '${s.id} ${s.domain} ${s.name} ${s.description} ${s.triggers} skill'
			desc: '${s.domain} · ${state}'
			available: true
			panel: .skills
		}
	}
	return out
}

// build_agent_entries derives catalog agent personas. A catalog agent is not
// a running process — descriptions carry tier/role only, never activity.
fn build_agent_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for a in engine.agents_catalog() {
		out << RegistryEntry{
			kind: .agent
			id: a.id
			label: a.id
			category: 'Agents'
			keywords: '${a.id} ${a.role} ${a.tier} ${a.description} ${a.triggers} agent persona'
			desc: '${a.tier} · ${a.role}'
			available: true
			panel: .agents
		}
	}
	return out
}

// build_target_entries derives coding-tool target entities. A target is
// manageable through the registry only when a bundled profile exists; targets
// without one stay visible but unavailable with that reason.
fn build_target_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for t in engine.targets() {
		available := t.path != ''
		out << RegistryEntry{
			kind: .target
			id: t.id
			label: if t.name != '' { t.name } else { t.id }
			category: 'Targets'
			keywords: '${t.id} ${t.name} ${t.status} ${t.layer} target platform'
			desc: trim_desc('${t.status}${if t.detected { ' · detected' } else { '' }}')
			available: available
			unavailable_reason: if available {
				''
			} else {
				'no bundled profile installer for this target'
			}
			panel: .targets
		}
	}
	return out
}

// build_mcp_entries derives MCP provider entities from the bundled provider
// catalog. Providers without a packaged template are unavailable with reason.
fn build_mcp_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for m in engine.mcp_catalog() {
		available := m.template_path != ''
		state := if m.enabled { 'enabled' } else { m.health }
		out << RegistryEntry{
			kind: .mcp_provider
			id: m.id
			label: if m.name != '' { m.name } else { m.id }
			category: 'MCP'
			keywords: '${m.id} ${m.name} ${m.health} ${m.description} mcp provider'
			desc: trim_desc(state)
			available: available
			unavailable_reason: if available { '' } else { 'no bundled template for this provider' }
			panel: .mcp
		}
	}
	return out
}

// build_product_entries derives product entities (catalog truth).
fn build_product_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for p in engine.products_catalog() {
		out << RegistryEntry{
			kind: .product
			id: p.id
			label: if p.name != '' { p.name } else { p.id }
			category: 'Products'
			keywords: '${p.id} ${p.name} ${p.description} product pack bundle'
			desc: '${p.skill_ids.len} skills · ${p.pack_ids.len} packs'
			available: true
			panel: .products
		}
	}
	return out
}

// build_pack_entries derives pack entities (catalog truth).
fn build_pack_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for p in engine.packs_catalog() {
		out << RegistryEntry{
			kind: .pack
			id: p.id
			label: if p.name != '' { p.name } else { p.id }
			category: 'Packs'
			keywords: '${p.id} ${p.name} pack bundle docs'
			desc: '${p.skill_count} skills${if p.docs_only { ' · docs' } else { '' }}'
			available: true
			panel: .products
		}
	}
	return out
}

// build_loop_entries derives loop template entities (catalog truth, not runs).
fn build_loop_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for l in engine.loops_catalog() {
		goal := if l.goal != '' { l.goal } else { l.description }
		out << RegistryEntry{
			kind: .loop_template
			id: l.name
			label: l.name
			category: 'Loops'
			keywords: '${l.name} ${goal} ${l.cadence} ${l.stage} loop mission'
			desc: trim_desc('${l.cadence} · ${goal}')
			available: true
			panel: .loops
		}
	}
	return out
}

// build_doctor_entries derives doctor checks with their real status. The
// repair action is available only when the check reports fixable.
fn build_doctor_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for c in engine.doctor() {
		out << RegistryEntry{
			kind: .doctor_check
			id: c.id
			label: if c.name != '' { c.name } else { c.id }
			category: 'Doctor'
			keywords: '${c.id} ${c.name} ${c.category} ${c.status} ${c.message} doctor check'
			desc: trim_desc('${c.status} · ${c.message}')
			available: c.fixable
			unavailable_reason: if c.fixable { '' } else { 'check is not auto-fixable' }
			panel: .doctor
		}
	}
	return out
}

// build_job_entries derives job entities from real runtime records. A fresh
// engine has no jobs, so this contributes zero rows — honest emptiness.
fn build_job_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for j in engine.jobs_catalog() {
		out << RegistryEntry{
			kind: .job
			id: j.id
			workspace: j.work_dir
			label: if j.cmd != '' { j.cmd } else { j.id }
			category: 'Jobs'
			keywords: '${j.id} ${j.cmd} ${j.status} job process'
			desc: trim_desc('${j.status} · ${j.cmd}')
			available: true
			panel: .jobs
		}
	}
	return out
}

// build_swarm_entries derives swarm run entities from real runtime records.
fn build_swarm_entries(mut engine &desktop_engine.Engine) []RegistryEntry {
	mut out := []RegistryEntry{}
	for s in engine.swarm_list() {
		out << RegistryEntry{
			kind: .swarm_run
			id: s.id
			workspace: s.worktree
			label: trim_desc(s.task)
			category: 'Swarm'
			keywords: '${s.id} ${s.task} ${s.status} ${s.recipe} swarm run'
			desc: trim_desc('${s.status} · ${s.task}')
			available: true
			panel: .swarm
		}
	}
	return out
}

// entries_to_actions projects registry entries into palette actions.
fn entries_to_actions(entries []RegistryEntry) []PaletteAction {
	mut out := []PaletteAction{}
	for e in entries {
		out << PaletteAction{
			id: e.action_id()
			label: e.label
			category: e.category
			keywords: e.keywords
			desc: e.desc
			keys: e.keys
			panel: e.panel
			kind: e.kind
			entity_id: e.id
			workspace: e.workspace
			available: e.available
			unavailable_reason: e.unavailable_reason
		}
	}
	return out
}
