#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
umask 077

ARTIFACT_ID="CARSON_LTE_ACCESSIBILITY_CLONE_FRESH_E2E_V31_20260816_163000"
WORK="$HOME/.carson_ui_lte_poc"
CLIENT="$WORK/carson-ui"

CLAUDE_PKG="com.anthropic.claude"
DOCS_PKG="com.google.android.documentsui"
TEST_MARKER="CARSON_UI_LOOP_ACCEPTANCE_V13"
TASK_TEXT="Create one downloadable Termux Bash .sh file that prints exactly CARSON_UI_LOOP_ACCEPTANCE_V13 followed by a newline and exits with status 0. The file must require no input and make no persistent changes."
TRANSCRIPT_NAME="LLM_EXECUTION_TRANSCRIPT.txt"
CONTINUATION_MESSAGE="Use the attached local execution transcript as runtime evidence for the same task. If the original task is complete, follow the TASK_COMPLETE response contract from my first message. Otherwise continue from the existing state and return the next downloadable Termux .sh file."

PUBLIC_A="/sdcard/a"
PUBLIC_B="/sdcard/B"
ARCHIVE_BUCKET="$PUBLIC_B/ARCHIVE_${ARTIFACT_ID}"
REPORT="$PUBLIC_A/CARSON_LTE_ACCESSIBILITY_CLONE_FRESH_E2E_V31_REPORT.txt"
TMPBASE="${TMPDIR:-$HOME/.cache}/carson-lte-accessibility-clone-v31-$$"

AUTO_EXEC_TIMEOUT_MS=90000
DOWNLOAD_WAIT_MS=600000
FINAL_TIMEOUT_MS=150000

mkdir -p "$TMPBASE" "$PUBLIC_A" "$PUBLIC_B" "$ARCHIVE_BUCKET"
while IFS= read -r -d '' old; do
    mv -f -- "$old" "$ARCHIVE_BUCKET"/
done < <(find "$PUBLIC_A" -mindepth 1 -maxdepth 1 -print0 2>/dev/null || true)
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
clean(){ tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-3200; }
now_ms(){ python - <<'PY'
import time
print(int(time.monotonic()*1000))
PY
}
nap_ms(){ python - "$1" <<'PY'
import sys,time
time.sleep(int(sys.argv[1])/1000)
PY
}
file_sig(){
    local f="$1"
    if [[ -f "$f" ]]; then
        printf '%s:%s:' "$(stat -c '%s' "$f" 2>/dev/null || echo 0)" "$(stat -c '%Y' "$f" 2>/dev/null || echo 0)"
        sha256sum "$f" 2>/dev/null | awk '{print $1}'
    else
        printf 'ABSENT'
    fi
}

SCRIPT_START_MS="$(now_ms)"
PHASE_START_MS="$SCRIPT_START_MS"
phase_begin(){
    PHASE_START_MS="$(now_ms)"
    say "PHASE_BEGIN=$1"
}
phase_end(){
    local name="$1" now
    now="$(now_ms)"
    say "TIMING_${name}_MS=$((now-PHASE_START_MS))"
}

say "CARSON_LTE_ACCESSIBILITY_CLONE_FRESH_E2E_V31"
say "ARTIFACT_ID=$ARTIFACT_ID"
say "MODE=GENUINELY_FRESH_BODY_ONLY_BOUND_CHAT_DOWNLOAD_AUTOEXEC_A_TRANSCRIPT_TASK_COMPLETE"
say "TEST_MARKER=$TEST_MARKER"
say "BUILD5_REQUIRED=YES"
say "FRESH_SESSION_REQUIRED=YES"
say "PROMPT_REUSE=NO"
say "CHAT_REUSE=NO"
say "ARTIFACT_REUSE=NO"
say "TRANSCRIPT_REUSE=NO"
say "CURSOR_RECONSTRUCTION=NO"
say "ADB_USED=NO"
say "WIRELESS_DEBUGGING_REQUIRED=NO"
say "WIFI_REQUIRED=NO"
say "LTE_COMPATIBLE=YES"
say "GITHUB_MUTATION=NONE"
say "EXECUTION_SOURCE=FRESH_GITHUB_CLONE"
say "SOURCE_CONTROL_DEVIATION=NONE"
say "TASK_COMPLETE_DETECTOR=EVENT_DRIVEN_ANCHORED_ASSISTANT_RESPONSE_NOT_COUNT_DELTA"
say "V20_REGRESSION_FIX=RESTORE_PROVEN_ONE_LINE_BODY_NORMALIZATION_BEFORE_SET_TEXT"
say "V21_REGRESSION_FIX=CLEAR_AND_VERIFY_ANY_CLAUDE_PERSISTED_DRAFT_AFTER_NEW_CHAT_BEFORE_INITIAL_SET_TEXT"
say "V22_REGRESSION_FIX=AFTER_RENAME_CLASSIFY_UI_AND_REENTER_BOUND_CHAT_WITHOUT_UNCONDITIONAL_BACK"
say "V23_REGRESSION_FIX=RETRY_POST_SET_TEXT_SNAPSHOT_AND_HIDE_IME_ONLY_IF_ACTIVE_PACKAGE_IS_NOT_CLAUDE"
say "V24_V26_ACCEPTANCE=V10_DOWNLOAD_EVENTUALLY_MATERIALIZED_AUTOEXEC_TRANSCRIPT_ATTACH_CONTINUE_TASK_COMPLETE_PASS"
say "V27_STARTUP_FIX=BOUNDED_HOME_REOPEN_AND_SEMANTIC_FRESH_CHAT_RETRIES_NO_USER_APP_CLOSING_REQUIRED"
say "V27_DOWNLOAD_FIX=ONE_DOWNLOAD_TAP_THEN_WAIT_UP_TO_600_SECONDS_FOR_REAL_NON_CARSON_AGENT_V12_ARTIFACT"
say "V28_ACCEPTANCE=V27_V11_NATURAL_AUTOEXEC_TRANSCRIPT_ATTACH_CONTINUE_TASK_COMPLETE_PASS"
say "V29_AUTOEXEC_FIX=WAIT_FOR_CURRENT_UNIQUE_MARKER_DIRECTLY_IN_NATIVE_RESULT_AND_TRANSCRIPT"
say "V29_LATENCY=PHASE_TIMERS_AND_BOUNDED_SEMANTIC_STARTUP_RECOVERY_NO_MANUAL_APP_CLOSING"
say "REPORT=$REPORT"
say

for c in bash python timeout tmux sha256sum find stat; do
    command -v "$c" >/dev/null 2>&1 || fail 10 "$c missing"
done
[[ -x "$CLIENT" ]] || fail 11 "accessibility client missing"

BRIDGE_OUT=""
BRIDGE_RC=0
bridge_capture(){
    local sec="$1"; shift
    set +e
    BRIDGE_OUT="$(timeout "$sec" bash "$CLIENT" "$@" 2>&1)"
    BRIDGE_RC=$?
    set -e
}
bridge_ok(){ [[ "$BRIDGE_RC" -eq 0 && "$BRIDGE_OUT" == OK$'\t'* ]]; }
bridge_show(){ printf '%s\n' "$BRIDGE_OUT" | tr '\t' ' ' | clean; }

