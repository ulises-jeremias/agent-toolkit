module pixelart

import os
import time

// Grid validity: all authored sprites have uniform rows and known palette keys.
fn test_all_sprites_validate() {
	pal := paper_palette()
	known := [
		u8(`k`), u8(`p`), u8(`P`), u8(`m`), u8(`M`), u8(`b`), u8(`B`),
		u8(`w`), u8(`W`), u8(`f`), u8(`F`), u8(`s`), u8(`S`), u8(`t`),
		u8(`a`), u8(`n`), u8(`N`), u8(`h`), u8(`c`), u8(`C`), u8(`e`),
		u8(`l`), u8(`r`),
	]
	for s in all_sprites() {
		errs := s.validate(known)
		assert errs.len == 0, 'sprite ${s.name} invalid: ${errs.join("; ")}'
	}
}

// Expansion: dimensions, palette mapping, transparency.
fn test_expand_rgba() {
	pal := paper_palette()
	s := env_terminal
	rgba := s.expand(pal, 1)
	assert rgba.len == s.width() * s.height() * 4
	// terminal well pixel: 't' at row 1 col 2
	row1 := s.rows[1]
	mut px := -1
	for ci, ch in row1 {
		if ch == `t` {
			px = ci
			break
		}
	}
	assert px >= 0, 'terminal well pixel not found'
	base := (1 * s.width() + px) * 4
	assert rgba[base] == 23 && rgba[base + 1] == 28 && rgba[base + 2] == 31
	assert rgba[base + 3] == 255
	// transparent corner (row 0 col 0 is '.')
	assert rgba[3] == 0
}

// Scale: 2× expansion doubles dimensions with 2×2 pixel blocks.
fn test_expand_scale2() {
	pal := paper_palette()
	s := agent_idle
	rgba := s.expand(pal, 2)
	assert rgba.len == 12 * 2 * 12 * 2 * 4
	// block uniformity: pixel (0,0) == (1,0) == (0,1)
	base00 := 0
	base10 := 4 * 2
	base01 := 4 * 2 * 2
	assert rgba[base00] == rgba[base10] && rgba[base00] == rgba[base01]
}

// Paper/Ink palettes both map every key; Ink differs from Paper (not an inversion clone)
fn test_palettes_complete_and_distinct() {
	paper := paper_palette()
	ink := ink_palette()
	for s in all_sprites() {
		for row in s.rows {
			for ch in row {
				k := u8(ch)
				if k == `.` {
					continue
				}
				_ = paper.rgba(k)
				_ = ink.rgba(k)
			}
		}
	}
	// same key, different material between variants (not a clone)
	assert paper.rgba(u8(`p`)) != ink.rgba(u8(`p`))
	// palette ids
	assert paper.id == .paper && ink.id == .ink
	assert palette_for(.ink).id == .ink
}

// Mapping coverage: every state and environment asset resolves to a valid sprite.
fn test_mapping_coverage() {
	for st in all_agent_states() {
		s := agent_for_state(st)
		assert s.rows.len > 0
	}
	for a in all_environment_assets() {
		s := environment_for(a)
		assert s.rows.len > 0
	}
	// no duplicate names
	mut names := map[string]bool{}
	for s in all_sprites() {
		assert !names[s.name]
		names[s.name] = true
	}
}

// Package/clean-machine: the module is pure V (no file I/O at sprite build
// time). This test pins that: expansion works in an empty CWD.
fn test_expansion_works_from_any_cwd() {
	old := os.getwd()
	os.chdir('/') or {}
	defer { os.chdir(old) or {} }
	pal := paper_palette()
	s := env_desk
	rgba := s.expand(pal, 1)
	assert rgba.len == s.width() * s.height() * 4
	_ = time.now()
}

// Authored dimensions: agent avatars are 12×12, env assets keep their
// documented grids. The renderer derives GPU size as grid × integer scale.
fn test_authored_dimensions() {
	assert agent_idle.width() == 12 && agent_idle.height() == 12
	assert agent_running.width() == 12 && agent_running.height() == 12
	assert env_desk.width() == 18 && env_desk.height() == 12
	assert env_rug.width() == 24 && env_rug.height() == 10
	assert env_meeting.width() == 20 && env_meeting.height() == 10
}

// Cache identity: every (sprite, palette, scale) triple maps to a distinct
// key, so Paper/Ink variants and scales never share a GPU image.
fn test_cache_key_identity() {
	a := cache_key(agent_idle, .paper, 2)
	assert a == cache_key(agent_idle, .paper, 2)
	assert a != cache_key(agent_idle, .ink, 2)
	assert a != cache_key(agent_idle, .paper, 3)
	assert a != cache_key(agent_running, .paper, 2)
	assert a != cache_key(env_desk, .paper, 2)
	// full manifest × both palettes × scales 1..3: all keys distinct.
	mut seen := map[string]bool{}
	for s in all_sprites() {
		for pid in [PaletteId.paper, PaletteId.ink] {
			for scale in 1 .. 4 {
				k := cache_key(s, pid, scale)
				assert !seen[k], 'duplicate cache key ${k}'
				seen[k] = true
			}
		}
	}
	assert seen.len == all_sprites().len * 2 * 3
}

// Identity variants: same anatomy, deterministic material swaps, distinct
// names (cache-key safe), variant 0 unchanged.
fn test_with_identity() {
	base := agent_for_state(.idle)
	v0 := with_identity(base, 0)
	assert v0.name == base.name
	assert v0.rows == base.rows
	v1 := with_identity(base, 1)
	v2 := with_identity(base, 2)
	assert v1.name == '${base.name}-id1'
	assert v2.name == '${base.name}-id2'
	assert v1.rows.len == base.rows.len
	assert v2.rows.len == base.rows.len
	// shirt material actually changed in the torso row
	assert base.rows[6] != v1.rows[6]
	assert base.rows[6] != v2.rows[6]
	// unknown variants fall back to the authored sprite
	assert with_identity(base, 7).name == base.name
	// variants still validate against the palette
	known := [
		u8(`k`), u8(`p`), u8(`P`), u8(`m`), u8(`M`), u8(`b`), u8(`B`),
		u8(`w`), u8(`W`), u8(`f`), u8(`F`), u8(`s`), u8(`S`), u8(`t`),
		u8(`a`), u8(`n`), u8(`N`), u8(`h`), u8(`c`), u8(`C`), u8(`e`),
		u8(`l`), u8(`r`),
	]
	for st in all_agent_states() {
		for v in 0 .. 3 {
			errs := with_identity(agent_for_state(st), v).validate(known)
			assert errs.len == 0, 'identity variant invalid: ${errs.join("; ")}'
		}
	}
}
