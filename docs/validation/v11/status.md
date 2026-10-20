# v1.1 locomotion refinement before M7

Spec: [grip_up_v1.1.md](../../specs/grip_up_v1.1.md). Detailed current
decisions: [report.md](report.md).

Baseline checkpoint: `6646cdeda0a0104b723c483905a9a4fc36e00674`.
Branch: `feature/v1.1-locomotion-refinement`.
Rollback tag: `baseline/pre-v1.1-locomotion`.

| Milestone | Status |
|---|---|
| LP0 source freeze and technical baseline | Complete; 782 checks / 28 runs, immutable historical manifest |
| LP0 genuine designer baseline | Pending; no observations or ratings invented |
| LP1 instrumentation and diagnosis | Implemented opt-in; 20 checks per frequency plus hybrid ownership regression |
| LP2 A1 movement coordination | Implemented; **REVISE**. Useful motion/twist regress; high ledge fails at 60 Hz. A0 retained. A2 not implemented |
| LP3 B2 active feet | Local ranking implemented; 29 checks per frequency. Local directional benefit, general benefit unproven. B1 retained |
| LP4 C1/C2 swing | Feedback-only pilot delivered; no revised physics frame/damping or C2. Human gate pending |
| LP5 transitions | Read-only windows and relevant regressions delivered; no demonstrated physical ownership bug requiring motor rewrite. Full feel audit remains open |
| LP6 optional grip quality and camera | Deferred as spec requires earlier acceptance; neither implemented |
| LP7 human A/B | Pending; no session/rating fabricated |
| LP8 narrow integration and pre-M7 decision | Technical candidate tested/exported separately; **NO-GO for default promotion** and no M7 content |

The designer explicitly directed implementation from the supplied spec instead
of another baseline questionnaire. Isolated opt-in experiments therefore proceed;
that steering does not invent human results or authorize promotion. The original
[short baseline protocol](LP0_PLAYTEST_PT.md) remains a historical test aid.

The engine audit reports Godot `4.7.2-stable (steam)`, hash
`ed1daf0bf001b61586d9930840f2f1394092c079`, Jolt. The export prints the distribution
label `official` with the same version/hash; no engine upgrade is inferred.

A0/B1 and profile2 startup remain. Body mass, reach, force/torque limits, finite
contact, static hybrid route and Janga are preserved. Offline baseline:
`builds/GripUp-v1.0-pre-v1.1.exe`. The existing reactive-beam laboratory remains
available; it is not the future M7 counterweight challenge.
