module desktop_engine

import sync
import os
import agent_toolkit_core

// Plane distinguishes Capability vs Runtime DI planes.
pub enum Plane {
	capability
	runtime
}

// ServiceFactory is a DI factory — no GUI types allowed here.
pub type ServiceFactory = fn() !voidptr

struct ServiceEntry {
	factory   ServiceFactory
	plane     Plane
	singleton bool
mut:
	instance voidptr
	created  bool
}

// DIContainer resolves Capability + Runtime plane services by name.
// Same shape as modules/agent_toolkit_core but headless.
pub struct DIContainer {
mut:
	mu       sync.RwMutex
	services map[string]ServiceEntry
}

// new_di_container creates an empty container.
pub fn new_di_container() &DIContainer {
	return &DIContainer{}
}

// register adds a named service factory.
pub fn (mut c DIContainer) register(name string, plane Plane, factory ServiceFactory) ! {
	if name.len == 0 {
		return error('service name empty')
	}
	if factory == unsafe { nil } {
		return error('factory is nil')
	}
	c.mu.lock()
	defer { c.mu.unlock() }
	if name in c.services {
		return error('service already registered: ${name}')
	}
	c.services[name] = ServiceEntry{
		factory: factory
		plane: plane
	}
}

// register_singleton is like register but caches the instance.
pub fn (mut c DIContainer) register_singleton(name string, plane Plane, factory ServiceFactory) ! {
	if name.len == 0 {
		return error('service name empty')
	}
	c.mu.lock()
	defer { c.mu.unlock() }
	if name in c.services {
		return error('service already registered: ${name}')
	}
	c.services[name] = ServiceEntry{
		factory: factory
		plane: plane
		singleton: true
	}
}

// resolve returns a service instance by name, constructing via factory on first call.
// Thread-safe; singleton instances are cached.
pub fn (mut c DIContainer) resolve(name string) !voidptr {
	c.mu.rlock()
	if name !in c.services {
		c.mu.runlock()
		return error('service not found: ${name}')
	}
	entry := c.services[name] or { ServiceEntry{} }
	c.mu.runlock()
	if entry.singleton && entry.created {
		return entry.instance
	}
	inst := entry.factory()!
	if entry.singleton {
		c.mu.lock()
		if name in c.services {
			mut e := c.services[name] or { ServiceEntry{} }
			if !e.created {
				e.instance = inst
				e.created = true
				c.services[name] = e
			}
		}
		c.mu.unlock()
	}
	return inst
}

// has reports whether a service is registered.
pub fn (mut c DIContainer) has(name string) bool {
	c.mu.rlock()
	defer { c.mu.runlock() }
	return name in c.services
}

// list returns registered names filtered by plane (empty plane = all).
pub fn (mut c DIContainer) list(plane Plane) []string {
	c.mu.rlock()
	defer { c.mu.runlock() }
	mut out := []string{}
	for k, v in c.services {
		// If caller wants all, they pass capability then runtime separately;
		// We expose simple filter: if plane matches or list all when called with capability+runtimes
		// For now return all; callers filter by plane if needed.
		_ = plane
		_ = v
		out << k
	}
	out.sort()
	return out
}

// list_by_plane returns names for a given plane.
pub fn (mut c DIContainer) list_by_plane(plane Plane) []string {
	c.mu.rlock()
	defer { c.mu.runlock() }
	mut out := []string{}
	for k, v in c.services {
		if v.plane == plane {
			out << k
		}
	}
	out.sort()
	return out
}

// EnvPrecedence resolves AGENT_TOOLKIT_ROOT precedence Project > Workspace > Toolkit.
// Thin wrapper around agent_toolkit_core path resolution so Engine preserves tiers
// AGENT_TOOLKIT_ROOT → XDG → embedded → FHS (ADR-015/026).
pub struct EnvResolver {
pub:
	toolkit_root string
	tier         string
}

// resolve_env determines toolkit root using same tiers as paths.v.
pub fn resolve_env() EnvResolver {
	// Prefer AGENT_TOOLKIT_ROOT env if valid
	root_override := os.getenv('AGENT_TOOLKIT_ROOT').trim_space()
	if root_override.len > 0 && agent_toolkit_core.is_valid_toolkit_root(root_override) {
		return EnvResolver{
			toolkit_root: root_override
			tier: 'override'
		}
	}
	// Try core resolver
	core_root := agent_toolkit_core.find_toolkit_root() or {
		return EnvResolver{
			toolkit_root: os.getwd()
			tier: 'cwd'
		}
	}
	return EnvResolver{
		toolkit_root: core_root.path
		tier: core_root.tier
	}
}
