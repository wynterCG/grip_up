# v0.6 M1 physical targeting gate

M0 reference: `fb56d1f`, feature/v0.6-out-of-reach-targeting. Work is limited to staging C. No canonical E files, running editor, or native session were changed by the physics agent.

## Implemented boundary

- `resources/climbing_tuning.gd`: additive `allow_out_of_reach_grip_targets=false`. Existing gains, strength, reach, timeouts and predictive settings are unchanged.
- `scripts/climbing_controller.gd`: `request_held_grip`, `set_hand_held`, `pending_diagnostics`; separate branch for latched selections. Cancellation/reset/profile changes clear the selected hand. A purely pending hand is excluded from new physical-foot activation as well as existing arm support/allocation.
- `scripts/pending_grip_target.gd`: material-local weak anchor, immutable compact snapshots, finite shoulder-relative gesture and full world-segment collision query. No body force/torque or pose/velocity assignment.
- `tests/test_pending_grip.gd`: 32 independent checks per physics frequency.

This is deliberately **M1 only**. The new held-target branch cannot become ATTACHED yet. Existing `request_grip` and the v0.2/v0.5 buffered paths remain available and unchanged. Acquire a left support through that existing path for M1 app scenarios. Moving-world contact progression, obstruction recovery and attachment/handoff are later gates; they have not been declared validated by this result.

## API

`request_held_grip(id, support, world_point, normal) -> bool`: with the new flag OFF, delegates to the existing unbuffered request exactly. With it ON, validates an alive eligible support and finite sampled point/normal, remembers a single material point and reports selection success. Camera visibility/selection eligibility remains the app's responsibility. Initial anatomical distance and physical shoulder obstruction do not reject an otherwise valid selection. No predictor or buffer horizon is consulted.

`set_hand_held(id, held, reason="input_released")`: false synchronously releases/cancels only that selected hand. True cannot resurrect a cancelled gesture. Release, invalid/ungrabbable support, disabling the flag, profile change and reset also invalidate the attempt.

`pending_diagnostics(id) -> Dictionary`: a deep copy, bounded to one record per hand. Fields include active/held, attempt_id/selected_time, support_id/local_point/local_normal, target_world/normal_world, shoulder_world/hand_world/hand_goal, distance/reach_margin, pending_time/transition_count, blocked/blocker_id, world/gesture/transport velocity and speed, target_relative_speed, workspace_valid/reason and contact/load placeholders. No unbounded per-frame event arrays are returned. Selected-attempt events reuse `transfer_event` and its bounded journal when diagnostics are enabled.

Public compatibility state is REACHING with a pending substate. The hand has zero allocation/force/reaction force. It contributes neither support torque nor an independent force budget, and it cannot trigger the absolute support-posture planner as a physical anchor.

## Motion convention and collision limitation

The endpoint is carried by the current physical shoulder frame; its own muscle gesture then advances at the unchanged 4m/s relative to that frame. World transport and gesture are reported separately, with `world_velocity = transport_velocity + gesture_velocity`. This allows a real moving shoulder to carry its free arm without pretending that body transport is hand actuation. The full world segment is ray-swept. A blocking intersection clips along that segment, without adding an outward-normal jump.

A moving shoulder and obstacle can make the collision constraint and anatomical envelope mutually infeasible. The helper exposes `workspace_sweep_conflict`/`workspace_valid=false`; it never attaches or produces effort in that condition. M1's static fixture has no such conflict. **A safe render/retraction/recovery policy and actual moving-world cases must be agreed and tested at M2 before claiming an every-frame anatomical guarantee in arbitrary moving geometry.** No hidden clamp/teleport was used to conceal that unsolved case. Hysteresis for moving boundary labels also remains M2 work; the physical authorization limit will not be increased.

The normal approach/strict CaptureEvaluator check is not enabled as an attachment path at this gate. M2/M3 must reuse the existing final actual-surface validation independently of old predictive flags; the legacy6cm broad visibility allowance alone cannot authorize a new grip.

## Reproducible results

```
python tools/project.py test test_pending_grip
python tools/project.py test test_pending_grip -- --60hz
```

| Suite |120Hz|60Hz|
|---|---:|---:|
|New pending M1|32/32|32/32|
|Original physics|45/45|45/45|
|Existing v0.5 transfer capture|25/25|25/25|

Logs: `builds/test_test_pending_grip.log`, `builds/test_test_pending_grip_60hz.log`, equivalent physics/transfer_capture logs. Structured reports: `builds/pending_grip_m1_120hz.json`, `builds/pending_grip_m1_60hz.json`.

The static target remains selected for2s, beyond the old candidate .65s and predictive .15s timeouts, but never attaches. Maximum extension measured .657080114m against .65708m anatomical reach. Maximum measured gesture speed was4.00001097m/s at120Hz and4.00001049m/s at60Hz: float32 position subtraction noise, covered by a stated .0001m/s numeric tolerance. World/transport/gesture decomposition residual was exactly zero in this static fixture. Body transform, linear velocity and angular velocity stayed exactly unchanged and force/torque stayed zero.

For a separate physical support fixture, the left hand first makes a real finite legacy catch. Gravity is then enabled as a fixture load; no live body pose or velocity is assigned. With/without an additional distant right selection, the left load, complete body transform and both velocities are exactly equal at each frequency's final sample. Peak real left-hand load was219.80N at120Hz and216.67N at60Hz; pending right load/allocation stayed zero, with the left material anchor/rest length unchanged. This establishes lack of attraction or support-budget sharing by the pending target, rather than merely testing a stationary zero-gravity body.

Cancellation is synchronous, cannot revive on a later held=true call, and cannot release the other support. Tests cover flag OFF rejection and exact legacy valid-catch trajectory equality, flag disable, destroyed/ungrabbable support, reset and profile changes. Camera/UI/focus event routing remains root app-test ownership. The standard Windows root-certificate-store warning appears on60Hz headless runs; all required suite footers pass without script errors.

## Gate recommendation

M1 physics T1/T3 gate: PASS. No new-branch grip attached early: the branch cannot attach at this milestone. Do not infer ten-transfer improvement, moving support correctness or human usability from M1. Await the root's M1 acceptance before M2 or a COM-AUTO correction; no COM, actuator, planner or force algorithm was changed here.
