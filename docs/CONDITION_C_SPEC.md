# Condition C — LLM + Player Knowledge Model adaptive hint selection

**Status: FROZEN.** This document was written and frozen *before* the holdout
Condition C will be scored on (`heldout-v4`) was generated. Its hashes and the
hashes of every asset it names are recorded in
`docs/condition_c_freeze_manifest.json` and tagged `condition-c-pre-v4-freeze-v2`.

**Amended once, before any holdout existed.** The original freeze
(`condition-c-pre-v4-freeze`, still present and unmoved) reached the model over
the Anthropic Messages API. That transport was replaced by the
company-broker-authenticated subprocess described in §E, because the Messages
API path required separately billed credentials this project does not have. The
amendment is confined to §E, §D.4 and §G: **no research semantics changed.** The
prompt template, the candidate derivation, the validation gates, the retry
budgets and the SILENCE policy are byte-identical to the original freeze, and
`spec_version` is unchanged at `condition-c-v1` for that reason. Both freezes
predate `heldout-v4`; neither has been scored.

Condition C has **no score**. It has never been run on `heldout-v3`, on any
scenario in it, or on any state derived from one. Its confirmatory evaluation
will use a new holdout generated only after this freeze.

---

## 0. What Condition C is, and what it is not

C is a **selector**, not a writer. Given a player state and the set of authored
lines an NPC may validly say, C chooses one — or chooses silence. The only text
that ever reaches a player is the authored string the returned identifier names.

This is the same job Conditions A-4 and B do. The three differ only in *how* the
choice is made:

| | how it chooses | what it may see |
|---|---|---|
| **A-4** | fixed evidence-depth tier per NPC | evidence only |
| **B** | four deterministic rules over PKM | evidence, story flags, PKM |
| **C** | a language model reads the state and the candidates | evidence, story flags, PKM, room, stage |

### The ten standing commitments

These predate this document and constrain it. Each is listed with the mechanism
that enforces it, because a commitment that is only written down is a promise,
and a commitment that is enforced by construction is a property.

| # | commitment | enforced by |
|---|---|---|
| 1 | C selects from the SAME shared authored catalogue as A and B | `Data.all_hints()` — the identical call A and B make |
| 2 | C does not generate hint prose | only an identifier crosses the boundary (§C) |
| 3 | C returns a catalogue hint id or SILENCE | `validate()` (§D) |
| 4 | C receives only hints satisfying the SAME hard-prerequisite predicate as A and B | `hard_eligible()` → `Data.state_violations()` |
| 5 | C may use canonical PKM state | `pkm_snapshot()` → `PlayerKnowledgeModel.state_in` |
| 6 | `preferred_when_demonstrated` is soft metadata, never eligibility | no predicate in C reads it; it appears only as prompt prose |
| 7 | evidence/story prerequisites remain hard | `Data.state_violations`, re-checked after model output |
| 8 | human relevance labels are never input | `INPUT_FIELDS` allowlist (§A.3) |
| 9 | A/B outputs are never input | C's source contains no call to either selector; fallback is SILENCE |
| 10 | scenario ordinal / benchmark identity is never input | `INPUT_FIELDS` allowlist |

Commitments 8, 9 and 10 are *negative* claims — "C never sees X". A negative
claim cannot be established by observing a run: C might have ignored X by luck.
They are established structurally instead, by an allowlist that excludes X by
default and by the absence of the call site. See §D.6 and the test suite.

### Files

| role | path |
|---|---|
| this specification | `docs/CONDITION_C_SPEC.md` |
| implementation | `scripts/condition_c_selector.gd` |
| model transport (client) | `scripts/condition_c_client.gd` |
| model transport (invocation) | `tools/condition_c_claude_invoke.sh` |
| prompt template | `prompts/condition_c_selector_v1.txt` |
| model configuration | `config/condition_c_model_v2.json` |
| contract tests | `tests/condition_c_selector_test.gd` |
| transport tests (offline) | `tests/condition_c_transport_test.gd` |
| isolation canary (live) | `tests/condition_c_isolation_canary.sh` |
| freeze manifest (hashes) | `docs/condition_c_freeze_manifest.json` |
| freeze checker | `tools/check_condition_c_freeze.py` |
| shared catalogue (unchanged, read-only) | `scripts/adaptive_hint_data.gd` |
| PKM (unchanged, read-only) | `scripts/player_knowledge_model.gd` |

`spec_version` = `condition-c-v1`. Every run record carries it.

---

## A. INPUT

### A.1 What C receives

Exactly these, and nothing else.

