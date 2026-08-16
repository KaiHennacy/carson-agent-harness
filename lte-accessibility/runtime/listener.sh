#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

STATE_ROOT="${1:-}"
SESSION_DIR="${2:-}"

[[ -n "$STATE_ROOT" && -n "$SESSION_DIR" ]] || {
  printf 'usage: listener.sh STATE_ROOT SESSION_DIR\n' >&2
  exit 64
}

[[ -f "$STATE_ROOT/instance.env" ]] || exit 65
[[ -f "$SESSION_DIR/session.env" ]] || exit 66

# shellcheck disable=SC1090
source "$STATE_ROOT/instance.env"
# shellcheck disable=SC1090
source "$SESSION_DIR/session.env"

LEDGER="$SESSION_DIR/processed_sha256.tsv"
EVENT_LOG="$SESSION_DIR/events.log"
LOCK_DIR="$SESSION_DIR/listener.lock"
POLL_SECONDS="${CARSON_POLL_SECONDS:-2}"

mkdir -p "$CARSON_A_DIR" "$CARSON_B_DIR" "$SESSION_DIR"
touch "$LEDGER" "$EVENT_LOG"

utc_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

log_event() {
  printf '%s\t%s\n' "$(utc_now)" "$*" >> "$EVENT_LOG"
}

already_seen_sha() {
  grep -Fq $'\t'"$1"$'\t' "$LEDGER" 2>/dev/null
}

record_sha() {
  printf '%s\t%s\t%s\t%s\n' "$(utc_now)" "$1" "$2" "$3" >> "$LEDGER"
}

stable_file() {
  local file="$1" a b
  a="$(stat -c '%s:%Y' "$file" 2>/dev/null)" || return 1
  sleep 1
  b="$(stat -c '%s:%Y' "$file" 2>/dev/null)" || return 1
  [[ "$a" == "$b" ]]
}

has_header_line() {
  local file="$1" expected="$2"
  head -c 4096 "$file" 2>/dev/null | grep -aFqx -- "$expected"
}

metadata_matches() {
  local file="$1"
  has_header_line "$file" "# CARSON_AGENT_PROTOCOL=CARSON_DOWNLOAD_AGENT_V1" || return 1
  has_header_line "$file" "# CARSON_INSTANCE_ID=$CARSON_INSTANCE_ID" || return 1
  has_header_line "$file" "# CARSON_SESSION_ID=$CARSON_SESSION_ID" || return 1
  has_header_line "$file" "# CARSON_PAYLOAD_TYPE=NEXT_LLM_TASK" || return 1
}

archive_and_clear_a() {
  local stamp suffix archive
  suffix="${1:-EVENT}"
  stamp="$(date -u '+%Y%m%dT%H%M%SZ')"

  if find "$CARSON_A_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
    archive="$CARSON_B_DIR/A_ARCHIVE_${stamp}_${suffix}_$$"
    mkdir -p "$archive"
    cp -a "$CARSON_A_DIR"/. "$archive"/
    find "$CARSON_A_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    printf '%s\n' "$archive"
  fi
}

