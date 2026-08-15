# Arbitrary LLM chat bootstrap

The repository can generate a device-specific Markdown attachment that teaches
an otherwise context-free AI chat how to emit correctly routed harness tasks.

After installing and starting an instance:

```bash
bin/carson-chat-bootstrap <INSTANCE_ID>
```

The command writes a Markdown file containing the current live instance ID,
session ID, filename prefix, stable A result path, and task-file contract.
Attach that generated Markdown file to the new AI chat.

The generated file also tells the AI to use `carson-ingest` in its one-line
launcher. This separates **where an AI client happens to save an attachment**
from **the harness inbox directory**. The ingest helper can locate an exact
filename in common Termux-accessible shared-storage locations and copy it to
the configured inbox.

App-private storage that Android does not expose to Termux cannot be discovered
by the harness. In that case the attachment must first be saved/shared into an
accessible shared-storage location.

## Path behavior

`install.sh` remains explicit and reproducible: callers provide
`CARSON_DOWNLOAD_DIR`, `CARSON_A_DIR`, and `CARSON_B_DIR`.

`quick-install.sh` is the convenience path for a normal fresh device. It:

- auto-discovers the usual Termux shared Download directory;
- defaults the stable result path to `$HOME/storage/shared/carson-agent/a`;
- defaults archive history to `$HOME/storage/shared/carson-agent/B`;
- starts the listener automatically.

Environment variables override every quick-install default. The project does
not mutate the user's persistent shell environment; resolved paths are passed
into `install.sh` and stored in that instance's manifest.

For multiple independent instances on one device, explicitly assign distinct A
and B directories. They may still share the same Download inbox.
