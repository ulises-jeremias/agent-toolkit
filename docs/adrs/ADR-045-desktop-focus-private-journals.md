# ADR-045: Store Desktop Focus journals in private app storage

- Status: Accepted storage direction; cross-platform race/reparse validation remains open
- Date: 2026-11-13
- Related: #1667, #1670, #1777, #1779, ADR-044

## Context

ADR-044 put durable Focus transcripts under the selected workspace. A workspace
and its repositories contain user-controlled files, including symlinks and hard
links. The journal checks path components before file operations and uses
`O_NOFOLLOW` where available, but portable Node filesystem APIs do not provide
one race-free, descriptor-relative operation for every path component on Linux,
macOS and Windows. Keeping writable journal state beside repository content
therefore leaves an avoidable redirect surface.

## Decision

1. Production Focus journals live under Electron `userData/focus-journals/`,
   outside the workspace and repositories.
2. Each workspace gets a directory keyed by SHA-256 of its canonical absolute
   path. The workspace path remains metadata; the hash is only a storage key.
3. The app-owned root, per-workspace directory, thread directories and files
   use private permissions where the platform supports POSIX modes. Existing
   symlinks and hard-linked journal files are rejected. File opens use
   `O_NOFOLLOW` where supported.
4. On first access, valid legacy threads under
   `<workspace>/.agent-toolkit/focus/threads/` are copied once to private
   storage. Each thread is staged in a private temporary directory and
   atomically renamed into place. A migration marker prevents later access to
   the workspace journal tree. Source files are never modified or deleted. For
   each source read, the app records every path component's device/inode before
   opening, opens the regular file with no-follow where supported, then checks
   the component identities and opened descriptor again before reading. A
   changed ancestor or leaf fails closed instead of redirecting the copy.
5. A symlink, hard link, malformed migration marker or unsafe legacy thread
   fails closed and is surfaced as a Focus history error. The app does not
   silently treat rejected legacy history as an empty successful migration.

The intended boundary is repository/workspace content versus app-owned local
state. After migration, normal Focus reads, writes and deletion use the private
store, so workspace entries cannot redirect those operations. Legacy import
now detects path-component replacement by comparing the opened file's device
and inode with stable pre/post path snapshots; a deterministic test swaps an
ancestor for a symlink (or Windows junction) during `open` and verifies
migration stops without creating a destination or marker. This narrows the
race window without claiming portable descriptor-relative traversal. Hosted
macOS and Windows junction/reparse-point results must complete before those
platform guarantees are claimed. The importer never writes to or deletes
workspace paths. This ADR does not claim isolation from another process
running as the same user with write access to the Electron `userData`
directory. Keep #1777 open until platform checks and security review accept the
guarantee.

## Consequences

- Existing history is copied without deleting the workspace copy, allowing
  rollback to the old application for pre-migration history. New threads
  created after migration exist only in app storage; an older version will not
  display them. If an older version is used to create new legacy threads after
  rollback, the migration marker means this version will not automatically
  import those threads. Keep Electron `userData` and workspace backups; record
  this limitation before treating downgrade as a seamless round trip.
- Focus history is local to this Desktop profile and is not automatically
  shared by copying or opening the workspace on another machine.
- A workspace path change produces a new private storage key. If its legacy
  `.agent-toolkit/focus/threads` directory moves with the workspace, the next
  access migrates those preserved records under the new key.
- The original workspace journal remains a user-owned backup. The app does not
  clean it up as part of migration or deletion in the new store.
- Tests cover symlink and hard-link rejection, nondestructive byte-for-byte
  migration, interrupted migration recovery, the ancestor-replacement race,
  and POSIX private-store permissions. macOS and Windows junction/reparse-point
  results are a release gate for closing #1777.

## Alternatives considered

- **Keep the journal in the workspace and add more `lstat` checks:** rejected;
  checks remain separate from open, rename and recursive removal on supported
  portable Node APIs.
- **Add a native filesystem addon for descriptor-relative traversal on every
  platform:** rejected for this rescue slice; it expands packaging and ABI
  risk. Revisit if the threat model expands to same-user processes modifying
  app-owned `userData`.
- **Delete or ignore old journals:** rejected because it would discard useful
  history or make the migration appear successful while hiding records.
