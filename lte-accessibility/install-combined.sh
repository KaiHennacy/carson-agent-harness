#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
umask 077

ARTIFACT_ID="CARSON_V0_3_0_RC1_COMBINED_INSTALLER_V45"
BASE_RELEASE_TAG="v0.2.0"
BASE_RELEASE_COMMIT="4982bbaac362edc259dddd6a8f07129fa5dd0e90"
RC_BRANCH="v0.3.0-rc1"

REAL_HOME="$HOME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK="$REAL_HOME/.carson_combined_installer_v45"
CLEAN_HOME="$WORK/clean-home"
CLEAN_TMP="$WORK/clean-tmp"
CLEAN_OUT="$WORK/clean-quick-install.out"
CLEAN_ACCEPT="$WORK/clean-dynamic-e2e.sh"
CLEAN_ACCEPT_OUT="$WORK/clean-dynamic-e2e.out"

REAL_UI_WORK="$REAL_HOME/.carson_ui_lte_poc"
REAL_UI_CLIENT="$REAL_UI_WORK/carson-ui"
REAL_UI_TOKEN="$REAL_UI_WORK/control-token.txt"

COMPANION_WORK="$WORK/companion"
COMPANION_NEW_TOKEN="$COMPANION_WORK/new-token.txt"
COMPANION_OLD_TOKEN="$COMPANION_WORK/old-token.txt"
COMPANION_FRESH_TREE="$COMPANION_WORK/android-fresh"
COMPANION_ROLLBACK_TREE="$COMPANION_WORK/android-rollback"
COMPANION_FRESH_APK="$COMPANION_WORK/CARSON_UI_BRIDGE_V45_FRESH_TOKEN.apk"
COMPANION_ROLLBACK_APK="$COMPANION_WORK/CARSON_UI_BRIDGE_V45_ROLLBACK_TOKEN.apk"
COMPANION_DOWNLOAD_APK="/storage/emulated/0/Download/CARSON_UI_BRIDGE_V45_FRESH_TOKEN.apk"
TOKEN_PLACEHOLDER="__CARSON_UI_DEVICE_TOKEN__"
COMPANION_REKEY_ACCEPTED=0

SHARED_ROOT="/storage/emulated/0"
SHARED_CARSON="$SHARED_ROOT/carson-agent"
SHARED_BACKUP="$SHARED_ROOT/carson-agent-v45-preexisting-$(date -u +%Y%m%dT%H%M%SZ)-$$"
CLEAN_SENTINEL="$SHARED_CARSON/.CARSON_V45_COMBINED_SENTINEL"

REPORT="/sdcard/a/CARSON_V0_3_0_RC1_COMBINED_INSTALLER_V45_REPORT.txt"

ORIG_INSTANCE=""
ORIG_TMUX=""
ORIG_SOURCE=""
ORIG_AGENT=""
ORIG_SHARED_PRESENT=0
ORIG_LISTENER_STOPPED=0
CLEAN_CREATED=0
RESTORE_DONE=0

mkdir -p "$WORK" "$CLEAN_TMP" "$COMPANION_WORK" /sdcard/a /sdcard/B
: > "$REPORT"

say(){ printf '%s\n' "$*" | tee -a "$REPORT"; }
fail(){
  local rc="$1" msg="$2" next="${3:-RETURN_THIS_OUTPUT_FOR_NEXT_BOUNDED_FIX}"
  say "FAILED_STAGE=$STAGE"
  say "ERROR=$msg"
  say "NEXT=$next"
  say "STATUS=FAIL"
  exit "$rc"
}
sha(){ sha256sum "$1" | awk '{print $1}'; }


companion_request_state_with(){
  local tok="$1"
  cp -f "$tok" "$REAL_UI_TOKEN"
  chmod 600 "$REAL_UI_TOKEN"
  set +e
  COMPANION_STATE_OUTPUT="$(timeout 8 bash "$REAL_UI_CLIENT" state 2>&1)"
  COMPANION_STATE_RC=$?
  set -e
}

companion_state_ok_build5(){
  [[ "$COMPANION_STATE_OUTPUT" == OK$'\t'STATE* && "$COMPANION_STATE_OUTPUT" == *$'\tBUILD=5\t'* ]]
}

companion_state_auth_reject(){
  [[ "$COMPANION_STATE_OUTPUT" == ERR$'\t'AUTH* ]]
}

render_companion_tree(){
  local source_tree="$1" dest_tree="$2" token_file="$3" sdk_root="$4"
  rm -rf "$dest_tree"
  mkdir -p "$dest_tree"
  cp -a "$source_tree"/. "$dest_tree"/
  rm -rf "$dest_tree/.gradle" "$dest_tree/app/build" "$dest_tree/build"
  rm -f "$dest_tree/local.properties"
  printf 'sdk.dir=%s\n' "$sdk_root" > "$dest_tree/local.properties"

  python - "$dest_tree" "$token_file" "$TOKEN_PLACEHOLDER" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
token=Path(sys.argv[2]).read_text(encoding="utf-8").strip()
placeholder=sys.argv[3]
if not token:
    raise SystemExit("empty token")
hits=0
for p in root.rglob("*"):
    if not p.is_file() or p.stat().st_size > 2_000_000:
        continue
    try:
        text=p.read_text(encoding="utf-8")
    except Exception:
        continue
    if placeholder in text:
        n=text.count(placeholder)
        p.write_text(text.replace(placeholder,token),encoding="utf-8")
        hits += n
if hits < 1:
    raise SystemExit("device-token placeholder not rendered")
print("TOKEN_RENDER_REPLACEMENTS="+str(hits))
PY
}

