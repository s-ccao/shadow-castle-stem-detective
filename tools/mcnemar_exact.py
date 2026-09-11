#!/usr/bin/env python3
"""Exact paired binary tests for the held-out v4 relevance comparison.

This is the preregistered analysis code for `docs/EVALUATION_PROTOCOL.md` §12.5,
and it is committed *before* heldout-v4 exists. That ordering is the point: an
exact test written after seeing the data is a choice about the data, while one
written before it is a commitment.

Conditions A, B and C are scored on the same scenarios, so their per-scenario
relevance outcomes are paired. Only the discordant pairs carry information about
a difference, and with 48 CORE scenarios there may be very few of them -- which
is exactly the regime where a normal approximation misleads. Hence the exact
binomial form of McNemar's test rather than the chi-square one.

Probabilities are computed in exact rational arithmetic and converted to float
only on the way out, so a p-value near the reporting threshold is not an artefact
of accumulated rounding.

    python3 tools/mcnemar_exact.py --self-test
"""

from __future__ import annotations

import math
import sys
from fractions import Fraction
from typing import Iterable, Sequence


def paired_table(x: Sequence[bool], y: Sequence[bool]) -> tuple[int, int, int, int]:
    """The 2x2 paired table (a, b, c, d) for two aligned outcome vectors.

        a = both succeeded      b = x succeeded, y failed
        c = x failed, y succeeded               d = both failed

    `b` and `c` are the discordant counts; `a` and `d` carry no information
    about a difference and are returned only for reporting.
    """
    if len(x) != len(y):
        raise ValueError(f"unpaired vectors: {len(x)} vs {len(y)}")
    a = b = c = d = 0
    for xi, yi in zip(x, y):
        if xi and yi:
            a += 1
        elif xi and not yi:
            b += 1
        elif yi and not xi:
            c += 1
        else:
            d += 1
    return a, b, c, d


def exact_p(b: int, c: int) -> float:
    """Two-sided exact McNemar p-value from the discordant counts.

    Under the null the direction of each discordant pair is a fair coin, so
    b ~ Binomial(b + c, 1/2). The two-sided p-value doubles the lower tail, which
    is exact here because the null distribution is symmetric.

    With no discordant pairs the data contain no evidence either way and the
    p-value is 1.0 -- not an error, and not significance.
    """
    if b < 0 or c < 0:
        raise ValueError("discordant counts must be non-negative")
    n = b + c
    if n == 0:
        return 1.0
    m = min(b, c)
    tail = Fraction(sum(math.comb(n, k) for k in range(m + 1)), 2 ** n)
    return float(min(Fraction(1), 2 * tail))


def compare(name_x: str, x: Sequence[bool], name_y: str, y: Sequence[bool]) -> dict:
    """One preregistered pairwise comparison, with everything §12.5 requires."""
    a, b, c, d = paired_table(x, y)
    n = len(x)
    nx, ny = sum(1 for v in x if v), sum(1 for v in y if v)
    rx, ry = (nx / n if n else 0.0), (ny / n if n else 0.0)
    discordant = b + c
    if b > c:
        direction = f"{name_x} > {name_y}"
    elif c > b:
        direction = f"{name_y} > {name_x}"
    else:
        direction = "no difference"
    return {
        "comparison": f"{name_x} vs {name_y}",
        "n": n,
        name_x: {"numerator": nx, "denominator": n, "rate": rx},
        name_y: {"numerator": ny, "denominator": n, "rate": ry},
        "difference_pp": round((rx - ry) * 100, 4),
        "abs_difference_pp": round(abs(rx - ry) * 100, 4),
        "table": {"both": a, f"{name_x}_only": b, f"{name_y}_only": c, "neither": d},
        "discordant_b": b,
        "discordant_c": c,
        "discordant_total": discordant,
        "p_exact": exact_p(b, c),
        "direction": direction,
        "low_information": discordant < 5,
    }


def holm(pvalues: Iterable[float]) -> list[float]:
    """Holm step-down adjustment, preserving input order.

    Reported alongside the unadjusted values, never instead of them: §12.5 makes
    the unadjusted exact p-value the primary reporting and requires any
    significance claim to say which of the two it is using.
    """
    ps = list(pvalues)
    m = len(ps)
    order = sorted(range(m), key=lambda i: ps[i])
    out = [0.0] * m
    running = 0.0
    for rank, i in enumerate(order):
        running = max(running, min(1.0, (m - rank) * ps[i]))
        out[i] = running
    return out


# ---------------------------------------------------------------------------
# Self-tests. A statistical routine that is only ever run on real data has never
# been checked against an answer anyone knows independently.


