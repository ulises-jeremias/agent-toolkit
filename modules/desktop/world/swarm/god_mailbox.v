module swarm

// GOD Mailbox — Dunder Mifflin Paper Company, Scranton Branch.
// Michael Scott's desk is the GOD mailbox: every envelope (handoff) lands here
// before routing. Brass inbox flag glows when inbox>0, flap animates open/closed
// at 60 FPS, perforated feed-strip dots line the bullpen wall, and handoffs
// follow mailbox law (no direct desk→desk). Office charm that reads Scranton
// at a glance, yet remains Super Potente via Engine seams and EventBus.
import sync
import time
import x.json2
import desktop_engine.state as engine_state
import desktop_engine.eventbus

// GodMailboxRoutingPolicy enforces mailbox law: no direct desk→desk without mailbox.
pub enum GodMailboxRoutingPolicy {
	mailbox_only
	direct_forbidden
}

// GodEnvelope is a GOD-routed handoff via central mailbox.
pub struct GodEnvelope {
pub:
	id       string
	from     string
	to       string
	payload  string
	artifact string // optional handoff artifact file rel path
	ts       i64
	via      string // always GOD-mailbox
	priority int
}

// GodMailbox is the central router — Michael's mailbox. All handoffs enqueue via mailbox.
pub struct GodMailbox {
mut:
	inbox    int
	outbox   int
	queue    []GodEnvelope
	policy   GodMailboxRoutingPolicy
	bus      &eventbus.ToolkitEventBus
	repo     &engine_state.StateRepository
	mu       sync.RwMutex
	revision u64
	emitted  u64
}

// new_god_mailbox creates the Workshop mailbox bound to Engine seams.
pub fn new_god_mailbox(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &GodMailbox {
	return &GodMailbox{
		policy: .mailbox_only
		bus: bus
		repo: repo
	}
}

// enqueue routes a handoff via GOD mailbox — validates mailbox law and publishes swarm_handoff event.
// Returns envelope id. Stores durable handoff artifact file reference if provided.
pub fn (mut m GodMailbox) enqueue(from string, to string, payload string, artifact string) !string {
	if from.len == 0 || to.len == 0 {
		return error('GOD mailbox: from/to required')
	}
	if from == to {
		return error('GOD mailbox: self-route forbidden — must route via mailbox')
	}
	if from.contains('..') || to.contains('..') {
		return error('GOD mailbox: traversal forbidden')
	}
	if artifact.len > 0 {
		if artifact.contains('..') {
			return error('GOD mailbox: artifact traversal forbidden')
		}
		if artifact.len > 512 {
			return error('GOD mailbox: artifact path too long')
		}
	}
	m.mu.lock()
	defer { m.mu.unlock() }
	id := 'god-${time.now().unix_nano() % 1000000:06d}'
	env := GodEnvelope{
		id: id
		from: from
		to: to
		payload: payload
		artifact: artifact
		ts: time.now().unix()
		via: 'GOD-mailbox'
		priority: 0
	}
	m.queue << env
	m.inbox++
	m.outbox++
	// persist durable via StateRepository for EventBus→frame tick
	mut tx := m.repo.begin('god-mailbox-enqueue')
	tx.set('swarm/god_mailbox/inbox', m.inbox.str())
	tx.set('swarm/god_mailbox/outbox', m.outbox.str())
	tx.set('swarm/god_mailbox/last_id', id)
	tx.set('swarm/god_mailbox/last_from', from)
	tx.set('swarm/god_mailbox/last_to', to)
	tx.set('swarm/handoffs/${id}/from', from)
	tx.set('swarm/handoffs/${id}/to', to)
	tx.set('swarm/handoffs/${id}/payload', payload)
	tx.set('swarm/handoffs/${id}/artifact', artifact)
	tx.set('swarm/handoffs/${id}/via', 'GOD-mailbox')
	tx.set('swarm/handoffs/${id}/status', 'queued')
	rev := tx.commit() or { return error('god mailbox persist failed: ${err}') }
	m.revision = rev.revision
	m.emitted++
	// publish typed swarm_handoff + state_changed for Activity Journal
	m.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_handoff
		revision: rev.revision
		path: 'swarm/handoff/${id}'
		payload: json2.encode({
			'id':       id
			'from':     from
			'to':       to
			'payload':  payload
			'artifact': artifact
			'via':      'GOD-mailbox'
			'ts':       env.ts.str()
		})
	})
	m.bus.publish(eventbus.ToolkitEvent{
		kind: .state_changed
		revision: rev.revision
		path: 'swarm:god:${id}'
		payload: json2.encode(env)
	})
	return id
}

