#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

fail() {
  printf 'VALIDATION_FAIL=%s\n' "$*" >&2
  exit 1
}

TMP_BASE="${TMPDIR:-${PREFIX:+$PREFIX/tmp}}"
TMP_BASE="${TMP_BASE:-$HOME/.cache/carson-agent-validator}"
mkdir -p "$TMP_BASE"
TMP_SECRET="$(mktemp "$TMP_BASE/carson-secret.XXXXXX")"
TMP_IDS="$(mktemp "$TMP_BASE/carson-ids.XXXXXX")"
TMP_PATHS="$(mktemp "$TMP_BASE/carson-paths.XXXXXX")"
TMP_STORAGE="$(mktemp "$TMP_BASE/carson-storage.XXXXXX")"
trap 'rm -f "$TMP_SECRET" "$TMP_IDS" "$TMP_PATHS" "$TMP_STORAGE"' EXIT

printf '%s\n' "VALIDATION_BEGIN"

required=(
  README.md
  install.sh
  quick-install.sh
  validate.sh
  bin/carson-agent
  bin/carson-chat-bootstrap
  bin/carson-ingest
  bin/carson-submit
  lib/common.sh
  lib/listener.sh
  docs/INSTALLATION.md
  docs/INSTANCE_MODEL.md
  docs/ROUTING.md
  docs/SELF_PUBLISH.md
  docs/ARBITRARY_LLM_CHAT.md
  docs/LLM_DOWNLOADABLE_SCRIPT_NOTE.md
  docs/ABC_STORAGE.md
  examples/example.env
  .gitignore
)

for f in "${required[@]}"; do
  [[ -f "$f" ]] || fail "missing required file: $f"
done

bash -n install.sh
bash -n validate.sh
bash -n bin/carson-agent
bash -n bin/carson-chat-bootstrap
bash -n bin/carson-ingest
bash -n bin/carson-submit
bash -n quick-install.sh
bash -n lib/common.sh
bash -n lib/listener.sh

for pattern in \
  'processed_sha256.tsv' \
  'events.log' \
  'active-session.env' \
  'instance.env' \
  'NEXT_LLM_MESSAGE.txt' \
  'PREEXISTING_SENTINEL.txt'
do
  if find . -type f -not -path './.git/*' -name "$pattern" -print -quit | grep -q .; then
    fail "runtime file present: $pattern"
  fi
done

if grep -R -n -E \
  --exclude-dir=.git \
  --exclude=validate.sh \
  '(GITHUB_TOKEN|GH_TOKEN|GITHUB_PAT|ACCESS_TOKEN|PRIVATE_KEY|PASSWORD)[[:space:]]*=[[:space:]]*[^<"$][^[:space:]]+' \
  . >"$TMP_SECRET" 2>/dev/null
then
  cat "$TMP_SECRET" >&2
  fail "possible literal credential assignment"
fi

if grep -R -n -E \
  --exclude-dir=.git \
  --exclude=validate.sh \
  'CARSON_(PORTABLE_DEV|INSTANCE|SESSION)_[0-9]{8,}' \
  . >"$TMP_IDS" 2>/dev/null
then
  cat "$TMP_IDS" >&2
  fail "runtime identity embedded in source"
fi

if grep -R -n -F \
  --exclude-dir=.git \
  --exclude=validate.sh \
  '/data/data/com.termux/files/home/' \
  . >"$TMP_PATHS" 2>/dev/null
then
  cat "$TMP_PATHS" >&2
  fail "device-specific Termux home path embedded"
fi

if grep -R -n -E \
  --exclude-dir=.git \
  --exclude=validate.sh \
  '/storage/emulated/[0-9]+/' \
  . >"$TMP_STORAGE" 2>/dev/null
then
  cat "$TMP_STORAGE" >&2
  fail "device-specific Android shared-storage path embedded"
fi

grep -Fq 'CARSON_DOWNLOAD_DIR' install.sh ||
  fail "installer missing CARSON_DOWNLOAD_DIR"
