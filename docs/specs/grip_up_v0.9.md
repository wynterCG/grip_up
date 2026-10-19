# GRIP UP — Hybrid Animation-Assisted Mantle & Top-Out
## Prototype Implementation Specification — v0.9

**Status:** Proposed, experimental, gated. Not a claim that the maneuver works.  
**Date:** 19 October 2026  
**Engine:** Existing GRIP UP project, Godot 4.7.2 with integrated Jolt Physics (verify working tree before editing).  
**Platform:** Windows PC, third-person 3D, landscape.  
**Audience:** Codex main agent, physics-specialist agent, animation/gameplay implementer.  
**Depends on:** Approved v0.7.3 climbing route, unsuccessful v0.8 full mantle experiment, existing `RigidBody3D` body, free-surface gripping, grip state machine, camera and ground locomotion.  
**Priority:** Reliable, responsive **static-platform mantle** first. Dynamic support mantles are an explicitly separate future experiment.

---

## 1. Executive decision

Implement a **hybrid mantle**: players use the normal physics-based climbing controller to reach a legitimate ledge, then trigger a **short, deliberately authored, collision-aware assisted transition** that carries the actual character collision body over the ledge and finishes in a valid standing position. Finally, return control to the original dynamic `RigidBody3D` ground locomotion.

**This is an intentional design exception to pure physical locomotion, not a claim of physically simulated muscle forces.** It is permitted inside a small, validated mantle state only. The existing climbing, swinging, grip acquisition, reaction-force and moving-structure mechanics remain dynamic.

### Player experience contract

1. Approach a ledge using the existing movement/physics controller.
2. Establish a real, valid hand grip near a ledge with a safe standing surface above.
3. Press/hold **W** while the character is in the eligible hanging configuration.
4. The character smoothly pulls up, swings/tucks the legs, moves across the lip, and stands up using an authored animation synchronized with **collision-checked physical-body motion**.
5. The character finishes **supported by the top platform** and can immediately walk forward with the existing WASD controller.

The player should not need to solve a full articulated biomechanics simulation at every ledge. **Reaching the ledge is the skill challenge; getting onto a valid platform should be dependable.**

### Must never happen

- Visual skeleton reaches the top while the gameplay collider remains hanging below.
- Instant teleport to the destination without collision testing or a visible transition.
- Passing through an overhang, wall, ceiling or another solid collider because the destination alone was clear.
- Claiming mantle completion before the physical ground probe confirms platform support.
- Unfreezing a dynamic body while deeply overlapping the ledge, with explosive impulses or a sudden fall.
- Invalid/moving/too-small surfaces silently treated as eligible static ledges.
- Unintended activation when W merely requests normal climbing on a wall.

---

## 2. Verified v0.8 baseline and why the direction changes

The supplied v0.8 report gives these implementation facts:

- One dynamic `RigidBody3D`, mass **12 kg**, with compound torso/head/lower-body/sole collisions.
- Arms mainly use tension-only actuators; v0.8 experimented with finite palm compression, bent-arm wrist moments and collision-safe adaptive lower-body proxies.
- Actual upper platform entry and ordinary walking **failed** for both **1.25 m** and **2.10 m** fixture platforms.
- Isolated palm and lower-collision experiments passed safety/regression testing (reported **4,032 checks across 129 runs**), but this does **not** imply full-mantle success.
- In full trials, a palm's limited moment/geometry lost the contact chain while the torso rotated; lower collision could fold but had no independently controlled load-bearing leg placement onto the upper deck.
- The v0.8 functionality is experimental, with flags defaulting off; earlier climbing routes are preserved.

**Do not continue increasing wrist moment, arm force, foot force, leg-collision flexibility or posture gains to coerce the old M6/v0.8 sequence.** The new strategy reduces the scope of physical fidelity **only during the assisted top-out**.

The successful v0.8 isolated modules remain useful reference work, not mandatory runtime dependencies for v0.9. In particular, the hybrid design should **not require successful palm compression or a physically planted high foot** as preconditions.

---

## 3. Scope and non-goals

### Required in v0.9

- A reproducible static-ledge detector and input gate.
- An actual integrated mantle animation/pose sequence with a synced rigid-body route.
- Temporary, explicit controller-authority handoff from dynamic climbing to collision-aware assisted motion and back.
- Shape/clearance strategy that permits crouched/tucked traversal without disabling world collisions.
- Correct left/right hand pose transitions and contact cleanup.
- Continuous collision validation of movement and geometry changes.
- Safe cancellation/refusal/blocked recovery, with no stuck input/anchor states.
- Completion proven by genuine native ground support and functional walking.
- Regression checks for the previously approved climbing routes.

