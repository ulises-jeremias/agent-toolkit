module swarm

// Queue composer — per-run queued guidance for Operations run control.
//
// A composer holds one run's guidance drafts and queued items with an explicit
// typed state machine:
//
//   draft (per-run text, preserved across selection switches)
//     → enqueue → queued → begin_deliver → delivering → delivered
//                                                  ↘ failed → requeue → queued
//                        queued → cancel → canceled (before delivery only)
//
// Rules, enforced by the transitions (not by convention):
// - drafts are never auto-cleared: switching runs, failed deliveries, and
//   canceled items all leave other drafts untouched;
// - only queued items can be canceled or delivered — cancel-before-delivery
//   is structural, and delivered/failed/canceled are terminal;
// - a failed delivery keeps its text on the item AND restores the draft, so
//   no typed guidance is ever lost to an error;
// - Escape (or any blur) only releases input focus; destruction happens only
//   through explicit cancel/dismiss calls;
// - failures are truthful: failed items carry the Engine error string.

// QueueItemStatus is the explicit lifecycle of one queued guidance item.
pub enum QueueItemStatus {
	queued
	delivering
	delivered
	failed
	canceled
}

// QueueItem is one guidance text submitted for a run.
pub struct QueueItem {
pub:
	id         string
	run_id     string
	text       string
	created_at i64
pub mut:
	status   QueueItemStatus
	artifact string // artifact path once delivered
	err      string // Engine error once failed
}

// QueueComposer holds one run's draft plus its queued items.
pub struct QueueComposer {
pub:
	run_id string
mut:
	draft   string
	items   []QueueItem
	seq     int
	clock   i64
}

// new_queue_composer creates a composer for a run (empty draft, no items).
pub fn new_queue_composer(run_id string) QueueComposer {
	return QueueComposer{
		run_id: run_id
	}
}

// set_clock fixes the timestamp source (tests; 0 = wall time at enqueue).
pub fn (mut c QueueComposer) set_clock(ts i64) {
	c.clock = ts
}

fn (mut c QueueComposer) now() i64 {
	if c.clock > 0 {
		return c.clock
	}
	return 0
}

// set_draft stores the per-run draft. Empty drafts are kept as-is —
// clearing is an explicit user edit, never a side effect.
pub fn (mut c QueueComposer) set_draft(text string) {
	c.draft = text
}

// draft_text returns the preserved draft for the run.
pub fn (c QueueComposer) draft_text() string {
	return c.draft
}

// enqueue moves the draft into a queued item. Empty/blank drafts are refused
// with an error and the draft is left untouched.
pub fn (mut c QueueComposer) enqueue() !QueueItem {
	t := c.draft.trim_space()
	if t == '' {
		return error('guidance empty — type guidance before queuing')
	}
	if t.len > 4096 {
		return error('guidance too long (4096 max)')
	}
	c.seq++
	item := QueueItem{
		id: 'q-${c.seq}'
		run_id: c.run_id
		text: t
		status: .queued
		created_at: c.now()
	}
	c.items << item
	c.draft = ''
	return item
}

// queued_items returns items still awaiting delivery (oldest first).
pub fn (c QueueComposer) queued_items() []QueueItem {
	return c.items.filter(it.status == .queued)
}

// history returns terminal items (delivered/failed/canceled), newest last.
pub fn (c QueueComposer) history() []QueueItem {
	return c.items.filter(it.status != .queued && it.status != .delivering)
}

// get returns an item by id (none when unknown).
pub fn (c QueueComposer) get(id string) ?QueueItem {
	for it in c.items {
		if it.id == id {
			return it
		}
	}
	return none
}

// begin_deliver moves a queued item to delivering. Anything else — unknown
// id, double delivery, terminal item — is refused.
pub fn (mut c QueueComposer) begin_deliver(id string) !QueueItem {
	for i, it in c.items {
		if it.id == id {
			if it.status != .queued {
				return error('cannot deliver ${id} (status ${it.status})')
			}
			c.items[i].status = .delivering
			return c.items[i]
		}
	}
	return error('queued guidance not found: ${id}')
}

// mark_delivered resolves a delivering item with its artifact path.
pub fn (mut c QueueComposer) mark_delivered(id string, artifact string) !QueueItem {
	for i, it in c.items {
		if it.id == id {
			if it.status != .delivering {
				return error('cannot resolve ${id} (status ${it.status})')
			}
			c.items[i].status = .delivered
			c.items[i].artifact = artifact
			c.trim_history()
			return c.items[i]
		}
	}
	return error('queued guidance not found: ${id}')
}

// mark_failed resolves a delivering item with the Engine error and restores
// the text to the draft when the draft is empty — typed guidance is never
// lost to a failed write.
pub fn (mut c QueueComposer) mark_failed(id string, err_msg string) !QueueItem {
	for i, it in c.items {
		if it.id == id {
			if it.status != .delivering {
				return error('cannot resolve ${id} (status ${it.status})')
			}
			c.items[i].status = .failed
			c.items[i].err = err_msg
			if c.draft.trim_space() == '' {
				c.draft = it.text
			}
			c.trim_history()
			return c.items[i]
		}
	}
	return error('queued guidance not found: ${id}')
}

// cancel_before_delivery cancels a queued item. Delivery already started or
// finished cannot be canceled — the error says so.
pub fn (mut c QueueComposer) cancel_before_delivery(id string) !QueueItem {
	for i, it in c.items {
		if it.id == id {
			if it.status != .queued {
				return error('cannot cancel ${id} (status ${it.status} — already past delivery)')
			}
			c.items[i].status = .canceled
			c.trim_history()
			return c.items[i]
		}
	}
	return error('queued guidance not found: ${id}')
}

// requeue moves a failed item back to queued with its text intact.
pub fn (mut c QueueComposer) requeue(id string) !QueueItem {
	for i, it in c.items {
		if it.id == id {
			if it.status != .failed {
				return error('cannot requeue ${id} (status ${it.status})')
			}
			c.items[i].status = .queued
			c.items[i].err = ''
			return c.items[i]
		}
	}
	return error('queued guidance not found: ${id}')
}

// dismiss drops one terminal item from history. Queued/delivering items are
// never dismissable — cancel or resolve them first.
pub fn (mut c QueueComposer) dismiss(id string) ! {
	for i, it in c.items {
		if it.id == id {
			if it.status == .queued || it.status == .delivering {
				return error('cannot dismiss ${id} (status ${it.status})')
			}
			c.items.delete(i)
			return
		}
	}
	return error('queued guidance not found: ${id}')
}

// trim_history keeps the last 4 terminal items; queued/delivering are kept.
fn (mut c QueueComposer) trim_history() {
	mut terminal := []int{}
	for i, it in c.items {
		if it.status != .queued && it.status != .delivering {
			terminal << i
		}
	}
	for terminal.len > 4 {
		c.items.delete(terminal[0])
		terminal = terminal[1..].map(it - 1)
	}
}

// queue_status_label renders a status for the detail column (text, never color-only).
pub fn queue_status_label(s QueueItemStatus) string {
	return match s {
		.queued { 'Queued' }
		.delivering { 'Sending' }
		.delivered { 'Delivered' }
		.failed { 'Failed' }
		.canceled { 'Canceled' }
	}
}
