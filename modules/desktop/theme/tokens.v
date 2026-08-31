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
pub struct TypographyScale {
pub:
	xs_size        int = 12
	xs_height      int = 16
	sm_size        int = 14
	sm_height      int = 20
	md_size        int = 16
	md_height      int = 24
	lg_size        int = 20
	lg_height      int = 28
	xl_size        int = 24
	xl_height      int = 32
	xxl_size       int = 32
	xxl_height     int = 40
	mono_size      int = 13
	weight_regular int = 400
	weight_medium  int = 500
	weight_bold    int = 700
}

// ColorTokens are semantic color tokens — not raw hex per view.
// Light/dark themes swap these via Theme (instant reload <1 frame).
pub struct ColorTokens {
pub:
	bg          string = '#0b0e14'
	bg_elevated string = '#151a23'
	fg          string = '#e6e8eb'
	fg_muted    string = '#9aa0a6'
	border      string = '#232a36'
	primary     string = '#7c3aed'
	accent      string = '#0891b2'
	success     string = '#16a34a'
	warning     string = '#eab308'
	danger      string = '#dc2626'
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

// light_colors returns light semantic palette.
pub fn light_colors() ColorTokens {
	return ColorTokens{
		bg: '#ffffff'
		bg_elevated: '#f8fafc'
		fg: '#0f172a'
		fg_muted: '#64748b'
		border: '#e2e8f0'
		primary: '#7c3aed'
		accent: '#0891b2'
		success: '#16a34a'
		warning: '#ca8a04'
		danger: '#dc2626'
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

// GradientTokens for subtle surfaces.
pub struct GradientTokens {
pub:
	subtle string = 'linear-gradient(180deg, rgba(255,255,255,0.02), transparent)'
}

// BlurTokens for overlay blur.
pub struct BlurTokens {
pub:
	sm int = 4
	md int = 8
	lg int = 16
}