### Excluded unless separately approved

- Full skeletal ragdoll, per-bone muscle controller, fully physical palm/forearm/leg mantle.
- Automatic route planning, automatic moving-hand regrips for general climbing.
- Dynamic/moving/platform-mount mantle in M1–M5.
- Stamina, inventory, multiplayer, climbing upgrades or new player movement systems.
- Replacing the existing general grip solver, body mass or ground controller.

### Architectural principle

**All assistance is state-scoped and recoverable.** `DYNAMIC_CLIMBING` and `DYNAMIC_GROUNDED` use the existing physical rules. `ASSISTED_MANTLE` is a short, clearly owned kinematic/animated exception; no hybrid actuator or collision profile may leak into ordinary movement.

---

## 4. User controls and UX

### Control map (preserve baseline)

| Input | Outside mantle | Eligible mantle / active mantle |
|---|---|---|
| LMB held | Left hand hold-to-grip | Required for acquiring the initial legitimate grip; during committed animation, visual contact is animation-controlled |
| RMB held | Right hand hold-to-grip | Same for right hand |
| W | Existing forward/upward intent, based on climbing/ground state | Requests mantle when eligibility gate is true; after commitment no extra W pumping required |
| S/A/D | Existing movement and swing behaviors | Suppressed as forces during committed animation; optional queued ground intent after handoff |
| MMB + drag | Orbit camera | Orbit remains available if it does not disturb anchor/animation alignment |
| Scroll | Dolly | Camera zoom remains available |
| R | Existing restart | Reset current maneuver/level using existing semantics |
| Esc / pause | Existing pause behavior | Controlled pause; no loss of transform or half-restored physics |

### Initiation

- Use **W** as the initial candidate request, with a short configurable eligibility dwell (prototype suggestion: **0.08–0.15 s**, tune by playtesting).
- The command must remain consistent with the current intent-driven profile: only start when a **ledge-specific eligibility test** passes. Otherwise W continues its normal meaning.
- No additional mandatory key or hidden two-hand regrip operation.
- Once committed, the animation proceeds as one coherent action; users do **not** have to keep LMB/RMB/W pressed to prevent mid-animation drops.
- Releasing grip buttons **before** commitment retains existing immediate-release behavior. Releasing them **after** commitment changes only the physical-input flags; it does not abort the authored motion.

### Player feedback

- Before commitment: subtle ledge eligibility cue, with an optional debug text explaining refusal.
- At commitment: brief animation/pose blending so the body does not snap into a generic hanging pose.
- During action: clean camera framing and visible hand contact, no repeated input required.
- On obstruction: action pauses or transitions to a safe recovery, and the cause is legible.
- On success: normal third-person walking resumes seamlessly with no additional confirmation.

Avoid a large mantle HUD or a rhythm-game-style timing minigame. The mantle's role is traversal continuity.

---

## 5. Ledge detection and eligibility

Implement a compact `MantleCandidate` that is regenerated from **live geometry**, not painted sockets or an author-placed teleport endpoint.

### Inputs

- At least one genuine `ATTACHED` grip on or near the target upper ledge (not pending and not slipping).
- Player pose, body/collision dimensions and current movement state.
- Selected grip's collider and material-local point/normal.
- Camera-relative desired forward direction, projected toward the supporting structure.
- Platform top surface and front face geometry.

### Static platform eligibility for first milestone

1. Supporting collider is static or belongs to the approved world-static category; reject dynamic and moving bodies for now.
2. A top surface with `normal · UP >= 0.85` (configurable) is detected by **multiple** independent probes, not one coincidental ray hit.
3. Top is connected geometrically to the gripping ledge and of sufficient depth/width for **the standing footprint plus margin**.
4. Start location is near a real upper edge and the body is within an authored mantle-start envelope (distance, height difference, lateral offset, and facing).
5. Target standing position is collision-free with the **actual standing collision profile** and has ground support.
6. A feasible candidate *corridor* exists for the sequence of poses described below. Merely verifying the endpoint is **not sufficient**.
7. The player explicitly requests mantle with W, with no current dyno/launch, slip, pause or invalid input ownership.

### Required candidate data

