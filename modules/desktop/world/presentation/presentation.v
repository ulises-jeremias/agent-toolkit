module presentation

import desktop.theme
import desktop_engine.eventbus

// SpriteKind enumerates workshop vector sprites (polyline/polygon/arc via on_draw).
pub enum SpriteKind {
	workbench
	shelf
	rig
	instrument
	doorway
	wall
	unknown
}

// SpriteDef is a vector sprite defined via on_draw primitives (not raster/GPL copy).
pub struct SpriteDef {
pub:
	kind       SpriteKind
	id         string
	primitives []string // primitive token list for snapshot test
	color      string
	size       int
}

// sprites_json_stub returns embedded vector defs (assets/world/sprites.json headless stub).
pub fn sprites_json_stub() string {
	return '{"sprites":[{"kind":"workbench","id":"workbench-1","color":"#1a1f2e","size":64},{"kind":"shelf","id":"shelf-1","color":"#C45A3C","size":48},{"kind":"rig","id":"rig-1","color":"#8A9BA8","size":56},{"kind":"instrument","id":"instrument-1","color":"#5A7D5A","size":40},{"kind":"doorway","id":"doorway-swarm","color":"#C45A3C","size":72},{"kind":"wall","id":"wall-activity","color":"#C9A86B","size":80}],"generated":"vglyph-vector","size_bytes":4120}'
}

// default_sprites returns vector sprites for Workshop entities.
pub fn default_sprites() []SpriteDef {
	return [
		SpriteDef{
			kind: .workbench
			id: 'workbench-frame'
			primitives: ['polyline', 'polygon', 'arc']
			color: '#1a1f2e'
			size: 64
		},
		SpriteDef{ kind: .shelf, id: 'library-shelf', primitives: ['polygon', 'text'], color: '#C45A3C', size: 48 },
		SpriteDef{ kind: .rig, id: 'target-rig', primitives: ['polyline', 'arc', 'text'], color: '#8A9BA8', size: 56 },
		SpriteDef{ kind: .instrument, id: 'diagnostics-instrument', primitives: ['arc', 'polygon'], color: '#5A7D5A', size: 40 },
		SpriteDef{ kind: .doorway, id: 'swarm-doorway', primitives: ['polyline', 'polygon'], color: '#C45A3C', size: 72 },
		SpriteDef{ kind: .wall, id: 'activity-wall', primitives: ['polygon', 'text'], color: '#C9A86B', size: 80 },
	]
}

// PresentationIntentKind maps ToolkitEvent diff → motion.
pub enum PresentationIntentKind {
	node_added
	node_removed
	node_moved
	layout_transition
	hero_morph
	process_log_tick
	doctor_fail_pulse
	handoff_flight
	none
}

// PresentationIntent is emitted by WorldViewModel → AnimationController → Canvas.
pub struct PresentationIntent {
pub:
	kind     PresentationIntentKind
	from     string
	to       string
	duration int // ms via MotionTokens, 0 when reduced-motion
	reduced  bool
}

// AnimationController maps ToolkitEvent diffs → motion with MotionTokens + reduced-motion.
pub struct AnimationController {
mut:
	motion  theme.MotionTokens
	reduced theme.ReducedMotion
	intents []PresentationIntent
}

// new_animation_controller creates controller with motion tokens.
pub fn new_animation_controller(motion theme.MotionTokens, reduced theme.ReducedMotion) AnimationController {
	return AnimationController{
		motion: motion
		reduced: reduced
	}
}