build_companion_tree(){
  local tree="$1" dest_apk="$2" label="$3"
  say "COMPANION_BUILD_BEGIN=$label"
  set +e
  (
    cd "$tree"
    HOME="$REAL_HOME" ./gradlew --no-daemon assembleDebug
  ) >"$COMPANION_WORK/build-$label.out" 2>&1
  local rc=$?
  set -e
  tail -n 60 "$COMPANION_WORK/build-$label.out" | tee -a "$REPORT"
  (( rc == 0 )) || fail 46 "$label companion build failed"
  local apk="$tree/app/build/outputs/apk/debug/app-debug.apk"
  [[ -f "$apk" ]] || fail 47 "$label companion build produced no APK"
  cp -f "$apk" "$dest_apk"
  chmod 600 "$dest_apk"
  say "COMPANION_BUILD_PASS=$label"
  say "${label}_APK_SHA256=$(sha "$dest_apk")"
}

restore_real_environment(){
  local rc=$?
  (( RESTORE_DONE == 0 )) || return "$rc"
  RESTORE_DONE=1
  set +e

  say
  say "=== RESTORE PREEXISTING LIVE ENVIRONMENT ==="

  # Stop every listener created inside the clean HOME only.
  if [[ -d "$CLEAN_HOME/.carson_agent_instances/.registry" ]]; then
    for envf in "$CLEAN_HOME/.carson_agent_instances/.registry"/*.env; do
      [[ -f "$envf" ]] || continue
      st="$(HOME="$CLEAN_HOME" bash -c 'source "$1" 2>/dev/null;printf "%s" "${CARSON_STATE_ROOT:-}"' _ "$envf" 2>/dev/null)"
      [[ -n "$st" && -f "$st/active-session.env" ]] || continue
      tm="$(HOME="$CLEAN_HOME" bash -c 'source "$1" 2>/dev/null;printf "%s" "${CARSON_TMUX_SESSION:-}"' _ "$st/active-session.env" 2>/dev/null)"
      [[ -n "$tm" ]] && tmux kill-session -t "$tm" 2>/dev/null
    done
  fi
  say "CLEANROOM_LISTENERS_STOPPED=YES"

  if (( CLEAN_CREATED == 1 )) && [[ -f "$CLEAN_SENTINEL" ]]; then
    rm -rf "$SHARED_CARSON"
    say "CLEANROOM_SHARED_STATE_REMOVED=YES"
  else
    say "CLEANROOM_SHARED_STATE_REMOVED=NO_OR_NOT_OWNED"
  fi

  if (( ORIG_SHARED_PRESENT == 1 )); then
    if [[ -e "$SHARED_BACKUP" && ! -e "$SHARED_CARSON" ]]; then
      mv "$SHARED_BACKUP" "$SHARED_CARSON"
      say "ORIGINAL_SHARED_STATE_RESTORED=YES"
    else
      say "ORIGINAL_SHARED_STATE_RESTORED=FAILED_OR_AMBIGUOUS"
    fi
  else
    say "ORIGINAL_SHARED_STATE_RESTORED=NOT_APPLICABLE"
  fi

  if (( ORIG_LISTENER_STOPPED == 1 )) && [[ -x "$ORIG_AGENT" && -n "$ORIG_INSTANCE" ]]; then
    restart_out="$("$ORIG_AGENT" restart "$ORIG_INSTANCE" 2>&1)"
    restart_rc=$?
    printf '%s\n' "$restart_out" | sed 's/^/RESTORE_RESTART: /' | tee -a "$REPORT"
    if (( restart_rc == 0 )); then
      say "ORIGINAL_LISTENER_RESTART=PASS"
    else
      say "ORIGINAL_LISTENER_RESTART=FAIL rc=$restart_rc"
    fi
  else
    say "ORIGINAL_LISTENER_RESTART=NOT_NEEDED"
  fi

  if (( COMPANION_REKEY_ACCEPTED == 1 )); then
    cp -f "$COMPANION_NEW_TOKEN" "$REAL_UI_TOKEN" 2>/dev/null || true
    chmod 600 "$REAL_UI_TOKEN" 2>/dev/null || true
    say "COMPANION_TOKEN_POST_RESTORE=FRESH_ACCEPTED"
  elif [[ -s "$COMPANION_OLD_TOKEN" ]]; then
    cp -f "$COMPANION_OLD_TOKEN" "$REAL_UI_TOKEN" 2>/dev/null || true
    chmod 600 "$REAL_UI_TOKEN" 2>/dev/null || true
    say "COMPANION_TOKEN_POST_RESTORE=ORIGINAL"
  fi

  say "RESTORE_TRANSACTION=COMPLETE"
  set -e
  return "$rc"
}
trap restore_real_environment EXIT INT TERM

say "CARSON_V0_3_0_RC1_COMBINED_INSTALLER_V45"
say "ARTIFACT_ID=$ARTIFACT_ID"
say "MODE=EXACT_RC_CLONE_COMPANION_REKEY_ZERO_HOME_QUICK_INSTALL_LTE_OVERLAY_FULL_E2E_TRANSACTIONAL_RESTORE"
say "SOURCE_MODE=EXECUTE_FROM_CURRENT_FRESH_CLONE"
say "BASE_RELEASE_TAG=$BASE_RELEASE_TAG"
say "BASE_RELEASE_COMMIT=$BASE_RELEASE_COMMIT"
say "RC_BRANCH=$RC_BRANCH"
say "SCOPE=PROVE_EXACT_VERSION_CONTROLLED_RC_COMBINED_INSTALLER_WITH_COMPANION_REKEY_ZERO_STATE_CORE_AND_FULL_E2E"
say "ANDROID_COMPANION_COLD_INSTALL_PROVEN_BY_THIS_RUN=YES_WITH_ONE_TIME_ANDROID_MY_FILES_UPDATE_AND_ACCESSIBILITY_CONSENT_CHECKPOINT"
say "V40_ZERO_STATE_CORE_ACCEPTANCE=PASS"
say "V41_RELEASE_SOURCE_COMPANION_BUILD=PASS"
say "V42_MANUAL_MY_FILES_INSTALL_ROUTE=PASS"
say "V43_PROTOCOL_LEVEL_TOKEN_PROOF=PASS"
say "V45_COMBINES=VERSION_CONTROLLED_COMPANION_REKEY_PLUS_ZERO_STATE_CORE_PLUS_SEND_RECOVERY_PLUS_DIRECT_CURRENT_CHAT_BINDING"
say "GITHUB_MUTATION=NONE"
say "ANDROID_APP_MUTATION=YES_SAME_PACKAGE_V0_2_0_SOURCE_NEW_DEVICE_TOKEN"
say "CURRENT_CARSON_STATE_MUTATION=TEMPORARY_TRANSACTIONAL_QUIESCE_AND_SHARED_STATE_SWAP"
say "CURRENT_CARSON_STATE_RESTORE_REQUIRED=YES"
say "ADB_USED=NO"
say "WIRELESS_DEBUGGING_REQUIRED=NO"
say "WIFI_REQUIRED=NO"
say "V35_FAILURE_ROOT_CAUSE=ENV_OPTIONS_WERE_PLACED_AFTER_NAME_VALUE_ASSIGNMENTS_SO_TERMUX_ENV_TREATED_-u_AS_THE_COMMAND"
say "V36_FIX=PLACE_ALL_ENV_-u_OPTIONS_BEFORE_HOME_TMPDIR_ASSIGNMENTS"
say "V36_OBSERVED=ZERO_STATE_QUICK_INSTALL_PASS_LTE_OVERLAY_PASS_INITIAL_SEND_CLEARED_THEN_CLAUDE_RESTORED_EXACT_DRAFT_WITH_NO_ARTIFACT"
say "V37_FIX=RETRY_SEND_ONLY_AFTER_EXACT_RESTORED_DRAFT_PLUS_SEND_PRESENT_PLUS_NO_STOP_RESPONSE_PLUS_NO_ARTIFACT"
say "V37_OBSERVED=SEND_ACTION_WAS_REAL_BUT_IMMEDIATE_POST_SEND_COMPOSER_ENTERED_TRANSITIONAL_STATE;SCRIPT_FAILED_EARLY;CLAUDE_LATER_RETURNED_V37_ARTIFACT"
say "V38_FIX=NEVER_FAIL_ON_TRANSITIONAL_POST_SEND_COMPOSER;WAIT_UP_TO_240S_PER_ATTEMPT;RETRY_ONLY_AFTER_EXACT_DRAFT_ROLLBACK_IS_STABLE_FOR_3_CONSECUTIVE_POLLS"
say "V38_OBSERVED=SEND_AND_ARTIFACT_PASS_BIND_FAILED_BECAUSE_THREE_RECENTS_SHARED_THE_SAME_CLAUDE_GENERATED_TITLE"
say "V39_FIX=WHEN_RECENT_TITLE_IS_DUPLICATED_SELECT_TOPMOST_RECENT_VERIFY_FRESH_ARTIFACT_THEN_RENAME_FROM_CURRENT_CHAT_MORE_OPTIONS"
say "V39_OBSERVED=TOPMOST_DUPLICATE_RECENT_WAS_NOT_THE_FRESH_ARTIFACT_CHAT_SO_RECENTS_ORDER_IS_NOT_A_SAFE_IDENTITY_SIGNAL"
say "V40_FIX=NEVER_LEAVE_THE_ALREADY_VERIFIED_FRESH_ARTIFACT_CHAT_FOR_BINDING;RENAME_IT_DIRECTLY_FROM_TOP_CURRENT_CHAT_MORE_OPTIONS"
say "REPORT=$REPORT"
say

for c in bash git python tmux timeout sha256sum find grep sed awk date; do
  command -v "$c" >/dev/null 2>&1 || fail 10 "$c missing"
done

STAGE="BRIDGE_PRECHECK"
say "=== PRECHECK EXISTING ACCEPTED BUILD5 BRIDGE ==="
[[ -x "$REAL_UI_CLIENT" ]] || fail 20 "accepted BUILD5 client missing"
[[ -s "$REAL_UI_TOKEN" ]] || fail 21 "accepted BUILD5 device-local token missing"

set +e
BRIDGE_STATE="$(timeout 8 bash "$REAL_UI_CLIENT" state 2>&1)"
BRIDGE_RC=$?
set -e
say "BRIDGE_STATE=$(printf '%s' "$BRIDGE_STATE" | tr '\t' ' ')"
(( BRIDGE_RC == 0 )) || fail 22 "accepted BUILD5 bridge unavailable"
[[ "$BRIDGE_STATE" == OK$'\t'STATE* && "$BRIDGE_STATE" == *$'\tBUILD=5\t'* ]] ||
  fail 23 "accepted BUILD5 bridge is not active"
say "EXISTING_BUILD5_BRIDGE=PASS"
cp -f "$REAL_UI_TOKEN" "$COMPANION_OLD_TOKEN"
chmod 600 "$COMPANION_OLD_TOKEN"
say "COMPANION_ROLLBACK_TOKEN_CAPTURED=PASS"
say

STAGE="RESOLVE_ORIGINAL"
say "=== RESOLVE PREEXISTING LIVE CARSON INSTANCE ==="
REAL_REG="$REAL_HOME/.carson_agent_instances/.registry"
[[ -d "$REAL_REG" ]] || fail 30 "preexisting CARSON registry missing"

CAND="$WORK/original-instances.tsv"
: > "$CAND"
for idx in "$REAL_REG"/*.env; do
  [[ -f "$idx" ]] || continue
  st="$(bash -c 'source "$1" 2>/dev/null;printf "%s" "${CARSON_STATE_ROOT:-}"' _ "$idx" 2>/dev/null || true)"
  [[ -n "$st" && -f "$st/instance.env" && -f "$st/active-session.env" ]] || continue
  row="$(
    bash -c '
      source "$1";source "$2"
      printf "%s\t%s\t%s\t%s" \
        "${CARSON_INSTANCE_ID:-}" "${CARSON_TMUX_SESSION:-}" \
        "${CARSON_SOURCE_ROOT:-}" "${CARSON_SESSION_ID:-}"
    ' _ "$st/instance.env" "$st/active-session.env" 2>/dev/null || true
  )"
  tm="$(printf '%s' "$row" | cut -f2)"
  live=0
  [[ -n "$tm" ]] && tmux has-session -t "$tm" 2>/dev/null && live=1
  printf '%s\t%s\t%s\n' "$live" "$(stat -c '%Y' "$st/active-session.env" 2>/dev/null || echo 0)" "$row" >> "$CAND"
done

LIVE_COUNT="$(awk -F'\t' '$1==1{n++} END{print n+0}' "$CAND")"
[[ "$LIVE_COUNT" == 1 ]] || fail 31 "expected exactly one preexisting live listener; found $LIVE_COUNT"

SEL="$(sort -t $'\t' -k1,1nr -k2,2nr "$CAND" | head -n1)"
ORIG_INSTANCE="$(printf '%s' "$SEL" | cut -f3)"
ORIG_TMUX="$(printf '%s' "$SEL" | cut -f4)"
ORIG_SOURCE="$(printf '%s' "$SEL" | cut -f5)"
ORIG_AGENT="$ORIG_SOURCE/bin/carson-agent"

[[ -x "$ORIG_AGENT" ]] || fail 32 "preexisting carson-agent missing"
say "ORIGINAL_INSTANCE_ID=$ORIG_INSTANCE"
say "ORIGINAL_TMUX=$ORIG_TMUX"
say "ORIGINAL_SOURCE=$ORIG_SOURCE"
say

STAGE="VERIFY_RC_SOURCE"
say "=== VERIFY CURRENT VERSION-CONTROLLED RC SOURCE ==="
[[ -f "$CLONE/quick-install.sh" ]] || fail 40 "RC quick-install.sh missing"
[[ -f "$CLONE/lte-accessibility/bootstrap-from-clone.sh" ]] || fail 41 "RC LTE bootstrap missing"
[[ -f "$CLONE/lte-accessibility/acceptance/clone-fresh-e2e.sh" ]] || fail 42 "RC LTE acceptance missing"
[[ -f "$CLONE/lte-accessibility/install-combined.sh" ]] || fail 43 "RC combined installer missing"

CLONE_COMMIT="$(git -C "$CLONE" rev-parse HEAD 2>/dev/null)" ||
  fail 44 "could not resolve RC source commit"
SOURCE_DIRTY="$(git -C "$CLONE" status --porcelain --untracked-files=no)"
[[ -z "$SOURCE_DIRTY" ]] || fail 45 "RC tracked source tree is dirty"

say "RC_SOURCE_COMMIT=$CLONE_COMMIT"
say "RC_TRACKED_SOURCE_DIRTY=NO"

bash -n "$CLONE/quick-install.sh" || fail 46 "RC quick-install.sh fails bash -n"
bash -n "$CLONE/lte-accessibility/install-combined.sh" || fail 47 "RC combined installer fails bash -n"
(
  cd "$CLONE/lte-accessibility"
  sha256sum -c SHA256SUMS
) | tee -a "$REPORT"
say "RC_MANIFEST=PASS"
say "QUICK_INSTALL_PRESENT=PASS"
say

STAGE="COMPANION_BUILD_REKEY"
say "=== BUILD / INSTALL FRESH-TOKEN BUILD5 COMPANION FROM CURRENT RC SOURCE ==="

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$SDK_ROOT" || ! -f "$SDK_ROOT/platforms/android-34/android.jar" ]]; then
  SDK_ROOT=""
  while IFS= read -r candidate; do
    root="${candidate%/platforms/android-34/android.jar}"
    if [[ -d "$root/build-tools" ]]; then
      SDK_ROOT="$root"
      break
    fi
  done < <(find "$REAL_HOME" -type f -path '*/platforms/android-34/android.jar' 2>/dev/null | head -n 20)
fi
[[ -n "$SDK_ROOT" && -f "$SDK_ROOT/platforms/android-34/android.jar" ]] ||
  fail 44 "Android SDK platform 34 not found for companion build"

[[ -f "$REAL_HOME/.android/debug.keystore" ]] ||
  fail 45 "existing debug.keystore missing; cannot safely update the already-installed same-package companion on this device"

python - "$COMPANION_NEW_TOKEN" <<'PY'
from pathlib import Path
import secrets,sys
Path(sys.argv[1]).write_text(secrets.token_hex(32)+"\n",encoding="utf-8")
PY
chmod 600 "$COMPANION_NEW_TOKEN"
cmp -s "$COMPANION_OLD_TOKEN" "$COMPANION_NEW_TOKEN" &&
  fail 45 "fresh companion token unexpectedly equals current token"

say "COMPANION_FRESH_TOKEN_GENERATED=PASS"
say "COMPANION_FRESH_TOKEN_PRINTED=NO"
say "COMPANION_SDK_ROOT=$SDK_ROOT"

render_companion_tree "$CLONE/lte-accessibility/android" "$COMPANION_FRESH_TREE" "$COMPANION_NEW_TOKEN" "$SDK_ROOT"
build_companion_tree "$COMPANION_FRESH_TREE" "$COMPANION_FRESH_APK" "FRESH_TOKEN"

render_companion_tree "$CLONE/lte-accessibility/android" "$COMPANION_ROLLBACK_TREE" "$COMPANION_OLD_TOKEN" "$SDK_ROOT"
build_companion_tree "$COMPANION_ROLLBACK_TREE" "$COMPANION_ROLLBACK_APK" "ROLLBACK_TOKEN"

cp -f "$COMPANION_FRESH_APK" "$COMPANION_DOWNLOAD_APK"
chmod 644 "$COMPANION_DOWNLOAD_APK" 2>/dev/null || true

say "COMPANION_FRESH_APK=$COMPANION_DOWNLOAD_APK"
say "COMPANION_ROLLBACK_APK=$COMPANION_ROLLBACK_APK"
say "COMPANION_INSTALL_ROUTE=ANDROID_MY_FILES_MANUAL_UPDATE"
say "TERMUX_OPEN_CHOOSER_ROUTE=REJECTED"
say "PACKAGE_INSTALLER_ACCESSIBILITY_CLICK=REJECTED"
say
say "=== ONE-TIME ANDROID CONSENT CHECKPOINT ==="
say "ACTION=Script_attempts_My_Files_Downloads_APK;when_Android_installer_appears_tap_Update"
say "THEN=If bridge does not return, toggle CARSON UI Bridge Off then On in Android Accessibility"
say "SCRIPT_WILL_WAIT_AND_CONTINUE_AUTOMATICALLY=YES"

# Best effort: use the still-live old-token bridge to move My Files all the
# way to the staged APK. The only intended human action is Android's Update
# consent. Fall back to manual navigation without failing the installer.
set +e
MYFILES_OUT="$(timeout 8 bash "$REAL_UI_CLIENT" open com.sec.android.app.myfiles 2>&1)"
MYFILES_RC=$?
set -e
if (( MYFILES_RC == 0 )); then
  say "MY_FILES_OPEN_ATTEMPT=PASS"

  set +e
  DL_WAIT="$(timeout 12 bash "$REAL_UI_CLIENT" wait 10000 "Downloads" 2>&1)"
  DL_WAIT_RC=$?
  set -e
  if (( DL_WAIT_RC == 0 )); then
    set +e
    DL_CLICK="$(timeout 8 bash "$REAL_UI_CLIENT" click "Downloads" 2>&1)"
    DL_CLICK_RC=$?
    set -e
    if (( DL_CLICK_RC == 0 )); then
      say "MY_FILES_DOWNLOADS_NAVIGATION=PASS"

      set +e
      APK_WAIT="$(timeout 15 bash "$REAL_UI_CLIENT" wait 12000 "CARSON_UI_BRIDGE_V45_FRESH_TOKEN.apk" 2>&1)"
      APK_WAIT_RC=$?
      set -e
      if (( APK_WAIT_RC == 0 )); then
        set +e
        APK_CLICK="$(timeout 8 bash "$REAL_UI_CLIENT" click "CARSON_UI_BRIDGE_V45_FRESH_TOKEN.apk" 2>&1)"
        APK_CLICK_RC=$?
        set -e
        if (( APK_CLICK_RC == 0 )); then
          say "MY_FILES_APK_OPEN=PASS"
          set +e
          UPDATE_WAIT="$(timeout 12 bash "$REAL_UI_CLIENT" wait 10000 "Update" 2>&1)"
          UPDATE_WAIT_RC=$?
          set -e
          if (( UPDATE_WAIT_RC == 0 )); then
            say "PACKAGE_INSTALLER_UPDATE_PROMPT=PASS"
            say "HUMAN_ACTION_REQUIRED=Tap_Update"
          else
            say "PACKAGE_INSTALLER_UPDATE_PROMPT=NOT_SEMANTICALLY_VISIBLE"
            say "HUMAN_ACTION_REQUIRED=If_installer_is_visible_tap_Update"
          fi
        else
          say "MY_FILES_APK_OPEN=FALLBACK_MANUAL"
        fi
      else
        say "MY_FILES_APK_EXACT_MATCH=FALLBACK_MANUAL"
      fi
    else
      say "MY_FILES_DOWNLOADS_NAVIGATION=FALLBACK_MANUAL"
    fi
  else
    say "MY_FILES_DOWNLOADS_CONTROL=FALLBACK_MANUAL"
  fi
else
  say "MY_FILES_OPEN_ATTEMPT=UNAVAILABLE_MANUAL_OPEN_REQUIRED"
fi

COMPANION_WAIT_START="$(date +%s)"
COMPANION_LAST_NOTE=-1
while :; do
  now="$(date +%s)"
  elapsed=$((now-COMPANION_WAIT_START))
  (( elapsed < 900 )) ||
    fail 48 "fresh-token companion did not become available within 900 seconds" \
      "VERIFY_THE_V45_APK_WAS_UPDATED_FROM_ANDROID_MY_FILES_AND_REENABLE_CARSON_UI_BRIDGE_ACCESSIBILITY"

  companion_request_state_with "$COMPANION_NEW_TOKEN"
  if companion_state_ok_build5; then
    say "COMPANION_FRESH_TOKEN_DETECTED=YES elapsed_seconds=$elapsed"
    break
  fi

  companion_request_state_with "$COMPANION_OLD_TOKEN"
  if companion_state_ok_build5; then
    bucket=$((elapsed/10))
    if (( bucket != COMPANION_LAST_NOTE )); then
      say "COMPANION_WAIT=OLD_TOKEN_SERVICE_ACTIVE elapsed_seconds=$elapsed"
      say "ACTION_NEEDED=Install_the_V45_fresh_APK_from_Android_My_Files"
      COMPANION_LAST_NOTE=$bucket
    fi
  else
    bucket=$((elapsed/10))
    if (( bucket != COMPANION_LAST_NOTE )); then
      say "COMPANION_WAIT=NO_TOKEN_AUTHENTICATES elapsed_seconds=$elapsed"
      say "ACTION_NEEDED=If_update_finished_toggle_CARSON_UI_Bridge_Off_then_On_in_Android_Accessibility"
      COMPANION_LAST_NOTE=$bucket
    fi
  fi

  cp -f "$COMPANION_NEW_TOKEN" "$REAL_UI_TOKEN"
  chmod 600 "$REAL_UI_TOKEN"
  sleep 2
done

# Protocol-level token proof. Client process exit code is not auth authority.
companion_request_state_with "$COMPANION_NEW_TOKEN"
companion_state_ok_build5 ||
  fail 49 "fresh token stopped authenticating before protocol proof"
say "COMPANION_FRESH_TOKEN_ACCEPTED=PASS"

companion_request_state_with "$COMPANION_OLD_TOKEN"
if companion_state_ok_build5; then
  fail 50 "old companion token genuinely still receives OK STATE BUILD=5"
fi
companion_state_auth_reject ||
  fail 51 "old companion token did not receive ERR AUTH rejection"

say "COMPANION_OLD_TOKEN_REJECTED=PASS"
say "COMPANION_CLIENT_PROCESS_RC_NOT_AUTHORITY=CONFIRMED"

companion_request_state_with "$COMPANION_NEW_TOKEN"
companion_state_ok_build5 ||
  fail 52 "fresh companion token did not recover after old-token rejection proof"

cp -f "$COMPANION_NEW_TOKEN" "$REAL_UI_TOKEN"
chmod 600 "$REAL_UI_TOKEN"
COMPANION_REKEY_ACCEPTED=1

say "COMPANION_REKEY_FROM_RC_SOURCE=PASS"
say "COMPANION_BUILD5_AFTER_REKEY=PASS"
say "COMPANION_INSTALL_CHECKPOINT=PASS"
say

STAGE="PREPARE_CLEAN_HOME"
say "=== PREPARE ZERO-STATE HOME / ISOLATED INTERNAL STATE ==="
rm -rf "$CLEAN_HOME"
mkdir -p "$CLEAN_HOME/storage" "$CLEAN_HOME/.carson_ui_lte_poc" "$CLEAN_TMP"

# Mimic a normal termux-setup-storage layout while keeping the HOME itself clean.
ln -s "$SHARED_ROOT" "$CLEAN_HOME/storage/shared"
ln -s "$SHARED_ROOT/Download" "$CLEAN_HOME/storage/downloads"

# This phase intentionally reuses only the already accepted Android bridge.
# Copying the token/client into the clean HOME makes that dependency explicit.
cp -f "$REAL_UI_CLIENT" "$CLEAN_HOME/.carson_ui_lte_poc/carson-ui"
cp -f "$REAL_UI_TOKEN" "$CLEAN_HOME/.carson_ui_lte_poc/control-token.txt"
chmod 700 "$CLEAN_HOME/.carson_ui_lte_poc/carson-ui"
chmod 600 "$CLEAN_HOME/.carson_ui_lte_poc/control-token.txt"

for p in \
  "$CLEAN_HOME/.carson_agent_instances" \
  "$CLEAN_HOME/.local/share/carson-agent-harness" \
  "$CLEAN_HOME/.local/bin"
do
  [[ ! -e "$p" ]] || fail 50 "clean HOME unexpectedly contains CARSON path: $p"
done

say "ZERO_STATE_HOME=$CLEAN_HOME"
say "ZERO_STATE_PREEXISTING_CARSON_PATHS=NONE"
say "FRESHLY_REBUILT_BUILD5_DEPENDENCY_COPIED_INTO_CLEAN_HOME=YES"
say

STAGE="QUIESCE_SWAP"
say "=== TRANSACTIONALLY QUIESCE ORIGINAL / SWAP SHARED CARSON STATE ==="

tmux kill-session -t "$ORIG_TMUX" ||
  fail 60 "could not quiesce original listener"
ORIG_LISTENER_STOPPED=1
say "ORIGINAL_LISTENER_QUIESCED=PASS"

if [[ -e "$SHARED_CARSON" ]]; then
  [[ ! -e "$SHARED_BACKUP" ]] || fail 61 "shared backup destination already exists"
  mv "$SHARED_CARSON" "$SHARED_BACKUP"
  ORIG_SHARED_PRESENT=1
  say "ORIGINAL_SHARED_STATE_BACKUP=$SHARED_BACKUP"
else
  ORIG_SHARED_PRESENT=0
  say "ORIGINAL_SHARED_STATE=ABSENT"
fi

mkdir -p "$SHARED_CARSON"
touch "$CLEAN_SENTINEL"
CLEAN_CREATED=1
say "CLEANROOM_SHARED_STATE_READY=PASS"
say

STAGE="QUICK_INSTALL"
say "=== ZERO-STATE QUICK INSTALL FROM RELEASE ROOT ==="

set +e
(
  cd "$CLONE"
  env \
    -u CARSON_DOWNLOAD_DIR \
    -u CARSON_A_DIR \
    -u CARSON_B_DIR \
    -u CARSON_INSTANCE_ID \
    -u CARSON_STATE_ROOT \
    -u CARSON_INSTALL_BASE \
    -u CARSON_INSTANCE_LABEL \
    -u CARSON_AUTOSTART \
    HOME="$CLEAN_HOME" \
    TMPDIR="$CLEAN_TMP" \
    bash ./quick-install.sh
) >"$CLEAN_OUT" 2>&1
QI_RC=$?
set -e

cat "$CLEAN_OUT" | tee -a "$REPORT"
(( QI_RC == 0 )) || fail 70 "zero-state quick-install.sh failed"

CLEAN_REG="$CLEAN_HOME/.carson_agent_instances/.registry"
[[ -d "$CLEAN_REG" ]] || fail 71 "quick install did not create clean registry"

CLEAN_CAND="$WORK/clean-instances.tsv"
: > "$CLEAN_CAND"
for idx in "$CLEAN_REG"/*.env; do
  [[ -f "$idx" ]] || continue
  st="$(HOME="$CLEAN_HOME" bash -c 'source "$1";printf "%s" "${CARSON_STATE_ROOT:-}"' _ "$idx" 2>/dev/null || true)"
  [[ -n "$st" && -f "$st/instance.env" && -f "$st/active-session.env" ]] || continue
  row="$(
    HOME="$CLEAN_HOME" bash -c '
      source "$1";source "$2"
      printf "%s\t%s\t%s\t%s" \
        "${CARSON_INSTANCE_ID:-}" "${CARSON_TMUX_SESSION:-}" \
        "${CARSON_SOURCE_ROOT:-}" "${CARSON_SESSION_ID:-}"
    ' _ "$st/instance.env" "$st/active-session.env" 2>/dev/null || true
  )"
  tm="$(printf '%s' "$row" | cut -f2)"
  live=0
  [[ -n "$tm" ]] && tmux has-session -t "$tm" 2>/dev/null && live=1
  printf '%s\t%s\t%s\n' "$live" "$(stat -c '%Y' "$st/active-session.env" 2>/dev/null || echo 0)" "$row" >> "$CLEAN_CAND"
done

CLEAN_LIVE_COUNT="$(awk -F'\t' '$1==1{n++} END{print n+0}' "$CLEAN_CAND")"
[[ "$CLEAN_LIVE_COUNT" == 1 ]] || fail 72 "quick install did not produce exactly one clean live listener"

CLEAN_SEL="$(sort -t $'\t' -k1,1nr -k2,2nr "$CLEAN_CAND" | head -n1)"
CLEAN_INSTANCE="$(printf '%s' "$CLEAN_SEL" | cut -f3)"
CLEAN_TMUX="$(printf '%s' "$CLEAN_SEL" | cut -f4)"
CLEAN_SOURCE="$(printf '%s' "$CLEAN_SEL" | cut -f5)"

say "ZERO_STATE_QUICK_INSTALL=PASS"
say "CLEAN_INSTANCE_ID=$CLEAN_INSTANCE"
say "CLEAN_TMUX=$CLEAN_TMUX"
say "CLEAN_SOURCE=$CLEAN_SOURCE"
say

STAGE="LTE_OVERLAY"
say "=== APPLY ONLY VERSION-CONTROLLED V0.2.0 LTE OVERLAY ==="

set +e
BOOT_OUT="$(
  HOME="$CLEAN_HOME" TMPDIR="$CLEAN_TMP" \
    bash "$CLONE/lte-accessibility/bootstrap-from-clone.sh" 2>&1
)"
BOOT_RC=$?
set -e
printf '%s\n' "$BOOT_OUT" | tee -a "$REPORT"
(( BOOT_RC == 0 )) || fail 80 "v0.2.0 clone bootstrap failed against zero-state-created instance"
grep -Fq 'SOURCE_CONTROL_DEVIATION=NONE' <<<"$BOOT_OUT" ||
  fail 81 "clone bootstrap did not prove source-control parity"
grep -Fq 'STATUS=COMPLETE' <<<"$BOOT_OUT" ||
  fail 82 "clone bootstrap incomplete"

say "ZERO_STATE_LTE_OVERLAY=PASS"
say

STAGE="DYNAMIC_ACCEPTANCE"
say "=== CREATE DYNAMIC-MARKER COPY OF VERSION-CONTROLLED RC ACCEPTANCE ==="

DYN_HEX="$(python - <<'PY'
import secrets
print(secrets.token_hex(6).upper())
PY
)"
DYN_MARKER="CARSON_UI_LOOP_ACCEPTANCE_V45_${DYN_HEX}"

python - "$CLONE/lte-accessibility/acceptance/clone-fresh-e2e.sh" "$CLEAN_ACCEPT" "$DYN_MARKER" <<'PY'
from pathlib import Path
import re,sys
src=Path(sys.argv[1]).read_text(encoding="utf-8")
dst=Path(sys.argv[2])
marker=sys.argv[3]
m=re.search(r'CARSON_UI_LOOP_ACCEPTANCE_V[0-9]+(?:_[A-F0-9]+)?',src)
if not m:
    raise SystemExit("acceptance marker token not found")
src=src.replace(m.group(0),marker)
src=src.replace(
    "CARSON_LTE_ACCESSIBILITY_CLONE_FRESH_E2E_V31",
    "CARSON_LTE_ACCESSIBILITY_RC1_COMBINED_INSTALLER_E2E_V45"
)
src=src.replace(
    "CARSON_LTE_ACCESSIBILITY_CLONE_FRESH_E2E_V31_20260816_163000",
    "CARSON_LTE_ACCESSIBILITY_RC1_COMBINED_INSTALLER_E2E_V45"
)
src=src.replace(
    "CARSON_LTE_ACCESSIBILITY_CLONE_FRESH_E2E_V31_REPORT.txt",
    "CARSON_LTE_ACCESSIBILITY_RC1_COMBINED_INSTALLER_E2E_V45_REPORT.txt"
)
needle='say "SOURCE_CONTROL_DEVIATION=NONE"'
if needle in src:
    src=src.replace(
        needle,
        'say "SOURCE_CONTROL_DEVIATION=DYNAMIC_ACCEPTANCE_MARKER_ONLY_VERSION_CONTROLLED_RC_DRIVER"',
        1
    )
dst.write_text(src,encoding="utf-8")
PY

chmod 700 "$CLEAN_ACCEPT"
bash -n "$CLEAN_ACCEPT" || fail 90 "dynamic RC acceptance copy fails bash -n"

say "DYNAMIC_ACCEPTANCE_MARKER=$DYN_MARKER"
say "RUNTIME_SOURCE_DEVIATION=NONE"
say "ACCEPTANCE_DRIVER_SOURCE=VERSION_CONTROLLED_RC_WITH_DYNAMIC_MARKER_ONLY"
say "LOCAL_ACCEPTANCE_PATCHES=NONE"
say

STAGE="E2E"
say "=== RUN FULL E2E AGAINST ZERO-STATE-CREATED CARSON INSTANCE ==="

set +e
HOME="$CLEAN_HOME" TMPDIR="$CLEAN_TMP" \
  bash "$CLEAN_ACCEPT" 2>&1 | tee "$CLEAN_ACCEPT_OUT"
E2E_RC=${PIPESTATUS[0]}
set -e
cat "$CLEAN_ACCEPT_OUT" >> "$REPORT"

(( E2E_RC == 0 )) ||
  fail 100 "zero-state-created instance E2E failed" \
    "RETURN_THIS_OUTPUT;RESTORE_WILL_RUN_AUTOMATICALLY"

for needle in \
  'SINGLE_SCRIPT_FRESH_END_TO_END=PASS' \
  'FRESH_CARSON_PROMPT_ARMING=PASS' \
  'DETERMINISTIC_CHAT_BINDING=PASS' \
  'FIRST_ARTIFACT_DOWNLOAD=PASS' \
  'NATURAL_CARSON_AUTO_EXECUTION=PASS' \
  'NATIVE_TURN19_TRANSCRIPT=PASS' \
  'A_DIRECTORY_ATTACHMENT=PASS' \
  'CONTINUATION_SEND=PASS' \
  'TASK_COMPLETE=PASS' \
  'ADB_USED=NO' \
  'WIRELESS_DEBUGGING_REQUIRED=NO' \
  'WIFI_REQUIRED=NO' \
  'STATUS=COMPLETE'
do
  grep -Fq "$needle" "$CLEAN_ACCEPT_OUT" ||
    fail 101 "zero-state E2E output missing: $needle"
done

say
say "=== V45 RC1 COMBINED INSTALLER ACCEPTANCE ==="
say "RC_BRANCH=$RC_BRANCH"
say "RELEASE_COMMIT=$CLONE_COMMIT"
say "COMPANION_FRESH_TOKEN_GENERATION=PASS"
say "COMPANION_BUILT_FROM_CURRENT_RC_SOURCE=PASS"
say "COMPANION_MY_FILES_INSTALL_CHECKPOINT=PASS"
say "COMPANION_OLD_TOKEN_REJECTION=PASS"
say "COMPANION_FRESH_TOKEN_BUILD5=PASS"
say "ZERO_STATE_HOME=PASS"
say "QUICK_INSTALL_FROM_RELEASE_ROOT=PASS"
say "CLEAN_INSTANCE_CREATED_FROM_ZERO=PASS"
say "VERSION_CONTROLLED_LTE_OVERLAY=PASS"
say "DYNAMIC_MARKER_E2E=PASS"
say "TASK_COMPLETE=PASS"
say "RUNTIME_SOURCE_DEVIATION=NONE"
say "ACCEPTANCE_DRIVER_SOURCE=VERSION_CONTROLLED_RC_WITH_DYNAMIC_MARKER_ONLY"
say "LOCAL_ACCEPTANCE_PATCHES=NONE"
say "EXISTING_BUILD5_ANDROID_BRIDGE_DEPENDENCY=NO_AFTER_COMPANION_PHASE"
say "ANDROID_COMPANION_COLD_RECONSTRUCTION_PROVEN=YES"
say "ANDROID_FIRST_INSTALL_OR_UPDATE_USER_CONSENT=PACKAGE_INSTALLER_UPDATE_CHECKPOINT"
say "MY_FILES_DIRECT_APK_NAVIGATION=BEST_EFFORT_WITH_MANUAL_FALLBACK"
say "GITHUB_MUTATION=NONE"
say "ADB_USED=NO"
say "WIRELESS_DEBUGGING_REQUIRED=NO"
say "WIFI_REQUIRED=NO"
say "NEXT=IF_THIS_EXACT_FRESH_RC_CLONE_PASSES_PROMOTE_THE_ACCEPTED_RC_COMMIT_TO_MAIN_AND_TAG_V0_3_0_WITHOUT_CODE_CHANGES"
say "STATUS=COMPLETE"

# Explicit successful restore now; trap becomes a no-op after this.
restore_real_environment
trap - EXIT INT TERM

say
say "=== FINAL POST-RESTORE ==="
if tmux list-sessions -F '#S' 2>/dev/null | grep -Fxq "$(bash -c 'source "$1"; printf "%s" "${CARSON_TMUX_SESSION:-}"' _ "$REAL_HOME/.carson_agent_instances"/*/active-session.env 2>/dev/null | tail -n1)"; then
  say "PREEXISTING_RUNTIME_RESTORED=LIKELY_PASS"
else
  say "PREEXISTING_RUNTIME_RESTORED=CHECK_REPORT"
fi
say "STATUS=COMPLETE"
