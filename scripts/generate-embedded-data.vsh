#!/usr/bin/env -S v run

import compress.gzip
import os

fn main() {
	root := os.real_path(os.join_path(os.dir(@FILE), '..'))
	module_dir := os.join_path(root, 'modules', 'agent_toolkit_core')
	os.chdir(root) or { panic('could not enter repository root: ${err}') }
	listing := os.exec(['git', 'ls-files', '-z', '--', 'skills', 'loops', 'profiles', 'mcp', 'catalogs',
		'agents', 'capabilities', 'distributions', 'plugins', 'packs'])
	if listing.exit_code != 0 {
		panic('could not enumerate tracked embedded resources: ${listing.output}')
	}
	mut files := listing.output.split('\x00').filter(it.len > 0 && os.is_file(it) && !os.is_link(it))
	files.sort()

	mut capacity := 4
	for rel in files {
		path := os.join_path(root, rel)
		capacity += 12 + rel.len + int(os.file_size(path))
	}
	mut payload := []u8{cap: capacity}
	append_u32(mut payload, u32(files.len))
	for rel in files {
		path_bytes := rel.bytes()
		data := os.read_bytes(os.join_path(root, rel)) or { panic('could not read ${rel}: ${err}') }
		append_u32(mut payload, u32(path_bytes.len))
		append_u64(mut payload, u64(data.len))
		payload << path_bytes
		payload << data
	}
	compressed := gzip.compress(payload) or { panic('could not compress embedded data: ${err}') }
	bundle_path := os.join_path(module_dir, 'embedded_data.bundle.gz')
	os.write_file_array(bundle_path, compressed) or { panic('could not write ${bundle_path}: ${err}') }

	println('Wrote ${bundle_path} (${files.len} files, ${payload.len} bytes, ${compressed.len} compressed bytes)')
}

fn append_u32(mut out []u8, value u32) {
	for i in 0 .. 4 {
		out << u8(value >> (i * 8))
	}
}

fn append_u64(mut out []u8, value u64) {
	for i in 0 .. 8 {
		out << u8(value >> (i * 8))
	}
}