emit_next_message() {
  local source_file="$1" sha="$2" rc="$3" stdout_file="$4" stderr_file="$5"
  local archive_path tmp

  archive_path="$(archive_and_clear_a "${sha:0:12}" || true)"
  tmp="$CARSON_A_DIR/.NEXT_LLM_MESSAGE.$$.tmp"

  {
    printf 'CARSON_NEXT_LLM_MESSAGE_V2\n'
    printf 'INSTANCE_ID=%s\n' "$CARSON_INSTANCE_ID"
    printf 'SESSION_ID=%s\n' "$CARSON_SESSION_ID"
    printf 'PROTOCOL=CARSON_DOWNLOAD_AGENT_V1\n'
    printf 'SOURCE_FILE=%s\n' "$(basename "$source_file")"
    printf 'SOURCE_SHA256=%s\n' "$sha"
    printf 'EXECUTION_RC=%s\n' "$rc"
    printf 'CREATED_AT_UTC=%s\n' "$(utc_now)"
    printf 'PREVIOUS_A_ARCHIVE=%s\n' "${archive_path:-NONE}"
    printf '%s\n' '---BEGIN_NEXT_LLM_MESSAGE---'
    if [[ -s "$stdout_file" ]]; then
      cat "$stdout_file"
      printf '\n'
    else
      printf 'Payload produced no stdout.\n'
    fi
    if [[ "$rc" -ne 0 ]]; then
      printf '\n[HARNESS_EXECUTION_ERROR]\n'
      printf 'Downloaded payload exited with rc=%s.\n' "$rc"
      if [[ -s "$stderr_file" ]]; then
        printf '%s\n' '---BEGIN_STDERR---'
        cat "$stderr_file"
        printf '\n%s\n' '---END_STDERR---'
      fi
    fi
    printf '%s\n' '---END_NEXT_LLM_MESSAGE---'
  } > "$tmp"

  mv -f "$tmp" "$CARSON_A_DIR/NEXT_LLM_MESSAGE.txt"
}

# CARSON_AUTO_PLAIN_INGEST_V1
auto_ingest_plain_candidate() {
  local source_file="$1"
  local cursor="$STATE_ROOT/auto-ingest.cursor"
  local ingest="$CARSON_SOURCE_ROOT/bin/carson-ingest"
  local base size_before size_after rc

  [[ -f "$cursor" && -f "$source_file" ]] || return 0
  [[ "$source_file" -nt "$cursor" ]] || return 0

  base="$(basename "$source_file")"
  [[ "$base" == *.sh ]] || return 0
  [[ "$base" != CARSON_AGENT_* ]] || return 0

  [[ -x "$ingest" ]] || {
    log_event "AUTO_INGEST_FAIL reason=INGEST_UNAVAILABLE file=$base"
    return 0
  }

  size_before="$(stat -c '%s' -- "$source_file" 2>/dev/null || true)"
  [[ -n "$size_before" ]] || return 0
  sleep 1
  size_after="$(stat -c '%s' -- "$source_file" 2>/dev/null || true)"
  [[ "$size_before" == "$size_after" ]] || {
    log_event "AUTO_INGEST_DEFER reason=FILE_UNSTABLE file=$base"
    return 0
  }

  if "$ingest" "$CARSON_INSTANCE_ID" "$source_file" \
      > "$SESSION_DIR/auto-ingest.last.log" 2>&1; then
    touch "$cursor"
    log_event "AUTO_INGEST_PASS file=$base"
  else
    rc=$?
    log_event "AUTO_INGEST_FAIL rc=$rc file=$base"
  fi
}

# CARSON_LLM_FACING_TRANSCRIPT_V1
publish_llm_execution_transcript() {
  local routed_file="$1"
  local internal="$CARSON_A_DIR/NEXT_LLM_MESSAGE.txt"
  local handoff="$CARSON_A_DIR/LLM_EXECUTION_TRANSCRIPT.txt"
  local download_copy="$CARSON_DOWNLOAD_DIR/LLM_EXECUTION_TRANSCRIPT.txt"
  local tmp="$SESSION_DIR/.llm-execution-transcript.$$"
  local rc created original wrapper_base

  [[ -f "$internal" ]] || return 0

  rc="$(sed -n 's/^EXECUTION_RC=//p' "$internal" | head -n 1)"
  created="$(sed -n 's/^CREATED_AT_UTC=//p' "$internal" | head -n 1)"
  wrapper_base="$(basename "$routed_file")"
  original=""

  if [[ -f "$routed_file" ]]; then
    original="$(
      sed -n -E         's/^# (CARSON_WRAPPED_SOURCE_BASENAME|WRAPPED_SOURCE_BASENAME)=//p'         "$routed_file" 2>/dev/null | head -n 1
    )"
  fi
  [[ -n "$original" ]] || original="$wrapper_base"
  [[ -n "$rc" ]] || rc="unknown"
  [[ -n "$created" ]] || created="unknown"

  {
    printf 'LOCAL SCRIPT EXECUTION RESULT\n\n'
    printf 'This is a plain transcript captured locally after running the downloaded Termux shell script.\n'
    printf 'It contains runtime evidence only and does not contain instructions for the receiving chat.\n\n'
    printf 'Script: %s\n' "$original"
    printf 'Exit status: %s\n' "$rc"
    printf 'Captured at UTC: %s\n\n' "$created"
    printf 'OUTPUT\n'
    printf '%s\n' '------'
    awk '
      /^---BEGIN_NEXT_LLM_MESSAGE---$/ {inside=1; next}
      /^---END_NEXT_LLM_MESSAGE---$/   {inside=0; exit}
      inside {print}
    ' "$internal"
  } > "$tmp"

  mv -f "$tmp" "$handoff"
  cp -f "$handoff" "$download_copy"
  log_event "LLM_TRANSCRIPT_READY file=$download_copy exit_status=$rc"
}