```text
MantleCandidate
  support_id / instance_validity
  source_hand(s)
  top_normal_world
  outward_world / inward_world
  edge_tangent_world
  anchor_local_on_support
  top_reference_world
  start_pose_world
  target_standing_pose_world
  estimated_path_samples
  allowed_collision_profile_id
  eligibility_reason
  clearance_reason
  candidate_timestamp
```

### Rejection examples

- `NO_REAL_GRIP`
- `GRIP_SLIPPING`
- `NOT_A_LEDGE`
- `NO_FLAT_TOP`
- `TOO_NARROW`
- `TARGET_OCCUPIED`
- `PATH_BLOCKED`
- `CEILING_BLOCKED`
- `UNSUPPORTED_DYNAMIC_PLATFORM`
- `START_POSE_OUTSIDE_ENVELOPE`
- `SUPPORT_INVALIDATED`

Never silently increase the detection range to make failed tests pass. Prior v0.8 detection may be reused only if it satisfies these additional requirements.

---

## 6. Hybrid locomotion state machine

Create a dedicated `HybridMantleController`, independent of the general arm actuator, with explicit states:

```text
DYNAMIC
  └─ [eligible ledge + player W] → PREPARE
PREPARE
  ├─ [validation fails] → DYNAMIC
  └─ [collision/animation route available] → COMMIT
COMMIT
  └─ [atomically transfer authority] → ASSISTED_TRAVERSE
ASSISTED_TRAVERSE
  ├─ [valid segment] → next animation segment
  ├─ [blocked] → BLOCKED_RECOVERY
  └─ [final supported pose reached] → RESTORE_DYNAMIC
BLOCKED_RECOVERY
  ├─ [safe restart/rollback permitted] → DYNAMIC or saved safe state
  └─ [otherwise] → controlled recovery/reset, never penetrate
RESTORE_DYNAMIC
  ├─ [standing support confirmed] → DYNAMIC_GROUNDED
  └─ [not confirmed] → BLOCKED_RECOVERY
```

### Authority handoff: critical ordering

During `PREPARE`:

- Record character transform, linear/angular velocity, grip identities, source surface and currently held buttons.
- Perform candidate checks **without freezing or moving the body**.
- Validate a coherent authored assisted path against collision geometry.
- Ensure the animation clip/pose driver exists and has initial-frame alignment.

During `COMMIT` (one controlled physics-tick transition):

1. Mark the climbing/ground input motors **not authoritative**, so they stop applying climbing, ground, foot and wrist forces.
2. Retire real grip force/constraint ownership without one uncontrolled tick between physical and assisted authority.
3. Transfer visible hand control to animation/IK anchors at the remembered ledge points; these are presentation-only during the assisted phase.
4. Change the body to the approved assisted-movement mode, with its collision profile safely applied.
5. Initialize animation phase from the **actual body pose**, not an assumed canonical hanging transform.

During `RESTORE_DYNAMIC`:

1. Verify true ground support and non-overlapping standing collision profile.
2. Ensure all assisted hand contacts and latent timers are removed.
3. Restore the original dynamic collision geometry and normal physics mode.
4. Restore ground controller ownership only after support is confirmed.
5. Reinitialize velocities *safely*: use measured final assisted movement and support velocity as reference, avoid restoring stale incoming swing velocity or applying a large impulse. Do not set all velocities blindly to zero if doing so causes visibly abrupt behavior.
6. Avoid stale held-button events recreating a hand grip on the ledge when the maneuver ends; require a fresh grip press or explicit input rearming.

**Every transition must be idempotent:** pause, reset, lost focus, or multiple input callbacks must not apply COMMIT or RESTORE twice.

---

## 7. Physical-body representation during assisted movement

### Recommended prototype strategy

Use the **existing `RigidBody3D`** as the authoritative gameplay body, temporarily moved by a collision-aware kinematic controller:

- In the assisted phase, test `RigidBody3D.freeze_mode = FREEZE_MODE_KINEMATIC` with `freeze = true`.
- The body is temporarily exempt from dynamic gravity/force integration, **only while the mantle animation is active**.
- Move it through collision-tested steps, not direct large global-transform jumps.
- Inspect behavior against Godot **4.7.2 + integrated Jolt**; engine APIs are candidate techniques until verified on the project's exact version.

Godot 4.x documents kinematic frozen `RigidBody3D` as able to collide along animated motion and provides `PhysicsBody3D.move_and_collide()` / `test_move()`. Their **swept linear movement does not automatically certify arbitrary compound rotation and shape morphing**, so implement additional queries and substepping.

