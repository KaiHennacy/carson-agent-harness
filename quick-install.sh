#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -d "$HOME/storage/shared" ]] || {
  printf '%s\n' "ERROR=Termux shared storage is unavailable."
  printf '%s\n' "Run termux-setup-storage, grant storage access, then retry."
  exit 1
}

if [[ -n "${CARSON_DOWNLOAD_DIR:-}" ]]; then
  DOWNLOAD_DIR="$CARSON_DOWNLOAD_DIR"
else
  DOWNLOAD_DIR=""
  for candidate in \
    "$HOME/storage/downloads" \
    "$HOME/storage/shared/Download" \
    "$HOME/storage/shared/Downloads"
  do
    if [[ -d "$candidate" ]]; then
      DOWNLOAD_DIR="$candidate"
      break
    fi
  done
  [[ -n "$DOWNLOAD_DIR" ]] || {
    printf '%s\n' "ERROR=Could not auto-discover a shared Download directory."
    printf '%s\n' "Set CARSON_DOWNLOAD_DIR explicitly and retry."
    exit 1
  }
fi

# Canonicalize the selected directory before persisting it. Termux commonly
# exposes ~/storage/downloads as a directory symlink; storing the physical path
# prevents listener scans from depending on find(1)'s symlink traversal mode.
DOWNLOAD_DIR="$(cd "$DOWNLOAD_DIR" && pwd -P)"

# Stable device-level output location for the normal single primary instance.
# Advanced/multi-instance installs can override A/B paths explicitly.
A_DIR="${CARSON_A_DIR:-$HOME/storage/shared/carson-agent/a}"
B_DIR="${CARSON_B_DIR:-$HOME/storage/shared/carson-agent/B}"
C_DIR="${CARSON_C_DIR:-$HOME/storage/shared/carson-agent/C}"
mkdir -p "$A_DIR" "$B_DIR" "$C_DIR"

cp -p "$ROOT/docs/LLM_DOWNLOADABLE_SCRIPT_NOTE.md"   "$C_DIR/LLM_DOWNLOADABLE_SCRIPT_NOTE.md"

env \
  CARSON_DOWNLOAD_DIR="$DOWNLOAD_DIR" \
  CARSON_A_DIR="$A_DIR" \
  CARSON_B_DIR="$B_DIR" \
  CARSON_INSTANCE_LABEL="${CARSON_INSTANCE_LABEL:-default}" \
  CARSON_AUTOSTART="${CARSON_AUTOSTART:-1}" \
  bash "$ROOT/install.sh"

# GLOBAL_CARSON_PROMPT_INSTALL
# carson-prompt is stateless and should be available as a normal Termux command
# after a clean quick-install. PREFIX is Termux's portable installation prefix.
if [[ -z "${PREFIX:-}" || ! -d "$PREFIX/bin" ]]; then
  printf 'ERROR=Termux PREFIX/bin unavailable; cannot install carson-prompt globally\n' >&2
  exit 1
fi
install -m 755 "$ROOT/bin/carson-prompt" "$PREFIX/bin/carson-prompt"
command -v carson-prompt >/dev/null 2>&1 || {
  printf 'ERROR=global carson-prompt command not resolvable after install\n' >&2
  exit 1
}
