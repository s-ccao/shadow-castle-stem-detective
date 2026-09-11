#!/usr/bin/env python3
"""Verify the Condition C freeze manifest against the files on disk.

A manifest of hashes is only worth what checking it costs. This recomputes every
sha256 in `docs/condition_c_freeze_manifest.json` and fails on any drift, so
"Condition C is frozen" is a statement that can be tested rather than trusted.

It also re-checks three things the manifest asserts but a hash alone cannot:

  * the three heldout-v3 artifacts listed as untouched really do still carry the
    hashes the closed experiment recorded;
  * the spec, template and config agree on their version strings, so a run
    citing `condition-c-v1` cannot be citing three different things;
  * the implementation names the frozen template and config paths, and contains
    no call to Condition A or Condition B.

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

    config = json.loads((REPO / "config" / "condition_c_model_v1.json").read_text())
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
        ("CONFIG_PATH", "res://config/condition_c_model_v1.json"),
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


def main() -> int:
    manifest = json.loads(MANIFEST.read_text())
    problems: list[str] = []

    checked = check_hashes(manifest, problems)
    check_versions(manifest, problems)
    check_isolation(problems)

    if manifest.get("condition_c_has_been_run_on_heldout_v3") is not False:
        problems.append("the manifest no longer asserts C was never run on v3")

    print(f"Condition C freeze — {manifest['freeze']}")
    print(f"  spec        {manifest['spec_version']}")
    print(f"  template    {manifest['prompt_template_version']}")
    print(f"  config      {manifest['config_version']}")
    print(f"  model       {manifest['model_configuration']['model']}"
          f" @ temperature {manifest['model_configuration']['temperature']},"
          f" n={manifest['model_configuration']['samples_per_scenario']}")
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