**Alternative implementation to evaluate if the frozen RigidBody path is unreliable:** a temporary `AnimatableBody3D` or other test body that owns collision-query movement, synchronized with the gameplay transform and with a guarded return to the original rigid body. This is an isolated fallback, not permission to maintain two contradictory active colliders or bypass contacts.

### Collision rules

- Do not globally disable the character-world collision layers.
- Do not transform the mesh independently of the gameplay body.
- Do not simply set the rigid body `global_transform` each render frame without collision queries.
- Check all meaningful occupied body volumes, including head, chest, knees and feet.
- Treat runtime dynamic objects as potential blockers. v0.9 does not have to push them physically like a full dynamic character; it may stop/refuse the maneuver instead.
- All assisted movement runs on the fixed physics tick and renders through interpolation.

---

## 8. Mantle animation and root path

### Animation requirement

Create or author a **short genuine mantle animation** for the existing Quaternius mannequin rig. The imported animation library contains multiple clips, but the supplied reports **do not establish that a suitable mantle clip exists**; do not invent one. Verify clips before use.

Use `AnimationPlayer` and/or `AnimationTree`; the chosen pose source should support animation blending and, if available, root-motion deltas. Godot's `AnimationTree` exposes `get_root_motion_position()` and `get_root_motion_rotation()`.

### Suggested first authored phases (timings are hypotheses)

| Phase | Example portion | Gameplay meaning |
|---|---:|---|
| A — Acquire / settle | 0–15% | Blend from actual hanging pose to a coherent hand-supported pose |
| B — Lift / rotate | 15–48% | Raise torso toward lip and rotate over edge |
| C — Tuck / cross | 48–75% | Legs and knees tuck as hips pass across the edge |
| D — Plant / stand | 75–100% | Unfold feet and stand on top |

Try a first total duration of **0.75–1.20 s**; tune after implementation and player testing. This is not a requirement for perfectly uniform animation speed.

### Important: animation vs body route

There must be **one authoritative collision-body route** through world space. Two acceptable designs:

**Option A — Root-motion led route:** author the clip with meaningful root motion, transform deltas into a ledge-aligned frame, and feed them into the collision-aware controller. If blocked, do not advance motion/pose beyond the validated time.

**Option B — Parameterized ledge route:** author an explicit smooth route relative to the detected ledge (start, rise, forward cross, standing endpoint), while a pose animation follows normalized progress. This can be easier to calibrate for different ledge heights than raw root motion.

Choose **one** for the first implementation and record why. Do **not** simultaneously add root-motion travel and a separate position curve; that would double the displacement.

### Starting pose continuity

- Begin from the actual character position and orientation.
- Align the authored initial upper-body/hand pose with the existing attachment frame using a short pose blend or additive offsets.
- Preserve meaningful hand-to-ledge contact visually until the animation intentionally plants/releases that hand.
- Suppress general two-bone climbing IK from fighting the mantle animation; blend IK weights on purpose, rather than disabling all limb alignment instantly.
- Never assume starting positions precisely match fixture constants.

---

## 9. Pose-specific collision strategy

The v0.8 report demonstrated that a visually tucked leg does not automatically clear a rigid lower-body/sole collider. This issue **must be handled explicitly**, even with animation assistance.

### Recommended first pass

Provide at least two documented physics-body collision profiles:

1. `CLIMBING_NORMAL`: existing baseline compound shape, unchanged.
2. `MANTLE_TUCKED`: reduced/repositioned lower-limb proxies corresponding to the compact intermediate body pose, while keeping meaningful head and torso collision.

Optional third: `MANTLE_STAND_TRANSITION`, an intermediate shape for restoring full standing geometry.

### Collision-profile transition rules

- A shape change must be checked **before** it becomes authoritative.
- Prefer small steps/swept proxy checks or shape queries over instant resizing into an obstacle.
- Keep an immutable baseline of collision transforms/dimensions and restore it on exit/reset.
- A tucked profile must not remove the torso/head from world collision.
- Never temporarily hide all collision to cross the lip.
- If the final standing shape cannot fit, do not finish the mantle even if the smaller tucked shape fits.
- Shape changes inside an active physics body must be performed at engine-safe synchronization points; verify Godot/Jolt behavior rather than mutating shapes during unsafe physics callbacks.

### Geometry authoring note

