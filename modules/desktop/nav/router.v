module nav

import desktop.state as app_state

// PanelId enumerates every shell panel. Panels register via dock tabs;
// selection → AppState derived view model (push-based, not polling).
pub enum PanelId {
	skills
	agents
	products
	plugins
	loops
	swarm
	workspace
	memory
	mcp
	doctor
	world_view
	activity
	unknown
}

// label returns human label for PanelId.
pub fn (p PanelId) label() string {
	return match p {
		.skills { 'Skills' }
		.agents { 'Agents' }
		.products { 'Products' }
		.plugins { 'Plugins' }
		.loops { 'Loops' }
		.swarm { 'Swarm' }
		.workspace { 'Workspace' }
		.memory { 'Memory' }
		.mcp { 'MCP' }
		.doctor { 'Doctor' }
		.world_view { 'World View' }
		.activity { 'Activity' }
		.unknown { 'Unknown' }
	}
}

// from_string parses PanelId (case-insensitive fallback unknown).
pub fn panel_id_from_string(s string) PanelId {
	l := s.to_lower()
	return match l {
		'skills' { .skills }
		'agents' { .agents }
		'products' { .products }
		'plugins' { .plugins }
		'loops' { .loops }
		'swarm' { .swarm }
		'workspace' { .workspace }
		'memory' { .memory }
		'mcp' { .mcp }
		'doctor' { .doctor }
		'world_view', 'worldview', 'world-view' { .world_view }
		'activity' { .activity }
		else { .unknown }
	}
}

// Route binds a PanelId to its capability/runtime plane + placeholder handling.
pub struct Route {
pub:
	panel PanelId
	plane string // capability | runtime | view
	path  string // deep-link path e.g. /skills
}

// default_routes returns all shell panels + placeholder Capability/Runtime routes.
pub fn default_routes() []Route {
	return [
		Route{ panel: .skills, plane: 'capability', path: '/skills' },
		Route{ panel: .agents, plane: 'capability', path: '/agents' },
		Route{ panel: .products, plane: 'capability', path: '/products' },
		Route{ panel: .plugins, plane: 'capability', path: '/plugins' },
		Route{ panel: .loops, plane: 'runtime', path: '/loops' },
		Route{ panel: .swarm, plane: 'runtime', path: '/swarm' },
		Route{ panel: .workspace, plane: 'runtime', path: '/workspace' },
		Route{ panel: .memory, plane: 'runtime', path: '/memory' },
		Route{ panel: .mcp, plane: 'runtime', path: '/mcp' },
		Route{ panel: .doctor, plane: 'runtime', path: '/doctor' },
		Route{ panel: .world_view, plane: 'view', path: '/world' },
		Route{ panel: .activity, plane: 'view', path: '/activity' },
	]
}

// ViewModel is the router's projected view derived from AppState (State→View).
pub struct ViewModel {
pub:
	active   PanelId
	route    Route
	revision u64
	title    string
}

// Router owns panel registration + active selection → ViewModel projection.
// Binding: AppState → EventBus → router projection (debounce, distinct-until-changed).
// No CLI subprocess for state reads (#1021 AC).
pub struct Router {
mut:
	routes        map[string]Route
	active        PanelId
	last_revision u64
	// subscribers for ViewModel updates (cap 64)
	subscribers []chan ViewModel
	emitted     u64
}

// new_router creates a router with all default panel routes registered.
pub fn new_router() &Router {
	mut m := map[string]Route{}
	for r in default_routes() {
		m[r.panel.str()] = r
	}
	return &Router{
		routes: m
		active: .skills
	}
}

// active_panel returns currently selected panel.
pub fn (r Router) active_panel() PanelId {
	return r.active
}

// route_for returns Route for panel, or unknown placeholder.
pub fn (r Router) route_for(panel PanelId) Route {
	if route := r.routes[panel.str()] {
		return route
	}
	return Route{
		panel: .unknown
		plane: 'view'
		path: '/unknown'
	}
}

// register adds or replaces a panel route (dock tab registration point).
pub fn (mut r Router) register(route Route) {
	r.routes[route.panel.str()] = route
}

// navigate selects panel → updates ViewModel.
// Returns new ViewModel; distinct-until-changed suppresses duplicate navigations.
pub fn (mut r Router) navigate(panel PanelId) !ViewModel {
	if panel == .unknown {
		return error('unknown panel')
	}
	if _ := r.routes[panel.str()] {
		// ok
	} else {
		return error('panel not registered: ${panel}')
	}
	if r.active == panel {
		return error('already active')
	}
	r.active = panel
	vm := ViewModel{
		active: panel
		route: r.route_for(panel)
		revision: r.last_revision
		title: panel.label()
	}
	r.emit(vm)
	return vm
}

// project_app_state maps AppState → ViewModel.
// Deep-link: AppState revision drives active panel; View updates within one EventBus→frame tick.
// Pure projection: no I/O, no shell.
pub fn (mut r Router) project_app_state(s app_state.AppState) ?ViewModel {
	// distinct-until-changed on revision
	if s.revision == r.last_revision {
		return none
	}
	r.last_revision = s.revision
	// Example deep-link: if AppState dock_layout encodes target panel via "panel:xxx" value
	mut panel := PanelId.skills
	if s.dock_layout.contains('panel:') {
		raw := s.dock_layout.all_after('panel:').split(',')[0].trim_space()
		parsed := panel_id_from_string(raw)
		if parsed != .unknown {
			panel = parsed
		}
	}
	// If active already equals derived, still emit revision update
	r.active = panel
	vm := ViewModel{
		active: panel
		route: r.route_for(panel)
		revision: s.revision
		title: panel.label()
	}
	r.emit(vm)
	return vm
}

// subscribe registers ch for ViewModel updates.
pub fn (mut r Router) subscribe(ch chan ViewModel) {
	r.subscribers << ch
}

// emit fans out to subscribers (non-blocking cap 64).
fn (mut r Router) emit(vm ViewModel) {
	r.emitted++
	for ch in r.subscribers {
		if ch.len < 64 {
			ch <- vm
		}
	}
}

// emitted_count reports navigation emissions.
pub fn (r Router) emitted_count() u64 {
	return r.emitted
}

// all_panels returns all registered panel ids.
pub fn (r Router) all_panels() []PanelId {
	mut out := []PanelId{}
	for _, route in r.routes {
		out << route.panel
	}
	return out
}
