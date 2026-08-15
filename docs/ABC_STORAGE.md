# A / B / C storage model

For the normal quick-install layout:

- `A` contains the current harness result and is lifecycle-managed.
- `B` receives archives of prior A contents.
- `C` is persistent user-facing storage and is never cleared by normal A/B cycling.

Defaults:

```text
$HOME/storage/shared/carson-agent/a
$HOME/storage/shared/carson-agent/B
$HOME/storage/shared/carson-agent/C
```

C is intended for reusable handoff notes, prompts, and other files that should
remain visible to Android apps.

The watched Download inbox is separately auto-discovered and canonicalized to
its physical path. `carson-submit` can locate a plain `.sh` downloaded into
common Termux-accessible shared-storage locations, wrap it locally with the
active routing metadata, submit it, wait for completion, and print A.