// dequeue removes the oldest envelope from mailbox (FIFO).
pub fn (mut m GodMailbox) dequeue() ?GodEnvelope {
	m.mu.lock()
	defer { m.mu.unlock() }
	if m.queue.len == 0 {
		return none
	}
	env := m.queue[0]
	m.queue.delete(0)
	if m.inbox > 0 {
		m.inbox--
	}
	mut tx := m.repo.begin('god-mailbox-dequeue')
	tx.set('swarm/god_mailbox/inbox', m.inbox.str())
	tx.set('swarm/handoffs/${env.id}/status', 'active')
	rev := tx.commit() or { return env }
	m.revision = rev.revision
	m.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_status
		revision: rev.revision
		path: 'swarm/handoff/${env.id}/active'
		payload: json2.encode({
			'id':     env.id
			'status': 'active'
		})
	})
	return env
}

// complete marks a handoff completed with optional artifact file path.
pub fn (mut m GodMailbox) complete(id string, artifact_path string) bool {
	m.mu.lock()
	defer { m.mu.unlock() }
	for i, env in m.queue {
		if env.id == id {
			m.queue.delete(i)
			break
		}
	}
	// persist status even if not in queue (already dequeued)
	mut tx := m.repo.begin('god-mailbox-complete')
	tx.set('swarm/handoffs/${id}/status', 'completed')
	if artifact_path.len > 0 {
		tx.set('swarm/handoffs/${id}/artifact_completed', artifact_path)
	}
	rev := tx.commit() or { return false }
	m.revision = rev.revision
	m.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_status
		revision: rev.revision
		path: 'swarm/handoff/${id}/completed'
		payload: json2.encode({
			'id':       id
			'status':   'completed'
			'artifact': artifact_path
		})
	})
	return true
}

// pending returns mailbox queue snapshot ordered FIFO.
pub fn (m GodMailbox) pending() []GodEnvelope {
	m.mu.rlock()
	defer { m.mu.runlock() }
	return m.queue.clone()
}

// inbox_count returns pending inbox count.
pub fn (m GodMailbox) inbox_count() int {
	m.mu.rlock()
	defer { m.mu.runlock() }
	return m.inbox
}

// outbox_count returns total dispatched.
pub fn (m GodMailbox) outbox_count() int {
	m.mu.rlock()
	defer { m.mu.runlock() }
	return m.outbox
}

// on_bus_event handles EventBus→mailbox tick (distinct-until-changed).
pub fn (mut m GodMailbox) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .state_changed && ev.kind != .swarm_handoff && ev.kind != .watcher_invalidated {
		return false
	}
	if snap.revision == m.revision {
		return false
	}
	m.revision = snap.revision
	m.emitted++
	return true
}

// ── Dunder office charm — mailbox glow + envelope routing UI ────────────

// mailbox_glow_level returns brass glow alpha for the GOD mailbox flag.
// Inbox 0 → 0 (flag down, no glow), inbox>0 → 22-35 pulsing brass, frame
// drives 30-frame pulse (atelier glow at 60 FPS). Headless returns 0.
pub fn mailbox_glow_level(inbox int, frame int) int {
	if inbox <= 0 {
		return 0
	}
	// pulse every 30 frames between 18 and 35 (brass 22%→14% alpha)
	if frame % 30 < 15 {
		return 32
	}
	return 18
}

// mailbox_flag_text returns paper-slip text for the flag badge.
// Office charm: inbox count as paper requisition count on Michael's desk.
pub fn mailbox_flag_text(inbox int) string {
	if inbox <= 0 {
		return 'no mail'
	}
	if inbox == 1 {
		return '1 envelope'
	}
	return '${inbox} envelopes'
}

// mailbox_envelope_line renders the envelope story line for the floor.
// Dunder charm: "✉ Jim → Pam: quarterly report (via GOD mailbox)"
pub fn mailbox_envelope_line(env GodEnvelope) string {
	if env.artifact != '' {
		return '✉ ${env.from} → ${env.to}: ${env.payload} [${env.artifact}] via ${env.via}'
	}
	return '✉ ${env.from} → ${env.to}: ${env.payload} via ${env.via}'
}
