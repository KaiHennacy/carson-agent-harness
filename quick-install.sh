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

# Stable device-level output location for the normal single primary instance.
# Advanced/multi-instance installs can override A/B paths explicitly.
A_DIR="${CARSON_A_DIR:-$HOME/storage/shared/carson-agent/a}"
B_DIR="${CARSON_B_DIR:-$HOME/storage/shared/carson-agent/B}"
mkdir -p "$A_DIR" "$B_DIR"

env \
  CARSON_DOWNLOAD_DIR="$DOWNLOAD_DIR" \
  CARSON_A_DIR="$A_DIR" \
  CARSON_B_DIR="$B_DIR" \
  CARSON_INSTANCE_LABEL="${CARSON_INSTANCE_LABEL:-default}" \
  CARSON_AUTOSTART="${CARSON_AUTOSTART:-1}" \
  bash "$ROOT/install.sh"