click_exact(){
    local label="$1"
    bridge_capture 12 click "$label"
    say "CLICK[$label]=$(bridge_show)"
    bridge_ok
}
click_top(){
    local label="$1"
    bridge_capture 12 click-top "$label"
    say "CLICK_TOP[$label]=$(bridge_show)"
    bridge_ok
}
click_bottom(){
    local label="$1"
    bridge_capture 12 click-bottom "$label"
    say "CLICK_BOTTOM[$label]=$(bridge_show)"
    bridge_ok
}
long_click_exact(){
    local label="$1"
    bridge_capture 12 long-click "$label"
    say "LONG_CLICK[$label]=$(bridge_show)"
    bridge_ok
}
wait_exact(){
    local ms="$1"; shift
    bridge_capture $((ms/1000+20)) wait "$ms" "$*"
    say "WAIT_EXACT[$*]=$(bridge_show)"
    bridge_ok
}
wait_regex(){
    local ms="$1" rx="$2"
    bridge_capture $((ms/1000+20)) wait-regex "$ms" "$rx"
    say "WAIT_REGEX[$rx]=$(bridge_show)"
    bridge_ok
}
wait_package(){
    local ms="$1" pkg="$2"
    bridge_capture $((ms/1000+20)) wait-package "$ms" "$pkg"
    say "WAIT_PACKAGE[$pkg]=$(bridge_show)"
    bridge_ok
}
snapshot(){
    local out="$1"
    bridge_capture 15 snapshot
    bridge_ok || return 1
    printf '%s\n' "$BRIDGE_OUT" > "$out"
}

snapshot_after_set_text(){
    local out="$1"
    local attempt state pkg back_used=0

    for attempt in 1 2 3 4 5 6; do
        bridge_capture 15 snapshot
        if bridge_ok; then
            printf '%s\n' "$BRIDGE_OUT" > "$out"
            say "POST_SET_TEXT_SNAPSHOT=PASS attempt=$attempt ime_back_used=$back_used"
            return 0
        fi

        say "POST_SET_TEXT_SNAPSHOT_RETRY[$attempt]=$(bridge_show)"
        bridge_capture 8 state
        state="$BRIDGE_OUT"
        say "POST_SET_TEXT_STATE[$attempt]=$(bridge_show)"

        pkg="$(printf '%s\n' "$state" | sed -n 's/.*[[:space:]]PKG=\\([^[:space:]]*\\).*/\\1/p' | head -n1)"

        # When an IME owns the active accessibility window, hide it exactly once.
        # Do not use Back when Claude itself is still the active package.
        if [[ -n "$pkg" && "$pkg" != "$CLAUDE_PKG" && "$back_used" -eq 0 ]]; then
            say "POST_SET_TEXT_NON_CLAUDE_ACTIVE_PACKAGE=$pkg"
            bridge_capture 8 back
            say "POST_SET_TEXT_HIDE_IME_BACK=$(bridge_show)"
            back_used=1
            nap_ms 250
            wait_package 8000 "$CLAUDE_PKG" || true
        else
            nap_ms 200
        fi
    done

    return 1
}

snapshot_retry(){
    local out="$1" label="${2:-SNAPSHOT}"
    local attempt
    for attempt in 1 2 3 4 5 6; do
        if snapshot "$out"; then
            say "${label}=PASS attempt=$attempt"
            return 0
        fi
        say "${label}_RETRY[$attempt]=$(bridge_show)"
        nap_ms 200
    done
    return 1
}

set_text_exact_retry(){
    local file="$1" label="$2"
    local expected attempt snap edit count observed
    expected="$(cat "$file")"

    for attempt in 1 2 3 4 5 6; do
        bridge_capture 20 set-text-file "$file"
        say "${label}_SET_TEXT[$attempt]=$(bridge_show)"

        snap="$TMPBASE/${label,,}-verify-$attempt.txt"
        if snapshot_after_set_text "$snap"; then
            edit="$(decoded_edit "$snap")"
            count="$(printf '%s\n' "$edit" | sed -n 's/^COUNT=//p')"
            observed="$(printf '%s\n' "$edit" | sed -n 's/^TEXT=//p')"
            say "${label}_EDITABLE_COUNT[$attempt]=$count"
            say "${label}_OBSERVED_CHARS[$attempt]=${#observed}"

            if [[ "$count" == 1 && "$observed" == "$expected" ]]; then
                say "${label}_EXACT_VERIFY=PASS attempt=$attempt"
                printf '%s\n' "$snap"
                return 0
            fi

            if [[ "$count" != 1 ]]; then
                say "${label}_RETRY_REASON=COMPOSER_NOT_UNIQUE"
            elif [[ -z "$observed" ]]; then
                say "${label}_RETRY_REASON=COMPOSER_EMPTY_AFTER_SET_TEXT"
            else
                say "${label}_RETRY_REASON=TEXT_MISMATCH_PRE_SEND"
            fi
        else
            say "${label}_RETRY_REASON=POST_SET_TEXT_SNAPSHOT_UNAVAILABLE"
        fi
        nap_ms 250
    done
    return 1
}