grep -Fq 'CARSON_A_DIR' install.sh ||
  fail "installer missing CARSON_A_DIR"
grep -Fq 'CARSON_B_DIR' install.sh ||
  fail "installer missing CARSON_B_DIR"

grep -Fq 'quick-install.sh' install.sh ||
  fail "installer does not package quick-install.sh"
grep -Fq 'validate.sh' install.sh ||
  fail "installer does not package validate.sh"
grep -Fq '.github' install.sh ||
  fail "installer does not package GitHub metadata"

grep -Fq '# CARSON_INSTANCE_ID=' lib/listener.sh ||
  fail "listener missing instance metadata gate"
grep -Fq '# CARSON_SESSION_ID=' lib/listener.sh ||
  fail "listener missing session metadata gate"

if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
  git diff --check
  git diff --cached --check
fi

printf '%s\n' "VALIDATION_STATUS=PASS"

# Direct-prompt adapter regression checks.
[[ -x bin/carson-prompt ]] || {
  printf 'VALIDATION_FAIL=bin/carson-prompt missing or not executable\n' >&2
  exit 1
}
bash -n bin/carson-prompt || {
  printf 'VALIDATION_FAIL=bin/carson-prompt syntax\n' >&2
  exit 1
}
[[ -f docs/ARBITRARY_CHAT_PROMPT_ADAPTER.md ]] || {
  printf 'VALIDATION_FAIL=direct prompt adapter documentation missing\n' >&2
  exit 1
}

# Global carson-prompt portability checks.
grep -Fq '# GLOBAL_CARSON_PROMPT_INSTALL' quick-install.sh || {
  printf 'VALIDATION_FAIL=quick-install global carson-prompt step missing\n' >&2
  exit 1
}
grep -Fq 'install -m 755 "$ROOT/bin/carson-prompt" "$PREFIX/bin/carson-prompt"' quick-install.sh || {
  printf 'VALIDATION_FAIL=quick-install does not install carson-prompt into PREFIX/bin\n' >&2
  exit 1
}


# AUTO_PLAIN_INGEST_CONTRACT_V1
grep -Fq '# CARSON_AUTO_INGEST_ARM_V1' bin/carson-prompt || {
  printf 'VALIDATION_FAIL=carson-prompt auto-ingest arming missing\n' >&2
  exit 1
}
grep -Fq '# CARSON_AUTO_PLAIN_INGEST_V1' lib/listener.sh || {
  printf 'VALIDATION_FAIL=listener plain-script ingestion missing\n' >&2
  exit 1
}
grep -Fq '"$ingest" "$CARSON_INSTANCE_ID" "$source_file"' lib/listener.sh || {
  printf 'VALIDATION_FAIL=listener does not route plain scripts through carson-ingest\n' >&2
  exit 1
}
grep -Fq "! -name 'CARSON_AGENT_*'" lib/listener.sh || {
  printf 'VALIDATION_FAIL=auto-ingest does not exclude routed CARSON tasks\n' >&2
  exit 1
}


# LLM_FACING_TRANSCRIPT_CONTRACT_V1
grep -Fq '# CARSON_LLM_TRANSCRIPT_CONTRACT_V1' bin/carson-prompt || {
  printf 'VALIDATION_FAIL=initial transcript continuation contract missing\n' >&2
  exit 1
}
grep -Fq '# CARSON_LLM_FACING_TRANSCRIPT_V1' lib/listener.sh || {
  printf 'VALIDATION_FAIL=LLM-facing transcript publisher missing\n' >&2
  exit 1
}
grep -Fq 'LLM_EXECUTION_TRANSCRIPT.txt' lib/listener.sh || {
  printf 'VALIDATION_FAIL=stable LLM transcript filename missing\n' >&2
  exit 1
}
grep -Fq 'publish_llm_execution_transcript "$file"' lib/listener.sh || {
  printf 'VALIDATION_FAIL=transcript publisher not connected to execution path\n' >&2
  exit 1
}
