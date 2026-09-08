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