decoded_exact_count(){
    python - "$1" "$2" <<'PY'
import base64,pathlib,sys
target=sys.argv[2]; n=0
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"): continue
    p=line.split("\t")
    if len(p)<8: continue
    def d(x):
        try:return base64.b64decode(x).decode("utf-8","replace")
        except Exception:return ""
    if d(p[3]).strip()==target or d(p[4]).strip()==target:n+=1
print(n)
PY
}
decoded_regex_count(){
    python - "$1" "$2" <<'PY'
import base64,pathlib,re,sys
rx=re.compile(sys.argv[2],re.I|re.S);n=0
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"):continue
    p=line.split("\t")
    if len(p)<8:continue
    def d(x):
        try:return base64.b64decode(x).decode("utf-8","replace")
        except Exception:return ""
    if rx.search(d(p[3])) or rx.search(d(p[4])):n+=1
print(n)
PY
}
decoded_edit(){
    python - "$1" <<'PY'
import base64,pathlib,sys
vals=[]
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"):continue
    p=line.split("\t")
    if len(p)<8 or p[6]!="1":continue
    try:v=base64.b64decode(p[3]).decode("utf-8","replace")
    except Exception:v=""
    vals.append(v)
print("COUNT=%d"%len(vals))
print("TEXT="+(vals[0] if len(vals)==1 else ""))
PY
}
newest_recent_title(){
    python - "$1" <<'PY'
import base64,pathlib,sys
rows=[]
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"):continue
    p=line.split("\t")
    if len(p)<8:continue
    def d(x):
        try:return base64.b64decode(x).decode("utf-8","replace").strip()
        except Exception:return ""
    label=d(p[3]) or d(p[4])
    if not label:continue
    try:x1,y1,x2,y2=map(int,p[7].split(","))
    except Exception:continue
    rows.append((y1,y2,label))
rec_bottom=None
for y1,y2,label in rows:
    if label=="Recents":
        rec_bottom=y2;break
if rec_bottom is None:raise SystemExit(2)
skip={"New chat","Chats","Projects","Artifacts","Recents","Today","Yesterday",
      "Previous 7 days","Previous 30 days","Search","Open menu","Settings",
      "Upgrade","Starred","All chats"}
cand=[]
for y1,y2,label in rows:
    if y1<rec_bottom or y1>1900 or label in skip or len(label)>180:continue
    cand.append((y1,label))
seen=set();uniq=[]
for y,label in sorted(cand):
    if label not in seen:
        seen.add(label);uniq.append((y,label))
if not uniq:raise SystemExit(3)
print(uniq[0][1])
PY
}
artifact_card_title(){
    python - "$1" <<'PY'
import base64,pathlib,sys
nodes=[]
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"):continue
    p=line.split("\t")
    if len(p)<8:continue
    def d(x):
        try:return base64.b64decode(x).decode("utf-8","replace").strip()
        except Exception:return ""
    label=d(p[3]) or d(p[4])
    try:b=tuple(map(int,p[7].split(",")))
    except Exception:continue
    nodes.append((label,b))
codes=[n for n in nodes if n[0]=="Code · SH"]
if not codes:raise SystemExit(2)
code=max(codes,key=lambda n:n[1][1])
cb=code[1];ccx=(cb[0]+cb[2])/2;ccy=(cb[1]+cb[3])/2
skip={"Code · SH","1 Artifact","2 steps","Reply to Claude…","Sonnet 5","Thinking"}
cand=[]
for label,b in nodes:
    if not label or label in skip or len(label)>100:continue
    cx=(b[0]+b[2])/2;cy=(b[1]+b[3])/2
    dy=ccy-cy
    if dy<=0 or dy>220:continue
    overlap=max(0,min(cb[2],b[2])-max(cb[0],b[0]))
    if overlap<=0 and abs(cx-ccx)>260:continue
    cand.append((dy+abs(cx-ccx)*0.15,label))
if not cand:raise SystemExit(3)
cand.sort(key=lambda x:x[0])
print(cand[0][1])
PY
}
extract_artifact_filename(){
    python - "$1" <<'PY'
import base64,pathlib,re,sys
vals=[]
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"):continue
    p=line.split("\t")
    if len(p)<8:continue
    for pos in (3,4):
        try:v=base64.b64decode(p[pos]).decode("utf-8","replace").strip()
        except Exception:v=""
        if re.fullmatch(r'[A-Za-z0-9._-]+\.sh',v):
            vals.append(v)
if vals:print(vals[0])
PY
}
breadcrumb_root_label(){
    python - "$1" <<'PY'
import base64,pathlib,sys
cand=[]
ignore={"Recent","Images","Videos","Audio","Documents","Downloads","Download",
        "This week","Large files","Personal","Work","Open from","Files in a","Files on"}
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"):continue
    p=line.split("\t")
    if len(p)<8:continue
    def d(x):
        try:return base64.b64decode(x).decode("utf-8","replace").strip()
        except Exception:return ""
    label=d(p[3]) or d(p[4])
    if not label or label in ignore or len(label)>80:continue
    try:x1,y1,x2,y2=map(int,p[7].split(","))
    except Exception:continue
    if 110<=y1<=280 and x1<300:
        cand.append((x1,y1,label))
if not cand:raise SystemExit(2)
cand.sort()
print(cand[0][2])
PY
}
verified_task_complete(){
    python - "$1" "$2" <<'PY'
import base64,pathlib,sys
marker=sys.argv[2]
for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace").splitlines():
    if not line.startswith("NODE\t"):continue
    p=line.split("\t")
    if len(p)<8:continue
    for pos in (3,4):
        try:v=base64.b64decode(p[pos]).decode("utf-8","replace").strip()
        except Exception:v=""
        if v.upper().startswith("TASK_COMPLETE:") and marker in v:
            print("YES")
            raise SystemExit
print("NO")
PY
}

STAGE="BRIDGE_PRECHECK"
phase_begin BRIDGE_PRECHECK
say "=== BUILD5 BRIDGE PRECHECK ==="
bridge_capture 8 state
say "STATE=$(bridge_show)"
bridge_ok || fail 20 "accessibility bridge unavailable"
[[ "$BRIDGE_OUT" == *$'\tBUILD=5\t'* ]] || fail 21 "BUILD5 bridge is not active"
say "BUILD5_PRECHECK=PASS"
phase_end BRIDGE_PRECHECK
say

STAGE="RESOLVE_CARSON"
phase_begin RESOLVE_CARSON
say "=== RESOLVE LIVE CARSON INSTANCE ==="
REG="$HOME/.carson_agent_instances/.registry"
[[ -d "$REG" ]] || fail 30 "CARSON registry missing"
CAND="$TMPBASE/instances.tsv";:>"$CAND"