A **static platform** should provide a sensible mantle ledge shape (lip thickness, top depth, side clearance). The system should handle natural geometry variation but does not need to mantle impossibly narrow or fully enclosed ledges.

A candidate requiring physical limb articulation beyond what these profiles can represent should be rejected or deferred rather than forced through geometry.

---

## 10. Continuous path validation

The most important v0.8 warning was that `destination_clear` did **not** establish a valid path. v0.9 must close that gap.

### Before commitment

Build a finite set of route samples from the current pose to the standing endpoint:

- Sample body position and orientation through the mantle path.
- Sample collision-profile changes through animation progress.
- Include head/chest/limb proxies at each sample.
- Test collision/overlap along each path segment with conservative margins.
- Subdivide further based on **distance traveled, rotational delta and collision-profile delta**, not just elapsed seconds.
- Reject any route where the available query resolution cannot establish safe traversal.

### During execution

- Recheck every step using the actual live world and approved movement calls.
- Stop at an obstacle instead of moving through it.
- Never force the position to match the animation after a movement was blocked.
- Pause pose advancement if body movement is blocked, to avoid skeleton/collider divergence.
- If an obstacle is transient, optionally wait for a short bounded interval. Otherwise enter blocked recovery.

### Why both passes?

The preflight avoids beginning obviously impossible maneuvers. Runtime checks handle moving or newly obstructing objects and numerical differences. Neither preflight nor an animation curve alone is sufficient.

### Failure telemetry

Record `blocked_collider`, `blocked_segment`, `body_pose`, `collision_profile`, `progress`, `attempted_motion`, `allowed_motion`, `time_blocked`, and the chosen recovery action.

---

## 11. Blocked maneuvers, input cancellation, and recovery

**Do not solve failure by teleporting back through solid geometry.** Recovery is a first-class feature.

### Before commitment

If eligibility/path validation fails, do nothing to the physical character. Remain in normal climbing, show a small reason if debug feedback is enabled, and let the player reposition.

### During assisted traversal

Choose the **safest** supported recovery, in this order:

1. Pause/limit the authored travel at the last validated non-penetrating pose. Continue only if geometry becomes clear within a short bounded wait.
2. If a prevalidated reverse route exists and the original grip/support is still valid, play a collision-checked reversal to a safe hanging state; only then restore physical grip authority.
3. Otherwise allow a controlled fall/release at the current **collision-valid** position with restored dynamic physics, if this is safe and avoids overlaps.
4. If no safe physical continuation can be produced, stop the trial and offer the existing explicit restart/checkpoint action. Never conceal this as success.

### Hard reset / pause / window focus

- Reset destroys all mantle-only states, restores the original collision shape and physics flags, and clears old grip/animation commands.
- Pause freezes time coherently, rather than letting animation and physics advance differently.
- Focus loss must not replay a held input after returning; require fresh input to start a new mantle.
- A support object becoming invalid cancels the candidate. Moving-platform support loss during already committed v0.9 mantle is treated as a blocked recovery, not secretly followed as a supported dynamic mantle.

---

## 12. Finishing and restoring dynamic gameplay

The animation reaching `100%` is **not** sufficient for success.

### Required physical finish

1. The character's **normal standing collision profile** fits without penetration.
2. A valid top-platform **ground probe / native collision** reports support from the expected static top collider.
3. Character orientation is in an acceptable upright interval and any residual movement is within safe transition bounds.
4. Both visual hand contacts and real grip actuators from the previous climb are cleared.
5. Dynamic `RigidBody3D` behavior is restored cleanly, and the ground controller can own locomotion.
6. The player can walk forward at least **0.30 m** using normal ground input (same measurable goal as the earlier M6/v0.8 reports).

### Velocity and frame continuity

- Do not restore the old pre-mantle incoming swing velocity after the body has been transported to the standing endpoint.
- Derive an appropriate starting velocity from the final approved assisted movement and relative support motion; clamp/attenuate only as needed to avoid explosive unfreeze.
- Avoid accumulating queued forces, grip requests, or ground-control torque through the animation.
- After dynamic authority is restored, resume normal camera tracking, IK and ground animation by blending rather than abrupt resets.

### Completion telemetry

`ANIMATION_COMPLETE`, `STANDING_COLLISION_CLEAR`, `TOP_GROUND_VALID`, `GRIPS_RELEASED`, `DYNAMIC_RESTORED`, `WALK_DISTANCE_MET`, `MANTLE_COMPLETE` should be separately visible to tests.

