module world

// World entities — Scranton desks and handoffs as Dunder Mifflin paper slips.
// Each WorldNode is a sales desk or paper station; edges are envelope handoffs
// routed via GOD mailbox. Tokens map to brass/oxide/slate office palette.
import time

// WorldNodeKind enumerates entity types derived from Engine State.
pub enum WorldNodeKind {
	repo
	skill
	agent
	pack
	loop
	job
	handoff
	check
	target
	swarm_agent
	activity
	unknown
}

// WorldNode is a spatial node in the Workshop.
pub struct WorldNode {
pub:
	id     string
	label  string
	kind   WorldNodeKind
	domain string // skill domain color
	status string // enabled / disabled / pass / fail / etc
	pos    Point
	color  string // token color per domain/status
	tier   string // holistic / specialist / etc
}

// WorldEdge is a directed dependency/handoff edge.
pub struct WorldEdge {
pub:
	id       string
	from     string
	to       string
	from_pos Point
	to_pos   Point
	label    string
	kind     string // membership | ownership | handoff | wire
}

// WorldProjection is the derived view of Engine State (nodes/edges).
pub struct WorldProjection {
pub:
	revision u64
	nodes    []WorldNode
	edges    []WorldEdge
}

// EntityFilter allows domain/product filtering.
pub struct EntityFilter {
pub:
	domain  string
	product string
	kind    WorldNodeKind = .unknown
}

// filter_nodes returns nodes matching filter.
pub fn filter_nodes(nodes []WorldNode, f EntityFilter) []WorldNode {
	if f.domain == '' && f.product == '' && f.kind == .unknown {
		return nodes.clone()
	}
	mut out := []WorldNode{}
	for n in nodes {
		if f.domain != '' && n.domain != f.domain {
			continue
		}
		if f.kind != .unknown && n.kind != f.kind {
			continue
		}
		// product filter stub: label contains product
		if f.product != '' && !n.label.contains(f.product) {
			continue
		}
		out << n
	}
	return out
}

