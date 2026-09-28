module desktop

import os

// Office Handoff button must queue a real GOD-mailbox handoff — a durable
// id, never a message-only claim.
fn test_engine_handoff_to_reviewer_queues_real_id() {
	tmp := os.join_path(os.temp_dir(), 'desktop-handoff-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	cfg := DesktopConfig{
		title: 'Test Handoff'
		width: 1280
		height: 800
		headless: true
	}
	cfg.validate() or { panic(err.msg()) }
	mut d := new_desktop(DesktopBootArgs{
		config: cfg
		persist_path: persist
	})
	d.boot() or { panic(err.msg()) }
	defer { d.shutdown() or {} }
	id := d.engine_handoff_to_reviewer('implementer') or { panic(err.msg()) }
	assert id.starts_with('h-'), 'handoff must return a real queued id, got: ${id}'
	inbox, outbox := d.god_mailbox_counts()
	assert outbox >= 1, 'queued handoff must surface in mailbox counts (inbox=${inbox} outbox=${outbox})'
}
