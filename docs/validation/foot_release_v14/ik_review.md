# v1.4 F0 — independent visual / IK source review

**Scope: source inspection only. No runtime reproduction, engine launch, native capture or human-feel observation was performed by this reviewer.** This document follows the principal agent's `F0_READY` baseline freeze. It does not authorize B3 or claim that an actuator, collider or IK has caused the reported sticky foot.

The initial review wrote only this new diagnostic document. A subsequent explicitly assigned diagnostic-only change to the new opt-in observer is described below. No gameplay source, scene, tuning, historical receipt, Git state, E-drive mirror or native session was changed by the reviewer. Runtime B0/B1 reproduction and source identities belong to the principal agent's F0 evidence.

## Verified source configuration

- The normal biped remains one dynamic12kg body. Its lower capsule is0.84m tall, radius0.15m, centerY−0.4967. `FootBase` is a0.36×0.08×0.28m box at(0,−0.8767,−0.035), independent of visual ankle targets. Body friction remains0.12. These colliders remain present with physical foot actuatorsOFF.
- Foot tuning matches the reference:180N total,120N each,1800N/m spring,100N·s/m damping,25mm preload,0.12s engagement,2m/s planting and nominal friction0.85 limited by material. This review changes none of them.
- First Ascent is level21 and enables physical feet through `_open_first_ascent`. Its body has `max_contacts_reported=16`. The entry does not itself force A0 or B1: existing movement-allocation and B2-selection UI settings may be inherited. Controlled B0/B1 runs must record the actual flags and explicitly use the intended A0/B1 comparison setup.

## Findings established by source, not runtime observations

### 1. A zero-force SUPPORTING foot can still have a fully anchored visual target

`foot_contact_solver.prepare` can compute effortzero when the leg is no longer compressed. It nevertheless sets the state to `SUPPORTING` whenever friction excess is≤0.05. The same real material-local point can remain valid within the anatomical workspace even while contributing no actuator force. That is not a tensile constraint by itself.

`biped_visual._physics_process` unconditionally constrains the render leg to the solver ankle whenever the physical-foot state is `PLANTING`, `SUPPORTING` or `SLIDING`. It does not inspect admitted force, normal force or load-in before selecting that target. `PhysicalLimbIK.influence` is a shared scalar for the four limb settings and rises toward1 while climbing; there is no current per-foot physical-load IK weight.

Consequently, **a zero-force apparently planted foot is possible by source design**. This may be an appropriate stable foot placement, or it may contribute to the designer's visual symptom. It is not evidence that physical foot force is pinning the body. F0 must compare actual COM progress and force/intent measurements against the rendered foot before choosing a correction.

### 2. Ground ownership can deliberately discard foot force while preserving its visual state

For profile4, `climbing_controller` removes foot requests on the same collider already owned by genuine ground support, preventing duplicate support force. It does not turn those feet into `FREE`; their `SUPPORTING`/`SLIDING` states and anatomical ankle positions can persist while their current committed force iszero.

During actual hand climbing, the visual rig can still use those ankle states at full climbing IK influence. F0 should record `request filtered because same ground owner` separately from an opposing loaded foot. Otherwise a valid double-count prevention rule could be misclassified as invisible physical glue.

### 3. Visual surface retention also exists with B0 feetOFF

Before the physical-foot target override, `biped_visual` raycasts down around each current passive foot. A reachable horizontal hit becomes a render-only ground target. `biped_leg_motion.step` then approaches that world target. Additional hip-to-foot and toe rays constrain visual feet against solids.

These visual surface contacts do not depend on the physical-foot actuator being enabled. A passive foot can therefore remain visually near the same surface while the pelvis moves until probe, workspace or leg-length conditions change. This is a plausible B0 visual retention mechanism, not a native or explicit limb-force constraint. B0 is a necessary control; a persistently pinned-looking foot in B0 would not justify a B3 actuator fix by itself.

### 4. Explicit physical release stops the old physical-anchor override

`foot_contact_solver._release` changes state to `SEARCHING` and clears `support`; it retains historical ankle/contact/local-point fields. The visual hard-anchor branch excludes `FREE` and `SEARCHING`. There is no source path that directly keeps the old **physical** anchor selected merely because the historical ankle field survives a release.

The passive leg starts from its current direction/length and evolves continuously. The independent visual floor/toe contacts in finding3 may still influence it. A historical contact point printed after release is not a live anchor unless ownership/state/support validity establish that fact.

### 5. Existing physical-foot mismatch values are not First Ascent observations