---

## 13. Animation ownership and hand visuals

During the assisted phase, **authored upper-body pose** becomes authoritative for the visual skeleton.

- Hands initially remain aligned with the remembered material grip location.
- Contact can be kept using temporary IK targets anchored to the static ledge frame.
- At the appropriate animation phase, hand IK weights blend down and release visually.
- There must be no physical arm-motor force merely because a hand is drawn on the ledge during assisted movement.
- The mannequin's foot placement may use lightweight contact correction during the final stand, but it must not create gameplay support without the actual body ground check.

Provide a **debug split view / overlay** for the actual rigid-body position, torso collider, tucked lower-body proxy, animated skeleton root, wrist/palm targets and detected platform top. Any significant drift between visual foot/palm and physical support must be recorded, not hidden.

---

## 14. Camera, pacing and player perception

- Keep the camera in familiar third-person follow; do not switch to a cinematic cut unless testing proves necessary.
- Preserve MMB orbit and mouse wheel dolly where they remain safe.
- Temporarily adjust framing so the platform top and character body remain visible.
- Do not rotate the camera automatically by a large angle in mid-mantle.
- The animated transition should be readable at regular gameplay speed.
- Do not add a long recovery lockout after standing.
- Use an optional small contextual ledge indicator in early tests; minimize UI in the final experience.

Prioritize **consistency over photorealistic pose matching**. A clean 0.9-second authored mantle that always transitions safely is more valuable here than a brittle physical solver that only works on specially tuned geometry.

---

## 15. Implementation modules and boundaries

Suggested modules, subject to inspection of the real working tree:

| Module | Responsibility |
|---|---|
| `mantle_candidate_detector.gd` | Real ledge geometry, eligibility, width/depth/top classification |
| `hybrid_mantle_controller.gd` | Phase state machine and temporary control authority |
| `mantle_path_planner.gd` | Ledge-aligned target route and preflight sampled clearance |
| `mantle_kinematic_motor.gd` | Actual approved body travel with collision tests/substeps |
| `mantle_collision_profiles.gd` | Normal/tucked/stand shapes, safe transition/restore |
| `mantle_animation_driver.gd` | Blend, root-motion or normalized pose progress, IK ownership |
| Existing `climbing_controller.gd` | Grip-state handoff hooks only; core actuation unchanged |
| Existing `ground_locomotion.gd` | Reacquisition of normal ground authority |
| Existing `biped_visual.gd` | Limb pose blending, visual hand/foot coherence |
| `test_hybrid_mantle.gd` | Unit, integration and functional acceptance tests |
| Existing lab / HUD | Static platform selection, input, diagnostics, reset |

**Do not create all these files mechanically if existing modules provide the responsibility cleanly.** Favor minimal incremental changes with explicit ownership.

Suggested feature flags:

```ini
hybrid_mantle_v09_enabled = false
hybrid_mantle_debug = false
hybrid_mantle_static_only = true
hybrid_mantle_collision_profile = "MANTLE_TUCKED"
hybrid_mantle_animation_mode = "PARAMETERIZED_PATH" # or ROOT_MOTION
hybrid_mantle_resume_recovery = true
```

Legacy experimental `palm_compression_enabled`, `palm_wrist_support_enabled`, `adaptive_leg_collision_enabled`, and `mantle_support_handoff_enabled` must not silently auto-enable this implementation.

---

## 16. Prototype scenes

### Scene A — Low Static Ledge

Use the report's **1.25 m** platform, with sufficient top depth and a clear approach. Provide a repeatable start: ground → genuine grip → request mantle → physically supported stand → walk 0.30 m.

### Scene B — High Static Ledge

Use the report's **2.10 m** platform, which previously failed even with the v0.8 physical capabilities. The player must still legitimately reach a real ledge. The assisted transition starts only from a geometrically valid mantle-ready pose; do not lower the platform during runtime.

### Scene C — Narrow Platform

A platform with a clear upper normal but insufficient standing depth. Must refuse the mantle; no partial clipping or false success.

### Scene D — Overhead Blocker

A ceiling or crossbar blocks the planned head/torso path. Must refuse before commitment or safely stop at the collision.

### Scene E — Occupied Destination

Another solid body occupies the landing zone. The candidate must be rejected or halted; it must not displace the blocker unrealistically.

### Scene F — Moving/Hinged Support

