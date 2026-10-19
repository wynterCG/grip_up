# GRIP UP v0.9 ? hybrid mantle prototype

**Technical decision: GO for an opt-in static-platform prototype. Human UX gate:
PENDING.** Both1.25m and2.10m platforms now complete the actual body transition,
native ground support, restored dynamic locomotion and at least30cm of walking
at120Hz and60Hz. This is deliberately assisted motion, not simulated muscle work.
The approved route is preserved; v0.8's pure physical mantle still has its failed
gate and remains an independent comparison.

Canonical project: `E:\Godot Games\grip_up`. Local build:
`builds/GripUp-v0.9-experimental.exe`. Branch: `feature/v0.9-hybrid-mantle`.
Baseline: `14bb778c05cf30f37c8102003d7a3cba40d8c0be`; preserved branch:
`feature/v0.8-physical-mantle`. Exact final source commit and build hash are in
[verification.json](verification.json). Supplied spec: `docs/specs/grip_up_v0.9.md`.

## Milestone ledger

| Gate | Result and evidence | Decision |
|---|---|---|
| M0 audit/freeze | Saved v0.8 reproduces both failed top-outs,8 assertions/2 failures perHz; engine4.7.2/Jolt and imported43clip library audited | KEEP baseline |
| M1 assisted body motor |54/54 checks at eachHz; same RigidBody, swept rotation/morphology, exact movement, safe restore | GO |
| M2 geometry, route and profiles | Full lip corridor passes on low/high; narrow/occupied/ceiling/dynamic cases refuse; runtime blocker holds last safe pose | GO within declared envelope |
| M3 animation and presentation |23/23 checks perHz; genuine authored clip and rendered body/rig agreement; visible assisted-lift quality limit | GO technical / human review pending |
| M4 static functional top-out |14/14 perHz, both full sequences from normal input; native rendered runs also pass | GO |
| M5 repeated/input/adverse |12/12 sequence +59/59 resilience perHz, plus all earlier regression suites | GO for tested cases |
| M6 human experience / F10 | No independent human ratings or success-rate sample yet | PENDING / do not promote |

Final automated matrix: **4,356 checks across139 runs, zero failures**.
Of these,4,032 are the preserved earlier suites;324 are new v0.9 checks.
Final Godot MCP Pro rendered evidence: **13/13 perHz**,26 total, including
actual functional completion. Earlier rendered repetitions are retained in
`native/attempt_001` and `native/attempt_002`; `native/final` is the selected
final evidence. Automated inputs are not an independent human playtest.

## Player workflow and flags

Open **Controls / v0.9 / Mantle1.25m**, **Mantle2.10m** or **Two ledges**.
Acquire a real hand grip near the upper edge with held LMB/RMB, then press/holdW.
On the high wall, use ordinary intermediate surface grips to reach the edge.
The mouse still chooses actual free-surface contacts; there are no mantle sockets
or scripted hand selections in gameplay. Once the action commits, release grips
andW if desired: no pumping or continued hold is needed to finish the transition.
Normal WASD walking resumes only after actual upper-platform support. A held old
grip cannot silently recreate an edge contact; fresh input is required.

MMB orbit and scroll dolly remain available. Esc/Controls pauses the assisted
route and synchronized pose; R uses the existing fresh-level retry. Tab displays
real collision proxies and detailed authority/candidate diagnostics. Refused
narrow, moving and occupied ledges show short contextual feedback. The ordinary
climbing controls remain active before commitment and after a refusal.

`hybrid_mantle_v09_enabled` defaults **false** and is explicitly enabled only by
the new comparison buttons. Runtime defaults remain profile2, intentOFF,
feetOFF, early targetsOFF, postureP0 and experimental SpaceOFF. The new lab
explicitly uses profile4/early targeting with physical feetOFF. It does not enable
legacy palms, wrist support, adaptive v0.8 collision or v0.8 support handoff.
Static-only eligibility, parameterized route and authored animation are the sole
v0.9 implementation; no dynamic-platform option is secretly enabled.

Rollback: choose **PLAY / The first route**, an older lab or restart the
application to recover original defaults. The old v0.8 buttons and builds remain
available. Source rollback is the preserved v0.8 branch/commit; no project folder,
prior executable or Janga source was deleted. Test/editor windows are on monitor1
(Godot screen0) and the new low comparison is left prepared there.

