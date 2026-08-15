# CARSON Termux Agent Harness

Portable, multi-instance download-file agent harness for Termux.

The harness watches an environment-configured Download directory for
LLM-generated shell tasks. Each task is routed to one exact active
instance/session, deduplicated by SHA-256, executed, and converted into the next
LLM-facing message through an A/B file interface.

## Required runtime configuration

```text
CARSON_DOWNLOAD_DIR
CARSON_A_DIR
CARSON_B_DIR
```

No Android device-specific storage path is built into the repository.

## Isolation

- Every install creates a new instance by default.
- Every start creates a new session.
- Instances have separate state, installed source, A/B paths, ledgers, logs,
  session identities, and tmux identities.
- Multiple instances may watch the same Download directory.
- A session-specific filename prefix is a fast routing optimization.
- Exact instance/session metadata inside the task remains authoritative.

## Commands

```text
carson-agent init
carson-agent list
carson-agent show <INSTANCE_ID>
carson-agent start <INSTANCE_ID>
carson-agent stop <INSTANCE_ID>
carson-agent restart <INSTANCE_ID>
carson-agent status <INSTANCE_ID>
```

`carson-agent list` exposes the active instance/session routing information
needed by a human or LLM before generating a task file.

## Install

From a repository checkout:

```bash
CARSON_DOWNLOAD_DIR="..." \
CARSON_A_DIR="..." \
CARSON_B_DIR="..." \
CARSON_AUTOSTART=1 \
bash ./install.sh
```

## Validate

Before publication or installation testing:

```bash
bash ./validate.sh
```

See:

- `docs/INSTALLATION.md`
- `docs/INSTANCE_MODEL.md`
- `docs/ROUTING.md`
- `docs/SELF_PUBLISH.md`

The repository contains generic implementation only. Runtime state, generated
instance/session identities, device credentials, processed-checksum ledgers,
event logs, A/B history, and authentication material are not repository source.
