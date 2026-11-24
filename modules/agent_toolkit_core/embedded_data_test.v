module agent_toolkit_core

import os

fn append_bundle_test_u32(mut out []u8, value u32) {
	for i in 0 .. 4 {
		out << u8(value >> (i * 8))
	}
}

fn append_bundle_test_u64(mut out []u8, value u64) {
	for i in 0 .. 8 {
		out << u8(value >> (i * 8))
	}
}

fn test_embedded_bundle_preserves_binary_content_and_directory_listing() {
	assert embedded_is_valid_root()
	assert embedded_is_dir('skills/design/brag/assets/music')
	asset := 'skills/design/brag/assets/music/happy-beats-business-moves-vol-1-by-ende-dot-app.mp3'
	assert embedded_has_file(asset)
	assert embedded_is_file(asset)
	actual := embedded_read_file(asset) or { panic(err) }
	source_path := os.real_path(os.join_path(os.dir(@FILE), '../../${asset}'))
	source := os.read_bytes(source_path) or { panic(err) }
	assert actual == source.bytestr()
	assert 'happy-beats-business-moves-vol-1-by-ende-dot-app.mp3' in embedded_ls('skills/design/brag/assets/music')
	assert asset in embedded_file_paths()
}

fn test_embedded_bundle_decoder_rejects_truncation_duplicate_and_traversal() {
	if _ := decode_embedded_data_bundle([]u8{}) {
		assert false, 'truncated bundle header was accepted'
	}

	mut duplicate := []u8{}
	append_bundle_test_u32(mut duplicate, 2)
	for _ in 0 .. 2 {
		append_bundle_test_u32(mut duplicate, 5)
		append_bundle_test_u64(mut duplicate, 1)
		duplicate << 'a.txt'.bytes()
		duplicate << u8(0x41)
	}
	if _ := decode_embedded_data_bundle(duplicate) {
		assert false, 'duplicate resource path was accepted'
	}

	mut traversal := []u8{}
	append_bundle_test_u32(mut traversal, 1)
	append_bundle_test_u32(mut traversal, 7)
	append_bundle_test_u64(mut traversal, 0)
	traversal << '../x.md'.bytes()
	if _ := decode_embedded_data_bundle(traversal) {
		assert false, 'path traversal was accepted'
	}

	mut trailing := []u8{}
	append_bundle_test_u32(mut trailing, 0)
	trailing << u8(0xff)
	if _ := decode_embedded_data_bundle(trailing) {
		assert false, 'trailing bytes were accepted'
	}

	for invalid_path in ['../x.md', 'nested/../x.md', 'nested//x.md', './x.md', 'nested/.'] {
		mut invalid := []u8{}
		append_bundle_test_u32(mut invalid, 1)
		append_bundle_test_u32(mut invalid, u32(invalid_path.len))
		append_bundle_test_u64(mut invalid, 0)
		invalid << invalid_path.bytes()
		if _ := decode_embedded_data_bundle(invalid) {
			assert false, 'invalid embedded path was accepted: ${invalid_path}'
		}
	}

	mut file_directory_conflict := []u8{}
	append_bundle_test_u32(mut file_directory_conflict, 2)
	append_bundle_test_u32(mut file_directory_conflict, 1)
	append_bundle_test_u64(mut file_directory_conflict, 1)
	file_directory_conflict << 'a'.bytes()
	file_directory_conflict << u8(0x41)
	append_bundle_test_u32(mut file_directory_conflict, 3)
	append_bundle_test_u64(mut file_directory_conflict, 1)
	file_directory_conflict << 'a/b'.bytes()
	file_directory_conflict << u8(0x42)
	if _ := decode_embedded_data_bundle(file_directory_conflict) {
		assert false, 'file/directory conflict was accepted'
	}
}
