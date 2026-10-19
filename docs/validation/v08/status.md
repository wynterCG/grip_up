# v0.8 physics mantle — milestone ledger

Baseline: `9197172e50a9e78c481b9ed251725a3c9ccb3d1c` on the preserved
v0.7 mantle branch. Candidate branch: `feature/v0.8-physical-mantle`.
The supplied spec is archived as `docs/specs/grip_up_v0.8.md`.

| Milestone | Acceptance result |
|---|---|
| M0 baseline diagnosis | PASS: original saved checkout, 120 checks at both rates; runtime 4.7.2/Jolt and tuning confirmed |
| M1 real palm compression | PASS in favorable isolated posture: 49 checks at each frequency; not a mantle |
| M2 collision-valid lower-body flexion | PASS in isolated fixture: 25 checks at each frequency; 0.400 m physical sole rise |
| M3 local hand transfer H0 / H1 | Not yet demonstrated |
| M4 strict static top-out, low and high ledges | FAIL in attempts 001/002; retained as failed functional evidence, not accepted |
| M5 dynamic/adversarial | Not yet demonstrated |
| M6 human usability | Pending actual player evaluation |

Safety, geometry, physical progression, full top-out and human usability are
separate results. No count of passing checks promotes an unfinished gate.

Defaults remain OFF. Legacy profiles, v0.7 route and M6 comparison are preserved.
The M2 attempt_001 log contains 25 passing checks; its older `25 passed, 0 failed`
footer was not recognized by the archive runner. That attempt's runner failure
is a reporting-format mismatch, distinct from a failed physical assertion.
Each `tools/run_mantle_v08.py` invocation archives a new attempt, including raw
failure output and measured JSON, rather than replacing a failed run.
