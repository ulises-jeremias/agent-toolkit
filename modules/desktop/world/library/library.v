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

// default_library_model starts empty until a real Engine snapshot is projected.
// The desktop must never present fixture entities as installed capabilities.
pub fn default_library_model() LibraryViewModel {
	return LibraryViewModel{
		revision: 0
		skills: []
		agents: []
		packs: []
		edges: []
	}
}

fn domain_color(d string) string {
	return match d {
		'core' { '#C45A3C' }
		'delivery' { '#8A9BA8' }
		'design' { '#C45A3C' }
		'forge' { '#C9A86B' }
		'integrations' { '#5A7D5A' }
		'data' { '#6B8A9B' }
		'tooling' { '#8A9BA8' }
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
	// Counts alone cannot identify entities. Keep the projection empty until a
	// catalog-backed Engine projection supplies real IDs and metadata.
	mut vm := default_library_model()
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

// skill_detail_via_engine reports unavailable until wired to Engine.skill_detail.
pub fn skill_detail_via_engine(skill_id string) string {
	_ = skill_id
	return ''
}

// build_preview_digest reports unavailable until wired to Engine.build_preview.
pub fn build_preview_digest() string {
	return ''
}
