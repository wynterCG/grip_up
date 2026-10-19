# v1.1 locomotion refinement before M7

Spec: [grip_up_v1.1.md](../../specs/grip_up_v1.1.md).
Baseline source checkpoint: `6646cdeda0a0104b723c483905a9a4fc36e00674`.
Feature sources match the pre-M7 report's `d4fcaec` implementation.
Working branch: `feature/v1.1-locomotion-refinement`.
Rollback tag: `baseline/pre-v1.1-locomotion`.

| Milestone | Status |
|---|---|
| LP0 source freeze and runtime inspection | Complete; unchanged source manifest and live MCP settings archived |
| LP0 targeted 60/120 Hz regression | PASS: 782 checks / 28 runs, `lp0/attempt_001/results.json` |
| LP0 genuine designer baseline | Pending; no observations or ratings invented |
| LP1 instrumentation and diagnosis | Not started; existing trace available for LP0 |
| LP2 A1 movement coordination | Not started |
| LP3 B2 active feet | Not started |
| LP4 C1/C2 swing | Not started |
| LP5 demonstrated transition fixes | Not started |
| LP6 optional grip quality and camera | Not started; conditional on earlier acceptance |
| LP7 human A/B | Not started |
| LP8 narrow integration and pre-M7 decision | Not reached |

No gameplay, input, camera, collision, forces, torque budgets, startup defaults
or certified hybrid route have changed. There are no new experimental switches
claimed as implemented. The offline build is preserved as
`builds/GripUp-v1.0-pre-v1.1.exe` in both local project copies.

The read-only [physics audit](LP0_PHYSICS.md) identifies LP1 instrumentation
candidates: the generic swing-request field still reads the legacy request in
profile 4, and the coordinator's foot count excludes loaded SLIDING contacts.
The coordinator also estimates relative support velocity from hands only.
These observations have not been presented as human discomfort or fixed here.

The LP0 gate requires a playable reference plus prioritized genuine observations
on Step, Hang, Traverse, Corner and First Ascent. The supplied spec explicitly
says **“No rewriting before this gate.”** The [short playtest](LP0_PLAYTEST_PT.md)
uses existing Controls buttons; technical automation does not close this gate.

The engine audit reports Godot `4.7.2-stable (steam)` with hash
`ed1daf0bf001b61586d9930840f2f1394092c079`, integrated Jolt. Earlier reports used
the distribution label `official`; this runtime records `steam`. Version and
engine hash agree. Body mass, reach and all inspected force/target limits match
the report/spec reference values; no tuning correction was made.

The existing reactive-beam laboratory remains available for conservation checks.
No M7 counterweight level is authorized within this v1.1 refinement milestone.
