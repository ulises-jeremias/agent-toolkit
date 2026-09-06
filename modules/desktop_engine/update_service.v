module desktop_engine

import desktop_engine.state
import desktop_engine.eventbus
import x.json2
import crypto.sha256
import os
import agent_toolkit_core

// UpdateInfoEngine describes a real, verified update offer. It exists only
// when a real release feed provided it — never from hardcoded defaults.
pub struct UpdateInfoEngine {
pub:
	latest        string
	url           string
	sha256        string
	provenance    string
	channel       string // stable|next|pinned
	receipt_path  string
	manifest_path string
}

// UpdateServiceEngine is the Engine-owned update seam. There is no real
// release-feed reader yet: check_update reports no offer, apply/rollback are
// unavailable, and history reports only genuinely recorded updates. A
// state-only version change is not an update (WORKFLOW_COVERAGE).
pub struct UpdateServiceEngine {
mut:
	repo            &state.StateRepository
	bus             &eventbus.ToolkitEventBus
	current_version string
}

// new_update_service_engine creates the service with the real resolved
// toolkit version — never a hardcoded one.
pub fn new_update_service_engine(repo &state.StateRepository, bus &eventbus.ToolkitEventBus) &UpdateServiceEngine {
	return &UpdateServiceEngine{
		repo: repo
		bus: bus
		current_version: agent_toolkit_core.resolve_toolkit_version()
	}
}

// check_update consults the configured channel and pin state. Without a real
// release-feed reader there is no offer to make: it returns none rather than
// inventing a feed version, URL or digest. Wiring a real feed is a feature
// follow-up; the channel/pin configuration semantics are preserved.
pub fn (mut s UpdateServiceEngine) check_update(current string, channel string) ?UpdateInfoEngine {
	ch := if channel == '' { 'stable' } else { channel }
	_ = ch
	_ = current
	// pinned installs never receive offers
	if s.repo.snapshot().data['update:pinned'] == 'true' {
		return none
	}
	// No real feed reader is wired: an update offer requires verified feed
	// data (version + artifact URL + digest + provenance). None is honest.
	return none
}

// verify performs a REAL digest verification: SHA-256 of the actual content
// bytes must equal the expected digest. The former implementation ignored
// the content entirely and compared against a hardcoded string.
pub fn (s UpdateServiceEngine) verify(content string, expected_sha256 string) bool {
	if content.len == 0 || expected_sha256.len == 0 {
		return false
	}
	sum := sha256.hexhash(content)
	return sum == expected_sha256
}

// verify_provenance reports whether real provenance evidence exists for an
// update artifact. Without a real manifest there is none — a substring
// check is not verification.
pub fn (s UpdateServiceEngine) verify_provenance(manifest_path string) bool {
	if manifest_path == '' {
		return false
	}
	return os.is_file(manifest_path)
}

// apply is unavailable until a real updater exists. An update requires
// downloading and verifying a real artifact and replacing the installed
// binary; writing a version into state is not an update, so apply performs
// no mutation and reports false.
pub fn (mut s UpdateServiceEngine) apply(version string) bool {
	_ = version
	return false
}

// rollback is unavailable until a real updater with real artifacts exists.
pub fn (mut s UpdateServiceEngine) rollback(version string) bool {
	_ = version
	return false
}

// history returns only genuinely recorded updates. With no recorded update
// history the result is empty — never a fabricated feed entry.
pub fn (mut s UpdateServiceEngine) history() []UpdateInfoEngine {
	snap := s.repo.snapshot()
	mut out := []UpdateInfoEngine{}
	for k, _ in snap.data {
		if k.starts_with('update:applied:') && k.ends_with(':recorded') {
			ver := k.all_after('update:applied:').all_before(':recorded')
			out << UpdateInfoEngine{
				latest: ver
				channel: snap.data['update:applied:${ver}:channel'] or { 'unknown' }
			}
		}
	}
	return out
}

// manifest_json reports the honest availability state of the update
// service. No manifest is fabricated.
pub fn (s UpdateServiceEngine) manifest_json() string {
	return json2.encode({
		'available': 'false'
		'note':      'no release-feed reader wired — no update manifest exists'
		'current':   s.current_version
	},
		escape_unicode: true
	)
}

// UpdateManifest is the required shape of an update manifest: a real
// version, artifact digest and provenance reference.
struct UpdateManifest {
	version    string
	sha256     string
	provenance string
}

// manifest_verify structurally validates an offered manifest: it must parse
// as JSON and carry version, sha256 and provenance fields. Substring
// presence on arbitrary text is not validation.
pub fn (s UpdateServiceEngine) manifest_verify(text string) bool {
	r := json2.decode[UpdateManifest](text) or { return false }
	return r.version != '' && r.sha256 != '' && r.provenance != ''
}

// cache_path returns the XDG cache path for staged update artifacts.
pub fn cache_path(version string) string {
	base := os.getenv('XDG_CACHE_HOME')
	home := os.home_dir()
	cache := if base.len > 0 { base } else { os.join_path(home, '.cache') }
	return os.join_path(cache, 'agent-toolkit', 'updates', version, 'agent-toolkit')
}

// Engine wrappers for desktop management via the Engine API (no shell).

// check_for_update via Engine. None means no verified offer exists.
pub fn (mut e Engine) check_for_update(current string, channel string) ?UpdateInfoEngine {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut svc := new_update_service_engine(e.repo, e.bus)
	return svc.check_update(current, channel)
}

// apply_update via Engine — unavailable until a real updater exists; a
// state-only version change is not an update.
pub fn (mut e Engine) apply_update(version string) bool {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut svc := new_update_service_engine(e.repo, e.bus)
	return svc.apply(version)
}

// update_history via Engine — only genuinely recorded updates.
pub fn (mut e Engine) update_history() []UpdateInfoEngine {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut svc := new_update_service_engine(e.repo, e.bus)
	return svc.history()
}

// update_verify performs a real SHA-256 verification of the provided
// artifact content against the expected digest via Engine. Without the real
// artifact bytes the verification is false — never a hardcoded pass.
pub fn (mut e Engine) update_verify(content string, expected_sha256 string) bool {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut svc := new_update_service_engine(e.repo, e.bus)
	return svc.verify(content, expected_sha256)
}
