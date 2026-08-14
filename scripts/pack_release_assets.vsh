#!/usr/bin/env -S v run
// Pack ADR-018 floating binaries + versioned archives, SHA256SUMS, and manifest.json.
// Usage: RELEASE_VERSION=x.y.z RELEASE_BIN_DIR=binaries ./scripts/pack_release_assets.vsh

import crypto.sha256
import json
import time

struct FloatingSpec {
	floating     string
	os_name      string
	arch         string
	libc         string
	archive_kind string
}

struct AssetEntry {
	os       string
	arch     string
	channel  string
	kind     string
	filename string
	sha256   string
	url      string
	libc     string
}

struct Manifest {
	schema_version int    @[json: 'schemaVersion']
	name           string
	version        string
	git_tag        string @[json: 'gitTag']
	channel        string
	released_at    string @[json: 'releasedAt']
	assets         []AssetEntry
}

fn sha256_file(path string) string {
	data := read_bytes(path) or { return '' }
	sum := sha256.sum(data)
	return sum.hex()
}

fn main() {
	mut src := getenv('RELEASE_BIN_DIR')
	if src.len == 0 {
		src = 'binaries'
	}
	mut out := getenv('RELEASE_OUT_DIR')
	if out.len == 0 {
		out = 'release-assets'
	}
	// Absolute out path: zip after `cd` into a temp dir must not resolve relative
	// archive paths against the temp dir (I/O error: No such file or directory).
	if !out.starts_with('/') {
		out = join_path(getwd(), out)
	}
	version := getenv('RELEASE_VERSION')
	if version.len == 0 {
		eprintln('RELEASE_VERSION is required')
		exit(1)
	}
	mut tag := getenv('RELEASE_TAG')
	if tag.len == 0 {
		tag = 'v${version}'
	}
	mut license_path := getenv('LICENSE_PATH')
	if license_path.len == 0 {
		license_path = 'LICENSE'
	}
	mkdir_all(out) or {}

	specs := [
		FloatingSpec{'agent-toolkit-linux-x86_64', 'linux', 'x86_64', 'gnu', 'tar'},
		FloatingSpec{'agent-toolkit-linux-arm64', 'linux', 'arm64', 'gnu', 'tar'},
		FloatingSpec{'agent-toolkit-macos-arm64', 'macos', 'arm64', '', 'tar'},
		FloatingSpec{'agent-toolkit-macos-x86_64', 'macos', 'x86_64', '', 'tar'},
		FloatingSpec{'agent-toolkit-windows-x86_64.exe', 'windows', 'x86_64', '', 'zip'},
	]

	mut assets := []AssetEntry{}
	mut packed_names := []string{}
	base_url := 'https://github.com/ulises-jeremias/agent-toolkit/releases/download/${tag}'

	for spec in specs {
		mut src_bin := join_path(src, spec.floating)
		if !is_file(src_bin) {
			alt := join_path(src, spec.floating.trim_string_right('.exe'))
			if is_file(alt) {
				src_bin = alt
			} else {
				println('skip missing ${spec.floating}')
				continue
			}
		}
		dest_float := join_path(out, spec.floating)
		cp(src_bin, dest_float) or {}
		chmod(dest_float, 0o755) or {}
		packed_names << spec.floating

		inner := if spec.os_name == 'windows' { 'agent-toolkit.exe' } else { 'agent-toolkit' }
		mut archive_name := ''
		mut archive_path := ''
		if spec.archive_kind == 'zip' {
			archive_name = 'agent-toolkit-${version}-windows-${spec.arch}.zip'
			archive_path = join_path(out, archive_name)
			// Prefer zip CLI for portability in CI.
			rm(archive_path) or {}
			mut zip_cmd := 'zip -j -q "${archive_path}" "${dest_float}"'
			if is_file(license_path) {
				// zip with renamed entries via temp dir
				tmpdir := join_path(temp_dir(), 'atk-pack-${spec.arch}')
				rmdir_all(tmpdir) or {}
				mkdir_all(tmpdir) or {}
				cp(dest_float, join_path(tmpdir, inner)) or {}
				cp(license_path, join_path(tmpdir, 'LICENSE')) or {}
				zip_cmd = 'sh -c \'cd "${tmpdir}" && zip -q "${archive_path}" "${inner}" LICENSE\''
			} else {
				tmpdir := join_path(temp_dir(), 'atk-pack-${spec.arch}')
				rmdir_all(tmpdir) or {}
				mkdir_all(tmpdir) or {}
				cp(dest_float, join_path(tmpdir, inner)) or {}
				zip_cmd = 'sh -c \'cd "${tmpdir}" && zip -q "${archive_path}" "${inner}"\''
			}
			rc := system(zip_cmd)
			if rc != 0 {
				eprintln('zip failed for ${archive_name}')
				exit(rc)
			}
		} else {
			archive_name = 'agent-toolkit-${version}-${spec.os_name}-${spec.arch}.tar.gz'
			archive_path = join_path(out, archive_name)
			tmpdir := join_path(temp_dir(), 'atk-pack-${spec.os_name}-${spec.arch}')
			rmdir_all(tmpdir) or {}
			mkdir_all(tmpdir) or {}
			cp(dest_float, join_path(tmpdir, inner)) or {}
			mut tar_cmd := 'tar -C "${tmpdir}" -czf "${archive_path}" "${inner}"'
			if is_file(license_path) {
				cp(license_path, join_path(tmpdir, 'LICENSE')) or {}
				tar_cmd = 'tar -C "${tmpdir}" -czf "${archive_path}" "${inner}" LICENSE'
			}
			rc := system(tar_cmd)
			if rc != 0 {
				eprintln('tar failed for ${archive_name}')
				exit(rc)
			}
		}
		packed_names << archive_name

		mut bin_entry := AssetEntry{
			os:       spec.os_name
			arch:     spec.arch
			channel:  'stable'
			kind:     'binary'
			filename: spec.floating
			sha256:   sha256_file(dest_float)
			url:      '${base_url}/${spec.floating}'
			libc:     spec.libc
		}
		assets << bin_entry
		mut arch_entry := AssetEntry{
			os:       spec.os_name
			arch:     spec.arch
			channel:  'stable'
			kind:     'archive'
			filename: archive_name
			sha256:   sha256_file(archive_path)
			url:      '${base_url}/${archive_name}'
			libc:     spec.libc
		}
		assets << arch_entry
	}

	packed_names.sort()
	mut sum_lines := []string{}
	for name in packed_names {
		sum_lines << '${sha256_file(join_path(out, name))}  ${name}'
	}
	write_file(join_path(out, 'SHA256SUMS'), sum_lines.join('\n') + '\n') or {}

	// Omit empty libc fields by encoding via hand-built JSON for cleanliness.
	mut asset_jsons := []string{}
	for a in assets {
		mut libc_field := ''
		if a.libc.len > 0 {
			libc_field = ',\n    "libc": ${json.encode(a.libc)}'
		}
		asset_jsons << '  {
    "os": ${json.encode(a.os)},
    "arch": ${json.encode(a.arch)},
    "channel": ${json.encode(a.channel)},
    "kind": ${json.encode(a.kind)},
    "filename": ${json.encode(a.filename)},
    "sha256": ${json.encode(a.sha256)},
    "url": ${json.encode(a.url)}${libc_field}
  }'
	}
	released := time.utc().custom_format('YYYY-MM-DDTHH:mm:ss') + 'Z'
	manifest := '{
  "schemaVersion": 1,
  "name": "agent-toolkit",
  "version": ${json.encode(version)},
  "gitTag": ${json.encode(tag)},
  "channel": "stable",
  "releasedAt": ${json.encode(released)},
  "assets": [
${asset_jsons.join(',\n')}
  ]
}
'
	write_file(join_path(out, 'manifest.json'), manifest) or {}
	entries := ls(out) or { []string{} }
	println('packed ${entries.len} files in ${out}')
}
