module desktop_engine

import os

fn test_engine_lifecycle_headless() {
	tmp := os.join_path(os.temp_dir(), 'engine-lifecycle-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut e := new_engine(EngineConfig{
		persist_path: persist
	})
	// new -> init -> start boots headless
	e.init() or { assert false, err.msg() }
	assert !e.is_running()
	e.start() or { assert false, err.msg() }
	assert e.is_running()
	// double start idempotent
	e.start() or { assert false, 'double start should be safe: ${err.msg()}' }
	assert e.is_running()
	// stop
	e.stop() or { assert false, err.msg() }
	assert !e.is_running()
	// double stop safe
	e.stop() or { assert false, 'double stop should be safe: ${err.msg()}' }
	assert !e.is_running()
}

fn test_engine_context_cancellation_propagates() {
	tmp := os.join_path(os.temp_dir(), 'engine-ctx-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut e := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { assert false, err.msg() }
	e.start() or { assert false, err.msg() }
	assert e.is_running()
	e.stop() or { assert false, err.msg() }
	assert !e.is_running()
	// context should be canceled after stop; second stop no-op
	e.stop() or { assert false, err.msg() }
}

fn test_engine_api_call_counter() {
	tmp := os.join_path(os.temp_dir(), 'engine-api-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut e := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { assert false, err.msg() }
	e.start() or { assert false, err.msg() }
	before := e.api_call_count()
	_ = e.snapshot()
	_ = e.revision()
	_ = e.doctor()
	after := e.api_call_count()
	assert after > before, 'engine_api_call should increment'
	assert after >= 3
	e.stop() or {}
}