def _self_test() -> int:
    failures: list[str] = []

    def check(label: str, got, want) -> None:
        if got != want:
            failures.append(f"{label}: got {got!r}, want {want!r}")

    # Closed forms. Each is 2 * P(X <= min(b,c)) for X ~ Binomial(b+c, 1/2),
    # computable by hand, so these pin the arithmetic to an answer derived
    # outside the code rather than to the code's own output.
    check("b=0,c=0", exact_p(0, 0), 1.0)
    check("b=1,c=0", exact_p(1, 0), 1.0)            # 2 * 1/2
    check("b=2,c=0", exact_p(2, 0), 0.5)            # 2 * 1/4
    check("b=3,c=0", exact_p(3, 0), 0.25)           # 2 * 1/8
    check("b=10,c=0", exact_p(10, 0), 2 / 1024)
    check("b=5,c=1", exact_p(5, 1), 14 / 64)        # 2 * (C(6,0)+C(6,1)) / 2^6
    check("b=4,c=4", exact_p(4, 4), 1.0)            # capped at 1
    check("b=7,c=2", exact_p(7, 2), 2 * (1 + 9 + 36) / 512)

    # Symmetry: the test cannot know which condition was named first.
    for b, c in ((0, 3), (2, 9), (5, 1), (13, 4)):
        check(f"symmetry {b},{c}", exact_p(b, c), exact_p(c, b))

    # Monotone in the imbalance, and bounded.
    seq = [exact_p(k, 0) for k in range(1, 12)]
    if seq != sorted(seq, reverse=True):
        failures.append("p is not monotone decreasing in the imbalance")
    if not all(0.0 <= p <= 1.0 for p in seq):
        failures.append("p escaped [0, 1]")

    # The doubling is real: a one-sided implementation would pass the bounds
    # checks above while halving every reported value, so pin the factor.
    if exact_p(6, 0) != 2 * (Fraction(1, 2 ** 6)):
        failures.append("the two-sided doubling is missing")

    # Concordant pairs must not move the answer -- the whole premise of pairing.
    n = 40
    x = [True] * 30 + [False] * 10
    y = list(x)
    y[0] = False          # one discordant pair, x-favouring
    y[35] = True          # one discordant pair, y-favouring
    r = compare("A", x, "B", y)
    check("discordant b", r["discordant_b"], 1)
    check("discordant c", r["discordant_c"], 1)
    check("p on 1-1", r["p_exact"], 1.0)
    check("direction on 1-1", r["direction"], "no difference")
    check("low_information flagged", r["low_information"], True)

    # A clean separation, with the numerators the protocol requires reported.
    x = [True] * 20 + [False] * 20
    y = [True] * 12 + [False] * 28
    r = compare("A", x, "B", y)
    check("A numerator", r["A"]["numerator"], 20)
    check("B numerator", r["B"]["numerator"], 12)
    check("denominator", r["A"]["denominator"], 40)
    check("pp difference", r["abs_difference_pp"], 20.0)
    check("b", r["discordant_b"], 8)
    check("c", r["discordant_c"], 0)
    check("p", r["p_exact"], 2 / 256)
    check("direction", r["direction"], "A > B")
    check("not low information", r["low_information"], False)

    # The table must account for every scenario, or the pairing is broken.
    t = r["table"]
    check("table sums to n", t["both"] + t["A_only"] + t["B_only"] + t["neither"], 40)

    # Unpaired input is an error, not a silent truncation.
    try:
        paired_table([True, False], [True])
        failures.append("unpaired vectors were accepted")
    except ValueError:
        pass

    # Holm: order preserved, monotone, never below the unadjusted value, and it
    # actually adjusts (a pass-through implementation would fail the third).
    ps = [0.01, 0.04, 0.03]
    adj = holm(ps)
    check("holm smallest", round(adj[0], 10), 0.03)
    check("holm largest", round(adj[1], 10), 0.06)
    check("holm middle", round(adj[2], 10), 0.06)
    if any(a < p for a, p in zip(adj, ps)):
        failures.append("holm produced a value below the unadjusted p")
    if adj == ps:
        failures.append("holm is a pass-through")
    check("holm caps at 1", holm([0.9, 0.8, 0.7]), [1.0, 1.0, 1.0])

    if failures:
        print(f"mcnemar_exact self-test: FAIL ({len(failures)})")
        for f in failures:
            print("  - " + f)
        return 1
    print("mcnemar_exact self-test: PASS")
    print("  exact two-sided McNemar, rational arithmetic, Holm adjustment")
    print("  committed before heldout-v4 exists")
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv or len(sys.argv) == 1:
        sys.exit(_self_test())
    print(__doc__)
    sys.exit(0)
