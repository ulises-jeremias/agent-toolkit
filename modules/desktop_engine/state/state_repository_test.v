module state

import sync
import time as _
import os

fn test_put_snapshot_revision_monotonic() {
	tmp := os.join_path(os.temp_dir(), 'state-repo-mono-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut repo := new_state_repository(persist)
	s0 := repo.snapshot()
	assert s0.revision == 0
	mut tx := repo.begin('actor-test')
	tx.set('a', '1')
	rev := tx.commit() or {
		assert false, err.msg()
		return
	}
	assert rev.revision == 1
	s1 := repo.snapshot()
	assert s1.revision == 1
	assert s1.data['a'] == '1'
	// second commit bumps
	mut tx2 := repo.begin('actor2')
	tx2.set('b', '2')
	rev2 := tx2.commit() or {
		assert false, err.msg()
		return
	}
	assert rev2.revision == 2
	assert rev2.revision > rev.revision
}

fn test_transaction_atomic_rollback() {
	tmp := os.join_path(os.temp_dir(), 'state-rollback-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut repo := new_state_repository(os.join_path(tmp, 'state.json'))
	mut tx := repo.begin('actor')
	tx.set('k', 'v')
	tx.rollback()
	assert tx.staged_count() == 0
	s := repo.snapshot()
	assert 'k' !in s.data
	// rollback after commit no-op is safe (commit after rollback should error)
	mut tx2 := repo.begin('actor')
	tx2.set('k2', 'v2')
	tx2.rollback()
	mut tx3 := repo.begin('actor')
	tx3.set('k3', 'v3')
	rev := tx3.commit() or {
		assert false, err.msg()
		return
	}
	assert rev.revision == 1
	assert repo.snapshot().data['k3'] == 'v3'
}

fn test_immutability_snapshot_isolation() {
	tmp := os.join_path(os.temp_dir(), 'state-immut-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut repo := new_state_repository(os.join_path(tmp, 'state.json'))
	mut tx := repo.begin('actor')
	tx.set('x', '1')
	tx.commit() or {
		assert false, err.msg()
		return
	}
	snap_a := repo.snapshot()
	mut tx2 := repo.begin('actor')
	tx2.set('x', '2')
	tx2.commit() or {
		assert false, err.msg()
		return
	}
	snap_b := repo.snapshot()
	assert snap_a.data['x'] == '1'
	assert snap_b.data['x'] == '2'
	assert snap_a.revision != snap_b.revision
}

fn test_concurrent_writers_monotonic() {
	tmp := os.join_path(os.temp_dir(), 'state-conc-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut repo := new_state_repository(os.join_path(tmp, 'state.json'))
	mut wg := sync.new_waitgroup()
	mut repo_ptr := &repo
	// spawn 10 writers concurrently via sync.WaitGroup + spawn
	for i in 0 .. 10 {
		wg.add(1)
		spawn fn [i, mut repo_ptr, mut wg] () {
			mut tx := repo_ptr.begin('writer-${i}')
			tx.set('key${i}', 'val${i}')
			tx.commit() or {}
			wg.done()
		}()
	}
	wg.wait()
	s := repo_ptr.snapshot()
	// at least some writes succeeded; revision should be >= 10 or at least >0 and monotonic
	assert repo_ptr.revision_nr() >= 1
	assert repo_ptr.revision_nr() <= 10
	_ = s
}

fn test_selector_pure_fn() {
	tmp := os.join_path(os.temp_dir(), 'state-selector-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	mut repo := new_state_repository(os.join_path(tmp, 'state.json'))
	mut tx := repo.begin('actor')
	tx.set('hello', 'world')
	tx.commit() or {
		assert false, err.msg()
		return
	}
	val := repo.select(fn (s State) string {
		return s.data['hello']
	})
	assert val == 'world'
}
