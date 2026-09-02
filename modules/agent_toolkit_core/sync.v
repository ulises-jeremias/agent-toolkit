module agent_toolkit_core

import os

const data_subdirs = ['skills', 'agents', 'loops', 'profiles', 'mcp', 'catalogs']
const github_repo = 'ulises-jeremias/agent-toolkit'
const version_marker = '.version'

// DataSync downloads capability trees from GitHub Releases into XDG data.
pub struct DataSync {
pub:
	net NetworkClient
	fs  FsService
}

// new_data_sync builds a sync client; auto_offline honors AGENT_TOOLKIT_OFFLINE.
pub fn new_data_sync() DataSync {
	return DataSync{
		net: new_network_client(true)
		fs: new_fs()
	}
}

// data_dir is XDG data home / agent-toolkit / data (same as Python data_sync).
pub fn (s DataSync) data_dir() string {
	return s.fs.toolkit_data_dir()
}

// is_valid_data_root reports profiles/ plus skills/ or loops/.
pub fn is_valid_data_root(path string) bool {
	if path.len == 0 || !os.is_dir(path) {
		return false
	}
	if !os.is_dir(os.join_path(path, 'profiles')) {
		return false
	}
	return os.is_dir(os.join_path(path, 'skills')) || os.is_dir(os.join_path(path, 'loops'))
}

// cached_data_version reads the .version marker in the data dir.
pub fn (s DataSync) cached_data_version() string {
	vf := s.fs.join(s.data_dir(), version_marker)
	if !os.is_file(vf) {
		return ''
	}
	text := os.read_file(vf) or { return '' }
	return text.trim_space()
}

// ensure_data returns a valid data root. Offline never hits the network.
pub fn (s DataSync) ensure_data(version string, offline bool, force bool) !string {
	dest := s.data_dir()
	pin := strip_v_prefix(version)
	if !force && is_valid_data_root(dest) {
		cv := strip_v_prefix(s.cached_data_version())
		if cv.len == 0 || cv == pin || pin.len == 0 {
			return dest
		}
	}
	if offline || s.net.offline {
		if is_valid_data_root(dest) {
			return dest
		}
		return error('network offline: capability data cache missing (set AGENT_TOOLKIT_ROOT)')
	}
	return s.download_data(version)
}

// download_data fetches a release tarball into a staging dir, then promotes only if valid.
pub fn (s DataSync) download_data(version string) !string {
	if s.net.offline {
		return error('network offline: AGENT_TOOLKIT_OFFLINE prevents download')
	}
	tag := release_tag(version)
	url := 'https://github.com/${github_repo}/archive/refs/tags/${tag}.tar.gz'
	tmp := s.fs.join(os.temp_dir(), 'agent-toolkit-data-${os.getpid()}')
	os.mkdir_all(tmp) or { return error('staging mkdir failed: ${err}') }
	defer {
		os.rmdir_all(tmp) or {}
	}
	tarball := s.fs.join(tmp, 'source.tar.gz')
	s.net.download(url, tarball) or {
		return error('download failed (cache not activated): ${err}')
	}
	extract_dir := s.fs.join(tmp, 'extract')
	os.mkdir_all(extract_dir) or { return error('extract mkdir failed: ${err}') }
	extract_tarball(tarball, extract_dir)!
	src := first_dir(extract_dir) or { return error('no top-level directory in release tarball') }
	if !is_valid_data_root(src) {
		return error('release tarball does not contain capability data (cache not activated)')
	}
	return s.promote_staging(src, strip_v_prefix(tag))
}

// promote_staging copies DATA_SUBDIRS from a validated tree into the data dir.
// Dest is replaced only after the source validates — partial/corrupt trees never activate.
pub fn (s DataSync) promote_staging(src string, version string) !string {
	if !is_valid_data_root(src) {
		return error('staging tree is not a valid data root (cache not activated)')
	}
	dest := s.data_dir()
	staging := '${dest}.staging.${os.getpid()}'
	os.mkdir_all(staging) or { return error('staging dest mkdir failed: ${err}') }
	for name in data_subdirs {
		from := os.join_path(src, name)
		if !os.is_dir(from) {
			continue
		}
		to := os.join_path(staging, name)
		os.cp_all(from, to, true) or {
			os.rmdir_all(staging) or {}
			return error('copy ${name} failed (cache not activated): ${err}')
		}
	}
	if !is_valid_data_root(staging) {
		os.rmdir_all(staging) or {}
		return error('copied tree failed validation (cache not activated)')
	}
	ver := strip_v_prefix(version)
	os.write_file(os.join_path(staging, version_marker), ver + '\n') or {
		os.rmdir_all(staging) or {}
		return error('write .version failed (cache not activated): ${err}')
	}
	if os.exists(dest) {
		os.rmdir_all(dest) or {
			os.rmdir_all(staging) or {}
			return error('replace dest failed (cache not activated): ${err}')
		}
	}
	os.mv(staging, dest) or {
		os.rmdir_all(staging) or {}
		return error('activate dest failed: ${err}')
	}
	return dest
}

fn release_tag(version string) string {
	v := version.trim_space()
	if v.len == 0 {
		return 'v${embedded_version}'
	}
	if v.starts_with('v') {
		return v
	}
	return 'v${v}'
}

fn strip_v_prefix(version string) string {
	v := version.trim_space()
	if v.starts_with('v') {
		return v[1..]
	}
	return v
}

fn first_dir(path string) ?string {
	entries := os.ls(path) or { return none }
	for e in entries {
		p := os.join_path(path, e)
		if os.is_dir(p) {
			return p
		}
	}
	return none
}

fn extract_tarball(tarball string, dest string) ! {
	ps := new_process_service()
	res := ps.run(
		argv: ['tar', '-xzf', tarball, '-C', dest]
	)!
	if res.exit_code != 0 {
		return error('tar extract failed: ${res.stderr}')
	}
}
