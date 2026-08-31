module theme

// MotionTokens define tween/spring/keyframe durations + easings.
// Centralized AnimationController mapping ToolkitEvent diff → motion
// per ADR-032: node_added → scale-in + spring, layout reflow → constraint tween, etc.
// All durations honor reduced-motion pref (instant fallback).
pub struct MotionTokens {

	// Durations in milliseconds
pub:
	instant    int = 0
	fast       int = 120
	base       int = 200
	emphasized int = 340
	// Spring defaults (tension / friction-ish; composed via retained geometry)
	spring_stiffness int = 320
	spring_damping   int = 28
	// Easings as names (vlang/gui anim interpolates via these)
	ease_out_cubic string = 'easeOutCubic'
	ease_in_out    string = 'easeInOutCubic'
	spring_easing  string = 'spring'
}

// ReducedMotion flag — when true all motion collapses to 0 (instant).
// Sources: OS prefers-reduced-motion or State pref (EPIC 1009 #1017 AC).
pub struct ReducedMotion {
pub:
	enabled bool
}

// effective_duration returns duration honoring reduced-motion.
// When reduced-motion is enabled every tween/spring degrades to instant.
pub fn (m MotionTokens) effective_duration(requested int, rm ReducedMotion) int {
	if rm.enabled {
		return m.instant
	}
	return requested
}

// effective_motion_returns true duration and whether animation should run.
pub fn (m MotionTokens) should_animate(rm ReducedMotion) bool {
	return !rm.enabled
}

// hero_duration is the canonical hero morph (nav / docking).
pub fn (m MotionTokens) hero_duration(rm ReducedMotion) int {
	return m.effective_duration(m.emphasized, rm)
}

// fade_duration for overlay/dialog/toast.
pub fn (m MotionTokens) fade_duration(rm ReducedMotion) int {
	return m.effective_duration(m.fast, rm)
}

// layout_tween for dock splitter / panel reflow.
pub fn (m MotionTokens) layout_duration(rm ReducedMotion) int {
	return m.effective_duration(m.base, rm)
}

// default_motion returns canonical motion tokens.
pub fn default_motion() MotionTokens {
	return MotionTokens{}
}

// reduced_motion_disabled is the default (motion enabled).
pub fn reduced_motion_disabled() ReducedMotion {
	return ReducedMotion{
		enabled: false
	}
}

// reduced_motion_enabled is the accessibility fallback (instant).
pub fn reduced_motion_enabled() ReducedMotion {
	return ReducedMotion{
		enabled: true
	}
}

// motion_preset_headless validates that reduced-motion collapses to 0.
pub fn motion_preset_headless() (MotionTokens, ReducedMotion, ReducedMotion) {
	return default_motion(), reduced_motion_disabled(), reduced_motion_enabled()
}