Attempt to mantle from a genuinely dynamic support. v0.9 **must not** claim success; show `UNSUPPORTED_DYNAMIC_PLATFORM` and preserve normal climbing behavior.

### Scene G — Interruption & Recovery

Test lost focus, pause, restart, support invalidation, early button release, rapid input sequences, and reset during every phase.

---

## 17. Tests and acceptance gates

### Safety invariants (all must hold)

- No hidden dynamic force used to boost the climb before mantle eligibility.
- No active old grip actuator while kinematic assisted travel owns the body.
- No direct transform teleport through colliding geometry.
- No collision-layer disabling as a maneuver shortcut.
- No phase success declared purely from animation progress or endpoint query.
- Original v0.7.3 movement and all profiles function when v0.9 flag is OFF.
- No stale hands/inputs, duplicate COMMIT, invalid support references or collision-profile leaks.
- Physics at 60/120 Hz remains reasonable; no assumption of bitwise-identical trajectories.

### Functional tests (must actually pass)

| ID | Scenario | Pass condition |
|---|---|---|
| F1 | 1.25 m static ledge | Complete hanging-to-standing sequence and walk ≥0.30 m |
| F2 | 2.10 m static ledge | Same full criterion; genuine initial grip, no staged transport before request |
| F3 | Varied valid start poses | Mantle begins without visible root snap and ends supported |
| F4 | Narrow top / blocker / occupied goal | Correct refusal/stop; no penetration |
| F5 | Button release after commit | No unplanned fall or repeated mantle request |
| F6 | Button release before commit | Existing hold-to-grip behavior preserved |
| F7 | Camera orbit / pause / reset | No hand/shape/animation desynchronization |
| F8 | Dynamic ledge | Explicit rejection; normal climbing still works |
| F9 | Repeated mantles | Two consecutive top-outs with normal walking between, no lingering assisted state |
| F10 | Independent playtest | Player can discover and execute the action comfortably without debugging commands |

### Gate policy

Passing all **safety tests** is **not** enough. The milestone is **FAIL** if F1 or F2 cannot be completed. Preserve failed results and recorded traces. Do not mark v0.9 complete simply because an animation played or because the destination was free.

### Human feel pilot

Ask players to perform several ordinary ledge ascents and score (1–5):

- Trigger clarity: when will W mantle versus normal climb?
- Responsiveness: time from clear request to first visible motion.
- Visual continuity: arms, hips and legs look connected through the ledge.
- Reliability: can the same valid ledge be climbed consistently?
- Control return: does walking resume naturally?
- Perceived fairness: are invalid ledges rejected predictably?

Record number of attempts, unplanned refusals, interruption states and successful top-outs. Automated script success never substitutes for human testing.

---

## 18. Milestones and implementation order

### M0 — Audit / freeze baseline

- Read live repository, current branch, v0.7.3 approved route and v0.8 failed experiment.
- Confirm actual engine APIs in Godot 4.7.2/Jolt and existing animation clips.
- Create a branch/snapshot without altering the preserved climbing builds.
- Reproduce 1.25/2.10 m v0.8 failures and retain test evidence.

**Gate:** known baseline, same failure conditions, no source loss.

### M1 — Assisted body motor isolated lab

- Experiment with frozen kinematic `RigidBody3D` versus a temporary kinematic collision authority, selecting one validated approach.
- Execute a simple approved translation + rotation path on an unobstructed test body.
- Verify collisions stop motion, rather than allowing tunneling.
- Verify physics authority switches exactly once.

**Gate:** movement and physics restore are reliable **without** mantle animation.

### M2 — Mantle route and collision profiles

- Detect ledge, compute candidate and final standing target.
- Implement sampled/swept body path checks.
- Create and validate tucked/standing collision transitions.
- Reject narrow/blocked routes.

**Gate:** route travels across an actual lip without unsafe penetration using debug pose driver.

### M3 — Visual mantle animation and hand contact

- Author or verify a usable mantle clip on the Quaternius mannequin.
- Synchronize animation progress with collision-approved body position/rotation.
- Blend hand IK and temporary visual grip contact cleanly.
- Verify there is no visual-body drift at the edge.

**Gate:** continuous believable motion and identical gameplay collision result.

### M4 — Ground support handoff / complete static top-out

- Integrate precommit/W input, dynamic-to-assisted transition and restoration.
- Implement valid ground-support finalization and ≥0.30 m walk.
- Test both **1.25 m** and **2.10 m** platforms.

