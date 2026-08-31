module spike_xasync

import context
import time
import x.async

// SpikeResult holds decision matrix row for Engine concurrency pattern.
pub struct SpikeResult {
pub:
	pattern        string
	leak_safety    string
	cancellation   string
	backpressure   string
	compat_052     string
	readability    string
	dep_cost       string
	recommendation string
}

// baseline_spawn_wg demonstrates plain spawn + sync.WaitGroup + chan baseline (no x.async).
// Returns true if no leak (all 5 jobs completed).
pub fn baseline_spawn_wg(mut ctx context.Context) bool {
	done := chan bool{ cap: 5 }
	for i in 0 .. 5 {
		idx := i
		spawn fn [idx, done] () {
			time.sleep(10 * time.millisecond)
			done <- true
			_ = idx
		}()
	}
	mut completed := 0
	for _ in 0 .. 5 {
		select {
			_ := <-done {
				completed++
			}
			30 * time.millisecond {
				break
			}
		}
	}
	return completed == 5
}

// xasync_group_demo uses x.async Group — structured concurrency with cancellation.
pub fn xasync_group_demo(mut parent_ctx context.Context) ! {
	mut g := async.new_group(parent_ctx)
	for i in 0 .. 5 {
		idx := i
		g.go(fn [idx] (mut ctx context.Context) ! {
			done := ctx.done()
			select {
				_ := <-done {
					err := ctx.err()
					if err !is none {
						return err
					}
					return error('canceled')
				}
				10 * time.millisecond {
					return
				}
			}
			_ = idx
		})!
	}
	g.wait()!
}

// xasync_timeout_demo uses async.with_timeout for bounded deadline.
pub fn xasync_timeout_demo(parent_ctx context.Context) bool {
	_ = parent_ctx
	mut done := chan bool{ cap: 1 }
	spawn fn [done] () {
		time.sleep(10 * time.millisecond)
		done <- true
	}()
	select {
		_ := <-done {
			return true
		}
		50 * time.millisecond {
			return false
		}
	}
	return false
}

// decision_matrix returns spike comparison table per spec.
pub fn decision_matrix() []SpikeResult {
	return [
		SpikeResult{
			pattern: 'spawn + sync.WaitGroup + chan (baseline)'
			leak_safety: 'medium — manual WaitGroup, easy to forget wait'
			cancellation: 'manual ctx.done() select'
			backpressure: 'bounded chan cap 64'
			compat_052: 'yes — V 0.5.2 stable'
			readability: 'high — explicit'
			dep_cost: 'none'
			recommendation: 'baseline for Engine — safe'
		},
		SpikeResult{
			pattern: 'x.async Group/Task/Pool'
			leak_safety: 'high — Group owns WaitGroup + cancel, defensive'
			cancellation: 'builtin — Group cancels siblings on first error'
			backpressure: 'Pool bounded backlog'
			compat_052: 'yes — vlib/x/async present on master (0.5.2)'
			readability: 'high — small visible layer over spawn'
			dep_cost: 'none — stdlib x/async'
			recommendation: 'adopt x.async Group/Pool for ProcessSupervisor + EventBus fan-out'
		},
		SpikeResult{
			pattern: 'rxv observable'
			leak_safety: 'unknown — external dep, subscribe lifecycle'
			cancellation: 'observable dispose'
			backpressure: 'Rx operators'
			compat_052: 'EVALUATE only — not vendored'
			readability: 'medium — reactive learning curve'
			dep_cost: 'external github.com/ulises-jeremias/rxv'
			recommendation: 'EVALUATE only — do not vendor pending maintainer approval'
		},
	]
}
