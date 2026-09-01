module library

import desktop_engine.state as engine_state
import desktop_engine.eventbus

// LibraryStation is the spatial alcove for skills/agents/packs.
pub struct LibraryStation {
mut:
	view_model LibraryViewModel
	bus        &eventbus.ToolkitEventBus
	repo       &engine_state.StateRepository
}

// LibraryViewModel projects Engine State → canvas nodes for Library.
pub struct LibraryViewModel {
pub:
	revision       u64
	skills         []LibrarySkillNode
	agents         []LibraryAgentNode
	packs          []LibraryPackNode
	edges          []LibraryEdge
	filter_domain  string
	search_query   string
	orphan_warning bool
}

// LibrarySkillNode is a skill node colored by domain.
pub struct LibrarySkillNode {
pub:
	id      string
	label   string
	domain  string
	color   string
	product string
	owner   string // holistic_owner per registry.yaml
}

// LibraryAgentNode is an agent node with tier badges.
pub struct LibraryAgentNode {
pub:
	id    string
	label string
	tier  string // holistic | orchestrator | specialist | archived
	color string
	muted bool
}

// LibraryPackNode is a pack node (docs-only badge per ADR-006).
pub struct LibraryPackNode {
pub:
	id        string
	label     string
	skills    []string
	docs_only bool
}

// LibraryEdge is membership / ownership / pack→skill.
pub struct LibraryEdge {
pub:
	from string
	to   string
	kind string // membership | ownership | pack
}

// LibraryInspector shows SKILL.md / AGENT.md preview via Engine compiler path.
pub struct LibraryInspector {
pub:
	skill_detail   string // SKILL.md frontmatter+body
	agent_detail   string // AGENT.md preview
	digest_preview string // build_preview digest
}

// default_library_model creates model from 587-line catalog fixture (116 skills, 18 agents, 7 packs).
pub fn default_library_model() LibraryViewModel {
	mut skills := []LibrarySkillNode{cap: 116}
	domains := ['core', 'delivery', 'design', 'forge', 'integrations', 'data', 'tooling', 'ops',
		'loops', 'agentic-security', 'architecture', 'cloud', 'accessibility', 'quality']
	for i in 0 .. 116 {
		d := domains[i % domains.len]
		skills << LibrarySkillNode{
			id: 'skill-${i}'
			label: 'skill-${i} — ${d}'
			domain: d
			color: domain_color(d)
			product: if i % 3 == 0 { 'product-a' } else { 'product-b' }
			owner: 'agent-${i % 18}'
		}
	}
	mut agents := []LibraryAgentNode{cap: 18}
	for i in 0 .. 18 {
		tier := if i < 11 {
			'holistic'
		} else if i < 13 { 'orchestrator' } else { 'specialist' }
		muted := false
		agents << LibraryAgentNode{
			id: 'agent-${i}'
			label: 'agent-${i}'
			tier: tier
			color: '#0891b2'
			muted: muted
		}
	}
	// 7 archived collapsed (references/) muted
	mut archived := []LibraryAgentNode{cap: 7}
	for i in 0 .. 7 {
		archived << LibraryAgentNode{
			id: 'archived-${i}'
			label: 'archived-${i}'
			tier: 'archived'
			color: '#64748b'
			muted: true
		}
	}
	agents << archived

	mut packs := []LibraryPackNode{cap: 7}
	for i in 0 .. 7 {
		packs << LibraryPackNode{
			id: 'pack-${i}'
			label: 'pack-${i}'
			skills: ['skill-${i * 10}', 'skill-${i * 10 + 1}']
			docs_only: true
		}
	}
	mut edges := []LibraryEdge{}
	for s in skills {
		edges << LibraryEdge{ from: s.id, to: s.product, kind: 'membership' }
		edges << LibraryEdge{ from: s.id, to: s.owner, kind: 'ownership' }
	}
	for p in packs {
		for sid in p.skills {
			edges << LibraryEdge{ from: p.id, to: sid, kind: 'pack' }
		}
	}
	return LibraryViewModel{
		revision: 1
		skills: skills
		agents: agents
		packs: packs
		edges: edges
	}
}

fn domain_color(d string) string {
	return match d {
		'core' { '#7c3aed' }
		'delivery' { '#0891b2' }
		'design' { '#e11d48' }
		'forge' { '#ea580c' }
		'integrations' { '#16a34a' }
		'data' { '#0e7490' }
		'tooling' { '#6b7280' }
		'ops' { '#854d0e' }
		'loops' { '#7c2d12' }
		else { '#64748b' }
	}
}

// filtered returns debounced search+domain filtered skills (distinct-until-changed caller handles).
pub fn (vm LibraryViewModel) filtered(domain string, query string) []LibrarySkillNode {
	mut out := []LibrarySkillNode{}
	for s in vm.skills {
		if domain != '' && s.domain != domain {
			continue
		}
		if query != '' && !s.label.contains(query) {
			continue
		}
		out << s
	}
	return out
}

// orphan_check returns true if every skill has owner in 11+2+6 set.
pub fn (vm LibraryViewModel) orphan_check() bool {
	// valid owners are agent-0..agent-17 (11 holistic +2 orchestrators +6 specialists)
	// archived not valid owners
	for s in vm.skills {
		found := false
		for a in vm.agents {
			if a.id == s.owner && !a.muted {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

// new_library_station creates station bound to repo/bus.
pub fn new_library_station(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &LibraryStation {
	return &LibraryStation{
		view_model: default_library_model()
		repo: repo
		bus: bus
	}
}

// derive_from_state projects State snapshot (skills_count, agents_count).
pub fn derive_library_from_state(s engine_state.State) LibraryViewModel {
	// honor State data counts if present, else default 116/18
	skill_cnt := if 'skills_count' in s.data { s.data['skills_count'].int() } else { 116 }
	agent_cnt := if 'agents_count' in s.data { s.data['agents_count'].int() } else { 18 }
	mut vm := default_library_model()
	if skill_cnt != 116 {
		vm.skills = vm.skills[..if skill_cnt < vm.skills.len { skill_cnt } else { vm.skills.len }]
	}
	if agent_cnt != 18 {
		// keep first agent_cnt from non-archived
		vm.agents = vm.agents[..if agent_cnt < 18 { agent_cnt } else { 18 }]
	}
	vm.revision = s.revision
	vm.orphan_warning = !vm.orphan_check()
	return vm
}

// on_bus_event handles StateWatcher → EventBus debounce.
pub fn (mut s LibraryStation) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .state_changed && ev.kind != .watcher_invalidated {
		return false
	}
	next := derive_library_from_state(snap)
	if next.revision == s.view_model.revision && next.skills.len == s.view_model.skills.len {
		return false
	}
	s.view_model = next
	return true
}

// current returns view model.
pub fn (s LibraryStation) current() LibraryViewModel {
	return s.view_model
}

// skill_detail_via_engine stubs Engine.skill_detail(id) — no direct file read.
pub fn skill_detail_via_engine(skill_id string) string {
	return '---\nname: ${skill_id}\ndescription: synthetic SKILL.md for ${skill_id}\n---\n# ${skill_id}\nBody preview via Engine.skill_detail — no direct file read.'
}

// build_preview_digest stubs Engine.build_preview digest.
pub fn build_preview_digest() string {
	return 'sha256:abc123-engine-build-preview'
}
