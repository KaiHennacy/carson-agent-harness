# Installation

A repository checkout is generic source, not a runtime instance.

Every invocation of `install.sh` creates a **new isolated instance by default**.
It will not silently reuse an existing instance or overwrite another install.

## Required environment variables

```text
CARSON_DOWNLOAD_DIR
CARSON_A_DIR
CARSON_B_DIR
```

The Download directory may be shared by many instances. `CARSON_A_DIR` and
`CARSON_B_DIR` are mutable per-instance locations and must not already belong
to another registered instance.

## Optional environment variables

```text
CARSON_INSTANCE_ID
CARSON_INSTANCE_LABEL
CARSON_STATE_ROOT
CARSON_INSTALL_BASE
CARSON_REGISTRY_ROOT
CARSON_AUTOSTART
```

If `CARSON_INSTANCE_ID` is omitted, a unique ID is generated.

If `CARSON_STATE_ROOT` is omitted, state defaults beneath:

```text
$HOME/.carson_agent_instances/<INSTANCE_ID>
```

If `CARSON_INSTALL_BASE` is omitted, an isolated source copy is installed under:

```text
$HOME/.local/share/carson-agent-harness/<INSTANCE_ID>
```

`CARSON_AUTOSTART=1` starts a new unique listener session after installation.
The default is `0`.

## Example

```bash
CARSON_DOWNLOAD_DIR="$HOME/storage/shared/Download" \
CARSON_A_DIR="$HOME/storage/shared/my-agent/a" \
CARSON_B_DIR="$HOME/storage/shared/my-agent/B" \
CARSON_INSTANCE_LABEL="my-agent" \
CARSON_AUTOSTART=1 \
bash ./install.sh
```

Use the installed CLI's `list` command to discover instances and active routing
information before generating a task file.

## Global prompt command

`quick-install.sh` installs the stateless `carson-prompt` helper into
`$PREFIX/bin/carson-prompt`, so a clean Termux installation can invoke:

```bash
carson-prompt "your task"
```

without knowing the generated CARSON instance ID or installation directory.
This is part of the portable quick-install contract. The helper contains no
instance/session routing state.