| field | source | form |
|---|---|---|
| NPC identity | caller | string: `butler`, `gardener`, `mechanic` |
| current room | game state `room` | string, verbatim |
| progression stage | game state `stage` | string, verbatim |
| evidence held | game state `evidence_items` | list of strings |
| story progress | game state `story_flags` | list of strings |
| knowledge items | game state `knowledge_items` | list of strings |
| canonical PKM | **derived**, never read from a file | all 8 concepts → `UNSEEN` / `LEARNING` / `DEMONSTRATED` |
| candidate hints | **derived** via the shared predicate | for that NPC only |

`room` and `stage` are ordinary game-state fields. They are supplied because
they are part of the player's actual situation, and staleness (§B.2) cannot be
judged without knowing where the player has got to. They are **not** benchmark
metadata: `stage` is a named progression milestone (`chemistry`, `greenhouse`,
`circuit`), not a scenario index, and it carries no information about position in
any evaluation set. If a future dataset were ordered by stage, that ordering is a
property of the game, not of the benchmark.

Each candidate is supplied as four fields and no others:

```
- identifier: h_butler_stain
  text: "<the exact authored string>"
  teaches: (nothing)
  especially apt once DEMONSTRATED: (no authoring note)
```

`teaches` and `preferred_when_demonstrated` are disclosed so the model can reason
about §B.3–B.4. Disclosure is not authority: §D re-derives eligibility from the
catalogue and the state, so nothing the model infers from these fields can widen
what it is allowed to return.

### A.2 Candidate derivation (commitment 4)

A hint is a candidate iff:

1. its `npc` field equals the requested NPC by exact string match; **and**
2. `AdaptiveHintData.state_violations(hint_id, knowledge_items, story_flags,
   evidence_items)` returns empty.

That second call is the shared predicate. It is the same function the matched
catalogue check uses, and it covers `requires_evidence`,
`requires_evidence_absent`, `requires_story_flags` and `requires_concept`.

Condition B's inline filter reads the first three but **not** `requires_concept`.
The two predicates therefore coincide only while no hint in the catalogue
declares a `requires_concept`. None does. `assert_predicate_parity()` asserts
both that fact and the catalogue's size on **every** `select()` call, and aborts
the scenario with `predicate parity:` rather than silently letting C and B
diverge on eligibility. This is checked rather than assumed because a future
authoring change could introduce one, and the drift would otherwise be invisible.

The candidate list is never trimmed, ranked, truncated or pre-filtered beyond
this. Withholding an eligible hint would hand A and B a content advantage that
protocol §9b forbids; the test suite asserts that no hint eligible under the
shared predicate is missing from the pool, not merely that every supplied hint is
eligible.

### A.3 What C must NOT receive

Enforced by **allowlist**, not by deletion. `filter_state()` copies exactly six
named fields out of the caller's state dictionary and drops everything else. A
field added to a scenario file in future is excluded by default rather than
leaking until someone notices.

```
INPUT_FIELDS = [npc, room, stage, evidence_items, story_flags, knowledge_items]
```

Consequently absent, and unable to be re-added by accident:

- **human relevance labels** — `valid_hints`, `human_valid_hints`,
  `annotation_rationale`, `ambiguity_note`, any annotator field
- **Condition A output** — selected id, tier, trace
- **Condition B output** — selected id, rule fired, trace
- **benchmark identity** — `scenario_id`, `id`, `ordinal`, `protocol_version`
- **evaluation metrics** — `RelevantHintRate`, `Coverage`, `StateViolationRate`,
  divergence lists
- **prior evaluation failures** — of any condition, in any form
- **serialized `pkm_states`** — see A.4

The contract test feeds C a scenario row contaminated with every one of these
and asserts that none appears in the rendered prompt, the filtered state, or the
run record.

### A.4 PKM is derived, never read (commitment 5)

C computes PKM by calling `PlayerKnowledgeModel.state_in(concept, knowledge,
flags, evidence)` for each of the eight concepts. A `pkm_states` block present in
a dataset is **never** consulted.

This is not fastidiousness. A serialized `pkm_states` block has already disagreed
with the model once: `heldout-v3` records `indicator_reaction: UNSEEN` in 16
scenarios where the model derives `LEARNING`, because the generator's PKM table
had the shape `{concept: (learning_flag, demonstrated_flag)}` and so could not
express `indicator_reaction`'s `learning_evidence: ["fake_red_stain"]`. The v3
artifacts are frozen and are not repaired. Every *future* dataset is held to
canonical serialization by `tests/pkm_serialization_canonical_test.gd`, and C
sidesteps the question entirely by deriving rather than reading.

The eight concepts, in `PlayerKnowledgeModel.CONCEPTS` order:
`indicator_reaction`, `physical_chemical_change`, `spectrum`, `reflection`,
`additive`, `circuit_continuity`, `circuit_regulation`, `circuit_fault_isolation`.

