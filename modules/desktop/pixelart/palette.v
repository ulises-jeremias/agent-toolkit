module pixelart

// Paper Co. pixel-art palette (DESIGN.md §0).
// Material colors from the established surface tokens, compressed for the
// pixel-art density. Two variants: Paper (light flagship) and Ink (dark).

pub enum PaletteId {
	paper
	ink
}

// PaletteKey — single-char keys used in sprite grids (readable/diffable).
// Same key maps to different material colors per palette variant.
pub enum PaletteKey {
	outline  = 107
	paper    = 112
	paper_hi = 80
	manila   = 109
	manila_d = 77
	brass    = 98
	brass_hi = 66
	wood     = 119
	wood_d   = 87
	foliage  = 102
	foliage_d= 70
	sky      = 115
	slate    = 83
	terminal = 116
	accent   = 97
	skin     = 110
	skin_d   = 78
	hair     = 104
	shirt    = 99
	shirt_d  = 67
	white    = 101
	steel    = 108
	coral    = 114
	transparent = 46
}

pub struct Palette {
pub:
	id PaletteId
mut:
	colors map[u8]u64
}

// rgba64 packs RGBA into a u64: (r<<24) | (g<<16) | (b<<8) | a.
pub fn rgba64(r int, g int, b int) u64 {
	return (u64(r) << 24) | (u64(g) << 16) | (u64(b) << 8) | u64(255)
}

// channels unpacks a packed color.
pub fn channels(v u64) (int, int, int, int) {
	return int((v >> 24) & 0xFF), int((v >> 16) & 0xFF), int((v >> 8) & 0xFF), int(v & 0xFF)
}

// rgba returns the RGBA tuple for a palette-key byte.
pub fn (p Palette) rgba(k u8) [4]u8 {
	if v := p.colors[k] {
		r, g, b, a := channels(v)
		mut out := [4]u8{}
		out[0] = u8(r)
		out[1] = u8(g)
		out[2] = u8(b)
		out[3] = u8(a)
		return out
	}
	return [4]u8{}
}

// rgb_hex returns '#RRGGBB' for UI-adjacent uses.
pub fn (p Palette) rgb_hex(k u8) string {
	v := p.rgba(k)
	return '#${v[0]:02x}${v[1]:02x}${v[2]:02x}'
}

// paper_palette — warm flagship: cream paper, manila folders, brass, wood,
// ink outlines. Matches the established chrome tokens.
pub fn paper_palette() Palette {
	mut c := map[u8]u64{}
	c[u8(`k`)] = rgba64(37, 42, 45)
	c[u8(`p`)] = rgba64(246, 239, 227)
	c[u8(`P`)] = rgba64(255, 249, 237)
	c[u8(`m`)] = rgba64(217, 183, 121)
	c[u8(`M`)] = rgba64(201, 164, 95)
	c[u8(`b`)] = rgba64(154, 100, 22)
	c[u8(`B`)] = rgba64(220, 158, 60)
	c[u8(`w`)] = rgba64(166, 124, 82)
	c[u8(`W`)] = rgba64(120, 88, 58)
	c[u8(`f`)] = rgba64(106, 153, 78)
	c[u8(`F`)] = rgba64(74, 112, 56)
	c[u8(`s`)] = rgba64(126, 156, 216)
	c[u8(`S`)] = rgba64(59, 66, 82)
	c[u8(`t`)] = rgba64(23, 28, 31)
	c[u8(`a`)] = rgba64(168, 70, 49)
	c[u8(`n`)] = rgba64(232, 190, 160)
	c[u8(`N`)] = rgba64(198, 152, 122)
	c[u8(`h`)] = rgba64(72, 52, 38)
	c[u8(`c`)] = rgba64(143, 174, 204)
	c[u8(`C`)] = rgba64(104, 134, 164)
	c[u8(`e`)] = rgba64(255, 252, 245)
	c[u8(`l`)] = rgba64(156, 163, 175)
	c[u8(`r`)] = rgba64(228, 110, 90)
	return Palette{ id: .paper, colors: c }
}

// ink_palette — authored dark variant: deep cabinet surfaces, dimmed manila,
// desaturated foliage; NOT a global inversion.
pub fn ink_palette() Palette {
	mut c := map[u8]u64{}
	c[u8(`k`)] = rgba64(10, 12, 14)
	c[u8(`p`)] = rgba64(44, 50, 56)
	c[u8(`P`)] = rgba64(56, 63, 70)
	c[u8(`m`)] = rgba64(120, 100, 66)
	c[u8(`M`)] = rgba64(96, 78, 50)
	c[u8(`b`)] = rgba64(180, 124, 44)
	c[u8(`B`)] = rgba64(224, 168, 80)
	c[u8(`w`)] = rgba64(104, 82, 60)
	c[u8(`W`)] = rgba64(76, 58, 42)
	c[u8(`f`)] = rgba64(74, 102, 60)
	c[u8(`F`)] = rgba64(54, 76, 44)
	c[u8(`s`)] = rgba64(66, 96, 148)
	c[u8(`S`)] = rgba64(40, 46, 54)
	c[u8(`t`)] = rgba64(8, 10, 12)
	c[u8(`a`)] = rgba64(178, 84, 62)
	c[u8(`n`)] = rgba64(198, 158, 128)
	c[u8(`N`)] = rgba64(162, 124, 98)
	c[u8(`h`)] = rgba64(40, 30, 22)
	c[u8(`c`)] = rgba64(92, 116, 142)
	c[u8(`C`)] = rgba64(66, 86, 108)
	c[u8(`e`)] = rgba64(222, 220, 214)
	c[u8(`l`)] = rgba64(110, 118, 130)
	c[u8(`r`)] = rgba64(186, 92, 74)
	return Palette{ id: .ink, colors: c }
}

// palette_for returns the palette for a PaletteId.
pub fn palette_for(id PaletteId) Palette {
	return match id {
		.paper { paper_palette() }
		.ink { ink_palette() }
	}
}