`biped_visual._measure_physical_foot_error` measures an error only when an active `adaptive_legs` object exists. First Ascent normally has no such v0.8 metadata. Therefore `physical_foot_mismatch` remaining at its initialized0 is **not** proof of zero First Ascent visual/physical error. Mark this existing field `NOT_MEASURED` in that context.

### 6. Hybrid presentation owns a different path and clock

When `mantle_driver.is_driving()` is true, the ordinary visual update and passive leg physics return early. The mantle driver owns authored targets and its own IK. Ordinary `leg_motion` caches during this interval are not current physical-foot evidence. Hybrid retirement resets the foot solver; old ordinary caches must not be interpreted as a live actuator or planted contact.

The relevant region identified by the designer is the first wall's lateral transfer toward the bars, before top-out. Hybrid ownership should still be recorded, but should not be assumed to explain that location.

## Recommended F0 diagnostic access

|Quantity|Source/access|Interpretation|
|---|---|---|
|Actual native sole collider|`torso.get_node("FootBase").global_transform` and its actual shape size|Gameplay collider, not a render ankle|
|Native lower capsule|`torso.get_node("LowerCapsule").global_transform`, actual capsule dimensions|Native lower-body occupied region|
|Physical model hip|`torso.global_transform * feet_solver._hips[id]`|Use with the same physics sample's ankle and workspace limits|
|Physical solver ankle|`feet_solver.feet[id].ankle`|Meaning depends on current state; historical after release|
|This-tick applied contact|`foot.contact_point`, `foot.normal`, `foot.force`, `normal_force`, `tangent_force`|Admitted actuator request/commit, not native Jolt impulse|
|Live material anchor|`foot.support.to_global(foot.local_point)` with valid support/state|A material point; never a substitute for current applied-load evidence|
|Load-in|`foot.blend`|Engagement weight, not by itself actual force|
|Passive desired visual foot|`biped.leg_motion.feet[id]`|Physics-updated render target before interpolation|
|Actual IK target node|`biped.targets[id+2].global_position`|Render-interpolated target; sample render timestamp/frame|
|Actual rendered ankle|Full skeleton foot-bone global pose after modifiers|Measure in the completed modifier callback, not an authored/restored pose|
|Ordinary IK influence|`biped.ik.influence`|Shared four-limb weight; not a per-foot load indicator|
|Presentation owner|Mantle mode; ordinary ground animation vs climbing IK; solver override vs passive contacts|Expose the selected owner, not just a target coordinate|

In `SLIDING`, the solver can update `local_point` for the next material anchor after constructing the current force at the previous point. The saved applied point and newly updated anchor may legitimately differ by a small slip step. Label their roles and timestamps; do not classify that difference as stale anchoring.

## Actual rendered sole measurement and phase separation

The `foot_l`/`foot_r` bone origin is the ankle. It must not be labelled an observed sole/contact point. A useful, explicitly calibrated sole marker can be constructed from rest data:

```
foot_rest_body = skeleton_to_body * skeleton.get_bone_global_rest(foot_bone)
rest_sole_body = rest_ankle_body + DOWN * foot_clearance[id]
sole_marker_local = foot_rest_body.affine_inverse() * rest_sole_body

# In the post-modifier render observation:
rendered_foot_world = skeleton.global_transform * skeleton.get_bone_global_pose(foot_bone)
rendered_ankle = rendered_foot_world.origin
rendered_sole_marker = rendered_foot_world * sole_marker_local
```

Label this `REST_CALIBRATED_RENDER_SOLE_PROXY`, not mesh-triangle contact. It follows the actual foot-bone rotation and is more faithful than subtracting worldUP×clearance from a rotating ankle. Actual mesh contact is not measured by this approximation.

For ordinary climbing, the existing `hand_pose.modification_processed` hook is the appropriate available post-modifier observation point used by this project. Reading a bone immediately after a physics tick or `skeleton.advance` can observe the authored pose after temporary modifier poses were restored; it should not be called the final rendered IK result.

Record the render frame, timestamp, physics sample identity and owner with each actual-bone sample. If the modifier callback is not current, especially across authored ground animation or hybrid ownership, mark the observation stale/UNKNOWN rather than reusing it as a fresh zero-error value. The mantle driver has its own modifier/measurement path and must be labelled separately.

Keep these phases distinct:

1. `PHYSICS_POST_CONTROLLER`: state, admitted force, support-local anchor, desired physics foot endpoint and last solved body/native-contact state.
2. `RENDER_POST_MODIFIER`: actual rendered ankle/sole proxy, actual target-node transform, IK influence and current owner.

