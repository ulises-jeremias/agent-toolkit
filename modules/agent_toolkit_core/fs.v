module agent_toolkit_core

import os

// FsService centralizes filesystem helpers for install/receipts/workspace.
pub struct FsService {
pub:
	// home_dir override for tests; empty uses os.home_dir().
	home_dir string
}

// new_fs returns an FsService using the real home directory.
pub fn new_fs() FsService {
	return FsService{}
}

// home returns the effective home directory.
pub fn (fs FsService) home() string {
	if fs.home_dir.len > 0 {
		return fs.home_dir
	}
	return os.home_dir()
}

// join joins path segments with the OS separator (Windows-aware via os.join_path).
pub fn (fs FsService) join(parts ...string) string {
	if parts.len == 0 {
		return ''
	}
	mut out := parts[0]
	for i in 1 .. parts.len {
		out = os.join_path(out, parts[i])
	}
	return out
}

// xdg_cache_home returns XDG_CACHE_HOME or ~/.cache.
pub fn (fs FsService) xdg_cache_home() string {
	v := os.getenv('XDG_CACHE_HOME')
	if v.len > 0 {
		return v
	}
	return fs.join(fs.home(), '.cache')
}

// xdg_data_home returns XDG_DATA_HOME or ~/.local/share.
pub fn (fs FsService) xdg_data_home() string {
	v := os.getenv('XDG_DATA_HOME')
	if v.len > 0 {
		return v
	}
	return fs.join(fs.home(), '.local', 'share')
}

// toolkit_cache_dir returns the Agent Toolkit cache root under XDG cache.
pub fn (fs FsService) toolkit_cache_dir() string {
	return fs.join(fs.xdg_cache_home(), 'agent-toolkit')
}

// toolkit_data_dir returns the Agent Toolkit data root under XDG data home.
pub fn (fs FsService) toolkit_data_dir() string {
	return fs.join(fs.xdg_data_home(), 'agent-toolkit', 'data')
}

// ensure_dir creates a directory and parents; returns a domain error on failure.
pub fn (fs FsService) ensure_dir(path string) ! {
	os.mkdir_all(path) or { return error_with_code('mkdir_all failed: ${path}: ${err}', 1) }
}

// write_atomic writes data to path via a temp file + rename (best-effort atomic).
pub fn (fs FsService) write_atomic(path string, data string) ! {
	dir := os.dir(path)
	if dir.len > 0 {
		fs.ensure_dir(dir)!
	}
	tmp := '${path}.tmp.${os.getpid()}'
	os.write_file(tmp, data) or { return error_with_code('write temp failed: ${tmp}: ${err}', 1) }
	os.mv(tmp, path) or {
		os.rm(tmp) or {}
		return error_with_code('rename failed: ${tmp} -> ${path}: ${err}', 1)
	}
}

// read_text reads a UTF-8 text file.
pub fn (fs FsService) read_text(path string) !string {
	return os.read_file(path) or { return error_with_code('read failed: ${path}: ${err}', 1) }
}

// exists reports whether path exists.
pub fn (fs FsService) exists(path string) bool {
	return os.exists(path)
}
