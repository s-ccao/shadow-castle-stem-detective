#!/bin/sh
# Condition C -- frozen one-shot inference transport.
#
#   condition_c_claude_invoke.sh <system-prompt-file> <user-prompt-file> <model>
#
# Runs ONE isolated, non-interactive Claude Code process and prints its
# machine-readable JSON result on stdout. One process per scenario; nothing is
# carried between invocations.
#
# The exact invocation lives here rather than inside the GDScript client so that
# the isolation flags are a single reviewable, hashable artifact. If this file
# changes, the freeze manifest changes with it.
#
# WHY EACH ISOLATION FLAG IS PRESENT (all verified against `claude --help`,
# version 2.1.258; `--bare` is deliberately NOT used because its own help text
# states that under it "Anthropic auth is strictly ANTHROPIC_API_KEY or
# apiKeyHelper", which is the billing path this experiment forbids):
#
#   --print                     one shot, non-interactive, then exit
#   --model <model>             explicit model identity, never an alias
#   --output-format json        machine-readable result envelope
#   --no-session-persistence    no transcript on disk, nothing resumable
#   --tools ""                  no Bash, no Read, no file or shell capability
#   --strict-mcp-config         only MCP servers from --mcp-config; none given
#   --safe-mode                 CLAUDE.md, skills, plugins, hooks, agents off
#   --restricted                ignores user/project/local settings files
#   --setting-sources ""        loads no setting source at all
#   --disable-slash-commands    no skills reachable by name
#
# NOTE ON FLAG VERIFICATION: at the root command this CLI silently tolerates
# unknown options (`claude --not-a-real-flag --version` exits 0). Flag spelling
# therefore cannot be validated by exit status, and every flag above was taken
# verbatim from `--help`. Isolation is proven behaviourally by the canary suite
# (tests/condition_c_isolation_canary.sh), not by the CLI accepting these words.
#
# ENVIRONMENT: the child is started with `env -i` and receives only what the
# company broker needs to authenticate. It inherits no repository path, no
# scenario identity, no git metadata and no agent-session variables.
#
# EXIT CODES
#   0  the CLI ran; its JSON envelope is on stdout
#   3  SUBSCRIPTION_TRANSPORT_UNAVAILABLE  (no broker credential)
#   4  DIRECT_API_REFUSED                  (would have talked to Anthropic direct)
#   5  CLAUDE_CLI_NOT_FOUND
#   6  CLAUDE_CLI_FAILED                   (non-zero exit from the CLI)
#   7  CONDITION_C_TIMEOUT

set -eu

SYS_FILE="${1:?usage: condition_c_claude_invoke.sh <system-file> <user-file> <model>}"
USR_FILE="${2:?missing user prompt file}"
MODEL="${3:?missing model identifier}"
TIMEOUT_SECONDS="${CONDITION_C_TIMEOUT_SECONDS:-120}"

# --- Billing safety gates -------------------------------------------------
#
# The broker credential is required. Its ABSENCE must fail closed: there is no
# path in this script that reaches Anthropic directly, and none may be added.

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
	echo "SUBSCRIPTION_TRANSPORT_UNAVAILABLE: no company broker credential present" >&2
	exit 3
fi

if [ -z "${ANTHROPIC_BASE_URL:-}" ]; then
	echo "DIRECT_API_REFUSED: ANTHROPIC_BASE_URL is unset, so the credential would" \
		"be sent to the default Anthropic endpoint instead of the company broker" >&2
	exit 4
fi

BASE_HOST=$(printf '%s' "$ANTHROPIC_BASE_URL" | sed -e 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##' -e 's#/.*$##' -e 's#:.*$##')
if [ "$BASE_HOST" = "api.anthropic.com" ]; then
	echo "DIRECT_API_REFUSED: ANTHROPIC_BASE_URL points at api.anthropic.com;" \
		"Condition C must route through the company broker only" >&2
	exit 4
fi

# ANTHROPIC_API_KEY is never forwarded. `env -i` below is what guarantees it,
# not this comment: the child's environment is built from nothing.

# --- Locate the CLI -------------------------------------------------------

CLAUDE_BIN="${CONDITION_C_CLAUDE_BIN:-${CLAUDE_CODE_EXECPATH:-}}"
if [ -z "$CLAUDE_BIN" ]; then
	CLAUDE_BIN=$(command -v claude 2>/dev/null || true)
fi
if [ -z "$CLAUDE_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
	echo "CLAUDE_CLI_NOT_FOUND: set CONDITION_C_CLAUDE_BIN or CLAUDE_CODE_EXECPATH" >&2
	exit 5
fi

# --- Clean room -----------------------------------------------------------
#
# A fresh working directory holding no repository material, and a fresh HOME so
# that no user-level CLAUDE.md, settings file or plugin is discoverable even if
# a future CLI version changed what --safe-mode covers.

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/condition-c-XXXXXX")
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT INT TERM
mkdir -p "$SANDBOX/home" "$SANDBOX/work" "$SANDBOX/tmp"

SYSTEM_PROMPT=$(cat "$SYS_FILE")

cd "$SANDBOX/work"

env -i \
	PATH=/usr/bin:/bin \
	HOME="$SANDBOX/home" \
	TMPDIR="$SANDBOX/tmp" \
	ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN" \
	ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
	CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
	"$CLAUDE_BIN" \
		--print \
		--model "$MODEL" \
		--output-format json \
		--no-session-persistence \
		--tools "" \
		--strict-mcp-config \
		--safe-mode \
		--restricted \
		--setting-sources "" \
		--disable-slash-commands \
		--system-prompt "$SYSTEM_PROMPT" \
		< "$USR_FILE" &
CLI_PID=$!

# macOS ships no coreutils `timeout`, so the watchdog is explicit. It runs in
# this shell, not in the sanitized child.
#
# Its output MUST go to /dev/null. A background subshell inherits stdout, and a
# caller that reads this script's stdout to end-of-file would then block for the
# whole timeout even after the CLI had already answered -- the watchdog would be
# holding the pipe open. Killing the subshell below is not enough on its own,
# because `sleep` is its child and survives it; orphaned with no stdout it
# simply expires, and the `kill` it would have run never executes, so there is
# no stale PID to mis-target either.
( sleep "$TIMEOUT_SECONDS"; kill -TERM "$CLI_PID" 2>/dev/null || true ) >/dev/null 2>&1 &
WATCHDOG_PID=$!

STATUS=0
wait "$CLI_PID" || STATUS=$?
kill -TERM "$WATCHDOG_PID" 2>/dev/null || true

if [ "$STATUS" -eq 143 ] || [ "$STATUS" -eq 15 ]; then
	echo "CONDITION_C_TIMEOUT: no reply within ${TIMEOUT_SECONDS}s" >&2
	exit 7
fi
if [ "$STATUS" -ne 0 ]; then
	echo "CLAUDE_CLI_FAILED: exit $STATUS" >&2
	exit 6
fi
exit 0
