# v0.6 M2 — moving workspace and collision recovery

Reference M1 snapshot: `6e17fe6`. M2 code is staging C only. Attachment remains disabled in the new held-target branch: reaching a real valid contact candidate does not yet set ATTACHED, apply arm effort or claim catch success. Root owns app/native gate evidence and the next checkpoint.

## Changes

- `scripts/pending_grip_target.gd`: current shoulder-frame transport, finite relative gesture, actual material-local moving target, swept normal approach/released-surface departure, one conservative swept retraction for rounded flanks, temporary obstruction recovery and explicit infeasible-segment handling.
- `scripts/climbing_controller.gd`: passes geometry/tuning into that isolated branch, exposes pending transition events, clears impossible attempts, and retains the invalid historical-pose flag until finite FREE recovery really returns inside anatomy. Legacy request/buffer/update/force branches are unchanged.
- `resources/climbing_tuning.gd`: new-only `pending_reach_label_hysteresis=.003m`. It changes labels; physical reach eligibility remains the existing .65708m with the existing small numeric tolerance.
- `scripts/grip_anchor.gd`: approved opt-in `use_actual_center_of_mass=false` property. Only anchors created by `request_held_grip` set it true. This corrects material-point velocity for AUTO-COM supports without changing legacy anchor expressions.
- `tests/test_pending_motion.gd`: standalone 32 checks. M1 runner remains 32 checks; its own target serial is now explicitly named `target_selection_id`.

## Physical contract

Each pending tick transports the previous hand point by the actual successive shoulder frames, then requests at most4m/s muscle motion relative to that carried point. The full world endpoint segment is collision queried. The usable prefix is analytically intersected with both the current anatomical sphere and the current relative-gesture sphere. A collision never introduces an off-segment normal displacement or an extra movement allowance.

If that intersection is empty, the attempt is cancelled with `WORKSPACE_SWEEP_CONFLICT`, anchor/effort cleared, `active=false` and `endpoint_valid=false`. The returned old point is explicitly historical data, not a valid physical hand pose. Root's visual adapter uses a labelled passive anatomical fallback. No phantom endpoint is published as a successful reach. Actual FREE recovery is finite; the validity flag is restored only when the endpoint really reenters the workspace. The degenerate test is an explicitly adversarial frame/obstacle unit fixture using a real collision query; it does not pretend that a normal gameplay torso teleported through a wall.

Targets retain the same local point and normal throughout body translation/rotation, target translation and a real Jolt hinge swing. Out-of-range/temporarily blocked attempts keep their acquisition time and target. The helper approaches the visible side along the normal, retreats along a clear swept route when a rounded flank blocks a diagonal, and reuses an outward departure from a released surface. There is no general pathfinder and no guarantee of reaching a selectable surface from every pose.

Hysteresis applies only to `label_in_reach`/`transition_count`; `physical_in_reach`, raw margin and separate `physical_transition_count` still report the actual envelope. A label may intentionally remain reachable just outside the envelope, but cannot grant contact. Reversible blocked/clear and reach transitions do not become permanent transfer failures.

`attempt_id` is the real current transfer-journal attempt when diagnostics are enabled, otherwise-1. `target_selection_id` is a distinct controller selection serial. Compact diagnostics now also report endpoint validity, phase, actual target velocity and both raw/hysteretic reach state. The event journal remains bounded; no per-frame history array was added.

## AUTO COM evidence and deliberately narrow correction

A real dynamic support with its shape offset(.30,.12,-.08), AUTO COM and angular velocity(0,0,1) exposes a .323110m/s difference between the legacy anchor velocity and the actual material-point velocity around the physics COM. The new opt-in anchor uses `global_position + direct_state.center_of_mass` when available, and falls back to the original property expression otherwise. The test verifies the corrected velocity to1e-6m/s and exact equality of an unmodified legacy anchor with its old expression at the same physical epoch.

`arm_actuator.gd` was not edited. Its rotational effective-mass estimate for an asymmetric AUTO-COM support remains a known baseline approximation. The correction does not establish exact AUTO-COM catch loads or change caps, gains, masses, angular damping, planner objectives or force/reaction algorithms. Authored reactive beams use custom COM and do not rely on that approximation.

## Results

| Suite |120Hz|60Hz|
|---|---:|---:|
|M2 pending motion|32/32|32/32|
|M1 pending selection/cancel|32/32|32/32|
|Original physics|45/45|45/45|
|Existing transfer capture|25/25|25/25|

Commands: `python tools/project.py test test_pending_motion` and `python tools/project.py test test_pending_motion -- --60hz`. Logs: `builds/test_test_pending_motion.log` / `_60hz.log`; structured data: `builds/pending_grip_m2_120hz.json` / `_60hz.json`. Other suite logs follow the same names.60Hz retains the environment's unrelated certificate-store warning, with passing suite footer and no script errors.

The natural torso fixture starts with(.25,.3,0)m/s translation and(.12,.16,-.10)rad/s spin, then evolves entirely through physics. Across72 samples at120Hz, predicted shoulder transport versus applied transport had exactly zero residual; maximum transport speed .5170m/s and measured relative gesture maximum4.0000153m/s (float32 subtraction noise). No precontact force or support was created.

A separate upward-moving torso brings an initially distant static point into reach, reaches the exact selected point without another press and passes no attachment authority at M2. Translating and real hinged support fixtures likewise retain the material point and produce an actual endpoint that passes the unchanged CaptureEvaluator at a real contact candidate. These checks run from the same `sample_ready` epoch as transforms; comparing a previous diagnostic snapshot with a later server transform produced a false one-tick error in the first test draft, which was corrected in the runner rather than in production physics.

The hinge begins with .8rad/s physical angular velocity and a consistent pivot-point velocity, no motor and no transform updates. Its selected point starts .85695m from the shoulder and enters the existing envelope at both frequencies. Material tracking error in the same-epoch sample is zero; no target retargeting or force activation occurs.

When the un-attached M2 hand has touched the moving surface, later motion may again be blocked by that surface: this gate does not invent frictionless free-hand sliding or a hidden temporary grip. M3 must establish the actual grip at a valid contact candidate before switching to material-anchor following. This is why candidate arrival, actual attachment and retention remain separate claims.

Other checks cover: obstacle introduced during travel, no crossing while closed, persistence beyond old timeout, finite resumption after reopening, rounded-flank regression, released-wall normal departure, geometric label hysteresis, impossibility cancellation and validity recovery. M1 lifecycle tests continue to cover release, flag disable, object destruction/ungrabbability, profile change and reset. No new-branch ATTACHED event, force or physical body write exists at this milestone.

## Recommendation

M2 physics gate T2/T4/T5: PASS for the tested motion/collision cases. Freeze this result for root checkpoint before enabling attachment. No claim of human ten-transfer improvement, guaranteed high-speed catches, full arm-volume collision, arbitrary pathfinding or exact AUTO-COM load prediction is made. Point ray sweeps retain the prototype's virtual-hand collision model; large rotation is treated by its discrete full endpoint segment.
