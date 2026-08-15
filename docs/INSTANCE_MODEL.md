# Instance model

The harness distinguishes three identities:

1. **Repository checkout** — generic reusable source.
2. **Instance** — persistent isolated installation/runtime state.
3. **Session** — one active listener generation belonging to an instance.

A new installation creates a new instance ID unless the caller explicitly
provides one. Starting an instance creates a new session ID, route token,
filename prefix, checksum ledger, event log, and tmux listener identity.

Multiple listeners may watch the same Download directory. A candidate must
match both the session-specific filename prefix and the authoritative
instance/session metadata inside the file before it can execute.

Mutable A and B directories are instance-owned and may not be shared between
registered instances.