// world_projection_from_state creates projection from raw Engine State map.
// Headless deterministic layout for 100-node workshop sample.
pub fn world_projection_from_state(data map[string]string, revision u64) WorldProjection {
	mut nodes := []WorldNode{}
	mut edges := []WorldEdge{}
	// repos
	if repos_str := data['repos'] {
		repos := repos_str.split(',')
		for i, r in repos {
			if r.trim_space() == '' {
				continue
			}
			nodes << WorldNode{
				id: 'repo:${r.trim_space()}'
				label: r.trim_space()
				kind: .repo
				domain: 'core'
				status: 'active'
				pos: Point{ x: 120 + f64(i % 10) * 36, y: 120 + f64(i / 10) * 32 }
				color: '#1B2F4A'
			}
		}
	}
	// skills
	skill_count := if 'skills_count' in data { data['skills_count'].int() } else { 0 }
	for i in 0 .. skill_count {
		nodes << WorldNode{
			id: 'skill:${i}'
			label: 'skill-${i}'
			kind: .skill
			domain: skill_domain_for_index(i)
			status: 'enabled'
			pos: Point{ x: 540 + f64(i % 12) * 24, y: 100 + f64(i / 12) * 22 }
			color: domain_color(skill_domain_for_index(i))
		}
	}
	// agents
	agent_count := if 'agents_count' in data { data['agents_count'].int() } else { 0 }
	for i in 0 .. agent_count {
		nodes << WorldNode{
			id: 'agent:${i}'
			label: 'agent-${i}'
			kind: .agent
			domain: 'agents'
			status: 'holistic'
			pos: Point{ x: 560 + f64(i % 6) * 44, y: 180 + f64(i / 6) * 28 }
			color: '#C45A3C'
			tier: if i < 11 {
				'holistic'} else if i < 13 { 'orchestrator' } else { 'specialist' }
		}
	}
	// loops
	if loops_str := data['loops'] {
		loops := loops_str.split(',')
		for i, l in loops {
			if l.trim_space() == '' {
				continue
			}
			nodes << WorldNode{
				id: 'loop:${l.trim_space()}'
				label: l.trim_space()
				kind: .loop
				domain: 'loops'
				status: 'idle'
				pos: Point{ x: 120 + f64(i % 5) * 48, y: 460 + f64(i / 5) * 28 }
				color: '#C45A3C'
			}
		}
	}
	// jobs
	if jobs_str := data['jobs'] {
		jobs := jobs_str.split(',')
		for i, j in jobs {
			if j.trim_space() == '' {
				continue
			}
			nodes << WorldNode{
				id: 'job:${j.trim_space()}'
				label: j.trim_space()
				kind: .job
				domain: 'runtime'
				status: 'running'
				pos: Point{ x: 380 + f64(i % 5) * 48, y: 480 + f64(i / 5) * 28 }
				color: '#6B8F71'
			}
		}
	}
	// handoffs
	if handoffs_str := data['handoffs'] {
		handoffs := handoffs_str.split(',')
		for i, h in handoffs {
			if h.trim_space() == '' {
				continue
			}
			parts := h.trim_space().split('->')
			from_id := if parts.len > 1 { parts[0].trim_space() } else { 'agent:0' }
			to_id := if parts.len > 1 { parts[1].trim_space() } else { parts[0].trim_space() }
			nodes << WorldNode{
				id: 'handoff:${h.trim_space()}'
				label: h.trim_space()
				kind: .handoff
				domain: 'swarm'
				status: 'pending'
				pos: Point{ x: 700 + f64(i % 4) * 52, y: 400 + f64(i / 4) * 30 }
				color: '#B23C1F'
			}
			edges << WorldEdge{
				id: 'edge:handoff:${h.trim_space()}'
				from: from_id
				to: to_id
				from_pos: Point{ x: 700, y: 420 }
				to_pos: Point{ x: 800, y: 480 }
				label: h.trim_space()
				kind: 'handoff'
			}
		}
	}
	// skill->agent ownership edges (stub)
	for i in 0 .. skill_count {
		if agent_count > 0 {
			owner := i % agent_count
			s_node := nodes.filter(it.id == 'skill:${i}')[0] or { continue }
			a_node := nodes.filter(it.id == 'agent:${owner}')[0] or { continue }
			edges << WorldEdge{
				id: 'edge:skill:${i}->agent:${owner}'
				from: s_node.id
				to: a_node.id
				from_pos: s_node.pos
				to_pos: a_node.pos
				label: 'owns'
				kind: 'ownership'
			}
		}
	}
	_ = time.now().unix()
	return WorldProjection{
		revision: revision
		nodes: nodes
		edges: edges
	}
}

// skill_domain_for_index maps index to domain palette (mirrors LibraryStation).
pub fn skill_domain_for_index(i int) string {
	domains := ['core', 'delivery', 'design', 'forge', 'integrations', 'data', 'tooling', 'ops',
		'loops', 'agentic-security', 'architecture', 'cloud', 'accessibility', 'quality']
	return domains[i % domains.len]
}

// domain_color returns token color per domain — Dunder paper palette (no purple).
pub fn domain_color(domain string) string {
	return match domain {
		'core' { '#1B2F4A' }
		'delivery' { '#C45A3C' }
		'design' { '#B23C1F' }
		'forge' { '#8A7530' }
		'integrations' { '#6B8F71' }
		'data' { '#5A7A8A' }
		'tooling' { '#6B6560' }
		'ops' { '#7A6B5A' }
		'loops' { '#8B7F6E' }
		else { '#9E9A95' }
	}
}

// distinct_until_changed checks if projection changed (revision or node/edge count).
pub fn distinct_until_changed(prev WorldProjection, next WorldProjection) bool {
	if prev.revision != next.revision {
		return true
	}
	if prev.nodes.len != next.nodes.len {
		return true
	}
	if prev.edges.len != next.edges.len {
		return true
	}
	return false
}