## Implementation and authority

One dedicated `hybrid_mantle_controller.gd` owns DYNAMIC, PREPARE, COMMIT,
ASSISTED_TRAVERSE, RESTORE_DYNAMIC, DYNAMIC_GROUNDED and BLOCKED_RECOVERY.
PREPARE validates live geometry without freezing or moving the character.
COMMIT is guarded/idempotent: capture actual pose and hand points, transfer
presentation, retire physical grips and pending requests, suspend old climbing,
foot/wrist and ground actuation, then freeze the same12kg gameplay RigidBody in
KINEMATIC mode. There is no second contradictory collision body and no gap tick
with neither owner. Assistance never starts from a pending/slipping hand.

The motor validates the full route before commitment and rechecks every runtime
step against the live world. Position, rotation and lower-profile morph contribute
to a conservative point-motion bound. Intervals are at most3mm of bounded point
travel; inflated midpoint occupied volumes plus endpoint checks include head,
torso, thigh, shin and full sole. Normal movement uses `move_and_collide()`;
rotation and shape changes are applied only after the independent swept volume
certificate. All body/shape mutations occur on fixed physics ticks. World layers
and masks remain unchanged, and runtime dynamic blockers can stop the route.

Normal and tucked profiles retain the torso/head and limb radii. During assistance
the original lower capsule is represented by two same-body capsules with an exact
standing union. HEEL_BACK bends the shin to150degrees while the thigh stays down.
The sole rises about.504m, but the knee capsule remains the lowest volume at about
Y?.6467 relative to body origin. The planner uses the actual lowest occupied point,
not the sole alone. All immutable original shapes/transforms/flags are restored
before dynamic authority returns. This is an authored collision approximation,
not independently simulated limb mass or a physically load-bearing high foot.

### Initial native-contact recovery

At60Hz the normal dynamic climb can press the torso approximately9.15mm into the
wall under Jolt's existing contact solver. This was confirmed by the matching
native collider/shape/contact point and query depth; Node and PhysicsServer poses
agreed. A global2mm overlap exception would incorrectly reject these real starts.
Simply calling native movement was also unsafe: an isolated pressure test asked
for3mm of outward motion but received20.5mm from native depenetration.

The accepted extension is limited to a pre-existing **native-proven** static
contact, matching shape/collider/point/normal and at most20mm. That limit matches
the exact runtime Jolt penetration-slop setting(.01999999955m). Only constant-pose,
constant-profile, strictly outward and monotonically decreasing penetration is
authorized, with no new intersecting collider. Those initial recovery steps use
exact small frozen-body translations after their collision certificate, avoiding
hidden native correction. Once clear, the exemption expires and normal native
movement resumes. Wrong direction, rotation, morphing, unproven overlap, excessive
depth and later new collisions are refused. This is not permission to clip through
a wall or to loosen all collision tolerances.

See [motor audit and54 checks](motor/M1_PHYSICS.md). The engine's declared slop is
also documented in [Godot ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-jolt-physics-3d-simulation-penetration-slop).

### One body route, one pose clock

OptionB was chosen: `hybrid_mantle_route.gd` supplies one ledge-aligned body route;
`mantle_animation_driver.gd` samples the authored pose at the same approved
normalized progress. The imported43clip Quaternius library has no mantle clip.
A real new `resources/mantle_authored.tres` contains17 bone rotation tracks and
seven authored phases. Its1.05s clip is sampled over the approved1.15s body route
(about1.167s at60Hz). It contains no root translation, so displacement is not added
twice. Entry blends from the current skeleton pose; hand targets initially use
remembered real attachment positions and deliberately blend away at.25?.38.
Ordinary climbing IK/animation yields authority while the mantle driver owns
presentation, then blends back into idle/walking over about.16s.

The route first moves10cm outwards with unchanged orientation/profile, aligns in
free space, rises and folds outside the face, crosses to65cm inward, then raises
and unfolds to a standing endpoint derived from actual collision extents. Standing
recovery height also follows the shin/sole arc, closing an early failed route that
would have unfolded a shin into the deck despite clear endpoints. Endpoint-only
clearance is never used as a route certificate.