for idx in "$REG"/*.env;do
    [[ -f "$idx" ]]||continue
    state="$(bash -c 'source "$1" 2>/dev/null;printf "%s" "${CARSON_STATE_ROOT:-}"' _ "$idx" 2>/dev/null||true)"
    [[ -n "$state" && -f "$state/instance.env" && -f "$state/active-session.env" ]]||continue
    row="$(
      bash -c '
        source "$1";source "$2"
        printf "%s\t%s\t%s\t%s\t%s\t%s" \
          "${CARSON_INSTANCE_ID:-}" "${CARSON_SESSION_ID:-}" "${CARSON_TMUX_SESSION:-}" \
          "${CARSON_STATE_ROOT:-}" "${CARSON_DOWNLOAD_DIR:-/storage/emulated/0/Download}" \
          "${CARSON_A_DIR:-}"
      ' _ "$state/instance.env" "$state/active-session.env" 2>/dev/null||true
    )"
    tm="$(printf '%s' "$row"|cut -f3)";live=0
    [[ -n "$tm" ]]&&tmux has-session -t "$tm" 2>/dev/null&&live=1
    printf '%s\t%s\t%s\n' "$live" "$(stat -c '%Y' "$state/active-session.env" 2>/dev/null||echo 0)" "$row">>"$CAND"
done

SEL="$(sort -t $'\t' -k1,1nr -k2,2nr "$CAND"|head -n1)"
[[ "$(printf '%s' "$SEL"|cut -f1)" == 1 ]]||fail 31 "no live CARSON listener"
INSTANCE_ID="$(printf '%s' "$SEL"|cut -f3)"
SESSION_ID="$(printf '%s' "$SEL"|cut -f4)"
TMUX_SESSION="$(printf '%s' "$SEL"|cut -f5)"
STATE_ROOT="$(printf '%s' "$SEL"|cut -f6)"
DOWNLOAD_DIR="$(printf '%s' "$SEL"|cut -f7)"
A_DIR="$(printf '%s' "$SEL"|cut -f8)"
SOURCE_ROOT="$(bash -c 'source "$1";printf "%s" "${CARSON_SOURCE_ROOT:-}"' _ "$STATE_ROOT/instance.env")"
PROMPT_BIN="$SOURCE_ROOT/bin/carson-prompt"
CURSOR="$STATE_ROOT/auto-ingest.cursor"
BINDING="$STATE_ROOT/ui-automation/claude-session-binding.env"

[[ -x "$PROMPT_BIN" ]]||fail 32 "carson-prompt missing"
[[ -d "$DOWNLOAD_DIR" && -d "$A_DIR" ]]||fail 33 "CARSON data directories missing"

say "INSTANCE_ID=$INSTANCE_ID"
say "SESSION_ID=$SESSION_ID"
say "TMUX_SESSION=$TMUX_SESSION"
say "STATE_ROOT=$STATE_ROOT"
say "DOWNLOAD_DIR=$DOWNLOAD_DIR"
say "A_DIR=$A_DIR"
phase_end RESOLVE_CARSON
say

STAGE="FRESH_PROMPT"
phase_begin FRESH_PROMPT_ARM
say "=== RETIRE COMPLETED V29 ARM / ARM GENUINELY FRESH CLONE-SOURCED CARSON TURN ==="
if [[ -f "$CURSOR" ]]; then
    say "PREEXISTING_CURSOR=YES"
    say "PREEXISTING_CURSOR_CONTENT_BEGIN"
    sed -n '1,20p' "$CURSOR" | tee -a "$REPORT"
    say "PREEXISTING_CURSOR_CONTENT_END"
    rm -f "$CURSOR"
    say "COMPLETED_V29_CURSOR_REMOVED=YES"
else
    say "PREEXISTING_CURSOR=NO"
fi
say "CURSOR_RECONSTRUCTION=NO"
PROMPT_RAW="$TMPBASE/prompt.raw"
PROMPT_ERR="$TMPBASE/prompt.err"
set +e
"$PROMPT_BIN" "$TASK_TEXT" >"$PROMPT_RAW" 2>"$PROMPT_ERR"
PRC=$?
set -e
say "CARSON_PROMPT_RC=$PRC"
say "CARSON_PROMPT_STDERR=$(cat "$PROMPT_ERR"|clean)"
(( PRC==0 ))||fail 40 "carson-prompt failed"
grep -Fq 'AUTO_INGEST=ARMED' "$PROMPT_ERR"||fail 41 "fresh prompt did not arm auto-ingest"
[[ -f "$CURSOR" ]]||fail 42 "fresh auto-ingest cursor missing"

BODY_RAW="$TMPBASE/body-raw.txt"
BODY="$TMPBASE/body-one-line.txt"
python - "$PROMPT_RAW" "$BODY_RAW" "$BODY" <<'PY'
import pathlib,re,sys
s=pathlib.Path(sys.argv[1]).read_text(encoding="utf-8",errors="replace")
a="---BEGIN_DIRECT_USER_MESSAGE---"
b="---END_DIRECT_USER_MESSAGE---"
if s.count(a)!=1 or s.count(b)!=1:raise SystemExit(2)
body=s.split(a,1)[1].split(b,1)[0].strip()
if not body:raise SystemExit(3)
if a in body or b in body:raise SystemExit(4)
one=re.sub(r"\s+"," ",body).strip()
pathlib.Path(sys.argv[2]).write_text(body,encoding="utf-8")
pathlib.Path(sys.argv[3]).write_text(one,encoding="utf-8")
PY
[[ -s "$BODY" ]]||fail 43 "direct-user-message one-line body extraction failed"
! grep -Fq -- '---BEGIN_DIRECT_USER_MESSAGE---' "$BODY"||fail 44 "wrapper begin marker leaked"
! grep -Fq -- '---END_DIRECT_USER_MESSAGE---' "$BODY"||fail 45 "wrapper end marker leaked"
say "DIRECT_BODY_BYTES=$(stat -c '%s' "$BODY_RAW")"
say "DIRECT_BODY_LINES=$(wc -l < "$BODY_RAW"|tr -d ' ')"
say "ONE_LINE_BODY_BYTES=$(stat -c '%s' "$BODY")"
say "ONE_LINE_NORMALIZATION=PROVEN_V14_PATTERN"
say "AUTO_INGEST_CURSOR_MTIME_NS=$(python - "$CURSOR" <<'PY'
import os,sys
print(os.stat(sys.argv[1]).st_mtime_ns)
PY
)"
phase_end FRESH_PROMPT_ARM
say

STAGE="FRESH_CHAT"
phase_begin FRESH_CHAT
say "=== OPEN CLAUDE / CREATE GENUINELY FRESH CHAT WITH SOFT-RESET RETRIES ==="

FRESH_READY=0
for cycle in 1 2 3 4; do
    if (( cycle > 1 )); then
        bridge_capture 8 home
        say "FRESH_SOFT_RESET_HOME[$cycle]=$(bridge_show)"
        nap_ms 350
    fi

    bridge_capture 12 open "$CLAUDE_PKG"
    say "OPEN_CLAUDE[$cycle]=$(bridge_show)"
    if ! bridge_ok; then
        say "FRESH_CYCLE[$cycle]=OPEN_FAILED"
        continue
    fi
    if ! wait_package 20000 "$CLAUDE_PKG"; then
        say "FRESH_CYCLE[$cycle]=PACKAGE_WAIT_FAILED"
        continue
    fi

    for inner in 1 2 3 4; do
        S="$TMPBASE/fresh-cycle-${cycle}-${inner}.txt"
        if ! snapshot_retry "$S" "FRESH_ENTRY_SNAPSHOT[$cycle/$inner]"; then
            bridge_capture 8 back
            say "FRESH_ENTRY_BACK[$cycle/$inner]=$(bridge_show)"
            nap_ms 250
            continue
        fi

        NC="$(decoded_exact_count "$S" "New chat")"
        OM="$(decoded_exact_count "$S" "Open menu")"
        ADD="$(decoded_exact_count "$S" "Add to chat")"
        say "FRESH_ENTRY_STATE[$cycle/$inner]=NEW_CHAT:$NC OPEN_MENU:$OM ADD_TO_CHAT:$ADD"

        if (( ADD == 1 && NC == 0 )); then
            say "FRESH_ROUTE[$cycle/$inner]=EXISTING_NEW_CHAT_SURFACE"
            FRESH_READY=1
            break
        fi

        if (( NC == 1 )); then
            say "FRESH_ROUTE[$cycle/$inner]=DIRECT_NEW_CHAT"
            if click_exact "New chat"; then
                if wait_exact 12000 "Add to chat"; then
                    FRESH_READY=1
                    break
                fi
            fi
            say "FRESH_DIRECT_NEW_CHAT_RETRY[$cycle/$inner]=YES"
            nap_ms 250
            continue
        fi

        if (( OM == 1 )); then
            say "FRESH_ROUTE[$cycle/$inner]=OPEN_DRAWER_NEW_CHAT"
            if click_exact "Open menu"; then
                if wait_exact 8000 "New chat"; then
                    if click_exact "New chat"; then
                        if wait_exact 12000 "Add to chat"; then
                            FRESH_READY=1
                            break
                        fi
                    else
                        nap_ms 250
                        CHECK="$TMPBASE/fresh-click-check-${cycle}-${inner}.txt"
                        if snapshot_retry "$CHECK" "FRESH_NEW_CHAT_CLICK_CHECK[$cycle/$inner]" &&
                           (( $(decoded_exact_count "$CHECK" "Add to chat") == 1 )); then
                            FRESH_READY=1
                            break
                        fi
                    fi
                fi
            fi
            say "FRESH_DRAWER_NEW_CHAT_RETRY[$cycle/$inner]=YES"
            bridge_capture 8 back
            say "FRESH_DRAWER_BACK[$cycle/$inner]=$(bridge_show)"
            nap_ms 250
            continue
        fi

        bridge_capture 8 back
        say "FRESH_NESTED_BACK[$cycle/$inner]=$(bridge_show)"
        nap_ms 250
    done

    (( FRESH_READY == 1 )) && break
done

(( FRESH_READY == 1 )) ||
    fail 52 "could not establish a fresh Claude composer after bounded Home/reopen semantic retries"

wait_exact 12000 "Add to chat" || fail 57 "fresh composer not ready"
FRESH="$TMPBASE/fresh.txt"
snapshot_retry "$FRESH" "FRESH_COMPOSER_SNAPSHOT" || fail 58 "fresh snapshot failed"

EDIT="$(decoded_edit "$FRESH")"
EDIT_COUNT="$(printf '%s\n' "$EDIT"|sed -n 's/^COUNT=//p')"
EDIT_TEXT="$(printf '%s\n' "$EDIT"|sed -n 's/^TEXT=//p')"
[[ "$EDIT_COUNT" == 1 ]] || fail 59 "fresh composer not unique"

if [[ -n "$EDIT_TEXT" ]]; then
    say "PERSISTED_DRAFT_DETECTED=YES"
    say "PERSISTED_DRAFT_CHARS=${#EDIT_TEXT}"
    EMPTY="$TMPBASE/empty-composer.txt"
    : > "$EMPTY"

    CLEARED_OK=0
    for attempt in 1 2 3 4; do
        bridge_capture 15 set-text-file "$EMPTY"
        say "CLEAR_PERSISTED_DRAFT[$attempt]=$(bridge_show)"
        CLEARED="$TMPBASE/fresh-cleared-$attempt.txt"
        if snapshot_after_set_text "$CLEARED"; then
            CE="$(decoded_edit "$CLEARED")"
            CC="$(printf '%s\n' "$CE"|sed -n 's/^COUNT=//p')"
            CT="$(printf '%s\n' "$CE"|sed -n 's/^TEXT=//p')"
            if [[ "$CC" == 1 && -z "$CT" ]]; then
                CLEARED_OK=1
                FRESH="$CLEARED"
                break
            fi
        fi
        nap_ms 250
    done
    (( CLEARED_OK == 1 )) || fail 63 "persisted draft could not be cleared and verified"
    say "PERSISTED_DRAFT_CLEAR_VERIFY=PASS"
else
    say "PERSISTED_DRAFT_DETECTED=NO"
    say "PERSISTED_DRAFT_CLEAR_VERIFY=NOT_NEEDED"
fi

(( $(decoded_exact_count "$FRESH" "Code · SH")==0 )) || fail 64 "fresh chat already contains artifact"
say "FRESH_CHAT_PROVEN=PASS"
phase_end FRESH_CHAT
say

STAGE="INITIAL_SEND"
phase_begin INITIAL_SEND
say "=== SEND BODY-ONLY INITIAL PROMPT EXACTLY ONCE ==="
set_text_exact_retry "$BODY" "INITIAL_BODY" >/dev/null ||
    fail 70 "could not set and exactly verify initial body after bounded retries" "DO_NOT_SEND;RETURN_THIS_OUTPUT"
say "INITIAL_BODY_VERIFY=PASS"

click_exact "Send" || fail 73 "initial Send failed"
say "INITIAL_SEND_TAP_COUNT=1"

POST="$TMPBASE/post-initial.txt"
snapshot_retry "$POST" "INITIAL_POST_SEND_SNAPSHOT" ||
    fail 74 "initial post-send snapshot unavailable" "DO_NOT_RESEND"

POST_EDIT="$(decoded_edit "$POST")"
POST_TEXT="$(printf '%s\n' "$POST_EDIT"|sed -n 's/^TEXT=//p')"
[[ -z "$POST_TEXT" ]] ||
    fail 75 "composer did not clear after initial Send" "DO_NOT_RESEND"
say "INITIAL_SEND_CONSUMED=PASS"
phase_end INITIAL_SEND
say

STAGE="FIRST_RESPONSE"
phase_begin FIRST_RESPONSE
say "=== WAIT FIRST ARTIFACT RESPONSE ==="
wait_exact 120000 "Code · SH"||fail 80 "Claude did not return first .sh artifact"
CHAT="$TMPBASE/first-response.txt";snapshot "$CHAT"||fail 81 "first response snapshot failed"
(( $(decoded_exact_count "$CHAT" "Code · SH")>=1 ))||fail 82 "Code · SH vanished"
say "FIRST_ARTIFACT_RESPONSE=PASS"
phase_end FIRST_RESPONSE
say

STAGE="BIND_CHAT"
phase_begin BIND_CHAT
say "=== DETERMINISTICALLY BIND FRESH CHAT ==="
ROUTE_HEX="$(python - <<'PY'
import secrets
print(secrets.token_hex(8).upper())
PY
)"
BOUND_TITLE="CARSON $ROUTE_HEX"
ROUTE_KEY="CARSON_ROUTE_$ROUTE_HEX"

wait_exact 15000 "Open menu"||fail 90 "Open menu not ready for binding"
click_exact "Open menu"||fail 91 "Open menu click failed"
wait_exact 10000 "Recents"||fail 92 "Recents absent"
DRAWER="$TMPBASE/drawer.txt";snapshot "$DRAWER"||fail 93 "drawer snapshot failed"
OLD_TITLE="$(newest_recent_title "$DRAWER" 2>/dev/null||true)"
say "CLAUDE_GENERATED_TITLE=${OLD_TITLE:-UNRESOLVED}"
[[ -n "$OLD_TITLE" ]]||fail 94 "newest Recent title unresolved"
long_click_exact "$OLD_TITLE"||fail 95 "newest chat long-click failed"
wait_exact 10000 "Rename"||fail 96 "Rename action missing"
click_exact "Rename"||fail 97 "Rename action click failed"
TITLE_FILE="$TMPBASE/title.txt";printf '%s' "$BOUND_TITLE">"$TITLE_FILE"
bridge_capture 15 set-text-file "$TITLE_FILE"
say "RENAME_SET_TEXT=$(bridge_show)"
bridge_ok||fail 98 "rename SET_TEXT failed"
REN="$TMPBASE/rename.txt";snapshot "$REN"||fail 99 "rename verification snapshot failed"
[[ "$(decoded_edit "$REN"|sed -n 's/^TEXT=//p')" == "$BOUND_TITLE" ]]||fail 100 "rename text mismatch"
click_exact "Rename"||fail 101 "rename confirmation failed"

# Claude leaves the navigation drawer open after a successful rename on the
# current app build. Do not press Back blindly. Classify the post-rename UI and
# take the shortest semantic route back to the just-bound chat.
nap_ms 250
POST_RENAME="$TMPBASE/post-rename.txt"
snapshot "$POST_RENAME"||fail 102 "post-rename snapshot failed"

PR_ADD="$(decoded_exact_count "$POST_RENAME" "Add to chat")"
PR_BOUND="$(decoded_exact_count "$POST_RENAME" "$BOUND_TITLE")"
PR_MENU="$(decoded_exact_count "$POST_RENAME" "Open menu")"
PR_CHATS="$(decoded_exact_count "$POST_RENAME" "Chats")"
PR_RENAME="$(decoded_exact_count "$POST_RENAME" "Rename")"

say "POST_RENAME_STATE=ADD_TO_CHAT:$PR_ADD BOUND_TITLE:$PR_BOUND OPEN_MENU:$PR_MENU CHATS:$PR_CHATS RENAME:$PR_RENAME"

if (( PR_ADD == 1 && PR_BOUND == 0 )); then
    say "POST_RENAME_ROUTE=ALREADY_IN_BOUND_CHAT"
elif (( PR_BOUND == 1 )); then
    say "POST_RENAME_ROUTE=DRAWER_EXACT_BOUND_TITLE"
    click_exact "$BOUND_TITLE"||fail 103 "bound title visible after rename but could not be opened"
    wait_exact 15000 "Add to chat"||fail 104 "bound chat did not open after direct drawer selection"
elif (( PR_MENU == 1 )); then
    say "POST_RENAME_ROUTE=OPEN_DRAWER_THEN_BOUND_TITLE"
    click_exact "Open menu"||fail 105 "post-rename Open menu could not be activated"
    wait_exact 10000 "$BOUND_TITLE"||fail 106 "bound title did not appear in drawer after rename"
    click_exact "$BOUND_TITLE"||fail 107 "bound title could not be activated after opening drawer"
    wait_exact 15000 "Add to chat"||fail 108 "bound chat did not open after drawer selection"
else
    # A remaining rename/dialog surface is the only case where Back is allowed.
    if (( PR_RENAME >= 1 )); then
        say "POST_RENAME_ROUTE=DISMISS_REMAINING_RENAME_SURFACE"
        bridge_capture 8 back
        say "POST_RENAME_BACK=$(bridge_show)"
        nap_ms 250
        POST2="$TMPBASE/post-rename-back.txt"
        snapshot "$POST2"||fail 109 "post-rename Back verification snapshot failed"
        if (( $(decoded_exact_count "$POST2" "$BOUND_TITLE") == 1 )); then
            click_exact "$BOUND_TITLE"||fail 110 "bound title could not be opened after rename-surface dismissal"
            wait_exact 15000 "Add to chat"||fail 111 "bound chat did not open after rename-surface dismissal"
        elif (( $(decoded_exact_count "$POST2" "Add to chat") == 1 )); then
            say "POST_RENAME_ROUTE=BACK_RETURNED_TO_BOUND_CHAT"
        else
            fail 112 "post-rename state remained unresolved after one bounded Back"
        fi
    else
        fail 113 "post-rename state exposed neither bound chat nor drawer route"
    fi
fi

BOUND_VERIFY="$TMPBASE/bound-after-rename.txt"
snapshot "$BOUND_VERIFY"||fail 114 "bound-chat post-rename verification snapshot failed"
(( $(decoded_exact_count "$BOUND_VERIFY" "Add to chat") == 1 ))||
    fail 115 "post-rename routing did not land in a chat composer"
(( $(decoded_exact_count "$BOUND_VERIFY" "Code · SH") >= 1 ))||
    fail 116 "post-rename routing landed in a chat without the fresh V9 artifact"
say "POST_RENAME_BOUND_CHAT_VERIFY=PASS"

mkdir -p "$(dirname "$BINDING")"
{
    printf 'BINDING_VERSION=%q\n' "4"
    printf 'BINDING_STATE=%q\n' "BOUND"
    printf 'CLAUDE_CHAT_TITLE=%q\n' "$BOUND_TITLE"
    printf 'CLAUDE_CHAT_ROUTE_KEY=%q\n' "$ROUTE_KEY"
    printf 'CLAUDE_CHAT_OLD_TITLE=%q\n' "$OLD_TITLE"
    printf 'CREATED_AT_UTC=%q\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$BINDING"
chmod 600 "$BINDING"
say "BOUND_CHAT_TITLE=$BOUND_TITLE"
say "DETERMINISTIC_CHAT_BINDING=PASS"
say "POST_RENAME_SEMANTIC_RETURN=PASS"
phase_end BIND_CHAT
say

NEXT_BASE="$A_DIR/NEXT_LLM_MESSAGE.txt"
TRANSCRIPT_A="$A_DIR/$TRANSCRIPT_NAME"

STAGE="DOWNLOAD"
phase_begin DOWNLOAD
say "=== OPEN / REQUEST FIRST ARTIFACT DOWNLOAD EXACTLY ONCE ==="
CHAT="$TMPBASE/card.txt"
snapshot_retry "$CHAT" "ARTIFACT_CARD_SNAPSHOT" || fail 110 "artifact card snapshot failed"
CARD_TITLE="$(artifact_card_title "$CHAT" 2>/dev/null || true)"
say "ARTIFACT_CARD_TITLE=${CARD_TITLE:-UNRESOLVED}"
[[ -n "$CARD_TITLE" ]] || fail 111 "artifact card title unresolved"

click_exact "$CARD_TITLE" || fail 112 "artifact card title click failed"
wait_exact 12000 "Close" || fail 113 "artifact viewer did not open"
wait_exact 12000 "More options" || fail 114 "More options absent"

VIEW="$TMPBASE/view.txt"
snapshot_retry "$VIEW" "ARTIFACT_VIEWER_SNAPSHOT" || fail 115 "viewer snapshot failed"
ARTIFACT_FILENAME="$(extract_artifact_filename "$VIEW")"
say "ARTIFACT_FILENAME=${ARTIFACT_FILENAME:-UNRESOLVED}"
[[ -n "$ARTIFACT_FILENAME" ]] || fail 116 "viewer filename unresolved"

click_exact "More options" || fail 117 "More options click failed"
wait_exact 10000 "Download" || fail 118 "Download option absent"
click_exact "Download" || fail 119 "Download click failed"
say "DOWNLOAD_TAP_COUNT=1"
say "DOWNLOAD_RETRY_TAP_ALLOWED=NO"

find_real_artifact(){
    python - "$DOWNLOAD_DIR" "$TEST_MARKER" "$ARTIFACT_FILENAME" "$0" <<'PY'
import pathlib,sys
root=pathlib.Path(sys.argv[1]); marker=sys.argv[2]; expected=sys.argv[3]
selfp=pathlib.Path(sys.argv[4]).resolve()
hits=[]
for p in root.glob("*.sh"):
    if p.name.startswith("CARSON_AGENT_"):
        continue
    try:
        if p.resolve()==selfp:
            continue
        data=p.read_text(encoding="utf-8",errors="replace")
    except Exception:
        continue
    if marker not in data:
        continue
    st=p.stat()
    hits.append((0 if p.name==expected else 1,-st.st_mtime_ns,str(p)))
for _,__,p in sorted(hits):
    print(p)
PY
}

DL_START="$(now_ms)"
DOWNLOADED=""
LAST_NOTICE=-1
while :; do
    DOWNLOADED="$(find_real_artifact | head -n1 || true)"
    [[ -n "$DOWNLOADED" ]] && break

    ELAPSED=$(( $(now_ms)-DL_START ))
    if (( ELAPSED >= DOWNLOAD_WAIT_MS )); then
        say "DOWNLOAD_WAIT=TIMEOUT elapsed_ms=$ELAPSED"
        say "DOWNLOAD_TAP_COUNT=1"
        say "DOWNLOAD_RETRY_TAP_ALLOWED=NO"
        say "TASK_STATE_PRESERVED=YES"
        say "DOWNLOAD_DIRECTORY_DIAGNOSTICS_BEGIN"
        find "$DOWNLOAD_DIR" -maxdepth 1 -type f \
          \( -name '*.sh' -o -name '*.part' -o -name '*.download' -o -name '*.tmp' \) \
          -printf '%TY-%Tm-%TdT%TH:%TM:%TS %s %p\n' 2>/dev/null |
          sort | tail -n 40 | tee -a "$REPORT" || true
        say "DOWNLOAD_DIRECTORY_DIAGNOSTICS_END"
        df -k "$DOWNLOAD_DIR" 2>&1 | tee -a "$REPORT" || true
        fail 120 "real V12 artifact did not materialize after one Download request and 600-second wait" \
          "DO_NOT_RESTART_OR_RETAP_DOWNLOAD;USE_BOUND_RECOVERY_FOR_THIS_TASK"
    fi

    NOTICE=$((ELAPSED/10000))
    if (( NOTICE != LAST_NOTICE )); then
        say "DOWNLOAD_WAIT=WAITING elapsed_seconds=$((ELAPSED/1000))"
        LAST_NOTICE=$NOTICE
    fi
    nap_ms 500
done

[[ -f "$DOWNLOADED" ]] || fail 121 "resolved downloaded artifact is not a file"
[[ "$(basename "$DOWNLOADED")" != CARSON_AGENT_* ]] ||
    fail 122 "control artifact was incorrectly admitted as Claude download"
grep -Fq "$TEST_MARKER" "$DOWNLOADED" ||
    fail 123 "downloaded artifact does not contain V12 marker"
bash -n "$DOWNLOADED" || fail 124 "downloaded artifact fails bash -n"

say "DOWNLOADED_PATH=$DOWNLOADED"
say "DOWNLOADED_SHA256=$(sha256sum "$DOWNLOADED"|awk '{print $1}')"
say "REAL_ARTIFACT_DOWNLOAD=PASS"
phase_end DOWNLOAD
say

STAGE="AUTO_EXEC"
phase_begin AUTO_EXEC
say "=== WAIT NATURAL CARSON AUTO-EXECUTION ==="

wait_native_result(){
    local timeout_ms="$1" start now elapsed bucket last=-1
    start="$(now_ms)"
    while :; do
        if [[ -f "$NEXT_BASE" ]] &&
           grep -q '^EXECUTION_RC=0$' "$NEXT_BASE" 2>/dev/null &&
           grep -Fq "$TEST_MARKER" "$NEXT_BASE" 2>/dev/null; then
            return 0
        fi
        now="$(now_ms)"
        elapsed=$((now-start))
        (( elapsed < timeout_ms )) || return 1
        bucket=$((elapsed/2000))
        if (( bucket != last )); then
            say "AUTO_EXEC_WAIT=WAITING elapsed_ms=$elapsed"
            last=$bucket
        fi
        nap_ms 250
    done
}

wait_native_transcript(){
    local timeout_ms="$1" start now elapsed bucket last=-1
    start="$(now_ms)"
    while :; do
        if [[ -f "$TRANSCRIPT_A" ]] &&
           grep -Fq "$TEST_MARKER" "$TRANSCRIPT_A" 2>/dev/null &&
           grep -Fq 'Exit status: 0' "$TRANSCRIPT_A" 2>/dev/null; then
            return 0
        fi
        now="$(now_ms)"
        elapsed=$((now-start))
        (( elapsed < timeout_ms )) || return 1
        bucket=$((elapsed/2000))
        if (( bucket != last )); then
            say "TRANSCRIPT_WAIT=WAITING elapsed_ms=$elapsed"
            last=$bucket
        fi
        nap_ms 250
    done
}

wait_native_result "$AUTO_EXEC_TIMEOUT_MS" ||
    fail 130 "natural auto-execution result with unique V12 marker did not arrive" \
      "NO_MANUAL_SUBMIT_NO_CURSOR_RECONSTRUCTION"
say "CARSON_AUTO_EXECUTION=PASS"

wait_native_transcript 30000 ||
    fail 131 "native Turn19 transcript with unique V12 marker did not arrive"
say "NATIVE_TURN19_TRANSCRIPT=PASS"
say "TRANSCRIPT_SHA256=$(sha256sum "$TRANSCRIPT_A"|awk '{print $1}')"
phase_end AUTO_EXEC
say

enter_bound_chat(){
    bridge_capture 12 open "$CLAUDE_PKG";bridge_ok||return 1
    wait_package 20000 "$CLAUDE_PKG"||return 2
    local i snap add bound menu code
    for i in 1 2 3 4 5 6;do
        snap="$TMPBASE/return-$i.txt";snapshot "$snap"||return 3
        add="$(decoded_exact_count "$snap" "Add to chat")"
        bound="$(decoded_exact_count "$snap" "$BOUND_TITLE")"
        menu="$(decoded_exact_count "$snap" "Open menu")"
        code="$(decoded_exact_count "$snap" "Code · SH")"
        say "RETURN_STATE[$i]=ADD:$add BOUND:$bound MENU:$menu CODE:$code"
        if (( bound==1 ));then
            click_exact "$BOUND_TITLE"||return 4
            wait_exact 15000 "Add to chat"||return 5
            return 0
        fi
        if (( add==1 && code>=1 ));then
            say "BOUND_RETURN=ALREADY_IN_TASK_CHAT"
            return 0
        fi
        if (( menu==1 ));then
            click_exact "Open menu"||return 6
            wait_exact 10000 "$BOUND_TITLE"||true
            snap="$TMPBASE/return-drawer-$i.txt";snapshot "$snap"||return 7
            if (( $(decoded_exact_count "$snap" "$BOUND_TITLE")==1 ));then
                click_exact "$BOUND_TITLE"||return 8
                wait_exact 15000 "Add to chat"||return 9
                return 0
            fi
            if (( $(decoded_exact_count "$snap" "Chats")==1 ));then
                click_exact "Chats"||return 10
                snap="$TMPBASE/return-chats-$i.txt";snapshot "$snap"||return 11
                [[ "$(decoded_edit "$snap"|sed -n 's/^COUNT=//p')" == 1 ]]||return 12
                q="$TMPBASE/return-query.txt";printf '%s' "$ROUTE_HEX">"$q"
                bridge_capture 15 set-text-file "$q";bridge_ok||return 13
                wait_exact 15000 "$BOUND_TITLE"||return 14
                click_exact "$BOUND_TITLE"||return 15
                wait_exact 15000 "Add to chat"||return 16
                return 0
            fi
        fi
        bridge_capture 8 back
        say "RETURN_BACK[$i]=$(bridge_show)"
        nap_ms 250
    done
    return 17
}

STAGE="ATTACH"
phase_begin ATTACH_CONTINUE
say "=== RESUME BOUND CHAT / ATTACH AUTHORITATIVE A TRANSCRIPT ==="
enter_bound_chat||fail 140 "could not resume bound chat"
click_exact "Add to chat"||fail 141 "Add to chat unresolved"
wait_exact 10000 "Files"||fail 142 "Files option absent"
click_exact "Files"||fail 143 "Files option click failed"
wait_package 20000 "$DOCS_PKG"||fail 144 "DocumentsUI did not foreground"

DOC="$TMPBASE/docs.txt";snapshot "$DOC"||fail 145 "DocumentsUI snapshot failed"
if (( $(decoded_exact_count "$DOC" "$TRANSCRIPT_NAME")==1 ));then
    say "DOC_ROUTE=TRANSCRIPT_ALREADY_VISIBLE"
else
    ROOT_LABEL="$(breadcrumb_root_label "$DOC" 2>/dev/null||true)"
    say "DERIVED_DEVICE_ROOT_LABEL=${ROOT_LABEL:-UNRESOLVED}"
    [[ -n "$ROOT_LABEL" ]]||fail 146 "device root breadcrumb unresolved"
    click_exact "Show roots"||fail 147 "Show roots failed"
    nap_ms 250
    click_bottom "$ROOT_LABEL"||fail 148 "device root row click failed"
    wait_exact 12000 "carson-agent"||fail 149 "carson-agent missing at device root"
    click_bottom "carson-agent"||fail 150 "carson-agent row click failed"
    wait_exact 12000 "a"||fail 151 "a missing under carson-agent"
    click_bottom "a"||fail 152 "a row click failed"

    if ! wait_exact 7000 "$TRANSCRIPT_NAME";then
        say "A_DIRECTORY_INITIAL_REFRESH=MISS"
        A_STATE="$TMPBASE/a-stale.txt";snapshot "$A_STATE"||fail 153 "stale A snapshot failed"
        if (( $(decoded_exact_count "$A_STATE" "carson-agent")>=1 ));then
            click_top "carson-agent"||fail 154 "breadcrumb parent click failed"
            wait_exact 10000 "a"||fail 155 "a absent after parent navigation"
            click_bottom "a"||fail 156 "a re-entry failed"
        else
            bridge_capture 8 back
            say "A_REFRESH_BACK=$(bridge_show)"
            wait_exact 10000 "a"||fail 157 "a absent after Back"
            click_bottom "a"||fail 158 "a re-entry after Back failed"
        fi
        wait_exact 15000 "$TRANSCRIPT_NAME"||fail 159 "transcript absent after A refresh"
    fi
fi

click_exact "$TRANSCRIPT_NAME"||fail 160 "transcript selection failed"
wait_package 25000 "$CLAUDE_PKG"||fail 161 "Claude did not resume after attachment"
wait_exact 15000 "Remove"||fail 162 "transcript not staged"
say "A_DIRECTORY_ATTACHMENT=PASS"
say

STAGE="CONTINUATION"
say "=== SEND CONTINUATION EXACTLY ONCE ==="
READY="$TMPBASE/ready.txt";snapshot "$READY"||fail 170 "ready snapshot failed"
EDIT="$(decoded_edit "$READY")"
[[ "$(printf '%s\n' "$EDIT"|sed -n 's/^COUNT=//p')" == 1 ]]||fail 171 "composer not unique"
TEXT="$(printf '%s\n' "$EDIT"|sed -n 's/^TEXT=//p')"
[[ -z "$TEXT" || "$TEXT" == "$CONTINUATION_MESSAGE" ]]||fail 172 "unexpected composer text"

if [[ "$TEXT" != "$CONTINUATION_MESSAGE" ]];then
    F="$TMPBASE/continuation.txt"
    printf '%s' "$CONTINUATION_MESSAGE">"$F"
    set_text_exact_retry "$F" "CONTINUATION" >/dev/null ||
        fail 173 "continuation could not be set and exactly verified after bounded retries" "DO_NOT_SEND;RETURN_THIS_OUTPUT"
fi
VERIFY="$TMPBASE/verify.txt"
snapshot_retry "$VERIFY" "CONTINUATION_FINAL_VERIFY_SNAPSHOT" ||
    fail 174 "continuation verify snapshot unavailable" "DO_NOT_SEND;RETURN_THIS_OUTPUT"
[[ "$(decoded_edit "$VERIFY"|sed -n 's/^TEXT=//p')" == "$CONTINUATION_MESSAGE" ]] ||
    fail 175 "continuation exact verification failed"
click_exact "Send"||fail 176 "continuation Send failed"
say "CONTINUATION_SEND_TAP_COUNT=1"
POST="$TMPBASE/post-cont.txt";nap_ms 350;snapshot "$POST"||fail 177 "post-send snapshot failed" "DO_NOT_RESEND"
[[ -z "$(decoded_edit "$POST"|sed -n 's/^TEXT=//p')" ]]||fail 178 "composer not empty after send" "DO_NOT_RESEND"
say "CONTINUATION_SEND_CONSUMED=PASS"
phase_end ATTACH_CONTINUE
say

STAGE="TASK_COMPLETE"
phase_begin TASK_COMPLETE_WAIT
say "=== EVENT-DRIVEN TASK_COMPLETE WAIT ==="
if ! wait_regex "$FINAL_TIMEOUT_MS" '^TASK_COMPLETE:';then
    fail 180 "anchored TASK_COMPLETE response did not arrive before timeout" "DO_NOT_RESEND"
fi

FINAL="$TMPBASE/final.txt";snapshot "$FINAL"||fail 181 "TASK_COMPLETE verification snapshot failed"
if [[ "$(verified_task_complete "$FINAL" "$TEST_MARKER")" != YES ]];then
    # Accessibility virtualization can swap nodes immediately after the event.
    # Give it one bounded second event wait/snapshot, but do not keep polling.
    nap_ms 300
    snapshot "$FINAL"||fail 182 "second TASK_COMPLETE verification snapshot failed"
fi
[[ "$(verified_task_complete "$FINAL" "$TEST_MARKER")" == YES ]]||
    fail 183 "TASK_COMPLETE event appeared but response did not contain the V12 marker"

say
phase_end TASK_COMPLETE_WAIT
TOTAL_NOW_MS="$(now_ms)"
say "TIMING_TOTAL_E2E_MS=$((TOTAL_NOW_MS-SCRIPT_START_MS))"
say
say "=== FINAL FRESH END-TO-END ACCEPTANCE ==="
say "SINGLE_SCRIPT_FRESH_END_TO_END=PASS"
say "UNIQUE_MARKER_AUTOEXEC_WAIT=PASS"
say "STARTUP_RECOVERY_WITHOUT_MANUAL_APP_CLOSING=PASS"
say "ONE_TAP_DOWNLOAD_WITH_LONG_WAIT=PASS"
say "STARTUP_RECOVERY_WITHOUT_MANUAL_APP_CLOSING=PASS"
say "ONE_TAP_DOWNLOAD_WITH_LONG_WAIT=PASS"
say "FRESH_CARSON_PROMPT_ARMING=PASS"
say "FRESH_CLAUDE_CHAT=PASS"
say "PERSISTED_DRAFT_NORMALIZATION=PASS"
say "BODY_ONLY_INITIAL_SEND=PASS"
say "DETERMINISTIC_CHAT_BINDING=PASS"
say "FIRST_ARTIFACT_DOWNLOAD=PASS"
say "NATURAL_CARSON_AUTO_EXECUTION=PASS"
say "NATIVE_TURN19_TRANSCRIPT=PASS"
say "DETERMINISTIC_BOUND_CHAT_RESUME=PASS"
say "A_DIRECTORY_ATTACHMENT=PASS"
say "CONTINUATION_SEND=PASS"
say "TASK_COMPLETE=PASS"
say "TASK_COMPLETE_STOP_BEHAVIOR=IMMEDIATE_AFTER_VERIFIED_EVENT"
say "ADB_USED=NO"
say "WIRELESS_DEBUGGING_REQUIRED=NO"
say "WIFI_REQUIRED=NO"
say "LTE_CAPABLE_CONTROL_PLANE=PASS"
say "CURSOR_RECONSTRUCTION=NO"
say "GITHUB_MUTATION=NONE"
say "STATUS=COMPLETE"
exit 0
