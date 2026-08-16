#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
umask 077

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_SRC="$SELF_DIR/ui/carson-ui"
PROMPT_SRC="$SELF_DIR/runtime/carson-prompt"
LISTENER_SRC="$SELF_DIR/runtime/listener.sh"
UI_WORK="$HOME/.carson_ui_lte_poc"
CLIENT_DST="$UI_WORK/carson-ui"
TOKEN_FILE="$UI_WORK/control-token.txt"
TOKEN_PLACEHOLDER="__CARSON_UI_DEVICE_TOKEN__"

say(){ printf '%s\n' "$*"; }
die(){ say "STATUS=FAIL"; say "ERROR=$*"; exit 1; }
sha(){ sha256sum "$1"|awk '{print $1}'; }

for c in bash tmux sha256sum; do command -v "$c" >/dev/null 2>&1 || die "$c missing"; done

REG="$HOME/.carson_agent_instances/.registry"
[[ -d "$REG" ]] || die "registry missing"
tmp="${TMPDIR:-$HOME/.cache}/clone-bootstrap-$$.tsv"
: > "$tmp"

for idx in "$REG"/*.env; do
  [[ -f "$idx" ]] || continue
  st="$(bash -c 'source "$1" 2>/dev/null;printf "%s" "${CARSON_STATE_ROOT:-}"' _ "$idx" 2>/dev/null || true)"
  [[ -n "$st" && -f "$st/instance.env" && -f "$st/active-session.env" ]] || continue
  row="$(
    bash -c '
      source "$1";source "$2"
      printf "%s\t%s\t%s" "${CARSON_INSTANCE_ID:-}" "${CARSON_TMUX_SESSION:-}" "${CARSON_SOURCE_ROOT:-}"
    ' _ "$st/instance.env" "$st/active-session.env" 2>/dev/null || true
  )"
  tm="$(printf '%s' "$row"|cut -f2)"
  live=0
  [[ -n "$tm" ]] && tmux has-session -t "$tm" 2>/dev/null && live=1
  printf '%s\t%s\t%s\n' "$live" "$(stat -c '%Y' "$st/active-session.env" 2>/dev/null||echo 0)" "$row" >> "$tmp"
done

sel="$(sort -t $'\t' -k1,1nr -k2,2nr "$tmp"|head -n1)"
[[ "$(printf '%s' "$sel"|cut -f1)" == 1 ]] || die "no live instance"
INSTANCE_ID="$(printf '%s' "$sel"|cut -f3)"
SOURCE_ROOT="$(printf '%s' "$sel"|cut -f5)"
AGENT="$SOURCE_ROOT/bin/carson-agent"
PROMPT_DST="$SOURCE_ROOT/bin/carson-prompt"
LISTENER_DST="$SOURCE_ROOT/lib/listener.sh"

[[ -x "$AGENT" ]] || die "carson-agent missing"
mkdir -p "$SOURCE_ROOT/local-clone-backups" "$UI_WORK"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="$SOURCE_ROOT/local-clone-backups/$stamp"
mkdir -p "$backup"
cp -f "$PROMPT_DST" "$backup/carson-prompt.before" 2>/dev/null || true
cp -f "$LISTENER_DST" "$backup/listener.sh.before" 2>/dev/null || true
cp -f "$CLIENT_DST" "$backup/carson-ui.before" 2>/dev/null || true

cp -f "$PROMPT_SRC" "$PROMPT_DST"
cp -f "$LISTENER_SRC" "$LISTENER_DST"

[[ -s "$TOKEN_FILE" ]] || die "device-local control token missing"

if grep -Fq "$TOKEN_PLACEHOLDER" "$CLIENT_SRC"; then
  say "CLONE_UI_CLIENT_MODE=RENDER_TEMPLATE"
  python - "$CLIENT_SRC" "$CLIENT_DST" "$TOKEN_FILE" "$TOKEN_PLACEHOLDER" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1])
dst=Path(sys.argv[2])
token=Path(sys.argv[3]).read_text(encoding="utf-8").strip()
placeholder=sys.argv[4]
data=src.read_text(encoding="utf-8")
if placeholder not in data:
    raise SystemExit("client token placeholder missing")
if not token:
    raise SystemExit("device token empty")
dst.write_text(data.replace(placeholder,token),encoding="utf-8")
PY
  expected="${TMPDIR:-$HOME/.cache}/carson-ui-rendered-$$"
  cp -f "$CLIENT_DST" "$expected"
else
  say "CLONE_UI_CLIENT_MODE=EXACT_COMMITTED_CLIENT"
  cp -f "$CLIENT_SRC" "$CLIENT_DST"
  expected="$CLIENT_SRC"
fi

chmod 755 "$PROMPT_DST" "$LISTENER_DST" "$CLIENT_DST"

[[ "$(sha "$PROMPT_SRC")" == "$(sha "$PROMPT_DST")" ]] || die "prompt clone/install hash mismatch"
[[ "$(sha "$LISTENER_SRC")" == "$(sha "$LISTENER_DST")" ]] || die "listener clone/install hash mismatch"
[[ "$(sha "$expected")" == "$(sha "$CLIENT_DST")" ]] || die "UI client clone/install parity mismatch"

if [[ "$expected" != "$CLIENT_SRC" ]]; then rm -f "$expected"; fi

set +e
restart="$("$AGENT" restart "$INSTANCE_ID" 2>&1)"
rc=$?
set -e
printf '%s\n' "$restart" | sed 's/^/RESTART: /'
(( rc==0 )) || die "listener restart failed"

state="$(timeout 8 bash "$CLIENT_DST" state 2>&1 || true)"
say "ACCESSIBILITY_STATE=$(printf '%s' "$state"|tr '\t' ' ')"
[[ "$state" == OK$'\t'STATE* && "$state" == *$'\tBUILD=5\t'* ]] ||
  die "BUILD=5 accessibility bridge is not active"

say "CLONE_RUNTIME_PROMPT_SHA256=$(sha "$PROMPT_SRC")"
say "CLONE_RUNTIME_LISTENER_SHA256=$(sha "$LISTENER_SRC")"
say "CLONE_UI_CLIENT_COMMITTED_SHA256=$(sha "$CLIENT_SRC")"
say "CLONE_UI_CLIENT_INSTALLED_SHA256=$(sha "$CLIENT_DST")"
say "SOURCE_CONTROL_DEVIATION=NONE"
say "STATUS=COMPLETE"
