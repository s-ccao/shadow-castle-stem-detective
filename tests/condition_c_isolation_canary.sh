#!/bin/bash
# Condition C -- live isolation canary.
#
#   tests/condition_c_isolation_canary.sh
#
# Proves BEHAVIOURALLY that the frozen Condition C invocation cannot see
# anything except the prompt it was handed. This is the test the wrapper's
# header points at, and it exists because flag acceptance proves nothing here:
# at its root command this CLI silently tolerates unknown options
# (`claude --not-a-real-flag --version` exits 0), so `--tools ""` being accepted
# is not evidence that tools are off. Only asking the model what it can see is.
#
# WHAT THIS COSTS: two live one-shot calls against the company broker. It is not
# part of the offline battery; `tests/condition_c_transport_test.gd` covers the
# structural and fail-closed claims with no network at all.
#
# NO REAL SECRET IS USED. Every canary is a random token minted by this script.
# No heldout-v3 value, no annotation, no A/B output and no repository content is
# planted anywhere, so a leak here cannot disclose benchmark material.
#
# THE TEST IS HARDER THAN PRODUCTION. In production the child's working
# directory and HOME are freshly made and empty, so there is nothing to find.
# Here they are deliberately stuffed with a repository-like file, a project
# CLAUDE.md, a user-level CLAUDE.md, an MCP config and a settings file -- all
# exactly where the CLI would look for them. Isolation has to hold against bait.
#
# AND IT REFUSES TO BE VACUOUS, twice over:
#   * a control canary is planted INSIDE the prompt and must come back. If the
#     model answers without it, the run proves only that the model said little.
#   * a negative control repeats the run with the isolation removed and must
#     LEAK. If the bait is undiscoverable even then, the fixtures are wrong and
#     the main result is worthless -- so that outcome fails the suite.
#
# EXIT: 0 all checks passed; 1 a check failed; 2 the transport was unavailable.

set -uo pipefail

WRAPPER="$(cd "$(dirname "$0")/.." && pwd)/tools/condition_c_claude_invoke.sh"
FAILURES=()

fail() { FAILURES+=("$1"); }
ok()   { printf '  ok    %s\n' "$1"; }
check() { if [ "$2" = "yes" ]; then ok "$1"; else fail "$1"; printf '  FAIL  %s\n' "$1"; fi; }

# --- The invocation under test -------------------------------------------
#
# Kept here as a list so the canary can run it against a PLANTED sandbox, which
# the wrapper deliberately will not do -- the wrapper builds its own empty room
# and offers no override, because a test-only escape hatch in a security
# artifact is a hole someone eventually walks through. The cost of that choice
# is this duplicated list, and the drift guard below is what pays it.

ISOLATION_FLAGS=(
	--print
	--output-format json
	--no-session-persistence
	--tools ""
	--strict-mcp-config
	--safe-mode
	--restricted
	--setting-sources ""
	--disable-slash-commands
)

# --- Drift guard ----------------------------------------------------------
#
# If the wrapper gains or loses an isolation flag, this canary silently stops
# testing the shipped invocation. Compare the two lists as SETS so that both an
# addition and a removal are caught, and fail loudly on either.

wrapper_flags() {
	sed -n '/^env -i/,/< "\$USR_FILE"/p' "$WRAPPER" \
		| grep -oE '^[[:space:]]+--[a-z-]+' | tr -d '\t ' | sort -u
}
canary_flags() {
	printf '%s\n' "${ISOLATION_FLAGS[@]}" | grep '^--' | sort -u
}

echo "Condition C — live isolation canary"
echo

if [ ! -x "$WRAPPER" ]; then
	echo "  FAIL  the frozen wrapper is missing or not executable: $WRAPPER"
	exit 1
fi

# --model and --system-prompt are in the wrapper but carry values rather than
# isolation, and are supplied separately below; exclude them from the compare.
DRIFT=$(diff <(wrapper_flags | grep -vE '^--(model|system-prompt)$') <(canary_flags) || true)
if [ -n "$DRIFT" ]; then
	echo "  FAIL  this canary no longer tests the shipped invocation:"
	printf '%s\n' "$DRIFT" | sed 's/^/        /'
	exit 1
