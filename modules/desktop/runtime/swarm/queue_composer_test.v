module swarm

// Queue composer transitions: draft → queued → delivered/failed/canceled.
// Behavior-named; clock fixed for determinism.

fn test_enqueue_refuses_empty_draft() {
	mut c := new_queue_composer('run-1')
	c.enqueue() or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'empty draft must not enqueue'
}

fn test_enqueue_assigns_ids_and_clears_draft() {
	mut c := new_queue_composer('run-1')
	c.set_draft('do the thing')
	assert c.draft_text() == 'do the thing'
	item := c.enqueue() or { panic(err.msg()) }
	assert item.id == 'q-1'
	assert item.status == .queued
	assert c.draft_text() == ''
	assert c.queued_items().len == 1
}

fn test_cancel_before_delivery_only() {
	mut c := new_queue_composer('run-1')
	c.set_draft('never mind')
	item := c.enqueue() or { panic(err.msg()) }
	c.cancel_before_delivery(item.id) or { panic(err.msg()) }
	assert c.queued_items().len == 0
	assert c.history().len == 1
	assert c.history()[0].status == .canceled
}

fn test_deliver_then_history() {
	mut c := new_queue_composer('run-1')
	c.set_draft('guidance text')
	item := c.enqueue() or { panic(err.msg()) }
	c.begin_deliver(item.id) or { panic(err.msg()) }
	c.mark_delivered(item.id, 'artifacts/guidance/q-1.md') or { panic(err.msg()) }
	assert c.queued_items().len == 0
	assert c.history().len == 1
	assert c.history()[0].artifact == 'artifacts/guidance/q-1.md'
}

fn test_failed_item_keeps_text_and_requeues() {
	mut c := new_queue_composer('run-1')
	c.set_draft('risky guidance')
	item := c.enqueue() or { panic(err.msg()) }
	c.begin_deliver(item.id) or { panic(err.msg()) }
	c.mark_failed(item.id, 'boom') or { panic(err.msg()) }
	failed := c.history().filter(it.status == .failed)
	assert failed.len == 1
	assert failed[0].text == 'risky guidance'
	c.requeue(item.id) or { panic(err.msg()) }
	assert c.queued_items().len == 1
}