`ASSISTED` exists in the `Mastery` enum but is unreachable in PKM v1
(`ASSISTED_REQUIRES_NEW_STATE = true`). The prompt therefore defines three
levels, not four; naming a state the game cannot produce would invite reasoning
about a situation that cannot arise.

---

## B. TASK

The frozen wording is in `prompts/condition_c_selector_v1.txt`. This section
states what that wording is required to say; the template is authoritative for
how it says it.

> Choose the single line that gives this player the most meaningful guidance for
> their COMPLETE current state.

"Complete current state" is the operative phrase. C's reason for existing is that
A sees only evidence depth and B applies four rules in fixed order; neither can
weigh a consideration against another. C is asked to.

The model must weigh all six of the following. They are numbered in the prompt
and are not ranked — no weighting between them is specified, because specifying
one would be re-implementing B's rule order in prose.

1. **Investigative usefulness** — does it move the player's actual investigation
   forward from where they now stand?
2. **Staleness** — has the player's progression already passed this information
   by, so that saying it now tells them something they have moved beyond?
3. **Fit to what the player understands** — is teaching this concept appropriate
   given whether the player has it as UNSEEN, LEARNING or DEMONSTRATED?
4. **Value of re-teaching** — if a line teaches a concept the player has already
   DEMONSTRATED, does it still add enough contextual or narrative value to be
   worth saying, or is it merely repeating a proven lesson?
5. **Prematurity** — is this clue too far ahead of the player, so that it would
   confuse rather than guide?
6. **Addresses evidence actually held** — does the response meaningfully speak to
   the evidence the player is carrying, rather than evidence they do not have?

### B.7 Silence is a permitted answer

> If none of the listed lines provides meaningful guidance for this player's
> current state — every one is stale, premature, redundant or beside the point —
> choose SILENCE.

The prompt states silence is "a real answer, not a failure to answer", and
symmetrically warns against both failure modes: do not pick a weak line merely to
avoid silence, and do not pick silence merely to be cautious when a listed line
genuinely helps.

Silence is not free. Under protocol §6 a silent scenario is **not relevant**,
counts against `RelevantHintRate`, lowers `Coverage`, and is never excluded from
the relevance denominator. C cannot improve its score by abstaining.

**Condition B has no silence branch at all** (protocol §9b, "Silence behaviour"):
it returns a hint for every scenario with a known NPC, so its `Coverage` is 48/48
by construction. C can abstain. The two are therefore **not comparable on
`Coverage`** without saying so, and any report that puts them in one column must
carry that caveat.

### B.8 What the task does NOT ask

The model is not asked to check whether a line is *allowed*. The prompt states
plainly that every listed line is already valid and that the job is judging which
one helps. Asking a model to re-derive eligibility would put a hard safety
property behind a soft judgement. Eligibility is decided before the model sees
anything (§A.2) and re-checked after it answers (§D.2).

---

## C. OUTPUT

Machine-readable only.

```json
{"decision": "<identifier>", "reason": "<one short sentence>"}
```

| field | required | type | meaning |
|---|---|---|---|
| `decision` | yes | string | a catalogue hint identifier, copied exactly, **or** the single token `SILENCE` |
| `reason` | no | string | research trace only |

Any other value of `decision` is rejected (§D).

### C.1 No free-form hint text

There is no field in which the model can supply player-facing prose, and no path
by which any string it emits can be shown to a player. C returns only
`selected_hint_id`; the text a player sees is
`AdaptiveHintData.all_hints()[id]["text"]`, looked up by the caller. The model's
output is used as a *key*, never as content.

The contract test covers both attacks. A reply whose `decision` **is** invented
prose is refused outright and ends in silence. A reply carrying a valid
`decision` alongside extra `hint_text` and `text` fields holding invented
dialogue delivers the identifier and nothing else: the smuggled fields do not
appear in the run record, and the delivered id is asserted to be a catalogue key.

### C.2 `reason` is inert by construction

`reason` is defined separately from `decision`, is recorded in the run log, and
**cannot affect eligibility or acceptance**:

- no predicate in `validate()` reads it;
- it is not parsed, matched, or searched for identifiers;
- a reply with a valid `decision` and a nonsensical, empty, or missing `reason`
  is accepted unchanged;
- a reply with an invalid `decision` and an impeccable `reason` is rejected.

The prompt tells the model this directly: `reason` "is recorded for research
only. It is never read by the game, never affects whether your choice is
accepted, and must not contain dialogue for the character to say."

---

## D. VALIDATION AND POST-PROCESSING

### D.1 Parsing

The reply must be a single JSON object with a string `decision`.

