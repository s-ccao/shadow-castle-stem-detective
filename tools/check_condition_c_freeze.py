#!/usr/bin/env python3
"""Verify the Condition C freeze manifest against the files on disk.

A manifest of hashes is only worth what checking it costs. This recomputes every
sha256 in `docs/condition_c_freeze_manifest.json` and fails on any drift, so
"Condition C is frozen" is a statement that can be tested rather than trusted.

It also re-checks four things the manifest asserts but a hash alone cannot:

  * the three heldout-v3 artifacts listed as untouched really do still carry the
    hashes the closed experiment recorded;
  * the spec, template and config agree on their version strings, so a run
    citing `condition-c-v1` cannot be citing three different things;
  * the implementation names the frozen template and config paths, and contains
    no call to Condition A or Condition B;
  * the transport the config DESCRIBES is the transport the wrapper actually
    RUNS -- every isolation flag the config advertises is really in the
    invocation, and no directly billed path exists in either file.

Exit 0 on success, 1 on drift.

    python3 tools/check_condition_c_freeze.py
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MANIFEST = REPO / "docs" / "condition_c_freeze_manifest.json"

# Names that must not appear in Condition C's executable code. Comments are
# stripped first: both files name these symbols in prose precisely to record
# which calls are forbidden, and a check that banned the words outright would
# force the commitment to go unwritten in order to be kept.
FORBIDDEN_SYMBOLS = (
    "select_condition_a",
    "select_adaptive",
    "adaptive_hint_selector",
    "CONDITION_A_TIERS",
)

C_SOURCES = ("scripts/condition_c_selector.gd", "scripts/condition_c_client.gd")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def code_only(source: str) -> str:
    """GDScript source with whole-line comments removed."""
    return "\n".join(
        line for line in source.splitlines() if not line.strip().startswith("#")
    )


def check_hashes(manifest: dict, problems: list[str]) -> int:
    checked = 0
    for section in ("required_hashes", "supporting_hashes",
                    "unchanged_since_heldout_v3_evaluation"):
        for role, entry in manifest[section].items():
            if not isinstance(entry, dict) or "path" not in entry:
                continue  # the prose `note` key
            path = REPO / entry["path"]
            if not path.exists():
                problems.append(f"{section}.{role}: {entry['path']} is missing")
                continue
            actual = sha256(path)
            if actual != entry["sha256"]:
                problems.append(
                    f"{section}.{role}: {entry['path']}\n"
                    f"    manifest {entry['sha256']}\n"
                    f"    on disk  {actual}"
                )
            checked += 1
    return checked


def check_versions(manifest: dict, problems: list[str]) -> None:
    spec_version = manifest["spec_version"]

    # The config path comes from the manifest rather than being spelled out
    # here, so bumping the config version cannot leave this checker silently
    # validating the previous one.
    config_rel = manifest["required_hashes"]["model_configuration"]["path"]
    config = json.loads((REPO / config_rel).read_text())
    if config["config_version"] != manifest["config_version"]:
        problems.append(
            f"config_version: manifest {manifest['config_version']!r}, "
            f"config file {config['config_version']!r}"
        )
    if config["prompt_template_version"] != manifest["prompt_template_version"]:
        problems.append(
            f"prompt_template_version: manifest "
            f"{manifest['prompt_template_version']!r}, config file "
            f"{config['prompt_template_version']!r}"
        )

    template = (REPO / config["prompt_template"]).read_text()
    declared = re.search(r"^template_version:\s*(\S+)", template, re.M)
    if declared is None:
        problems.append("the prompt template declares no template_version")
    elif declared.group(1) != manifest["prompt_template_version"]:
        problems.append(
            f"template_version: manifest {manifest['prompt_template_version']!r}, "
            f"template file {declared.group(1)!r}"
        )

    selector = (REPO / "scripts" / "condition_c_selector.gd").read_text()
    impl = re.search(r'SPEC_VERSION\s*:=\s*"([^"]+)"', selector)
    if impl is None:
        problems.append("the selector declares no SPEC_VERSION")
    elif impl.group(1) != spec_version:
        problems.append(
            f"SPEC_VERSION: manifest {spec_version!r}, selector {impl.group(1)!r}"
        )

    for const, expected in (
        ("TEMPLATE_PATH", "res://" + config["prompt_template"]),
        ("CONFIG_PATH", "res://" + config_rel),
    ):
        found = re.search(rf'{const}\s*:=\s*"([^"]+)"', selector)
        if found is None or found.group(1) != expected:
            problems.append(
                f"{const}: expected {expected!r}, "
                f"found {found.group(1) if found else None!r}"
            )

    # The sampling parameters the manifest reports must be the ones the frozen
    # config actually holds. A manifest that described a different temperature
    # than the run would use is worse than no manifest.
    reported = manifest["model_configuration"]
    for key in ("provider", "api", "model", "temperature", "top_p", "top_k",
                "max_tokens", "seed", "stop_sequences", "samples_per_scenario"):
        if reported[key] != config[key]:
            problems.append(
                f"model_configuration.{key}: manifest {reported[key]!r}, "
                f"config file {config[key]!r}"
            )
    for key in ("max_retries", "on_exhausted"):
        if reported["schema_retry"][key] != config["schema_retry"][key]:
            problems.append(f"schema_retry.{key} disagrees with the config file")
        if reported["transport_retry"][key] != config["transport_retry"][key]:
            problems.append(f"transport_retry.{key} disagrees with the config file")


def check_isolation(problems: list[str]) -> None:
    for rel in C_SOURCES:
        source = (REPO / rel).read_text()
        stripped = code_only(source)
        if len(stripped) >= len(source):
            problems.append(f"{rel}: comment stripping removed nothing")
        for symbol in FORBIDDEN_SYMBOLS:
            if symbol in stripped:
                problems.append(f"{rel} calls {symbol!r}")

    selector = (REPO / "scripts" / "condition_c_selector.gd").read_text()
    if "select_condition_a" not in selector:
        problems.append(
            "the selector no longer records which calls are forbidden; the "
            "isolation check above may be passing vacuously"
        )
    if "SILENCE (never Condition A or B)" not in selector:
        problems.append("the selector does not declare the SILENCE fallback policy")


def check_transport(manifest: dict, problems: list[str]) -> None:
    """The transport the config describes must be the one the wrapper runs.

    A config block listing isolation flags is a claim about a shell script it
    does not control. Cross-check it: every flag the config advertises has to be
    in the invocation, and neither file may contain a directly billed path.
    """
    config_rel = manifest["required_hashes"]["model_configuration"]["path"]
    config = json.loads((REPO / config_rel).read_text())
    transport = config.get("transport")
    if not transport:
        problems.append(f"{config_rel} describes no transport")
        return

    wrapper_rel = transport["wrapper"]
    wrapper_path = REPO / wrapper_rel
    if not wrapper_path.exists():
        problems.append(f"the transport names a missing wrapper: {wrapper_rel}")
        return

    # Comments are stripped first, for the same reason they are in
    # check_isolation. The wrapper's header documents every flag and states
    # "ANTHROPIC_API_KEY is never forwarded" -- scanning the raw text would
    # credit the header for flags the invocation might have lost, and would read
    # that promise as the violation it promises not to commit.
    prose = wrapper_path.read_text()
    wrapper = code_only(prose)
    if len(wrapper) >= len(prose):
        problems.append(f"{wrapper_rel}: comment stripping removed nothing")
    if "ANTHROPIC_API_KEY" not in prose[: prose.find("set -eu")]:
        problems.append(
            f"{wrapper_rel}: the header no longer records that ANTHROPIC_API_KEY "
            f"is never forwarded; the strip above may be passing vacuously"
        )

    # Only the flag NAME is compared. Values such as the model identifier are
    # substituted at call time and are checked by the contract tests, not here.
    for flag in transport["flags"]:
        name = flag.split(" ", 1)[0]
        if name not in wrapper:
            problems.append(f"the config advertises {name} but the wrapper never passes it")

    # The environment is built from nothing, and the allowlist is the whole of
    # what the child receives.
    if "env -i" not in wrapper:
        problems.append("the wrapper no longer builds the child environment from nothing")
    start, end = wrapper.find("env -i"), wrapper.find('< "$USR_FILE"')
    block = wrapper[start:end] if 0 <= start < end else ""
    if "ANTHROPIC_AUTH_TOKEN" not in block:
        problems.append("the wrapper's environment block could not be located")
    for name in ("ANTHROPIC_API_KEY", "apiKeyHelper"):
        if name in block:
            problems.append(f"the wrapper forwards {name} to the CLI")
    for name in transport["environment_allowlist"]:
        if name not in block:
            problems.append(f"the allowlist names {name} but the wrapper does not pass it")

    # Fail closed, with no way back to a separately billed endpoint.
    if 'if [ "$BASE_HOST" = "api.anthropic.com" ]; then' not in wrapper:
        problems.append("the wrapper no longer refuses a direct Anthropic endpoint")
    if "SUBSCRIPTION_TRANSPORT_UNAVAILABLE" not in wrapper:
        problems.append("the wrapper no longer reports an unavailable broker")
    if transport.get("personal_api_key_used") is not False:
        problems.append("the config no longer asserts that no personal API key is used")
    if transport.get("direct_anthropic_endpoint_used") is not False:
        problems.append("the config no longer asserts that no direct endpoint is used")

    # The manifest summarises the transport for readers who never open the
    # config. Where the two overlap they must agree, or the summary becomes a
    # second source of truth that drifts.
    summary = manifest["transport"]
    for key in ("kind", "claude_code_version_at_freeze", "personal_api_key_used",
                "direct_anthropic_endpoint_used", "process_per_scenario",
                "conversation_persistence"):
        if summary[key] != transport[key]:
            problems.append(
                f"transport.{key}: manifest {summary[key]!r}, "
                f"config file {transport[key]!r}"
            )
    if summary.get("api_fallback_exists") is not False:
        problems.append("the manifest no longer asserts that no API fallback exists")

    client = code_only((REPO / "scripts" / "condition_c_client.gd").read_text())
    for banned in ("api.anthropic.com", "ANTHROPIC_API_KEY", "https://", "HTTPClient"):
        if banned in client:
            problems.append(f"condition_c_client.gd contains a {banned!r} path")

    # Determinism must not be claimed: this transport cannot pin sampling.
    if manifest["model_configuration"].get("determinism_claimed") is not False:
        problems.append("the manifest claims determinism this transport cannot provide")
    for key in ("temperature", "top_p", "top_k", "max_tokens", "seed"):
        if config[key] is not None:
            problems.append(
                f"{key} is set to {config[key]!r}, but the CLI transport exposes no "
                f"flag for it; a value here would be a setting that is never sent"
            )


def main() -> int:
    manifest = json.loads(MANIFEST.read_text())
    problems: list[str] = []

    checked = check_hashes(manifest, problems)
    check_versions(manifest, problems)
    check_isolation(problems)
    check_transport(manifest, problems)

    if manifest.get("condition_c_has_been_run_on_heldout_v3") is not False:
        problems.append("the manifest no longer asserts C was never run on v3")

    model = manifest["model_configuration"]
    print(f"Condition C freeze — {manifest['freeze']}")
    print(f"  spec        {manifest['spec_version']}")
    print(f"  template    {manifest['prompt_template_version']}")
    print(f"  config      {manifest['config_version']}")
    print(f"  model       {model['model']} via {model['provider']},"
          f" n={model['samples_per_scenario']}")
    # Sampling is not printed because this transport cannot set it. Saying
    # "temperature 0" here when no such flag is sent would be the exact claim
    # the freeze is careful not to make.
    print(f"  sampling    not controllable through this transport;"
          f" deterministic output is not claimed")
    print(f"  hashes      {checked} recomputed")

    if problems:
        print(f"\ncheck_condition_c_freeze: FAIL ({len(problems)})")
        for problem in problems:
            print("  - " + problem)
        return 1
    print("\ncheck_condition_c_freeze: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
