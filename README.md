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

## Arbitrary AI chats

For a normal fresh Termux device, `bash ./quick-install.sh` auto-discovers the
usual shared Download directory and uses a stable device-level A/B location.
Explicit environment variables remain available for custom or multi-instance
installations.

To onboard a context-free AI chat, generate a live routing attachment:

```bash
bin/carson-chat-bootstrap <INSTANCE_ID>
```

Attach the generated Markdown file to that chat. It instructs the model how to
emit a routed downloadable task and how to use `bin/carson-ingest` so the
workflow does not depend on which accessible shared-storage folder the AI
client used for its download.

See `docs/ARBITRARY_LLM_CHAT.md`.

## Plain-script bridge for arbitrary AI chats

An arbitrary AI chat does not need to know the CARSON routing protocol.

Ask it for an ordinary downloadable Termux `.sh` file, then submit that file
locally:

```bash
bin/carson-submit <INSTANCE_ID> <DOWNLOADED_FILE.sh>
```

`carson-ingest` adds the active local routing envelope only after the file is on
the user's device. Already-routed CARSON task files continue to pass through.

See `docs/ABC_STORAGE.md`.
