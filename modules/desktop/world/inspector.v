module world

// InspectorKind enumerates detail overlays.
pub enum InspectorKind {
	skill
	agent
	pack
	check
	target
	handoff
	approval
	budget
	trace
	activity
	none
}

// InspectorContent is the detail shown when a node/edge is selected.
pub struct InspectorContent {
pub:
	kind      InspectorKind
	entity_id string
	title     string
	body      string
	meta      map[string]string
	fixable   bool
}

// Inspector is the floating overlay for selected entity.
pub struct Inspector {
mut:
	current ?InspectorContent
	history []InspectorContent
}

// new_inspector creates an empty inspector.
pub fn new_inspector() Inspector {
	return Inspector{}
}

// open shows content for entity.
pub fn (mut ins Inspector) open(content InspectorContent) {
	ins.current = content
	ins.history << content
}

// close clears current selection.
pub fn (mut ins Inspector) close() {
	ins.current = none
}

// current returns current content if any.
pub fn (ins Inspector) current_content() ?InspectorContent {
	return ins.current
}

// is_open reports whether inspector has selection.
pub fn (ins Inspector) is_open() bool {
	return ins.current != none
}

// highlight_entity maps cross-link from Activity Journal / timeline dot → canvas entity.
// Returns true if entity exists in projection.
pub fn highlight_entity(entity_id string, proj WorldProjection) bool {
	for n in proj.nodes {
		if n.id == entity_id {
			return true
		}
	}
	for e in proj.edges {
		if e.id == entity_id {
			return true
		}
	}
	return false
}

// virtualized_inspector_rows returns virtualized row count for SKILL.md / AGENT.md preview.
pub fn virtualized_inspector_rows(body string) int {
	if body.len == 0 {
		return 0
	}
	lines := body.split('\n')
	return lines.len
}