**Gate:** both full functional tests pass using ordinary player input. Otherwise stop and report exact blocker.

### M5 — Adversarial / input resilience

- Test occupied goals, blockers, narrow ledges, pause, focus, repeated inputs, reset and multiple consecutive mantles.
- Run 60/120 Hz suites and baseline climbing regressions.

**Gate:** no leaks, clipping, unintended starts or regressions.

### M6 — Human UX acceptance

- Playtest ordinary approaches (not teleported fixtures), W initiation, natural camera and smooth walking return.
- Revise animation timing/detection only when tests show a real issue.
- Decide `KEEP / REVISE / REJECT`; do not automatically promote the feature.

**Gate:** both technical and human acceptance are documented.

---

## 19. Telemetry and reproducibility

Log a time-stamped per-attempt trace:

```text
mantle_attempt_id
scenario_id
engine_build / physics_hz
candidate_support / selected_grip_ids
eligibility_status / rejection_reason
body_world_transform / incoming_velocity
ledge_top / outward / inward
planned_path_version / path_samples / path_clearance
collision_profile_id / collision_shape_transforms
state / animation_progress / actual_body_progress
attempted_motion / allowed_motion / blocking_body
visual_root_error / hand_contact_error
freeze_mode / freeze / motor_ownership
ground_support_id / actual_ground_normal
final_body_velocity / restored_dynamic_state
walk_distance_relative_to_support
result: COMPLETE | REJECTED | BLOCKED | RECOVERED | RESET
```

Keep snapshots at essential transitions, plus optional frame-by-frame traces in the existing JSONL infrastructure. Preserve the raw failed attempts, not only successful verification summaries.

---

## 20. Required task split / Codex handoff

### Main Codex agent

Own project audit, scene and input integration, candidate geometry, feature flags, testing orchestration, animation presentation, recovery UX and final results. Preserve v0.7.3 approved path and the v0.8 experiment as a separately disabled comparison.

### Physics specialist

Own the audit of freeze/kinematic collision behavior in exact Godot/Jolt build, robust swept/rotational clearance and collision profile transitions, safe handoff back to dynamic simulation, and physical state invariants. Sign off only on mechanically accurate claims for the limited scope of an **assisted** mantle.

### Animation/gameplay integrator

Own believable root/pose authoring, entry blending from actual hanging pose, ledge hand anchors, pose-to-body coherence, end-of-mantle idle/walk blend and observable responsiveness.

### Mandatory report per milestone

- Exact files changed and branch/commit.
- Feature flags and initial/final values.
- Algorithm description and why chosen over alternatives.
- Automated/rendered tests with pass/fail and actual scenario ids.
- Human-played behavior if relevant, clearly separated from automation.
- Remaining blockers and explicit next-step `GO / NO-GO`.

**Stop at a failed gate. Do not increase arm strength, disable collisions, invent contact support or silently change the character model to make a screenshot look successful.**

---

## 21. Success definition

**GRIP UP v0.9 is successful only when:**

> From normal physics-driven play, the character reaches a legitimate stationary ledge, deliberately initiates a short animation-assisted mantle, moves its true collision body along a validated obstacle-free route, finishes with a real supporting collision on top, and immediately resumes normal dynamic third-person walking—without teleports, penetration, leftover grips or a brittle one-off fixture cheat.

The climbing system remains physically driven everywhere else. This approach makes a deliberate tradeoff: **simulation purity is relaxed briefly to make traversal continuous, comfortable and production-viable.**

---

## References / project evidence

- User-provided *M6 — relatório físico da tentativa de mantle / top-out*: neither 1.25 m nor 2.10 m mantle completed with tension-only arms plus limited torque; observed body origin, leg collision limitations and missing palm compression.
- User-provided *GRIP UP v0.8 — physical capability experiment*: palm/leg capabilities passed isolated safety tests; full top-out failed, contact chain invalidated, dynamic standing/walking not achieved.
- Godot `RigidBody3D`: `FREEZE_MODE_KINEMATIC` and frozen-body movement behavior — https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html
- Godot `PhysicsBody3D`: `move_and_collide` and `test_move` behavior — https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html
- Godot `AnimationTree`: root-motion access and blended animation — https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html

**Verification caveat:** Published Godot documentation establishes the available APIs, but exact frozen-body rotational sweeps, dynamic-contact behavior, animated collision transitions and interpolation must be verified against this project's actual Godot 4.7.2/Jolt build.
