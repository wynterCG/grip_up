# v0.5 M0 — physics authority and evidence audit

Date: 2026-10-19. Scope: read-only inspection of current staging source and archived results, following the complete `grip_up_transfer_posture_reachability_spec_v0_5_en.md`. This document is the only file changed by this audit. No production, tuning, scene, or test changes; no new simulation or human-play claim. M1 diagnostics must precede assistance experiments.

## Verified current configuration

The running app constructs `resources/biped_tuning.gd`, which overrides the older robot defaults in `climbing_tuning.gd`. Reading only the base resource would report the wrong reach, hand speed, stiffness, and body geometry.

| Quantity | Current biped value / source |
|---|---|
| Engine/backend/physics | Godot 4.7.2 reported by existing logs; project Jolt, 120 Hz, interpolation on, maximum 16 physics steps/frame; 60 Hz comparison runners |
| Mass / COM | 12 kg / custom local COM zero; app `grip_up_lab.gd:229–237` |
| Body | One rigid body, compound torso/leg capsules, head sphere, flat sole; friction 0.12 |
| Body damping | Linear 0.08, angular 0.35, default COMBINE mode; project does not override world damping, so these are not the complete effective damping |
| Shoulder local coordinates | Left/right x = ±0.1919, y = 0.5241, z = 0.0153 m |
| Arm target interval | 0.18–0.62 m |
| Selectable anatomical reach | 0.54708 m skeletal chain + 0.11 m palm = 0.65708 m |
| Physical extension allowance | 0.04 m beyond target maximum; actual maximum 0.66 m |
| Axial actuator | K = 6000 N/m, D = 220 N·s/m; length error clamp 0.12 m; tension only, implicit effective-mass denominator |
| Hand budgets | Sum of force magnitudes ≤360 N, individual arm ≤360 N; default grip integrity capacity 260 N unless support metadata overrides |
| Torque budgets | Resultant shoulder-force moments + optional leg moments + attitude/swing ≤150 N·m; combined attitude/tilt/swing vector ≤20 N·m |
| Finite reaching | 4 m/s; approach distance 0.045 m; candidate timeout 0.65 s |
| Transition | Grip blend 0.10 s; allocation response 0.14 s; old directional-intent response 0.12 s |
| Baseline attitude | Angular damping coefficient 2 N·m·s when arm force sum >5 N; trunk twist stiffness 16 N·m/rad, damping 3 N·m·s |
| Supported swing | Requested 18 N·m maximum, 0.10 s input ramp, relative-axis angular-speed governor parameter 1.8 rad/s; still shares the 20 N·m cap |
| v0.4 B/C posture | Comfort extension ratio 0.30 →0.312 m; support clearance 0.24 m; target speed ≤0.25 m/s, acceleration ≤1 m/s²; settle timeout 2 s |
| v0.4 optional tilt | Stiffness 12 N·m/rad, damping 1.2 N·m·s, shoulder-force moment compensation factor 0.80; engagement ramp 0.20 s, manual swing fades this authority by up to80% |
| Optional Space | Charge extension 0.75 m/s for0.45 s; full pull2 m/s for0.30 s; cooldown0.45 s; no new force allowance |

App defaults at inspection: input profile2, posture policy1, independent posture/tilt/supported-WASD flags true, Space opt-in false, predictive grip false, physical feet false. v0.4 independent aim is opt-in profile3. Policies A/B/C are length-planning variants within v0.4, **not** the proposed v0.5 P0/P1/P2 attitude variants. P0 must preserve whichever existing policy is selected for the comparison.

Source fingerprints (SHA256, staging):

```text
climbing_controller.gd 73C2F1A64AC8FBE896344321ADAF67546C75CBF09347F546F1901483CE9C9722
climbing_tuning.gd    FCC8424E0B1340E7187F8FC278C8EEFB2FBA9E37C15EFBA73CCFF2719DC92054
biped_tuning.gd       B8A4F1AAA01C7563144DBBC10B80046FBB4A33FEDD7ADDF75989A028349714C3
```

## Physical authority and reaction path

`arm_actuator.gd` computes axial tension along actual shoulder→material-anchor separation. It uses both bodies' point velocities, rotational effective mass, nonnegative tension, and finite force allocation. The controller applies +F at the torso shoulder and −F at the support anchor (`climbing_controller.gd:780–783`). Since F is collinear with those two points, their total pair moment about any common origin cancels. The COM lever still creates legitimate torso rotation.

The current system is **not an ideal moment-free point grip**. `_compute_attitude_assist` adds trunk twist correction and angular damping; the v0.4 tilt block adds bounded attitude correction; `supported_swing.gd` adds a bounded reaction couple. The controller applies their common capped torque to the torso and the opposite torque to the gripped dynamic supports (`:785–791`). In profiles1/2/3 the shares are normalized allocation×grip-blend weights. Two hands on one body sum to one opposite torque rather than duplicating it. Static supports imply an unmodelled world reaction; a hinge can transmit reaction to the world as well.

