module main

import os

// repo_version_path locates the checkout root VERSION from this file's path
// (cmd/agent-toolkit-desktop/ → root), independent of CWD and env.
fn repo_version_path() string {
	return os.join_path(os.dir(os.dir(os.dir(@FILE))), 'VERSION')
}

// R2 product-truth: the displayed desktop version must match the single source
// of truth — repo VERSION at build, installed VERSION sibling at runtime,
// embedded build version otherwise (with -d commit fallback for dev builds).
fn test_desktop_version_matches_source_of_truth() {
	vp := repo_version_path()
	assert os.is_file(vp), 'repo VERSION must exist at ${vp}'
	want := os.read_file(vp) or { panic(err) }.trim_space()
	assert want.len > 0, 'repo VERSION must not be empty'
	assert want[0].is_digit(), 'VERSION must start with a digit, got: ${want}'
	assert want == embedded_desktop_version, 'embedded_desktop_version must track root VERSION (run scripts/bump-version.vsh): embedded=${embedded_desktop_version} VERSION=${want}'
	got := desktop_version()
	assert got.len > 0, 'desktop_version must never be empty'
	// got is either this checkout's VERSION (CWD walk) or another legitimate
	// source (AGENT_TOOLKIT_ROOT / installed sibling / embedded) — but with a
	// clean checkout it must equal the repo file.
	assert got == want || got == embedded_desktop_version, 'displayed version must match source of truth: got=${got} want=${want}'
	full := desktop_version_full()
	assert full.starts_with(got), 'full version must start with display version: ${full}'
	assert desktop_commit().len > 0, 'commit fallback must never be empty'
}

// The GuiApp default must already carry the embedded truth so a window opened
// without an explicit version stamp can never show a stale hardcoded string.
fn test_gui_app_default_version_is_embedded_truth() {
	app := &GuiApp{}
	assert app.version == embedded_desktop_version, 'GuiApp default version must be embedded truth: ${app.version}'
}
