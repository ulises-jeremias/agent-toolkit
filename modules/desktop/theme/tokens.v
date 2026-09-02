module theme

// SpacingScale is the 4pt base spacing token scale (EPIC 1009 design system).
pub struct SpacingScale {
pub:
	xs  int = 4
	sm  int = 8
	md  int = 16
	lg  int = 24
	xl  int = 32
	xxl int = 48
}

// TypographyScale defines font size / line height / weight tokens.
// Renderer is vglyph / Pango / HarfBuzz through vlang/gui (Issue #1017).
// All sizes are logical pixels — high-DPI multiplies via dpi_scale.
// Dunder type system — distinctive, not Inter-only:
//   Display: Fraunces (soft serif, ink-trap) — letterhead, headlines, 20-32
//   Body:    IBM Plex Sans (humanist grotesk) — chrome, 14-16
//   Mono:    IBM Plex Mono (typewriter) — logs, code, terminal, 13
pub struct TypographyScale {
pub:
	xs_size        int = 12
	xs_height      int = 16
	sm_size        int = 13
	sm_height      int = 18
	md_size        int = 15
	md_height      int = 22
	lg_size        int = 18
	lg_height      int = 26
	xl_size        int = 22
	xl_height      int = 30
	xxl_size       int = 28
	xxl_height     int = 36
	mono_size      int = 13
	mono_height    int = 18
	weight_regular int = 400
	weight_medium  int = 500
	weight_bold    int = 700
}

// ColorTokens are semantic color tokens — not raw hex per view.
// Paper Co. Office — Dunder Mifflin warm paper world (taste anti-slop: no purple).
// Single source of truth: warm paper #F4EFE6, ink #1A1A1A, steel #8A9BA8, manila #E6D8B8, rust #C45A3C.
// Light/dark themes swap these via Theme (instant reload <1 frame).
pub struct ColorTokens {
pub:
	bg          string = '#F4EFE6'
	bg_elevated string = '#E6D8B8'
	fg          string = '#1A1A1A'
	fg_muted    string = '#8A9BA8'
	border      string = '#D1C7B3'
	primary     string = '#C45A3C'
	accent      string = '#8A9BA8'
	success     string = '#5A7D5A'
	warning     string = '#C9A86B'
	danger      string = '#C45A3C'
}

// default_spacing returns canonical spacing scale.
pub fn default_spacing() SpacingScale {
	return SpacingScale{}
}

// default_typography returns canonical typography scale.
pub fn default_typography() TypographyScale {
	return TypographyScale{}
}

// default_colors returns dark semantic palette (default).
pub fn default_colors() ColorTokens {
	return ColorTokens{}
}

// light_colors returns light semantic palette — paper world variant.
// Warm paper stays dominant; elevated is slightly lighter manila.
pub fn light_colors() ColorTokens {
	return ColorTokens{
		bg: '#F4EFE6'
		bg_elevated: '#FFF8E7'
		fg: '#1A1A1A'
		fg_muted: '#8A9BA8'
		border: '#E6D8B8'
		primary: '#C45A3C'
		accent: '#8A9BA8'
		success: '#5A7D5A'
		warning: '#C9A86B'
		danger: '#C45A3C'
	}
}

// ShadowTokens for SDF shadows / elevation (per ADR-032 shader stance —
// Phase 0 composed via on_draw + retained geometry, shader later).
pub struct ShadowTokens {
pub:
	sm string = '0 1px 2px rgba(0,0,0,0.08)'
	md string = '0 4px 12px rgba(0,0,0,0.12)'
	lg string = '0 12px 32px rgba(0,0,0,0.16)'
}

// GradientTokens for subtle surfaces — paper fiber, never purple.
// Rust-tinted paper wash, 6% opacity maximum (taste: no purple gradient).
pub struct GradientTokens {
pub:
	subtle string = 'linear-gradient(180deg, rgba(196,90,60,0.06), transparent)'
}

// BlurTokens for overlay blur.
pub struct BlurTokens {
pub:
	sm int = 4
	md int = 8
	lg int = 16
}