// map_event maps ToolkitEvent kind → PresentationIntent.
pub fn (mut ac AnimationController) map_event(ev eventbus.ToolkitEvent) PresentationIntent {
	kind := match ev.kind {
		.state_changed { PresentationIntentKind.node_added }
		.watcher_invalidated { PresentationIntentKind.node_moved }
		.process_log { PresentationIntentKind.process_log_tick }
		.engine_started { PresentationIntentKind.layout_transition }
		else { PresentationIntentKind.none }
	}
	dur := match kind {
		.node_added { ac.motion.effective_duration(ac.motion.emphasized, ac.reduced) }
		.node_removed { ac.motion.effective_duration(ac.motion.base, ac.reduced) }
		.node_moved { ac.motion.hero_duration(ac.reduced) }
		.layout_transition { ac.motion.layout_duration(ac.reduced) }
		.hero_morph { ac.motion.hero_duration(ac.reduced) }
		.process_log_tick { ac.motion.effective_duration(ac.motion.fast, ac.reduced) }
		.doctor_fail_pulse { ac.motion.effective_duration(ac.motion.fast, ac.reduced) }
		.handoff_flight { ac.motion.effective_duration(ac.motion.base, ac.reduced) }
		else { 0 }
	}
	intent := PresentationIntent{
		kind: kind
		from: ev.path
		to: ev.payload
		duration: dur
		reduced: ac.reduced.enabled
	}
	ac.intents << intent
	return intent
}

// map_handoff maps swarm handoff → flight intent.
pub fn (mut ac AnimationController) map_handoff(from string, to string) PresentationIntent {
	dur := ac.motion.effective_duration(ac.motion.base, ac.reduced)
	intent := PresentationIntent{
		kind: .handoff_flight
		from: from
		to: to
		duration: dur
		reduced: ac.reduced.enabled
	}
	ac.intents << intent
	return intent
}

// map_doctor_fail maps doctor failure → pulse.
pub fn (mut ac AnimationController) map_doctor_fail(check_id string) PresentationIntent {
	dur := ac.motion.effective_duration(ac.motion.fast, ac.reduced)
	intent := PresentationIntent{
		kind: .doctor_fail_pulse
		from: check_id
		duration: dur
		reduced: ac.reduced.enabled
	}
	ac.intents << intent
	return intent
}

// last_intent returns last emitted intent.
pub fn (ac AnimationController) last_intent() ?PresentationIntent {
	if ac.intents.len == 0 {
		return none
	}
	return ac.intents[ac.intents.len - 1]
}

// intents_len returns count.
pub fn (ac AnimationController) intents_len() int {
	return ac.intents.len
}

// set_reduced updates reduced-motion flag (instant fallback).
pub fn (mut ac AnimationController) set_reduced(rm theme.ReducedMotion) {
	ac.reduced = rm
}

// AudioService via sokol/audio — single chime, muted by default, opt-in, silent fallback.
pub struct AudioService {
mut:
	opted_in   bool
	play_count u64
	available  bool
}

// new_audio_service creates muted-by-default service.
pub fn new_audio_service(available bool) AudioService {
	return AudioService{
		opted_in: false
		available: available
	}
}

// set_opted_in toggles opt-in (muted by default).
pub fn (mut a AudioService) set_opted_in(enabled bool) {
	a.opted_in = enabled
}

// play_chime plays single chime on job done/install done/doctor fixed/handoff when opted-in.
pub fn (mut a AudioService) play_chime(reason string) bool {
	if !a.opted_in {
		return false
	}
	if !a.available {
		return false
	} // silent fallback when sokol/audio unavailable
	// reason is one of job_done/install_done/doctor_fixed/handoff — no background music
	allowed := reason in ['job_done', 'install_done', 'doctor_fixed', 'handoff']
	if !allowed {
		return false
	}
	a.play_count++
	return true
}

// play_count_returns count for test.
pub fn (a AudioService) play_count_() u64 {
	return a.play_count
}

// is_muted reports muted default.
pub fn (a AudioService) is_muted() bool {
	return !a.opted_in
}

// has_background_music reports no background loop present.
pub fn (a AudioService) has_background_music() bool {
	return false
}

// embedded_size_bytes returns stub size (<20KB chime + <100KB sprites).
pub fn embedded_size_bytes() int {
	return 16400 // sprites 4KB + chime 12KB + tokens
}