process_candidate() {
  local file="$1" sha rc out err

  [[ -f "$file" ]] || return 2
  metadata_matches "$file" || return 2
  stable_file "$file" || return 2

  sha="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')" || return 2
  [[ "$sha" =~ ^[0-9a-fA-F]{64}$ ]] || return 2
  already_seen_sha "$sha" && return 3

  log_event "EXECUTE_START sha=$sha file=$file"

  out="$SESSION_DIR/stdout.$sha.tmp"
  err="$SESSION_DIR/stderr.$sha.tmp"

  set +e
  bash "$file" >"$out" 2>"$err"
  rc=$?
  set -e

  emit_next_message "$file" "$sha" "$rc" "$out" "$err"
  record_sha "$sha" "EXECUTED_RC_$rc" "$file"
  log_event "EXECUTED sha=$sha rc=$rc file=$file"
  rm -f "$out" "$err"
  return 0
}

process_latest_matching_unseen() {
  local entry file rc

  # While armed, route the next future ordinary .sh through the existing
  # carson-ingest bridge. Only one plain artifact is accepted per cursor
  # position; successful ingestion advances the cursor for the following turn.
  if [[ -f "$STATE_ROOT/auto-ingest.cursor" ]]; then
    while IFS= read -r -d '' plain_file; do
      auto_ingest_plain_candidate "$plain_file"
      break
    done < <(
      find "$CARSON_DOWNLOAD_DIR" -maxdepth 1 -type f \
        -name '*.sh' \
        ! -name 'CARSON_AGENT_*' \
        -newer "$STATE_ROOT/auto-ingest.cursor" \
        -print0 2>/dev/null
    )
  fi

  while IFS= read -r -d '' entry; do
    file="${entry#*$'\t'}"
    [[ -f "$file" ]] || continue

    set +e
    process_candidate "$file"
    publish_llm_execution_transcript "$file"
    rc=$?
    set -e

    [[ "$rc" -eq 0 ]] && return 0
  done < <(
    find "$CARSON_DOWNLOAD_DIR" -maxdepth 1 -type f \
      -name "${CARSON_TASK_PREFIX}*.sh" \
      -printf '%T@\t%p\0' 2>/dev/null |
      sort -z -t $'\t' -k1,1nr
  )
}

carson_requirements_ok=1
[[ -d "$CARSON_DOWNLOAD_DIR" ]] || carson_requirements_ok=0
[[ -d "$CARSON_A_DIR" ]] || carson_requirements_ok=0
[[ -d "$CARSON_B_DIR" ]] || carson_requirements_ok=0

[[ "$carson_requirements_ok" -eq 1 ]] || {
  log_event "FATAL configured_directory_missing"
  exit 67
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log_event "FATAL duplicate_listener_lock"
  exit 68
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

log_event "LISTENER_START instance=$CARSON_INSTANCE_ID session=$CARSON_SESSION_ID prefix=$CARSON_TASK_PREFIX"

while true; do
  process_latest_matching_unseen || true
  sleep "$POLL_SECONDS"
done