One surrounding ```` ```json ```` fence is stripped before parsing. That is
transport cleanup, not leniency: a code fence is a formatting habit of chat
models and removing it changes no decision. **Nothing else is repaired.** No
identifier is extracted from surrounding prose, no near-miss is snapped to the
nearest candidate, no second JSON object in the reply is considered. A reply
that needs interpretation is a rejected reply.

| failure | error class |
|---|---|
| not a single JSON object | `the reply was not a single JSON object` |
| no string `decision` field | `the reply had no string `decision` field` |

### D.2 Validation gates

In order. The first failure wins and names the rejection class.

| # | gate | rejection class |
|---|---|---|
| 0 | `decision == "SILENCE"` → **accept** | — |
| 1 | identifier exists in the shared catalogue | `` `decision` was not a known hint identifier `` |
| 2 | identifier was among the candidates offered for this NPC | `` `decision` named a hint that was not offered `` |
| 3 | hard prerequisites **still** hold, re-checked against the state | `` `decision` named a hint whose preconditions do not hold `` |
| 4 | the hint's `npc` equals the requested NPC | `` `decision` named a hint that was not offered `` |

Cross-NPC returns are impossible via gate 2 alone, since the candidate pool is
NPC-filtered; gate 4 is a second, independent guard on the same property.

Gate 3 is likewise redundant while the candidate list is built correctly — and is
kept for exactly that reason. *Redundant* and *unnecessary* are different words.
It is the only check that survives a bug in candidate construction, and a
state-violating hint reaching a player is the failure this entire protocol exists
to measure. Both redundant gates are fault-injection tested: removing either
makes the suite fail.

### D.3 Retry policy

**Exactly one schema retry.** Frozen in `config/condition_c_model_v2.json` as
`schema_retry.max_retries = 1`.

The retry prompt is the `RETRY_NOTE` block of the frozen template, appended to
the *identical* first prompt. It:

- names the rejection class from §D.1/§D.2 and nothing else;
- restates the required output format;
- states explicitly: "This is a formatting correction only. It is not a
  judgement about which line you chose, and you should not change your assessment
  because of it";
- **names no hint identifier.**

That last point is asserted mechanically: the test extracts the byte-exact
difference between the first and second prompts and asserts that all eleven
catalogue identifiers are absent from it. One retry is enough to recover a stray
code fence or a truncated object; more would be an iterative repair loop quietly
searching for an acceptable answer, which is a different algorithm.

The candidate pool is **not** re-derived differently on retry. A retry that
offered a different pool would be answering a different question.

### D.4 Two independent budgets

A network outage is not a badly formatted answer, and conflating them would let
an outage be scored as an abstention — a fabricated data point.

| failure kind | budget | on exhaustion |
|---|---|---|
| **schema** — call succeeded, answer unusable (malformed, invalid id, ineligible id, refusal, empty completion) | 1 retry | **SILENCE**, `fallback_used = true` |
| **transport** — the subprocess never produced a usable envelope (§E.0) | 2 retries, backoff `[2, 8]`s | **ABORT_RUN**, `aborted = true`, `silence = false` |

Under the subprocess transport, "transport failure" is any non-zero exit from
`tools/condition_c_claude_invoke.sh`, or a zero exit whose envelope carries
`is_error` or no result text:

| exit | meaning |
|---|---|
| 3 | `SUBSCRIPTION_TRANSPORT_UNAVAILABLE` — no company broker credential |
| 4 | `DIRECT_API_REFUSED` — the call would have gone to Anthropic directly |
| 5 | `CLAUDE_CLI_NOT_FOUND` |
| 6 | `CLAUDE_CLI_FAILED` — the CLI exited non-zero |
| 7 | `CONDITION_C_TIMEOUT` — no reply within 120s |

Exits 3 and 4 are the fail-closed gates of §E.0.3. They abort the run. They are
**not** retried into an alternative endpoint and are **not** scored as silence: a
run that could not reach the sanctioned transport is an incomplete run, not a run
in which the model declined to speak.

A transport failure never consumes the schema retry. An aborted scenario is not
scored as silence; it is not scored at all, and a run containing one is not a
complete run.

### D.5 Fallback after retries: SILENCE

> **No fallback invokes Condition A or Condition B. Ever.**

Every run record carries `"fallback_policy": "SILENCE (never Condition A or B)"`.

The reasoning: falling back to A would make C a superset of A, and the A-vs-C
contrast would degrade into a measurement of how often C declined to answer.
Under protocol §6 silence scores as not-relevant, so this fallback can never
flatter C — it is the costly choice, which is the correct property for a
fallback to have.

### D.6 Structural isolation (commitments 8, 9, 10)

"C never falls back to A" cannot be established by running C: A and C may agree
by coincidence, and a fallback that fires rarely may not fire during the run. It
is established from the source instead. `scripts/condition_c_selector.gd` and
`scripts/condition_c_client.gd` contain, in executable code, no occurrence of:

`select_condition_a` · `select_adaptive` · `adaptive_hint_selector` ·
`CONDITION_A_TIERS`

The test strips whole-line comments before the grep — both files *name* these
symbols in prose, precisely to record which calls are forbidden, and a grep that
banned the words outright would force the commitment to go unwritten in order to
be kept. A call cannot hide in a comment. The test additionally asserts that
stripping removed text, that it kept the code, and that the banned names really
are present in the prose, so the grep cannot pass by inspecting an empty string.

---

## E. MODEL CONFIGURATION AND TRANSPORT

Frozen in `config/condition_c_model_v2.json`, version `condition-c-model-v2`.
Nothing in the client code supplies a default that could override it.

### E.0 How the model is reached

C invokes the model as an **isolated one-shot Claude Code subprocess**,
authenticated by the **company-managed Claude Code broker**. It opens no HTTP
connection to Anthropic and holds no API key; `scripts/condition_c_client.gd`
contains no HTTP client, no endpoint URL and no key lookup at all.

Authentication and semantic context are separate things, and this transport
keeps them separate. **Being authenticated as this user must not mean being
handed this user's repository, instructions, history or tools.** The broker
credential is the one thing the subprocess inherits.

The exact invocation lives in `tools/condition_c_claude_invoke.sh` — a hashed,
reviewable artifact rather than a string built at runtime inside the client:

```sh
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
		< "$USR_FILE"
