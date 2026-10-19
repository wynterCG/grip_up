# v0.8 physics mantle ? milestone ledger

Baseline: `9197172e50a9e78c481b9ed251725a3c9ccb3d1c` on the preserved
v0.7 mantle branch. Candidate branch: `feature/v0.8-physical-mantle`.
The supplied spec is archived as `docs/specs/grip_up_v0.8.md`.

| Milestone | Acceptance result | Decision |
|---|---|---|
| M0 baseline diagnosis | PASS: original saved checkout, 120 checks across both rates; runtime4.7.2/Jolt and tuning confirmed | KEEP baseline |
| M1 real palm compression | PASS isolated:49 axial +37 bent-arm/wrist checks per frequency, real dynamic reaction and finite shared budgets | KEEP opt-in |
| M2 lower-body collision clearance | PASS isolated:37 checks per frequency; both symmetric tuck and heel-back variants, loaded-contact guard and safe restoration | KEEP opt-in |
| M3 H0 / H1 | PARTIAL: H0 arrives and briefly carries load in integrated native/headless hang; stable handoff unproven. H1 unimplemented | REVISE |
| M4 strict low/high static top-out | FAIL: no actual top-ground support or completed walking in either ledge, both frequencies; attempts001?006 preserved | REVISE / no promotion |
| M5 dynamic/adversarial full mantle | GATED by failed M4; isolated dynamic palm and leg obstacle checks pass | NOT DEMONSTRATED |
| M6 human usability | No human ordinary-approach evaluation or H0/H1 comparison | NOT EVALUATED |

Final regression matrix: **4032 checks /129 suite runs, zero failures** at
60/120Hz (the static asset suite runs once). This includes legacy behavior and
new isolated/safety contracts. It explicitly excludes the failed M4 functional
runner: each final M4 run has8 checks with2 failed top-out assertions.
Godot MCP Pro rendered captures:32 isolated primitive checks and22 integration
safety checks, all passing; functional completion remains false.

Safety, geometry, physical progression, full top-out and human usability are
separate results. Passing primitives do not promote an unfinished gate.
All new features default OFF; profiles0?4 and the approved route are preserved.
Tests and editor are configured for monitor2 locally.

Raw failed functional attempts remain in `m4/attempt_001` through `attempt_006`.
The first M2 archive runner did not recognize its older25-passed footer; this
was a reporting-format mismatch, not a failed physical assertion. Integration
attempt001 read node state one callback too early; the corrected wait passes.
An invalid native capture against partially synchronized source was stopped;
its error receipt is retained under development and excluded from acceptance.

See [report and missing capability](report.md), [physics](M1_WRIST_H0_PHYSICS.md),
[lower-body geometry](m2/physics_report.md), [native receipts](native/) and
[regression results](results.json).
