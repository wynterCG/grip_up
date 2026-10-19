# v0.6 M3 — actual contact and handoff

M2 checkpoint: `3246da6`. Production controller/helper are frozen after the final runs below. Work stayed in C staging; no E/editor/native action was performed by the physics agent. Root owns real-input/native/ten-transfer validation and the final aggregate.

## Attachment authority

The persistent gesture is not a support until `_try_held_contact` verifies held input, valid/eligible material anchor, a valid collision-swept endpoint, current physical reach, no current obstruction and hand-to-selected-point error<=1e-6m. It then **always** calls the existing CaptureEvaluator, regardless of old predictive/advisory/buffer flags. No future pose, hysteretic label, normal-offset waypoint or speed-risk estimate can authorize attachment.

On acceptance, the same precise selected local point becomes the arm anchor. Only the selected hand changes to ATTACHED; its real separation is cached, rest target initialized by the existing .18..62m clamp, acquisition blend reset, and ordinary support allocation/force generation used. At a full .65708m catch the initial target is still .62m: the .03708m preload is real and blended/capped; no zero-error initialization or enlarged target range is claimed. No torso or support transform/velocity is assigned.

Pending metadata switches to ATTACHED before CONTACT/SUCCESS publication. `contact_time` and `pending_time` freeze at contact; live material position/normal and separation continue updating. `acquisition_load=0` means the instant before the existing blend begins, with that scope named explicitly. First applied load/current force/peak blend load are separate observations. Fresh attempts clear all old capture time/failure/prediction fields; `persistent_target=true` is distinct from the older short buffer.

Pending hands retain zero force/reaction/allocation. The original support's anchor, rest target and allocation are unchanged until the new hand actually attaches. The existing smooth allocation/force acquisition then handles one-to-two support transition under the same total budgets. Release, loss of eligibility/object, profile/reset and input routing retain their ownership rules; the attached grip uses the existing elastic/overload/slip logic rather than auto-releasing at the selectable .65708m threshold.

## Files and test isolation

- Production changes: `scripts/climbing_controller.gd`, `scripts/pending_grip_target.gd`. No gain, mass, speed, force budget, solver equation, planner or base damping changed at M3.
- New `tests/test_pending_contact.gd`:47 checks at each rate.
- `tests/test_pending_motion.gd`: still32 checks. It now explicitly substitutes a test-only controller subclass that suppresses only the new contact callback, isolating the historical M2 motion/obstruction gate. There is no production flag that disables contact for these tests.
- M1 tests remain32, including exact OFF legacy trajectory equivalence and loaded one-hand/no-pending equivalence.

## Results and reproducing

| Suite |120Hz|60Hz|
|---|---:|---:|
|M3 actual contact/handoff|47/47|47/47|
|M2 motion isolation|32/32|32/32|
|M1 select/cancel/OFF equivalence|32/32|32/32|
|Original physics|45/45|45/45|
|Existing transfer capture|25/25|25/25|

```
python tools/project.py test test_pending_contact
python tools/project.py test test_pending_contact -- --60hz
```

Logs: `builds/test_test_pending_contact.log` and `_60hz.log`. Structured fixtures/events: `builds/pending_grip_m3_120hz.json` and `_60hz.json`. No script errors. The environment's60Hz certificate-store warning is unrelated to the passing suite footer.

At120Hz, representative real contact times from selection were .2083s for the static current-valid point, .475s for a point initially1.0171m away approached by a torso moving upward .9m/s, .5917s for an incoming dynamic support initially .8549m away, and .625s for a lateral .7m/s torso catching a point initially1.0314m away. These catches passed actual geometry and retained after capture. Contact preserved the incoming .9/.7m/s velocity; subsequent force integration, rather than a velocity reset, changed motion.

Full-extension fixture: actual contact separation .657080114m, unchanged .62m initial rest target, correct finite travel and force blend. The physical limit was not enlarged.

The two-hand fixture first makes a real legacy left catch, then selects a right point initially outside reach. Existing supported motion earns contact without another click. The entire pending interval preserves the left anchor/rest/allocation and right zero effort; releasing left preserves current pose/linear/angular velocity and the new right anchor, which retains as the remaining support.

### Timing miss and overload are separate results

A deliberately extreme12m/s incoming-body fixture has a valid authored initial free-hand endpoint at the shoulder. This is an explicit initial-condition fixture, not a production hand or body teleport. The selected point starts1.4465m away. Its approximately .09167s physical reach window at120Hz is too short for the finite hand path: no catch occurs, body retains12m/s, and the same still-held selection remains pending. `HAND_WINDOW_MISSED` records a nonterminal `HAND_TOO_SLOW` observation and measured window; this does not become a fake timeout or a permanent primary failure.

Without that valid initial endpoint, the existing legacy FREE world-speed behavior at12m/s has already left the hand outside its workspace before mouse-down; that separate adversarial setup correctly produced WORKSPACE_SWEEP_CONFLICT. The two outcomes were not conflated.

A weak-support fixture first makes real contact, then receives an explicit gravity load with grip capacity reduced to1N. It records SUCCESS at CONTACT followed by GRIP_SLIP at RETENTION and ultimately `grip_overload`; it does not receive extra strength. Because this load is deliberately introduced after the initial acquisition interval, the case is later retention overload, not mislabeled as immediate CATCH_OVERLOAD. Existing initial-catch overload instrumentation remains unchanged.

### Dynamic reaction audit

Two new grips on the same free30kg support exercise nonzero grip-moment assistance. At120/60Hz, measured sum-force reaction error is zero, and complete applied moment residual is below6e-6Nm. Both grips share one opposite assist reaction; it is not duplicated per anchor. Shared hand force360N, assist20Nm and resultant150Nm all remain bounded.

The original anisotropic spinning-capsule closed-force fixture is retained. Its linear momentum error is below1e-6Ns and angular momentum drift .03891/.03646Nms over .8s. A matched anisotropic unactuated control with the controller disabled already drifts .04534Nms. Thus exact applied action/reaction does not justify claiming mathematically exact integrated angular conservation for that engine fixture. No engine setting, production inertia or tolerance was silently changed to hide it.

A separate explicitly isotropic-inertia force-pair control distinguishes that simulation effect: linear drift below1e-6Ns, angular drift6.22e-6/2.49e-6Nms, with the same actual catches and bounded assist. This extra control does not replace the original anisotropic measurement. Pair fixtures disable incidental torso/target collision constraints to isolate the closed actuator wrench; collision handling is covered by the obstruction/actual-contact fixtures.

## Limits and gate

Physical M3 gate T6/T7/T10: PASS for the tested fixtures. No observed new grip attached before valid actual contact; no force was observed while its gesture was pending. Root's UI/focus/resize/scene and native tests are separate evidence. M4 ten-transfer improvement/human comfort is not established by a force fixture and must be reported by root.

The known approximations remain: virtual point-ray hand/arm collision rather than a complete arm volume; finite torque-capable gripper rather than an ideal moment-free pin; AUTO-COM effective-mass estimation in the unchanged actuator, despite corrected new-anchor point velocity; bounded absolute posture plans rather than full-body constrained optimization; infeasible moving-workspace cases explicitly cancelled and visually marked invalid. No guaranteed high-speed catches, new air thrust, direct velocity correction or range inflation was introduced.