```

The system prompt is passed **by value**, the user prompt on **stdin**. Neither
is passed as a path, so the argument vector of the model process contains no
filesystem location, no scenario identity and no per-scenario content: it is
byte-identical from one scenario to the next. Prompt files exist on the harness
side of the boundary and are never named to the child.

#### E.0.1 What each isolation flag removes

| flag | what it removes |
|---|---|
| `--print` | interactivity; one shot, then exit |
| `--model <id>` | alias resolution; the model identity is explicit |
| `--output-format json` | prose scraping; a machine-readable envelope |
| `--no-session-persistence` | any transcript on disk, and anything resumable |
| `--tools ""` | every tool: no file reads, no shell, no search |
| `--strict-mcp-config` | every MCP server not named on the command line — and none is |
| `--safe-mode` | `CLAUDE.md`, skills, plugins, hooks, subagents |
| `--restricted` | user, project and local settings files |
| `--setting-sources ""` | every remaining setting source |
| `--disable-slash-commands` | skills reachable by name |

Verified against `claude --help` for version **2.1.258**, the version pinned in
the config. `--bare` is deliberately **not** used: its own help text states that
under it "Anthropic auth is strictly `ANTHROPIC_API_KEY` or `apiKeyHelper`" —
the separately billed path this project forbids. Stronger-sounding isolation
that forces the wrong billing path is not stronger isolation.

> **Flag acceptance is not evidence.** At its root command this CLI silently
> tolerates unknown options: `claude --not-a-real-flag --version` exits 0. A
> misspelled isolation flag would therefore be accepted in silence and isolate
> nothing. None of the claims above rest on the CLI accepting these words; they
> rest on the behavioural canary of §E.0.5.

#### E.0.2 Environment and working directory

The child's environment is built **from nothing** with `env -i` and receives
exactly six variables: `PATH`, `HOME`, `TMPDIR`, `ANTHROPIC_AUTH_TOKEN`,
`ANTHROPIC_BASE_URL`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`. Everything
else in the harness environment — `ANTHROPIC_API_KEY` if one exists, every
agent-session variable, every path, every git variable — is dropped by
construction rather than by enumeration. There is no deny-list to keep current.

`HOME` and the working directory are freshly created empty directories under
`mktemp -d`, destroyed on exit. The child is `cd`-ed into the empty working
directory before launch. So even if a future CLI version narrowed what
`--safe-mode` covers, there is no repository, no `CLAUDE.md`, no settings file
and no MCP config anywhere it would look.

#### E.0.3 Fail closed, never fall back

Two gates run before the CLI is located, and both abort:

- **no `ANTHROPIC_AUTH_TOKEN`** → exit 3, `SUBSCRIPTION_TRANSPORT_UNAVAILABLE`;
- **`ANTHROPIC_BASE_URL` unset, or pointing at `api.anthropic.com`** → exit 4,
  `DIRECT_API_REFUSED`.

> **There is no API fallback.** If the company broker is unavailable, C returns
> a transport failure and the run aborts (§D.4). It does not retry against
> `api.anthropic.com`, and no code path in the client or the wrapper can reach
> it. An unset base URL is treated as a refusal precisely because the CLI's own
> default would be the direct endpoint.

#### E.0.4 One process per scenario

