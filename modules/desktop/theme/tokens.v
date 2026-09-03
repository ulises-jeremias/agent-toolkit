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
// F1 approved palette (gui-redesign-legibility plan, section 8) lives in the
// surface_*/text_*/signal_* fields below. The legacy bg/fg/primary/* fields are
// frozen for backward compatibility (existing struct literals keep compiling);
// new renderer code must use the surface_*/text_*/signal_* roles.
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
	// F1 semantic roles — Paper defaults (plan section 8). Field defaults keep
	// every existing struct literal compiling (additive only).
	surface_canvas   string = '#F3EBDD'
	surface_paper    string = '#FFF9ED'
	surface_cabinet  string = '#171C1F'
	text_primary     string = '#252A2D'
	text_secondary   string = '#596A73'
	signal_selection string = '#9A6416'
	signal_success   string = '#3F704D'
	signal_danger    string = '#A84631'
	text_on_cabinet  string = '#FFF9ED'
}

// default_spacing returns canonical spacing scale.
pub fn default_spacing() SpacingScale {
	return SpacingScale{}
}

// default_typography returns canonical typography scale.
pub fn default_typography() TypographyScale {
	return TypographyScale{}
}

// default_colors returns dark semantic palette (default) — Ink/Night Shift.
// Legacy roles keep the frozen values; the F1 roles below carry the same
// semantic jobs on dark surfaces. Signal hues are lightened versus Paper so
// text in those hues keeps passing contrast on surface_cabinet.
pub fn default_colors() ColorTokens {
	return ColorTokens{
		bg: '#1A1A1A'
		bg_elevated: '#252525'
		fg: '#F4EFE6'
		fg_muted: '#8A9BA8'
		border: '#3A3630'
		primary: '#C45A3C'
		accent: '#C9A86B'
		success: '#5A7D5A'
		warning: '#C9A86B'
		danger: '#C45A3C'
		surface_canvas: '#171C1F'
		surface_paper: '#232A2E'
		surface_cabinet: '#101415'
		text_primary: '#FFF9ED'
		text_secondary: '#C9C0A8'
		signal_selection: '#D9A648'
		signal_success: '#7FB08D'
		signal_danger: '#D9785F'
		text_on_cabinet: '#FFF9ED'
	}
}

// light_colors returns light semantic palette — Paper (plan section 8).
// Legacy roles stay frozen; the F1 roles carry the approved values.
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
		surface_canvas: '#F3EBDD'
		surface_paper: '#FFF9ED'
		surface_cabinet: '#171C1F'
		text_primary: '#252A2D'
		text_secondary: '#596A73'
		signal_selection: '#9A6416'
		signal_success: '#3F704D'
		signal_danger: '#A84631'
		text_on_cabinet: '#FFF9ED'
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