The render target is interpolated, whereas `leg_motion.feet` is a physics endpoint. Comparing their values without clock labels can create false error or false target freezing. Likewise current requested force and last solved native impulse/body velocity should not be asserted to be a simultaneous causal response from one unlabelled snapshot.

## Native-contact limitations

The First Ascent body requests up to16 native contacts. When direct body state and shape/contact APIs supply records, preserve collider ID, actual shape owner, point, normal and impulse. Positive `FootBase`/lower-collider records are useful evidence. A ray near the sole is not native contact; a geometric overlap query is not a solved contact impulse.

If direct state is absent, contact reporting is disabled, shape identity is stale/invalid or the active body mode cannot supply the relevant solved contact, report `UNKNOWN`. A zero reported count is `NONE_REPORTED`, with capacity/body-mode information; do not silently turn it into proof that no native collider can resist motion. This reviewer did not launch the exact engine or test frozen/static contact-report behavior in this task.

Even if explicit foot actuation reacheszero, the ordinary `FootBase` and lower capsule remain physical colliders with their own contact response. B3 cannot legitimately claim to release that native response by changing a virtual foot state.

## F0 decision

**No root-cause classification has been accepted by this source-only review.** B1's force-independent visual anchoring, B0's passive visual surface retention and native-body contact all remain plausible contributors. The principal agent must preserve the reported first-wall-to-bars sequence and compare B0/B1 actual body motion, admitted foot load, native contacts and post-modifier rendered targets.

- If only rendered targets remain stuck while body response is normal, pursue the smallest isolated F2 presentation fix.
- If B0 still resists at the same place with native body contacts, investigate that collider/other-controller path instead of speculative B3.
- Only if a controlled B1 versus B0 reproduction implicates restrictive foot actuation should a separate opt-in B3 policy proceed.

No designer rating, pleasant-feel judgment, automated pass count or runtime improvement is claimed here.

## Subsequent observer-only instrumentation handoff

After the principal agent created `features/foot_release_lab/scripts/foot_diagnostics.gd`, this reviewer was assigned that new file exclusively for a minimal instrumentation pass. It is allocated only by the explicit diagnostic entry. Ordinary startup does not allocate this observer or its markers. The existing foot solver, passive leg behavior, actual IK actuation, native collision rules and physical budgets were not changed.

The diagnostic changes are:

- Correct the run-allocation lookup to the actual app property. Actual `FootBase` transforms are read from the body node; the app does not have a `foot_collision` member.
- Observe actual foot-bone pose after the ordinary hand-pose modifier; compute the explicitly labelled rest-calibrated sole proxy through the full bone transform.
- Bind the observation callback to its specific visual rig and disconnect when reloading. An old queued-free rig cannot cause a sample of a newly created, not-yet-processed skeleton.
- Record animation clip, shared four-limb IK influence, presentation-owner fingerprint, render-frame age, physics-tick age and wall-clock age. Invalidate current-use status when the owner changes or the sample is stale. Hybrid `ASSISTED` and `EXIT_BLEND` are recognized through the mantle driver's actual ownership; the ordinary modifier does not pretend to measure hybrid final bones.
- Keep the historical render sample separate from physics rows. Unknown/stale/hybrid-only render observations are labelled rather than converted into zero error or reused as a current pose.
- Show small render-only markers: cyan actual native `FootBase` box/sole center, green observed render sole proxy, pink current observed IK target, orange valid current material contact. They contain no collision shapes or physics behavior. Native and visual positions retain their explicitly different clock roles; stale or old-body markers are hidden.
- Tie marker/text groups to the independent actuator/native/IK/opposition toggles. Add reported FootBase/lower-capsule contact counts and peak reported native impulse, with UNKNOWN preserved when reporting is unavailable. Zero reported contacts remain explicitly insufficient proof of absence.
- Protect prior recordings by allocating a unique take directory when recording is restarted instead of overwriting an existing physics/render trace.

The renderer is observational: it writes transforms only on its own `MeshInstance3D` markers. It does not move body, feet, IK targets or anchors. Expected dynamic reaction is explicitly labelled derived from the source commit contract, not an independently measured reaction sensor.

This pass was handed back as frozen source for the principal agent's parse, headless and native runs. **The reviewer did not execute the engine or certify runtime/visual results.** Any later runtime findings and F0 classification must cite the actual principal-agent receipts.