Each scenario is a **fresh process** with a fresh sandbox. Nothing is carried
between scenarios: no session, no transcript, no cache, no working directory.
Scenario *n+1* cannot be influenced by scenario *n*, and the order of the
holdout cannot affect the answers. A 120-second watchdog bounds each call
(exit 7).

#### E.0.5 How the isolation is verified

Structurally and behaviourally, because neither alone is sufficient:

| claim | offline (`tests/condition_c_transport_test.gd`) | live (`tests/condition_c_isolation_canary.sh`) |
|---|---|---|
| flags reach the CLI | argv captured from a fake `claude` | — |
| environment is sanitized | env captured; a planted `ANTHROPIC_API_KEY` canary is absent while the broker token is present | — |
| working directory is empty | `ls -a` captured from the child | — |
| no repository path, benchmark id, annotation or A/B output crosses | argv and stdin scanned | — |
| tools are off, files unreadable | — | the model is asked, with bait planted |
| `CLAUDE.md`, settings, MCP unreadable | — | bait planted in all four locations |
| no agent conversation inherited | no transcript path in argv, env or stdin | a token existing **only** in the calling agent's conversation, never written to disk, does not come back |
| no transcript persisted | — | child `HOME` scanned after the call |
| fail-closed gates fire | exits 3/4/5/6 asserted | — |

The canary plants **freshly minted random tokens** — never a v3 value, an
annotation, an A/B output or any real secret — in a repository-like file, a
project `CLAUDE.md`, a user `CLAUDE.md`, an `.mcp.json` and a `settings.json`,
then asks the model to report every `CANARY-` string it can find. It refuses to
be vacuous twice over: a control token inside the prompt must come back (proving
the model answered at all), and a **negative control** repeats the run with
isolation removed and must leak (proving the bait was findable). A drift guard
diffs the canary's flag list against the wrapper's as sets, so a flag added to or
removed from the wrapper fails the suite rather than silently un-testing it.

At freeze: the isolated run leaked **0 of 5** baits, reported no tools, no file
access, an empty working directory and no prior conversation, and left 0
transcripts. The negative control leaked **5 of 5** with 21 tools available.

The agent-inheritance row is checked differently, because the thing that must not
leak cannot be planted on disk without ceasing to be what it is. A token was
minted **inside the calling agent's conversation only** — never written to a
file, never passed to the subprocess, never named in the invocation — and the
isolated model was asked to describe the context it had been given. It reported
`prior_conversation: false`, `parent_task_visible: false`, and the token did not
appear. This is a manual probe rather than a suite entry, for the same reason:
committing it to a file would destroy the property it tests.

#### E.0.6 What the model actually sees

Only three things: the frozen system/task prompt, the single current scenario
payload, and that scenario's hard-eligible candidates.

One honest caveat: under `--print` the CLI injects a system reminder stating the
current date. It is not suppressible from the command line. It carries no
repository, benchmark or conversation content, and no prompt in this protocol
refers to a date — but it is context C did not author, and it is recorded here
rather than omitted.

That caveat is not an inference. Asked to enumerate its context sources, the
isolated model listed exactly three — the system prompt, "system-reminder
context block with currentDate", and the request itself — and named the date
string as the only identifier it had received beyond the control token. The
documented exception is the whole of the exception.

### E.1 Parameters

| parameter | value | why |
|---|---|---|
| provider | `claude-code-cli` | §E.0 |
| API | `cli-print-json` | `--print --output-format json` |
| model | `claude-opus-5` | C exists to answer "given a knowledge model, what does an LLM add over deterministic rules?" The fair test is the strongest selector, not the cheapest. A smaller-model variant is a separate condition with its own frozen config and its own holdout. Confirmed at freeze from the envelope's `modelUsage`, which reports `canonicalModel: claude-opus-5`. |
| temperature | `null` — **not controllable** | The CLI exposes no sampling flag. `null` records that nothing is sent, not that a value was chosen. |
| top_p | `null` — not controllable | as temperature |
| top_k | `null` — not controllable | as temperature |
| max output tokens | `null` — not controllable | The CLI exposes no output-token flag. The envelope reports a 64000-token ceiling; the required output is well under 100 tokens. An over-long reply is a schema failure and is retried, never salvaged. |
| seed | **not available** | No seed parameter exists on this transport, as none existed on the previous one. |
| stop sequences | `[]` | none sent |
| samples per scenario | `1` | Self-consistency voting over *k* samples is a different condition with a different failure profile, and choosing *k* after seeing results would be tuning. |
| schema retries | `1` → SILENCE | §D.3 |
| transport retries | `2`, backoff `[2, 8]`s → ABORT_RUN | §D.4 |
| timeout | `120`s per call | §E.0.4 |

