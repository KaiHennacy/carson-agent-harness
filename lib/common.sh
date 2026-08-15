#!/data/data/com.termux/files/usr/bin/bash

CARSON_IMPLEMENTATION_VERSION="0.2-dev"

carson_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

carson_generate_token() {
  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    tr -d '-' < /proc/sys/kernel/random/uuid | cut -c1-16 | tr '[:lower:]' '[:upper:]'
  else
    printf '%s:%s:%s:%s\n' "$(date +%s%N)" "$$" "$RANDOM" "$HOME" |
      sha256sum | cut -c1-16 | tr '[:lower:]' '[:upper:]'
  fi
}

carson_generate_instance_id() {
  printf 'CARSON_INSTANCE_%s_%s\n' \
    "$(date -u '+%Y%m%dT%H%M%SZ')" \
    "$(carson_generate_token)"
}

carson_generate_session_id() {
  local instance_id="$1"
  local short
  short="$(printf '%s' "$instance_id" | sha256sum | cut -c1-10 | tr '[:lower:]' '[:upper:]')"
  printf 'CARSON_SESSION_%s_%s_%s\n' \
    "$short" \
    "$(date -u '+%Y%m%dT%H%M%SZ')" \
    "$(carson_generate_token)"
}

carson_route_token() {
  printf '%s|%s' "$1" "$2" | sha256sum | cut -c1-12 | tr '[:lower:]' '[:upper:]'
}

carson_shell_kv() {
  local key="$1" value="$2"
  printf '%s=' "$key"
  printf '%q' "$value"
  printf '\n'
}

carson_require_dir() {
  local name="$1" value="$2"
  [[ -n "$value" ]] || carson_die "$name is required"
  [[ -d "$value" ]] || carson_die "$name is not a directory: $value"
}

carson_registry_root() {
  printf '%s\n' "${CARSON_REGISTRY_ROOT:-$HOME/.carson_agent_instances}"
}

carson_registry_index_dir() {
  printf '%s/.registry\n' "$(carson_registry_root)"
}

carson_register_instance() {
  local instance_id="$1" state_root="$2"
  local index_dir
  index_dir="$(carson_registry_index_dir)"
  mkdir -p "$index_dir"
  {
    carson_shell_kv CARSON_INSTANCE_ID "$instance_id"
    carson_shell_kv CARSON_STATE_ROOT "$state_root"
  } > "$index_dir/$instance_id.env"
  chmod 600 "$index_dir/$instance_id.env"
}

carson_resolve_state_root() {
  local instance_id="$1"
  local registry index
  registry="$(carson_registry_root)"
  index="$(carson_registry_index_dir)/$instance_id.env"

  if [[ -f "$index" ]]; then
    local CARSON_STATE_ROOT=""
    # shellcheck disable=SC1090
    source "$index"
    [[ -n "$CARSON_STATE_ROOT" ]] || return 1
    printf '%s\n' "$CARSON_STATE_ROOT"
    return 0
  fi

  if [[ -f "$registry/$instance_id/instance.env" ]]; then
    printf '%s\n' "$registry/$instance_id"
    return 0
  fi

  return 1
}

carson_load_instance() {
  local instance_id="$1"
  local state_root
  state_root="$(carson_resolve_state_root "$instance_id")" ||
    carson_die "Unknown instance: $instance_id"
  [[ -f "$state_root/instance.env" ]] ||
    carson_die "Missing instance manifest: $state_root/instance.env"
  # shellcheck disable=SC1090
  source "$state_root/instance.env"
}

carson_load_active_session_if_any() {
  local state_root="$1"
  if [[ -f "$state_root/active-session.env" ]]; then
    # shellcheck disable=SC1090
    source "$state_root/active-session.env"
    return 0
  fi
  return 1
}
