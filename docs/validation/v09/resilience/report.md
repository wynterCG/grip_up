# v0.9 M5 — negative geometry and input resilience

**GO for the tested resilience contracts:59/59 checks at120Hz and59/59 at60Hz, process exit0.** This report does not accept F1/F2,30cm walking, two consecutive ascents, rendered quality or human usability. Those have separate functional/animation/native evidence owned by the principal agent.

## Files and boundaries

This assignment changes only `features/grip_up/tests/test_hybrid_resilience.gd` and this `docs/validation/v09/resilience` evidence directory. It makes no production-controller, motor, level, animation, Git, E-drive mirror or MCP changes. The principal agent records final branch/commit/source snapshot.

Commands:

```
python tools/project.py test test_hybrid_resilience
python tools/project.py test test_hybrid_resilience -- --60hz
```

Final JSON receipts and full normalized logs are `final_120hz.json/.txt` and `final_60hz.json/.txt`. Raw failures and their explanatory provenance remain in `development/`.

## What was actually exercised

Every ordinary trial starts at the authored approach-floor spawn. Grip acquisition uses the real mouse targeting and held grip events, followed by W through normal dynamic climbing to earn eligibility. No body transform, body velocity, frozen setup pose, removed start pad or hidden lift force is assigned by this test.

One explicitly marked eligibility fixture substitutes an `AnimatableBody3D` for the static platform before any grip is acquired, with the same collision geometry and grippable metadata. Its grips still arrive through the normal finite targeting path. This isolates the distinct unsupported support type; it is not an accepted mantle.

The test uses a real `InputEventAction` for Esc and R. Focus loss invokes the actual app's `Window.focus_exited` callback chain by emitting the signal headlessly, twice. It proves callback behavior and idempotence, not real OS focus delivery. Camera orbit/dolly are called through their normal camera APIs. Duplicate `_commit()` calls are deliberately fault-injected after one legitimate input-driven commitment to verify the entry handler itself is idempotent.

| Contract | Result at both rates |
|---|---|
|Narrow standing top|Real grips, normal W, `TOO_NARROW`; zero commits, no freeze/assisted ownership|
|Ceiling fixture|Real grips, normal W, `TARGET_OCCUPIED`; zero commits|
|Occupied landing fixture|Real grips, normal W, `TARGET_OCCUPIED`; zero commits|
|Dynamic rigid platform|Actual grips remain ordinary physical grips; `UNSUPPORTED_DYNAMIC_PLATFORM`|
|Animatable support, even atzero commanded velocity|Actual grips, explicit `UNSUPPORTED_DYNAMIC_PLATFORM`|
|Button release before commitment|Hands immediately release; no phantom commitment|
|Repeated focus loss before commitment|Actions and real grips release; no assisted start|
|Esc during committed travel|Collision-body pose, route progress and animation progress stop together|
|Camera orbit/dolly during pause|Committed standing route unchanged|
|Repeated COMMIT entry callbacks|Exactly one commit and one animation start; progress is not reset|
|Pause/resume|Authored travel resumes; exactly one restore to actual top-ground dynamic ownership|
|Stale held grip buttons after restore|No reattachment; acquisition remains locked until release|
|Fresh release/press|Ordinary acquisition becomes available again without a duplicate mantle|
|Both grip buttons and W released after commit|Coherent assisted traversal continues, with no old grip forces|
|New runtime head-corridor obstacle|Route stops at safe progress~0.42029; collider and animation remain there|
|Persistent obstacle|Explicit `BLOCKED / R TO RESTART`; no unchecked rollback or false completion|
|Repeated focus loss midcommit|One frozen safe pose, animation synchronized, no automatic new commit|
|Support destroyed midcommit|`SUPPORT_INVALIDATED`; controlled recovery/reset ownership, no dangling physical grip or completion|
|R during traversal, blocked obstacle, focus recovery, invalid support|Fresh dynamic body; normal geometry/mass/layers/gravity/authority; new counters and progress|

Ceiling and occupied destination currently share the detector's general `TARGET_OCCUPIED` classification. This is an honest refusal, not a proof of distinct semantic ceiling diagnostics. Ordinary wall-climbing states may first report `START_POSE_OUTSIDE_ENVELOPE`; the test waits for actual movement into a ledge-ready configuration before expecting the geometric refusal.

## Authority and actual ground checks

Every sampled assisted tick checks that the old attached-hand list is empty, hand/leg force telemetry iszero, and ground applied force/torque arezero. This remains true during pause, focus loss, runtime obstruction and support invalidation.

Every sampled `ground.grounded` state must have a live `FootBase` native shape contact on the very same support object, with upward native contact impulse>0.0001Ns. The guard is positively exercised, not vacuous:1,852 grounded samples at120Hz and1,050 at60Hz. This validates the principal agent's v0.9-only `require_native_support` policy against actual contact observations; the older baseline proximity policy remains outside this test's acceptance.

Reset compares a full baseline shape signature: shape types, dimensions, local transforms and enabled states. Auto-generated head-node instance names are normalized to a stable head label; physical geometry is compared without float-literal equality mistakes. It additionally checks12kg, layer4/mask3, gravity1, no assisted ground suspension, no adaptive-leg metadata and legacy v0.8 palm/collider capabilitiesOFF. The v0.9 scenario flag intentionally remains enabled for restarting that selected experimental scene.

## Failures preserved and fixes accounted for

- `attempt001_120hz`:48 checks,3 failures. Reset oracle used exact float `.84` for a float32-backed shape property. Production body reset was physically correct. A full shape signature replaced that literal test.
- `attempt002_120hz`:48 checks,3 failures. The improved signature still included the head collision node's auto-generated instance name. It was normalized; types/dimensions/transforms/enabled geometry remain compared.
- `attempt002_60hz` and `attempt003_60hz`:22 checks,6 failures. Ordinary W never reached the expected static eligibility/commit state; narrow/ceiling/occupied trials remained `START_POSE_OUTSIDE_ENVELOPE`, and commit-dependent recovery branches could not execute. Failures were retained rather than replaced with a staged body pose. Diagnostics showed real attached hands, body upright~0.992 and `grounded=true` after partial lift.

The principal agent subsequently introduced a v0.9-only native-supported ground guard, while the physics specialist completed validated handling of shallow existing native contact during the initial outward route. A separate audit also identified the missing duplicate-COMMIT guard; the principal agent added it. This test contains no production bypass for those failures. Final reruns occurred after the specialist declared the motor frozen and passed its own isolated gates.

## Remaining limits / decision

KEEP these automated negative and resilience checks. Runtime blockers and invalidated supports intentionally retain the last safe frozen posture with an explicit R reset, as allowed by the specification's controlled-recovery fallback. This report does not claim a general automatic rollback or a resumed mantle after arbitrary obstruction.

Real OS focus changes, native camera/input behavior, rendered hand/foot continuity and ordinary human discoverability still require native/human evaluation. Full low/high ledge ascents and meaningful walking must pass their separate strict functional tests before v0.9 can be accepted.