**C is less controllable under this transport than it was under the Messages
API**, and that is a real cost of the amendment, not a detail. Temperature 0 is
no longer available. This is recorded rather than smoothed over because it
weakens nothing about C's *isolation* and everything about C's *repeatability*,
and a reader scoring C is entitled to know which.

### E.2 Determinism is NOT claimed

**Condition C is not a deterministic condition.** Conditions A and B are.

No sampling parameter can be set on this transport and no seed exists, so
repeated runs on identical input may differ. Nothing in this document should be
read as a claim that the model's output is reproducible.

This is stated rather than glossed because it changes how C's results may be
read. The run log records every raw response verbatim (§F) so that a rerun which
diverges is *visible* rather than silently averaged away. This is a limitation of
the condition, not a defect in the harness, and it belongs in the limitations
section of any report that scores C.

### E.3 Changing any of this

Any change to the model, the transport, the prompt template, or the retry policy
produces a **new config version and a new freeze tag**, never an in-place edit.
A run may only cite the version whose hash it logged. This amendment is itself an
instance of that rule: `condition_c_model_v1.json` was not edited, it was
superseded, and it remains on disk byte-identical under the original tag.

---

## F. REPRODUCIBILITY

Every `select()` call returns a record containing:

| field | content |
|---|---|
| `condition`, `spec_version` | `C LLM + PKM adaptive selector`, `condition-c-v1` |
| `model`, `provider` | from the frozen config |
| `temperature`, `max_tokens`, `samples_per_scenario` | from the frozen config; the first two are `null` under this transport (§E.1) and are still logged, so a record cannot be mistaken for one made under the Messages API |
| `prompt_template_version` | `condition-c-v1` |
| `prompt_template_sha256` | sha256 of the template file as loaded |
| `rendered_prompt_sha256` | sha256 of system + user as actually sent |
| `candidates_supplied` | the exact identifier list offered |
| `pkm_states_supplied` | canonical state of all 8 concepts |
| `attempts[]` | per attempt: index, **raw model response verbatim**, parsed decision, model `reason`, rejection class, or transport error |
| `retry_count` | schema retries consumed |
| `selected_hint_id` | final validated identifier, or `""` |
| `silence` | true iff no hint was delivered and the scenario did not abort |
| `fallback_used` | true iff retries were exhausted |
| `fallback_policy` | `SILENCE (never Condition A or B)` |
| `aborted`, `abort_reason` | transport exhaustion or predicate-parity drift |

`rendered_system` / `rendered_user` are logged only when `log_full_prompts` is
set, so full prompts are opt-in rather than bloating every record.

`model` above is the identifier **requested**. The envelope returned by this
transport also reports the model the broker actually **resolved** (its
`modelUsage` key), which the client exposes as `last_envelope` but which
`select()` does not currently copy into the record. Requested and resolved were
identical at freeze — both `claude-opus-5` — and the decision path was left
byte-identical rather than edited for a field the freeze does not require.
Copying it in is the one improvement this transport plainly wants, and it belongs
in the next config version, not in this one.

### F.1 No ground truth in the log

The record contains no human label, no other condition's output, and no benchmark
identifier. Scoring happens **later**, in a separate program, joining this log to
a ground-truth file that C never reads. Merging ground truth into a C run record
before scoring is prohibited.

---

## G. Verification status at freeze

`tests/condition_c_selector_test.gd` — **PASS**. No model is called: every
response is scripted through `ConditionCClient.Stub`, so the suite is offline,
deterministic, needs no credential, and exercises the real selector rather than a
rehearsal of it. No held-out scenario is read; every state is constructed inline.

Covered: only hard-eligible hints supplied (and no eligible hint withheld); no
cross-NPC hints; invalid hint id rejected; hard-ineligible returned id rejected;
SILENCE accepted; malformed response behaviour; retry behaviour; canonical PKM
supplied; the same 11-hint catalogue; no generated prose delivered as a
player-facing hint; human labels unavailable; A/B outputs unavailable.

### Fault injection

A passing suite proves nothing unless it can fail. Seven mutants of the selector
are compiled from mutated source at runtime — the frozen file is never written
to — each breaking exactly one commitment. **All seven are detected.** Every
mutation's anchor must appear exactly once in the source or the harness aborts,
so a mutation that silently failed to apply cannot report a false all-clear.

| mutant | breaks | detected by |
|---|---|---|
| `skip_eligibility_recheck` | 7 | post-output re-check assertions (2) |
| `accept_unoffered` | 3, 4 | cross-NPC assertions (4) |
| `leak_inputs` | 8, 10 | allowlist assertions (22) |
| `stale_pkm` | 5 | canonical PKM assertions (10) |
| `unbounded_retries` | frozen config | retry budget assertions (5) |
| `fallback_to_condition_a` | 9 | silence-on-exhaustion assertions (6) |
| `deliver_model_prose` | 2, 3 | identifier-not-text assertions (9) |

