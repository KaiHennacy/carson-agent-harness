#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SOURCE_ROOT/lib/common.sh"

carson_require_dir CARSON_DOWNLOAD_DIR "${CARSON_DOWNLOAD_DIR:-}"
carson_require_dir CARSON_A_DIR "${CARSON_A_DIR:-}"
carson_require_dir CARSON_B_DIR "${CARSON_B_DIR:-}"

# Preserve caller-supplied values before reading any existing instance files.
# Existing manifests are intentionally read in isolated subshells so they
# cannot overwrite the new installation request.
REQUESTED_DOWNLOAD_DIR="$CARSON_DOWNLOAD_DIR"
REQUESTED_A_DIR="$CARSON_A_DIR"
REQUESTED_B_DIR="$CARSON_B_DIR"
REQUESTED_INSTANCE_ID="${CARSON_INSTANCE_ID:-}"
REQUESTED_INSTANCE_LABEL="${CARSON_INSTANCE_LABEL:-}"
REQUESTED_STATE_ROOT="${CARSON_STATE_ROOT:-}"
REQUESTED_INSTALL_BASE="${CARSON_INSTALL_BASE:-}"
REQUESTED_REGISTRY_ROOT="${CARSON_REGISTRY_ROOT:-}"
REQUESTED_AUTOSTART="${CARSON_AUTOSTART:-0}"

REGISTRY_ROOT="${REQUESTED_REGISTRY_ROOT:-$(carson_registry_root)}"
INSTANCE_ID="${REQUESTED_INSTANCE_ID:-$(carson_generate_instance_id)}"
STATE_ROOT="${REQUESTED_STATE_ROOT:-$REGISTRY_ROOT/$INSTANCE_ID}"
INSTALL_BASE="${REQUESTED_INSTALL_BASE:-$HOME/.local/share/carson-agent-harness}"
INSTALL_ROOT="$INSTALL_BASE/$INSTANCE_ID"
INSTANCE_LABEL="$REQUESTED_INSTANCE_LABEL"
AUTOSTART="$REQUESTED_AUTOSTART"

[[ "$AUTOSTART" == "0" || "$AUTOSTART" == "1" ]] ||
  carson_die "CARSON_AUTOSTART must be 0 or 1"

[[ ! -e "$STATE_ROOT/instance.env" ]] ||
  carson_die "Refusing to reuse existing instance state: $STATE_ROOT"
[[ ! -e "$INSTALL_ROOT" ]] ||
  carson_die "Refusing to overwrite existing install root: $INSTALL_ROOT"

index_dir="$REGISTRY_ROOT/.registry"
mkdir -p "$index_dir"

read_manifest_value() {
  local file="$1" variable="$2"
  bash -c '
    set -Eeuo pipefail
    file="$1"
    variable="$2"
    # shellcheck disable=SC1090
    source "$file"
    printf "%s" "${!variable:-}"
  ' _ "$file" "$variable"
}

for index_file in "$index_dir"/*.env; do
  [[ -f "$index_file" ]] || continue

  EXISTING_STATE_ROOT="$(read_manifest_value "$index_file" CARSON_STATE_ROOT)"
  [[ -n "$EXISTING_STATE_ROOT" ]] || continue
  [[ -f "$EXISTING_STATE_ROOT/instance.env" ]] || continue

  EXISTING_A_DIR="$(
    read_manifest_value "$EXISTING_STATE_ROOT/instance.env" CARSON_A_DIR
  )"
  EXISTING_B_DIR="$(
    read_manifest_value "$EXISTING_STATE_ROOT/instance.env" CARSON_B_DIR
  )"

  [[ "$REQUESTED_A_DIR" != "$EXISTING_A_DIR" ]] ||
    carson_die "CARSON_A_DIR is already owned by another instance: $REQUESTED_A_DIR"
  [[ "$REQUESTED_B_DIR" != "$EXISTING_B_DIR" ]] ||
    carson_die "CARSON_B_DIR is already owned by another instance: $REQUESTED_B_DIR"
done

mkdir -p "$INSTALL_ROOT"

for item in bin lib docs examples .github README.md .gitignore install.sh quick-install.sh validate.sh; do
  [[ -e "$SOURCE_ROOT/$item" ]] || continue
  cp -a "$SOURCE_ROOT/$item" "$INSTALL_ROOT/"
done

chmod 755 \
  "$INSTALL_ROOT/install.sh" \
  "$INSTALL_ROOT/bin/carson-agent" \
  "$INSTALL_ROOT/lib/common.sh" \
  "$INSTALL_ROOT/lib/listener.sh"

env \
  CARSON_REGISTRY_ROOT="$REGISTRY_ROOT" \
  CARSON_DOWNLOAD_DIR="$REQUESTED_DOWNLOAD_DIR" \
  CARSON_A_DIR="$REQUESTED_A_DIR" \
  CARSON_B_DIR="$REQUESTED_B_DIR" \
  CARSON_INSTANCE_ID="$INSTANCE_ID" \
  CARSON_INSTANCE_LABEL="$INSTANCE_LABEL" \
  CARSON_STATE_ROOT="$STATE_ROOT" \
  "$INSTALL_ROOT/bin/carson-agent" init >/dev/null

# Point the instance at its private installed source copy.
tmp="$STATE_ROOT/instance.env.tmp"
grep -v '^CARSON_SOURCE_ROOT=' "$STATE_ROOT/instance.env" > "$tmp"
carson_shell_kv CARSON_SOURCE_ROOT "$INSTALL_ROOT" >> "$tmp"
mv "$tmp" "$STATE_ROOT/instance.env"
chmod 600 "$STATE_ROOT/instance.env"

# Register using the same registry selected for this installation.
{
  carson_shell_kv CARSON_INSTANCE_ID "$INSTANCE_ID"
  carson_shell_kv CARSON_STATE_ROOT "$STATE_ROOT"
} > "$index_dir/$INSTANCE_ID.env"
chmod 600 "$index_dir/$INSTANCE_ID.env"

if [[ "$AUTOSTART" == "1" ]]; then
  env CARSON_REGISTRY_ROOT="$REGISTRY_ROOT" \
    "$INSTALL_ROOT/bin/carson-agent" start "$INSTANCE_ID" >/dev/null
fi

printf '%s\n' "INSTALL_OK"
printf 'INSTANCE_ID=%s\n' "$INSTANCE_ID"
printf 'STATE_ROOT=%s\n' "$STATE_ROOT"
printf 'INSTALL_ROOT=%s\n' "$INSTALL_ROOT"
printf 'DOWNLOAD_DIR=%s\n' "$REQUESTED_DOWNLOAD_DIR"
printf 'A_DIR=%s\n' "$REQUESTED_A_DIR"
printf 'B_DIR=%s\n' "$REQUESTED_B_DIR"
printf 'AUTOSTART=%s\n' "$AUTOSTART"
env CARSON_REGISTRY_ROOT="$REGISTRY_ROOT" \
  "$INSTALL_ROOT/bin/carson-agent" status "$INSTANCE_ID"