The defensible model interpretation is a **finite torque-capable gripper/arm mechanism** with one shared20 N·m moment allowance. Its physical contact patch, pressure, frictional torsional capacity, and motor work are not explicitly modelled. Equal/opposite torque conserves momentum but does not prove a tiny free-surface hand contact could deliver that couple. Do not describe this as a moment generated solely by an ideal point tether, or use it as unquestioned human-biomechanics ground truth. P1/P2 must explicitly retain this approximation or separately authorize a moment-free comparison.

The150 N·m allocator caps the resultant, not the sum of absolute individual shoulder moments. Opposed moments can cancel physically. It is not a guarantee of150 N·m capacity at each hand. Feet have their own optional180 N budget and share the resultant torque cap; feet are disabled for this proposed initial study.

Important existing distinctions:

- Baseline angular damping acts on all torso angular velocity, not only twist, and uses absolute body spin.
- Twist uses the anatomical trunk axis and a heading frame cached during the supported gesture. It is not a world-Y Euler lock. Projection degeneracy fades authority continuously.
- Swing uses the true COM→shoulder lever, support-relative spin, cached world input direction, a ramp, and an angular-speed governor. A request parallel to that lever produces no moment; there is currently no explicit `SWING_AXIS_UNACTUATED` event.
- Tilt, twist, damping and swing compete for the same20 N·m vector allowance. Existing component telemetry does not provide an unambiguous raw-request/applied/saturation breakdown for every contribution.
- A speed governor does not mean zero actuator work under constant input: the mechanism can replace dissipated energy. Measure cumulative work and peak motion; do not claim a physical energy budget that is not implemented.
- The audited controller applies forces/torques; it does not impose climbing body pose or overwrite body velocity.

## Existing evidence and its limits

`docs/validation/v04/results.json` records **2012 checks, all passed**. Relevant suites pass at both120/60 Hz: independent physics89, independent input32, independent routes12, pendulum63, drag/swing physics101, capture matrix56. These are archived results inspected, not rerun by this audit. Root owns final snapshot/native archival; native37 checks at120 Hz were reported, with60 Hz validation in progress when this audit was requested.

Selected measured120/60 Hz values:

| Measurement | 120 Hz | 60 Hz |
|---|---:|---:|
| Passive single pendulum, third/first peak ratio, live | 0.63296 | 0.63407 |
| Same ratio, historical no-twist comparison | 0.63298 | 0.63408 |
| Live ±90° yaw perturbation, final error | 0.00967–0.01261 rad | 0.00930–0.01227 rad |
| No-twist comparison, final error | 1.516–1.532 rad | 1.515–1.531 rad |
| Live transfer peak jerk | 88.95 m/s³ | 86.73 m/s³ |
| Historical comparison transfer peak jerk | 195.65 m/s³ | 164.43 m/s³ |
| v0.4 passive tilt, assist off→on | 0.432→0.212 rad | 0.433→0.211 rad |
| v0.4 manual pump, horizontal amplitude / speed | 0.355 m /1.269 m/s | 0.357 m /1.266 m/s |
| Coast vs opposing WASD, signed endpoint velocity | +0.285→−0.335 m/s | +0.294→−0.345 m/s |
| Space new catch speed / retention | 2.313 m/s / >0.6 s | 2.255 m/s / >0.6 s |
| Closed dynamic beam launch, Δlinear momentum | 5.77e−6 kg·m/s | 3.84e−6 kg·m/s |
| Same, Δangular momentum / support Δspeed | 6.68e−6 kg·m²/s /0.138 m/s | 6.68e−6 kg·m²/s /0.141 m/s |

Sources: `v04/pendulum_{120,60}hz.txt`, `v04/independent_physics_{120,60}hz.txt`. The pendulum test's named `baseline` is an **older parameter comparison** (twist disabled, grip blend0.06, allocation0.10, intent smoothing0), not v0.5 P0. It demonstrates useful isolation, but jerk improvement is not attributable to twist alone. Its simple off-wall fixture does not establish that v0.4 posture tilt preserves all three-dimensional swings or solves wall transfers.

Existing authored left-lane routes pass12/12 at each frequency with deliberate A/D; this does not establish arbitrary center-lane success. The preserved adverse `v04/adverse/center_lane_depth_swing_120hz.json` supplies an actionable M0 reproduction:

- At0.16 m vertical spacing, policyB fails index6 at actual reach0.70584 m; C fails there at0.70677 m. Both exceed0.65708 m selectable reach by≈49 mm. Body positions≈(0.232,1.998,0.230), candidate(−0.1919,3.01,0). Immediate stage: **POSE_UNREACHABLE**, not evidence of catch overload or a hand too slow.
- At0.20 m spacing C fails index8 at0.69998 m, ≈43 mm beyond reach. B completes10 in that same archived set. Smaller vertical spacing is therefore not automatically easier; lateral body state and prior gestures matter.
- These runs' aggregate `failure` can be `manual`, while the event retains `rejection=out_of_reach`. Cleanup release reasons currently obscure the primary failure. Preserve event-time reasons before cleanup.