`unbounded_retries` initially went undetected, and the reason was worth
recording: the mutated guard sat on a branch — a client returning `ok: false`
without a transport error — that the stub could not reach. The mutant was inert,
not the suite blind. Both were fixed: the mutation now targets both retry guards,
and the previously unreachable branch (a refusal or empty completion, which is a
model-side failure and must spend the schema budget rather than the transport
budget) is now exercised directly.

### The transport

`tests/condition_c_transport_test.gd` — **PASS**, offline. It runs the *real*
wrapper against a fake `claude` binary that records its argv, environment,
working directory and stdin, so every claim in §E.0 is checked against what the
child process actually received rather than against what the script appears to
say. Twelve tests: wrapper structure; environment sanitization; isolation flags
reaching the CLI; an empty working directory; no forbidden material crossing the
boundary, checked at both the client→wrapper and wrapper→CLI edges; a fresh
process per scenario; the fail-closed gates; no API fallback; the decision
contract; player-facing text authored, never generated; canonical PKM; and the
canary suite present.

**Eight mutants, all eight detected.** One of them was a genuine blind spot found
this way: a mutant that made the client pass a repository path as a fourth
argument went undetected at first, because the wrapper ignores `$4` and so
nothing reached the fake CLI. The leak was real and the test could not see it.
The fix was to check the client→wrapper edge directly — exactly three arguments,
none containing a repository path — rather than only the edge downstream of it.

`tests/condition_c_isolation_canary.sh` — **PASS**, live, two calls. The
behavioural half of §E.0.5: 0 of 5 baits leaked under isolation, 5 of 5 leaked
with isolation removed, 0 transcripts persisted, control canary returned.

`tools/condition_c_live_smoke.gd` — **PASS**, live, one call, one invented
scenario that appears in no holdout. The whole path end to end: candidates →
canonical PKM → frozen prompt → isolated subprocess → parse → eligibility
re-check → validated decision (`h_butler_stain`, 0 schema retries, 1 subprocess,
4242 ms, `canonicalModel: claude-opus-5`). **Nothing was scored and nothing was
tuned.** There is no ground truth for an invented scenario and none was
consulted; the output was used to confirm that the plumbing carries a decision,
and for nothing else.

### The freeze itself

`tools/check_condition_c_freeze.py` — **PASS**. It recomputes all 22 hashes in
`docs/condition_c_freeze_manifest.json` and additionally checks that the spec,
template and config agree on their version strings, that the manifest's reported
parameters are the ones the config actually holds, that the implementation names
the frozen template and config paths, and that neither Condition C source calls
Condition A or B.

It also cross-checks the transport, because a config block that *describes* an
isolated invocation is a claim about a shell script it does not control: every
flag the config advertises must really be in the wrapper's invocation, every
allowlisted variable must really be passed and nothing else may be, both
fail-closed gates must be present, the client must contain no HTTP or API-key
path, no sampling parameter may hold a value the transport cannot send, and the
manifest's transport summary must agree with the config it summarises. A
manifest of hashes is worth what checking it costs.

One of those 22 hashes is `config/condition_c_model_v1.json`, the superseded
Messages API config. It is unused, and it is hashed anyway: the value matching
the one recorded under `condition-c-pre-v4-freeze` is the evidence that the
amendment superseded the original config rather than rewriting it.

Fault-injected six ways — a byte appended to the spec, a bumped `SPEC_VERSION`,
an inserted `select_condition_a(...)` call, a manifest parameter disagreeing with
the config, an isolation flag deleted from the wrapper, and `ANTHROPIC_API_KEY`
added to the wrapper's environment block. All six detected; every file restored
byte-identical afterwards.

### The closed experiment is untouched

`tools/check_heldout_v3_evaluation_integrity.py` — **PASS**, and it reports
`Condition C: not run`. `tools/check_heldout_v3_annotations.py` — **PASS**.
`tests/matched_catalogue_test.gd` — **PASS**. The only tracked file this phase
modified is `docs/EVALUATION_PROTOCOL.md`, and only to *document* Condition B's
already-frozen behaviour. `scripts/adaptive_hint_selector.gd` is byte-identical
to its `heldout-v3-pre-annotation` state.

---

## H. What happens next

1. Generate `heldout-v4` — **after** this freeze, never before.
2. Annotate it blind, under the existing protocol.
3. Run C once. Report with the §E.1 determinism caveat and the §B.7 `Coverage`
   caveat.

C must not be modified, tuned, re-prompted, or re-configured between this freeze
and that run. If it is, the result is exploratory and the holdout is spent.
