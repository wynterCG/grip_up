# v0.5 M2 conditional P2 study — not recommended as the default

Date: 2026-10-19. P1 comparison snapshot: `21d896b3219cd62de5ee65983b13b111c0b1cc0b`. P2 was authorized only after the measured roll/free-shoulder limitation in the P0/P1 study. P0/P1 results and their original handoff remain in [V05_M2_PHYSICS.md](V05_M2_PHYSICS.md).

**Decision: REJECT this P2 formulation as a default climbing improvement.** It is physically bounded and sometimes reduces tilt, but does not consistently improve useful reach windows. Keep P0/P1 recoverable and P2 explicitly experimental/off. Passing safety checks does not mean the hypothesis succeeded.

## Files and mechanism

New `scripts/supported_posture_refinement.gd`; narrowly scoped P2 branch in `climbing_controller.gd`; three new v0.5 tuning fields; additional cases in `tests/test_posture_study.gd`. No actuator, v0.4 absolute arm planner, base gains, strength, anatomy, body damping, input, camera, level geometry, E source, or editor/runtime session changed by this agent.

P2 uses `transfer_assist_enabled=true`, `posture_variant=2` in profile3, retaining P1 material-relative twist. It computes a soft gravity-upright preference only if actual current anchor/COM/shoulder geometry can support that orientation within anatomical length bounds and with an overhead load direction. It uses current support load and actual force moments. It never reads the pointer, next hold, route marker, desired climb height or a future target.

The target starts at the actual current body up direction and advances toward the feasible absolute gravity-up direction with rate≤0.8 rad/s and rate acceleration≤3 rad/s². Blend duration0.25 s is new; authority fades over0.10 s. Slip, infeasible geometry and observed saturation stop further target advancement with bounded braking, fade its effort, and have explicit telemetry reasons/flags. There is no positional integral or body-height target. Existing WASD fades posture authority by up to80% so deliberate swing remains possible.

The request uses the existing v0.4 tilt stiffness12, damping1.2 and actual shoulder-force moment compensation factor0.80. P2 **crossfades/replaces** the v0.4 tilt request; it does not stack a second tilt actuator on top. P0/P1 keep their old calculation. All twist/tilt/swing still share20 N·m, the resultant shoulder/leg/assist limit remains150 N·m and total hands remain360 N. The same equal/opposite support moment weights transmit reaction through the finite torque-capable gripper approximation. No pose/velocity assignment, unsupported force or automatic reach is added.

New telemetry lives in `transfer_posture.posture`: blend, target/preferred up, target rate/acceleration, actual target step, geometry margin, authority/load/manual factors, feasibility, slip/saturation flags, reason and requested torque. This is separate from the inherited P1 twist diagnostics. P2 can be selected for comparison, but should not be promoted as validated better control.

## Comparative evidence

**110/110 checks pass at120 Hz and60 Hz.** Commands remain:

```text
python tools/project.py test test_posture_study
python tools/project.py test test_posture_study -- --60hz
```

Reports: `builds/posture_study_120hz.json`, `_60hz.json`; logs: `builds/test_test_posture_study.log`, `_60hz.log`. These extend the earlier58-check P0/P1 study, retaining its assertions. Existing independent physics89/89 remains passing at each frequency, and diagnostic54/54 was rerun at60 Hz. Root owns the final full regression/native gate.

| Same physical fixture |120 Hz P0/P1→P2 |60 Hz P0/P1→P2 |
|---|---:|---:|
| HOLD neutral, tilt RMS |0.3732→0.2672 rad |0.3726→0.2664 rad |
| HOLD neutral, longest geometric+LOS shoulder window |0→0.342 s |0→0.317 s |
| HOLD initial roll, tilt RMS |0.4151→0.3045 rad |0.4138→0.3022 rad |
| HOLD initial roll, longest shoulder window |0.175→0.0667 s |0.1667→0 s |
| Same rolled fixture with existing v0.4 policyB, tilt RMS |0.3196→0.3054 rad |0.3160→0.3028 rad |
| Same policyB, longest shoulder window |0.625→0.517 s |0.5667→0.550 s |
| HOLD neutral, sampled third/first pendulum peak ratio |0.659→0.260 |0.658→0.259 |
| Timed pump, applied paired moment work |+5.44→+9.01 J |+5.94→+9.88 J |
| Opposing angular-phase brake, paired moment work |−2.32→−2.04 J |−2.43→−2.36 J |

The neutral improvement is real physical motion at unchanged limits, but not a general solution: the specifically rolled case becomes less catchable despite a more upright trunk. Existing policyB already provides much of the tilt effect; P2 adds only about4.5% RMS tilt improvement there and shortens the longest window. A geometric+LOS window is not a guaranteed actual catch; the existing finite hand-path lower bound is still reported separately.

Passive peak ratios include the bounded posture-settling transient, so they are not a clean small-signal damping coefficient. Nevertheless, P2 measurably changes the phase/decay and can suppress a useful reach window. That prevents claiming preserved neutral pendulum behavior from a lower tilt number alone. Pump/brake remain mechanically distinguishable, but P2 uses more positive moment work during the pump; no claim of zero extra motor work is made simply because the torque cap is unchanged.

P1's rotating-support axial improvement remains inherited by P2. The study still tests closed pair momentum; an additional **loaded** zero-gravity dynamic-support fixture actually exercises a nonzero P2 moment (not just the P1 twist term), verifies paired linear/angular momentum tolerances, and verifies no residual torque after the last grip releases. A25 mm initial actuator stroke seeds that fixture at unchanged gains/limits; it is explicitly fixture initialization, not a new player input shortcut.

## Safety and diagnostic checks

- Rate/acceleration caps, bounded activation/deactivation and pointer/body-state independence.
- Actual grip slipping stops target advance and fades posture effort; no integral windup.
- Observed allocator saturation stops advance. This adverse test temporarily **reduces** the fixture hand budget to80 N; it never increases force to pass a route. Infeasibility and saturation may coexist, with the first reason retaining priority and both flags preserved.
- Two real finite hand contacts and1→2→1 retain survivor targets and instantaneous momentum; original P1 cases remain.
- Asymmetric two-hand load allocation verifies that `SWING_AXIS_UNACTUATED` receives the exact applied allocation×blend shoulder lever, which differs from the unweighted shoulder mean. The existing diagnostic implementation already used the correct applied lever; this adds regression coverage rather than a physical change.
- No air assistance, shared force/torque limits and actual dynamic opposite moment.

The slip check samples the next posture step after integrity first detects SLIPPING: integrity runs after posture request calculation on the detection tick. This is one known physics-tick observation latency, not a hidden state/velocity reset. Comparisons between body pose and applied lever are taken from the same published controller sample to avoid mixing consecutive physics phases.

## Recommendation / limitations

Keep the experiment available only for explicit A/B inspection if desired, labelled unsuccessful as a robust transfer improvement. Do not enable it for the player by default, relax reach or increase torque to conceal the shorter windows. No further tuning sweep was performed solely to force a pass.

Root's human P0 ten-transfer completion is independent evidence that the basic route can work without this assistance. It does not remove the need for ratings/session repeatability, nor does it justify this P2 on its own. This specialist study does not claim human comfort improvement or a completed three-session comparison.

A future revision would need a more useful **feasible support-relative configuration** than generic upright tilt, with a separately justified mechanical objective and a new gate. It must still avoid next-cursor attraction, body snaps and extra strength. No such revision is implemented here. P0/P1 remain the recommended comparison states; this P2 hypothesis is not accepted.
