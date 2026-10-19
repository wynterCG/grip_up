# v0.9 authored mantle presentation

This is a presentation implementation for the deliberately assisted v0.9 maneuver. The isolated animation gate passes. Full static top-out, integrated rendered continuity, and human feel require the main controller/motor evidence; playing this clip alone proves none of them.

## Asset audit and authorship

The actual Quaternius `mannequin.glb` imports 65 bones and 43 animation clips. The imported names are recorded verbatim in `hybrid_animation_120hz.json` and `hybrid_animation_60hz.json`; none is a mantle. The GLB JSON audit likewise contains no mantle. No downloaded clip or guessed existing animation is used.

`features/grip_up/resources/mantle_authored.tres` is a newly authored 1.05 second, nonlooping `Animation` resource. It contains 17 quaternion rotation tracks with seven authored phase keys: pelvis, three spine bones, neck, two upper arms/forearms/hands, and two thighs/calves/feet. `tools/author_mantle_clip.gd` reproduces the resource using the actual rig and rest orientations. It authors settle, elbow contraction/press, torso lean, heel-back knee fold, arm release, and recovery to upright standing. Small hand rotation tracks preserve the authored wrist baseline while temporary palm alignment owns contact orientation.

Option B is the sole world-route authority. This clip has no root, position, body transform, velocity, or world displacement track. The collision motor chooses body position, rotation, collision geometry, and accepted normalized progress. There is no root-motion addition.

## API and ownership

Create a driver node, add it to the tree, then call:

```gdscript
driver.configure(biped, body)
driver.begin(candidate) # before real grips are retired
driver.set_collision_pose(actual_flex, actual_profiles.pose_for(actual_flex))
driver.set_progress(collision_approved_progress, physics_delta)
driver.finish() # after actual standing completion, not on animation end alone
# or driver.cancel(reason) for a physical recovery/reset
```

`begin` remembers the current post-modifier bone rotations and genuine attached hand locations. Explicit `candidate.hand_anchors_world` can supply the same remembered positions. Missing/free hands receive no fictitious anchor. `begin` and `finish` are idempotent. `candidate.hand_release_start` and `hand_release_end` parameterize deliberate visual release to match the selected collision route; root's rise-first route selects .25–.38, rather than the generic clip's .48–.78 defaults.

`set_collision_pose` consumes the actual approved `sole` transform and `knee` point. Visible ankle targets shift by exactly the physical sole's local displacement. Dedicated leg IK corrects the authored leg pose toward that actual proxy pose; it does not modify the collider. HEEL_BACK uses hip 0°, knee 150°, retaining the capsule knee as the lowest occupied point. The skeleton leg lengths remain those of the actual mannequin; proxy dimensions do not replace bone lengths.

The driver manually seeks its `AnimationPlayer` at `progress * 1.05`. Render updates never advance assisted progress. Entry blending uses the first .15 of accepted progress, so blocking the route also blocks pose advancement. Ordinary climbing/ground IK and ordinary animation playback cannot fight the mantle driver. During the active phase, separate hand IK keeps presentation targets at the remembered static ledge positions, then fades out at the explicit release phase. These anchors create no grip or force.

On finish/cancel, presentation anchors clear immediately and a .18 second pose blend resumes the existing Idle animation. The existing ordinary animator then chooses Idle/Walk from normal motor state. The driver temporarily makes the ordinary animation callback manual during handoff, restoring its previous callback mode after the blend; it does not double advance the imported animation.

`biped_visual.gd` has one default-null guarded driver reference. With no configured driver, old animation/IK behavior is retained. Its existing post-modifier callback additionally saves current bone rotations for later entry continuity. No hand pose script or physical controller needed modification.

## Telemetry and tests

`telemetry()` reports normalized progress, animation time, collision flex, actual post-IK hand/foot errors, measured modifier frame count, visual parent/body error, contact weight, begin/finish counts, and presentation ownership. Errors are sampled from the real final skeleton poses. A released hand reports -1 (not a hidden zero). Nonzero error while IK fades records deliberate release displacement; it is not a claim of continued contact.

`test_hybrid_animation.gd`: **23 checks / 0 failures at 120 Hz and 60 Hz**, including actual clip/bone audit, no displacement track, default-off ownership, idempotence, fixed progress during render updates, post-modifier telemetry, finite transforms, body transform/velocity invariance, hand release, finish/cancellation cleanup, and ordinary animation handoff. In the isolated fixed-body contact fixture, both visible palms remain within .01 m during the full-contact phase and both ankles remain within .01 m of supplied physical proxy targets after entry blend. These are geometry/ownership checks, not a gameplay mantle.

`test_biped_visual.gd`: **15 checks / 0 failures at 120 Hz and 60 Hz** after the default-null hook, retaining baseline physical IK, real finite grip acquisition, and pose-only evaluation invariants. The main agent's full regression matrix must also cover the baseline at both rates.

## Disposition

**GO for integration of the isolated authored presentation.** The resource and driver are real and testable. **Not human accepted and not a full M3/M4 success claim.** Native rendered inspection must assess torso/hand continuity through the selected motor route, especially contact release during the rise-first path. A successful collision/standing/walk result and ordinary player pilot remain separate gates.


## Integrated trace audit (attempt_007, 120 Hz)

The main agent's `functional/attempt_007/hybrid_mantle_120hz.json` records full physical F1/F2 standing and walking success. This is separate automated functional evidence, not a human animation acceptance.

During `ASSISTED`, both scenarios report zero parent/interpolated-body root error. After the entry blend (progress >= .15), visible ankle errors are approximately .001?.002 m before becoming submillimetre. Initial entry blend intentionally preserves the incoming dangling pose: ankle mismatch reaches .091 m (F1) and .196 m (F2) while leg correction fades in. During `EXIT_BLEND` and ordinary walking, comparing an animated gait to a stationary sole target produces .15?.24 m errors; those are not continued tucked-contact assertions. The raw numbers remain available.

Anchored palm discrepancy is also real and retained: F1 reaches approximately .019 m at full IK weight near progress .246; F2 reaches .011 m at full weight and .028 m at weight .998 near progress .254. Later release-phase errors of approximately .1?.32 m occur as the intended contact weight fades. The integrated clip therefore does not inherit the isolated fixture's <.01 m palm criterion automatically. Rendered inspection must judge this visible contact drift before accepting visual quality.

Additional diagnostic fields distinguish these situations without changing the animation algorithm or deleting raw errors:

- `last_measurement` records actual post-modifier mode/progress/weights/frame. Its anchored-hand field includes weight >= .99, deliberately retaining the F2 near-full-weight .028 m discrepancy. Lower weights return -1 in the scoped field; unfiltered `hand_contact_error` is preserved.
- Collision-corrected foot errors are scoped to the assisted phase after leg IK reaches full weight. Entry/exit/gait raw errors remain recorded.
- `visual_vs_assigned_interpolated_target_error_m` compares presentation position with its actual assigned render target. `body_interpolation_lag_at_visual_update_m` separately records render-target versus same-update raw simulation position. `interpolated_target_change_since_visual_update_m` identifies a newer target sampled between render updates. After exit, a scope label and -1 prevent treating an old mantle assignment as the current walking target.

These diagnostics add one ownership/measurement check: the isolated suite now has 23 passing checks at each physics rate. They make no new feel, clipping, or full-gameplay claim.
