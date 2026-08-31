module desktop_engine

import os

fn test_di_resolves_capability_and_runtime() {
	mut c := new_di_container()
	c.register('skills_catalog', .capability, fn () !voidptr {
		return unsafe { nil }
	}) or { assert false, err.msg() }
	c.register('job_runner', .runtime, fn () !voidptr {
		return unsafe { nil }
	}) or { assert false, err.msg() }
	assert c.has('skills_catalog')
	assert c.has('job_runner')
	assert !c.has('missing')
	caps := c.list_by_plane(.capability)
	runs := c.list_by_plane(.runtime)
	assert 'skills_catalog' in caps
	assert 'job_runner' in runs
	assert 'job_runner' !in caps
}

struct SingletonCounter {
mut:
	n int
}

fn test_di_singleton_cached() {
	mut counter := &SingletonCounter{}
	mut c := new_di_container()
	c.register_singleton('svc', .capability, fn [mut counter] () !voidptr {
		counter.n++
		return voidptr(0x1)
	}) or { assert false, err.msg() }
	v1 := c.resolve('svc') or { panic(err.msg()) }
	v2 := c.resolve('svc') or { panic(err.msg()) }
	// singleton factory should be called once; second resolve returns cached instance
	assert counter.n == 1
	assert v1 == v2
}

fn test_env_precedence_project_workspace_toolkit() {
	// AGENT_TOOLKIT_ROOT precedence Project > Workspace > Toolkit preserved
	dir := os.join_path(os.temp_dir(), 'at-di-env-${os.getpid()}')
	os.mkdir_all(os.join_path(dir, 'skills')) or { assert false, err.msg() }
	defer { os.rmdir_all(dir) or {} }
	old := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', dir, true)
	defer {
		if old.len > 0 {
			os.setenv('AGENT_TOOLKIT_ROOT', old, true)
		} else {
			os.unsetenv('AGENT_TOOLKIT_ROOT')
		}
	}
	env := resolve_env()
	assert env.tier == 'override'
	assert env.toolkit_root == dir
}

fn test_engine_di_contains_default_services() {
	tmp := os.join_path(os.temp_dir(), 'engine-di-def-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut e := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	e.init() or { assert false, err.msg() }
	mut di := e.di_container()
	assert di.has('skills_catalog')
	assert di.has('agents_catalog')
	assert di.has('products_catalog')
	assert di.has('job_runner')
	assert di.has('loop_service')
}