### Returning to physics

At the endpoint, normal geometry must fit before unfreeze. Linear velocity comes
from the last approved movement, bounded to3m/s; old incoming swing velocity is not
replayed. The route ends without angular travel, so outgoing angular velocity is
zero. Old actuators remain suspended while the dynamic body settles and a native
FootBase contact/upward impulse confirms support on the expected static top.

The new scene's ground motor requires native sole support plus at most5mm probe
gap; a nearby floor ray alone cannot grant walking authority. Original scenes keep
their earlier behavior. Restored standing clearance distinguishes collision-free
pre-unfreeze placement from expected shallow, native-supported sole/lower contact
after settling (up to4mm); torso/head penetration cannot satisfy the finish.
Both physical grips and presentation contacts are retired. After support is
confirmed, the ordinary ground motor resumes. Completion additionally requires
at least.30m of actual ordinary walking in support-local coordinates. Carrying by
a platform or animation progress alone cannot complete the gate.

A new real grip starts a new maneuver and clears the previous attempt's progress,
walk/result flags. Two-consecutive testing therefore cannot reuse a previous win.

## Detection and authored test geometry

`mantle_candidate_detector.gd` examines actual ATTACHED anchors on live colliders.
It rejects rigid/Animatable/moving supports, checks upward top normals>=.85 with
multiple same-material rays, verifies a standing-width corridor and about1.12m
bearing depth, validates the actual standing destination and finally preflights
the complete body route. Static transforms observed moving are remembered as
unsupported; a later support change aborts runtime travel.

Current start envelope: genuinely ungrounded support, body origin10cm?1.10m below
the top,18?72cm outside the face, upright dot>=.70, speed<=3.2m/s, spin<=3rad/s and
body/camera facing toward the structure. Actual hand reach is still the original
.65708m. The initial.90m body-height envelope was too small for an already valid
extended arm;1.10m was explicitly derived from the existing.524m shoulder offset
and anatomical reach. No grip range or precommit muscle strength was increased.

Low/high decks retain absolute world tops1.25m and2.10m and are2.4m wide/2.8m deep.
The new ordinary approach floor isY?.55m, character spawnY.37m/Z.40m; no pad is
removed during the run and no character transport occurs before W commitment.
These are new authored approach conditions, not the old v0.8 pad atY~.253m. The
high deck genuinely requires several intermediate free-surface grips. The narrow
comparison has only.12m depth. Ceiling/occupied/dynamic comparisons use the same
real detector and preserve ordinary climbing after refusal.

The consecutive course uses deck tops1.25m and3.25m, with the second front atZ?2.8m.
An earlier3.0m second deck was retained as a failed input/content attempt: the
selected lower hand geometry did not reliably unload the first deck at60Hz.
The final course provides a reachable higher grip supporting a genuine hanging
entry; it does not add force, move the body or change the deck after initialization.
This prototype does not promise all possible low-obstacle/stance combinations.

## Results and preserved development failures

| Test suite |120Hz|60Hz|
|---|---:|---:|
| Isolated hybrid motor |54/54|54/54|
| Authored animation/ownership |23/23|23/23|
| Low + high full top-out |14/14|14/14|
| Varied real approaches + two consecutive decks |12/12|12/12|
| Adverse/input/ground truth contracts |59/59|59/59|

All earlier profiles and the approved route also pass. `results.json` contains the
full139-run matrix. A final targeted sequence/resilience rerun covers the new
per-attempt result reset; no unrelated re-testing was used to hide failures.

Final native evidence,13 checks per frequency:

| Measurement |120Hz low/high|60Hz low/high|
|---|---:|---:|
| Post-restore ordinary walk |.30362 /.30359m|.31609 /.31608m|
| Assigned interpolated visual-root error |0 /0m|0 /0m|
| Fully corrected foot error, sampled maximum |2.52 /1.87mm|1.95 /2.58mm|
| Anchored hand error at IKweight>=.99 |8.39 /18.03mm|14.57 /13.35mm|
| Actual top support, clear standing profile, dynamics restored |all true|all true|