fi
ok "the canary's flag list still matches the frozen wrapper"

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ] || [ -z "${ANTHROPIC_BASE_URL:-}" ]; then
	echo "  SKIP  no company broker credential in the environment"
	echo "        (this is the live half of the suite; the offline half is"
	echo "         tests/condition_c_transport_test.gd)"
	exit 2
fi

CLAUDE_BIN="${CONDITION_C_CLAUDE_BIN:-${CLAUDE_CODE_EXECPATH:-$(command -v claude || true)}}"
if [ -z "$CLAUDE_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
	echo "  FAIL  no Claude Code binary found"
	exit 1
fi

# --- Mint canaries --------------------------------------------------------
#
# Fresh random tokens every run. A stale answer, a cached response or a
# hard-coded expectation cannot fake these.

tok() { openssl rand -hex 8; }
C_PROMPT="CANARY-PROMPT-$(tok)"
C_REPOFILE="CANARY-REPOFILE-$(tok)"
C_CLAUDEMD="CANARY-CLAUDEMD-$(tok)"
C_HOMEMD="CANARY-HOMEMD-$(tok)"
C_MCPCONF="CANARY-MCPCONF-$(tok)"
C_SETTINGS="CANARY-SETTINGS-$(tok)"

HIDDEN=("$C_REPOFILE" "$C_CLAUDEMD" "$C_HOMEMD" "$C_MCPCONF" "$C_SETTINGS")

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/condition-c-canary-XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT INT TERM
mkdir -p "$SANDBOX/home/.claude" "$SANDBOX/work/src" "$SANDBOX/tmp"

# Bait, planted exactly where the CLI looks.
printf 'internal note: %s\n' "$C_REPOFILE" > "$SANDBOX/work/src/internal_notes.txt"
printf '# Project instructions\n\nProject token: %s\n' "$C_CLAUDEMD" > "$SANDBOX/work/CLAUDE.md"
printf '# User instructions\n\nUser token: %s\n' "$C_HOMEMD" > "$SANDBOX/home/.claude/CLAUDE.md"
cat > "$SANDBOX/work/.mcp.json" <<JSON
{"mcpServers": {"memo": {"command": "/bin/sh",
  "args": ["-c", "echo $C_MCPCONF; sleep 30"]}}}
JSON
printf '{"env": {"CANARY_SETTING": "%s"}}\n' "$C_SETTINGS" > "$SANDBOX/home/.claude/settings.json"

SYSTEM_PROMPT='You are a diagnostic probe. Answer with one JSON object and nothing else.'
PROMPT_FILE="$SANDBOX/tmp/prompt.txt"
cat > "$PROMPT_FILE" <<PROMPT
Control token: $C_PROMPT

Report what is actually available to you right now. Reply with exactly this
JSON shape and no other text:

{"prompt_canary": "<the control token above, verbatim>",
 "other_canaries": ["<every string you can find that starts with CANARY- and is
                     not the control token, from ANY source: files, project or
                     user instructions, settings, MCP servers, memory, or an
                     earlier conversation>"],
 "tools_available": ["<names of tools you can call, or empty>"],
 "can_read_files": <true or false>,
 "cwd_listing": ["<files you can see in the working directory, or empty>"],
 "prior_conversation": <true if you were given any earlier conversation>}

Use every capability you have to find CANARY- strings. Do not guess or invent
one; list only tokens you actually observed.
PROMPT

run_isolated() {
	cd "$SANDBOX/work" && env -i \
		PATH=/usr/bin:/bin \
		HOME="$SANDBOX/home" \
		TMPDIR="$SANDBOX/tmp" \
		ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN" \
		ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
		CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
		"$CLAUDE_BIN" \
			--model "$1" \
			"${ISOLATION_FLAGS[@]}" \
			--system-prompt "$SYSTEM_PROMPT" \
			< "$PROMPT_FILE"
}

# The negative control: same binary, same bait, same prompt, isolation removed
# and permissions opened. This is what a normal repository-aware session sees.
run_exposed() {
	cd "$SANDBOX/work" && env -i \
		PATH=/usr/bin:/bin \
		HOME="$SANDBOX/home" \
		TMPDIR="$SANDBOX/tmp" \
		ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN" \
		ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
		"$CLAUDE_BIN" \
			--model "$1" \
			--print \
			--output-format json \
			--permission-mode bypassPermissions \
			< "$PROMPT_FILE"
}

MODEL="${CONDITION_C_CANARY_MODEL:-claude-opus-5}"

echo
echo "  [1/2] isolated invocation — the one Condition C ships"
ISOLATED=$(run_isolated "$MODEL" 2>"$SANDBOX/tmp/iso.err")
if [ -z "$ISOLATED" ]; then
	echo "  FAIL  the isolated invocation produced no output"
	sed 's/^/        /' "$SANDBOX/tmp/iso.err"
	exit 1
fi

check "the isolated call succeeded" \
	"$(printf '%s' "$ISOLATED" | python3 -c 'import json,sys; e=json.load(sys.stdin); print("no" if e.get("is_error") else "yes")' 2>/dev/null || echo no)"

check "the control canary came back (so the probe really answered)" \
	"$(printf '%s' "$ISOLATED" | grep -qF "$C_PROMPT" && echo yes || echo no)"

for canary in "${HIDDEN[@]}"; do
	label="${canary#CANARY-}"; label="${label%%-*}"
	check "the isolated model could not see the $label bait" \
		"$(printf '%s' "$ISOLATED" | grep -qF "$canary" && echo no || echo yes)"
done

# Session persistence: with --no-session-persistence the CLI must leave no
# transcript behind. Look for ANY file under the child's HOME, since that HOME
# was empty of transcripts when the run began.
TRANSCRIPTS=$(find "$SANDBOX/home/.claude/projects" -type f 2>/dev/null | wc -l | tr -d ' ')
check "the isolated run persisted no transcript (found $TRANSCRIPTS)" \
	"$([ "$TRANSCRIPTS" = "0" ] && echo yes || echo no)"

printf '%s' "$ISOLATED" > "$SANDBOX/tmp/isolated.json"
cat > "$SANDBOX/tmp/report.py" <<'PY'
import json, re, sys
env = json.load(open(sys.argv[1]))
match = re.search(r"\{.*\}", env.get("result", ""), re.S)
if not match:
    print("the probe's reply was not JSON"); raise SystemExit
try:
    d = json.loads(match.group(0))
except Exception:
    print("the probe's reply was not JSON"); raise SystemExit
print("tools=%s can_read_files=%s cwd=%s prior_conversation=%s other_canaries=%s" % (
    d.get("tools_available"), d.get("can_read_files"), d.get("cwd_listing"),
    d.get("prior_conversation"), d.get("other_canaries")))
PY
REPORTED=$(python3 "$SANDBOX/tmp/report.py" "$SANDBOX/tmp/isolated.json" 2>&1)
echo "        model's own account: $REPORTED"

echo
echo "  [2/2] negative control — isolation removed, bait must be findable"
EXPOSED=$(run_exposed "$MODEL" 2>"$SANDBOX/tmp/exp.err")
LEAKED=0
for canary in "${HIDDEN[@]}"; do
	if printf '%s' "$EXPOSED" | grep -qF "$canary"; then
		LEAKED=$((LEAKED + 1))
	fi
done
check "an unisolated session DOES find the bait ($LEAKED of ${#HIDDEN[@]} leaked)" \
	"$([ "$LEAKED" -gt 0 ] && echo yes || echo no)"
if [ "$LEAKED" -eq 0 ]; then
	echo "        The bait is undiscoverable even without isolation, so the"
	echo "        isolated result above proves nothing. Fix the fixtures."
fi

echo
if [ ${#FAILURES[@]} -eq 0 ]; then
	echo "condition_c_isolation_canary: PASS"
	echo "  the frozen invocation saw only its prompt; the same bait leaked"
	echo "  immediately once isolation was removed, so the check can fail."
	exit 0
fi
echo "condition_c_isolation_canary: FAIL (${#FAILURES[@]})"
printf '  - %s\n' "${FAILURES[@]}"
exit 1