Human ten-transfer repeatability, comfort ratings, a classified failure video, and the three-session/two-completion target remain separate evidence gates. Passing automated suites does not close them.

## M1 first: minimum diagnostics, unchanged controls

1. Record one immutable attempt ID with press, target object/local material point, shoulder/hand/body states, complete finite hand-path timing, actual reach margin, and final release reason. Preserve rejection/catch/slip events before reset/manual cleanup can replace them.
2. Separate stages: pose/LOS availability; transit window and hand arrival; contact validity; retention/load. Map existing reasons into the v0.5 event vocabulary without inventing certainty. In particular, geometry beyond reach is `POSE_UNREACHABLE`; a forecast alone cannot prove `HAND_TOO_SLOW` or `CATCH_OVERLOAD`.
3. Add sampled support-relative measurements: anchor→COM pendulum angle/speed, anatomical twist angle/rate, trunk tilt, high-frequency residual, force/torque requested versus applied, saturation time and transitions. Keep the reference frame continuous across support changes and log undefined/singular cases rather than choosing discontinuous fallback axes.
4. Log work: axial `Σ F·(v_shoulder−v_anchor) dt`; paired moment `τ·(ω_body−Σwω_support) dt`; body/support kinetic and potential energy with external gravity/contact/joint/damping work explicitly outside the closed actuator budget. Check free dynamic pairs in zero gravity separately from world-hinged scenes.
5. Existing predictor is read-only,0.20 s horizon (clamped0.10–0.25), actual local moving points, finite hand paths, gravity and current arm-force extrapolation. It never authorizes future attachment; NOW is geometric eligibility, not instant contact. Existing0.15 s held buffer remains off for P0. Forecast assumes approximately constant spin/force, omits unknown future collisions/joint reactions; do not convert its current generic confidence label into a catch guarantee.

M1 gate: replay a preserved failure with unchanged P0 controls and identify the stage from actual measurements. Only then select an assistance experiment. Root owns route/UI/input/trace integration; the specialist should validate decomposition and force/work accounting without changing behavior.

## Minimal later P0/P1/P2 study proposal — not implemented

| Variant | Smallest controlled change | Fixed for fair comparison |
|---|---|---|
| P0 | Byte-equivalent v0.4 suspension/attitude/swing, with selected existing A/B/C policy recorded | Same geometry, start/contact states, force limits, body damping, K/D, reach, hand speed, Space off, feet off, buffer off |
| P1 | Refine only unhelpful axial twist: transported support-relative heading, relative twist rate, continuous authority fade and acquisition/release ramp. Measure replacing only the unwanted axial part of global damping; do not remove pendular damping blindly. | No new next-hold goal or auto-height; existing shared20/150 caps and reaction weights; freeze arm planner settings |
| P2 | Only if P1 leaves a measured geometric shoulder-placement defect: add a soft support/COM-informed feasible torso objective, using existing length authority and explicitly modelled finite grip moment. Bound angular target rate/acceleration and release authority under slip/saturation/player swing. | No pointer/next-candidate attraction, no repeated regrip height increment, no torso transform lock, no increased actuator power/force allowance |

Begin with one static single grip, neutral and timed lateral/depth pump/brake, ±yaw/roll initial fixture perturbations; then1→2→1, free translating/rotating beam, world-hinged beam, and catch-speed cases. Use identical seeds/fixtures and60/120 Hz. A zero-grip control must generate zero new airborne actuation. Include a mechanically degenerate swing axis and expose lack of authority rather than adding a thruster.

Evaluate axial twist RMS/settling, free-shoulder reach margin, passive pendulum decay/period, pump versus brake energy, torque saturation, path/contact/load failure counts, and momentum residuals. Reject a variant that merely immobilizes useful swing, changes the route or boosts reach. Only after isolated improvement should root run the same ten-transfer and separate swing-required routes, including human sessions. Keep P0 switchable throughout.

## Dependencies / next decision

- Root finalizes v0.4 snapshot commit and native60 Hz archive, and captures reproducible baseline failure footage/gesture sequence.
- M1 needs diagnostic-only event schema and frame definitions agreed across root trace/targeting and specialist measurements. No new assistance is authorized by this audit.
- Before P1, explicitly document the existing finite gripper torque mechanism and shared20 N·m cap. If the intended model is moment-free instead, that is a separate comparison with reduced authority, not a silent implementation detail.
- P2 is conditional on measured P1 failure, not a pre-approved automatic reach solver. No new strength, foot mechanics, full ragdoll, or Janga changes are proposed.

Decision at M0: **KEEP v0.4 as frozen comparison; proceed to M1 diagnostics only after root gate.** Existing evidence establishes bounded mechanics and several successful routes, not improved human v0.5 control.
