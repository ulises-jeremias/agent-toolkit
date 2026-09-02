module agent_toolkit_core

import json2
import os

// CacheMeta is the metadata stored in cached_version.json.
pub struct CacheMeta {
pub:
	version string
	source  string
	url     string
}

// ContentCache is the XDG cache service (no network; sync is #557).
pub struct ContentCache {
pub:
	fs FsService
}

// new_content_cache builds a cache service using real XDG paths.
pub fn new_content_cache() ContentCache {
	return ContentCache{
		fs: new_fs()
	}
}

// dir returns the toolkit cache directory (~/.cache/agent-toolkit).
pub fn (c ContentCache) dir() string {
	return c.fs.toolkit_cache_dir()
}

// version_file returns the path to cached_version.json.
pub fn (c ContentCache) version_file() string {
	return c.fs.join(c.dir(), 'cached_version.json')
}

// read_meta loads cache metadata if present.
pub fn (c ContentCache) read_meta() ?CacheMeta {
	path := c.version_file()
	if !os.is_file(path) {
		return none
	}
	text := os.read_file(path) or { return none }
	meta := json2.decode[CacheMeta](text) or { return none }
	if meta.version.len == 0 {
		return none
	}
	return meta
}

// write_meta stores cache metadata atomically.
pub fn (c ContentCache) write_meta(meta CacheMeta) ! {
	c.fs.ensure_dir(c.dir())!
	payload := json2.encode(meta, escape_unicode: true)
	c.fs.write_atomic(c.version_file(), payload + '\n')!
}

// has_profiles reports whether the cache looks populated (profiles/).
pub fn (c ContentCache) has_profiles() bool {
	return os.is_dir(c.fs.join(c.dir(), 'profiles'))
}

// is_current reports whether cached version matches expected.
pub fn (c ContentCache) is_current(expected string) bool {
	meta := c.read_meta() or { return false }
	return meta.version == expected && c.has_profiles()
}

// resolve_local returns the cache dir on hit, or none on miss (never downloads).
pub fn (c ContentCache) resolve_local(expected string, offline bool) ?string {
	if c.is_current(expected) {
		return c.dir()
	}
	if offline && c.has_profiles() {
		return c.dir()
	}
	if c.has_profiles() && expected.len == 0 {
		return c.dir()
	}
	return none
}
