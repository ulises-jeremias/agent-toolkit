module agent_toolkit_gui

import os

// GuiConfig describes the spike window configuration (0.1 hello-world).
// In headless CI (no DISPLAY) the window is not created; harness runs
// via PerfHarness.run_headless instead.
pub struct GuiConfig {
pub:
	title    string = 'Agent Toolkit — GUI Feasibility Spike #1018'
	width    int = 1280
	height   int = 800
	headless bool
}

// default_gui_config returns the canonical spike window config on V master.
pub fn default_gui_config() GuiConfig {
	return GuiConfig{
		title: 'Agent Toolkit — GUI Feasibility Spike #1018'
		width: 1280
		height: 800
		headless: is_headless_env()
	}
}

// is_headless_env checks DISPLAY / WAYLAND_DISPLAY and ATK_GUI_HEADLESS.
pub fn is_headless_env() bool {
	if os.getenv('ATK_GUI_HEADLESS') != '' {
		v := os.getenv('ATK_GUI_HEADLESS')
		return v == '1' || v == 'true'
	}
	display := os.getenv('DISPLAY')
	wayland := os.getenv('WAYLAND_DISPLAY')
	return display == '' && wayland == ''
}

// validate checks GuiConfig invariants.
pub fn (c GuiConfig) validate() ! {
	if c.title == '' {
		return error('window title must not be empty')
	}
	if c.width < 320 || c.height < 240 {
		return error('window too small: ${c.width}x${c.height} (min 320x240)')
	}
	if c.width > 8192 || c.height > 8192 {
		return error('window too large: ${c.width}x${c.height}')
	}
}

// smoke_message returns a human-readable smoke summary for manual testing.
// Used by `make.vsh smoke-gui` style verification and manual Linux smoke.
pub fn smoke_message(cfg GuiConfig, res PerfResult) string {
	mode := if cfg.headless { 'headless (no DISPLAY)' } else { 'window ${cfg.width}x${cfg.height}' }
	status := if res.passed { 'PASS' } else { 'FAIL' }
	return '${status}: spike "${cfg.title}" | mode=${mode} | ${res.message}'
}

// hello_world_available reports whether the hello-world window path is
// available in this build. Always true when V master + gui vendoring plan
// is present; headless still returns true (harness path).
pub fn hello_world_available() bool {
	return true
}

// vendoring_plan is the single-source VMODULES placement for vlang/gui.
pub fn vendoring_plan() string {
	return 'VMODULES=modules: vendor vlang/gui as modules/gui (or modules/vlang_gui) via git subtree/submodule pin 78e581e baseline; core never imports gui, desktop/gui imports gui; gen-embedded unaffected'
}
