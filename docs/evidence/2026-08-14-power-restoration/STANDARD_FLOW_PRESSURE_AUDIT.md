# Standard pre-Circuit pressure audit

**Date:** 2026-08-14  
**Harness:** `tests/standard_flow_pressure_audit.gd`  
**Reference viewport:** 1024×768  
**Movement model:** real Castle Hall A* routes, player base speed 180 px/s, current Guardian escalation rules, 230px pre-power flashlight.

## Standard critical-path measurements

| Hall exposure | A* distance | Minimum movement time | Guardian tier | Guardian speed | Return reaction budget |
| --- | ---: | ---: | ---: | ---: | ---: |
| Wake entrance → Chemistry | 2656px | 14.76s | 1 | 162.4 px/s | 4.78s |
| Chemistry return → Greenhouse | 2976px | 16.53s | 1 | 162.4 px/s | 4.78s |
| Greenhouse return → Circuit | 1376px | 7.64s | 2 | 179.8 px/s | 4.32s |

**Total forced Hall navigation before Circuit power:** 38.93 seconds.

## Interpretation

- The darkness is not one continuous 39-second tunnel. Chemistry and Greenhouse are safe investigation rooms between the three Hall exposures, producing a tension/rest/tension/rest/tension curve.
- Each individual darkness exposure remains below 18 seconds at base movement speed.
- Tier 2 leaves almost no sustained speed advantage (player 180 vs Guardian 179.8 px/s), so fairness must come from readable routing and an honest initial separation rather than making the Guardian slower.
- The former 520px return separation yielded only 2.76 seconds before possible contact at Tier 2. It was increased to 800px, yielding a worst-case 4.32-second reaction budget while preserving the requested +12% escalation.
- The power-restoration return replaces the redundant Guardian close-up with a 1.20-second route scan plus a 1.15-second safe reward-reading window. This creates one deliberate breather at the end of the blackout arc.

## Automated acceptance

- Every critical Hall route exists on the authored A* grid.
- Player remains faster than the Guardian through pre-Circuit Tier 2.
- Every darkness exposure is ≤18 seconds; total is ≤45 seconds.
- Every Hall return provides ≥4 seconds before possible contact.
- Power restoration progressively reveals all recorded route cells, updates the Map objective, and leaves Map immediately usable.

## Remaining release requirement

This is a deterministic systems/route playtest, not a substitute for a first-time human usability session. Before public release, one player unfamiliar with the map should complete Wake → Chemistry → Greenhouse → Circuit without developer guidance. Record wrong turns, deaths, time-to-Circuit, whether the 230px flashlight communicates walls clearly, and whether the 4.32-second minimum warning feels actionable.
