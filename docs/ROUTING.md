# Download routing

Every running instance owns a unique active session.

The active session exposes:

- `CARSON_INSTANCE_ID`
- `CARSON_SESSION_ID`
- `CARSON_TASK_PREFIX`
- `CARSON_TMUX_SESSION`

A task filename begins with the active `CARSON_TASK_PREFIX` for fast discovery.
Filename routing is only an optimization. Execution requires all authoritative
metadata below to appear in the first 4096 bytes of the task:

```text
# CARSON_AGENT_PROTOCOL=CARSON_DOWNLOAD_AGENT_V1
# CARSON_INSTANCE_ID=<exact instance id>
# CARSON_SESSION_ID=<exact active session id>
# CARSON_PAYLOAD_TYPE=NEXT_LLM_TASK
```

Only after those checks match does the listener SHA-256 hash the candidate.
Processed hashes are persisted per session.

Multiple independent listeners may watch the same Download directory because
their task prefixes and authoritative instance/session metadata are unique.