Entry blend deliberately retains the incoming pose; raw early foot discrepancies
can be over10cm and remain logged. After hand-release blending, hand-to-ledge
distance is not a continuing contact error. EXIT/walking feet compared to an old
static sole target also remain in raw telemetry with explicit stale/measurement
scope; they are not silently presented as ongoing corrected support. Historical
headless samples included anchored-hand errors up to~28mm. The final native120Hz
repeat includes visible cyan physical colliders; screenshot clearance is supported
by the swept-query/native evidence, not visual appearance alone.

Raw failures are retained under `functional/attempt_001` through `attempt_007`
(and passing008), `sequence/attempt_001` through003 (and passing004), plus the
specialists' motor/resilience development receipts. They include overly small
start envelopes, an invalid unfold path, diagnostic compile errors, initial missing
native-contact reporting, a poor scripted pending-hand transfer strategy and the
native-contact recovery issue. The compile/crash receipts are failed development
runs, not accepted physical evidence. Parser-failed runs cannot reuse stale JSON.
The baseline pure-physics failure remains separately archived in `m0/`.

Adverse tests prove narrow/ceiling/occupied/dynamic/Animatable refusals, precommit
button release, focus before/during commitment, active pause/pose/body agreement,
camera anchoring, duplicate commit guard, postcommit release, fresh-grip rearming,
new runtime blocker, invalidated support and safe R resets. A ceiling may be
classified TARGET_OCCUPIED because it also blocks the standing destination; that
is an honest refusal. OS focus was exercised via the real game's callback signal,
not a claim of independently testing every desktop focus path.

## Recovery, limits and human pilot

A transient obstruction can wait/retry for a bounded.4s. Otherwise the last
validated frozen pose is retained and the visible R retry remains available.
There is no unchecked teleport back to the old anchor, no automatic reverse route
and no claimed full dynamic moving-platform mantle. An invalid support cannot be
silently followed. This deliberately uses the spec's safe explicit-reset option
when continuation cannot be certified. A failed approach remains ordinary physics.

The authored crossing currently has early hand release and visible tucked-foot
clearance of roughly.25m while the knee proxy clears the lip. It reads as an
assisted lift/transfer rather than a physically planted-foot push. That is a visual
quality limitation, not hidden physical success. Camera framing remains ordinary
third-person and no cinematic cut is added. We have rendered still evidence and
live automated playback, but no independent comfort/reliability ratings.

Human pilot: try several normal low/high approaches, W initiation, releasing
buttons after commitment, walking away, and the two-deck course. Compare the
approved route and the v0.8 experiment separately. Record attempts/successes,
unexpected refusals and1?5 ratings for trigger clarity, response, continuity,
reliability, control return and fairness. **F10/M6 remains pending until an actual
person supplies that evidence.** Do not promote by default on automation alone.

## Files and reproduction

Core new files: `scripts/hybrid_mantle_controller.gd`, `mantle_candidate_detector.gd`,
`hybrid_mantle_route.gd`, `mantle_kinematic_motor.gd`, `hybrid_mantle_level.gd`,
`mantle_animation_driver.gd`, `resources/mantle_authored.tres`. Guarded hooks only
in `scripts/climbing_controller.gd`, `ground_locomotion.gd`, `biped_visual.gd` and
`grip_up_lab.gd`. All these paths are relative to `features/grip_up/`.

New tests: `test_hybrid_motor.gd`, `test_hybrid_animation.gd`,
`test_hybrid_mantle.gd`, `test_hybrid_sequence.gd`, `test_hybrid_resilience.gd` and
`capture_hybrid_mantle.gd`. Animation authoring source is
`tools/author_mantle_clip.gd`. Diagnostic probes and raw logs remain available.

Commands:

```
python tools/run_regressions.py v09
python tools/run_hybrid_mantle.py functional hybrid_mantle
python tools/run_hybrid_mantle.py sequence hybrid_sequence
python tools/project.py export
python tools/project.py smoke
```

Milestone attempts get numbered directories, complete normalized logs and
freshly generated JSON only. Build startup smoke renders3 frames on monitor1;
it is not a long-session performance guarantee. Janga's protected grabber hash,
C/E saved-source parity, build hash and final editor diagnostics are recorded in
verification. All assistance remains opt-in for the human trial.
