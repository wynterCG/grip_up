# GRIP UP — Physics Climbing Prototype Specification v0.2

**Status:** Proposed next iteration — implementation brief for Codex and the physics specialist  
**Engine:** Godot 4.7.2 (as reported in the existing build)  
**Physics:** Jolt, 120 Hz primary / 60 Hz comparison  
**Target:** Windows PC, third-person, landscape 16:9, mouse and keyboard  
**Source of truth:** The supplied GRIP UP v0.1 implementation report. This document proposes changes; it does not claim that the proposed features have already been implemented.

---

## 1. Objective

**Move from a functional force-driven climbing controller to a predictable, expressive climbing system in which hands anchor, feet push, the body redistributes load, and dynamic structures react to those forces.**

Do **not** rebuild the existing controller from scratch. The prototype already supports free-surface gripping, two independently controlled hands, arm-force distribution, swinging, a charge-and-release launch, ground locomotion, IK visuals, and reactive supports. The work in v0.2 is to address known shortcomings and add targeted depth.

### Design pillars

1. **Physics produces motion.** Never teleport the climber into a pose or inject arbitrary body velocity to satisfy a requested movement.
2. **Player intent is simple.** Keep climbing comprehensible with mouse + keyboard; do not require direct control of every joint.
3. **Failure is legible.** Players should understand whether a catch failed due to reach, obstruction, relative speed, insufficient support, or grip overload.
4. **Movement is predictable, not trivial.** Small timing tolerances can compensate for input ambiguity, not circumvent geometry and physics.
5. **The world pushes back.** Dynamic supports receive equal-and-opposite reactions to the player's forces.
6. **Preserve feel.** The existing game is a valuable baseline; each improvement must be independently testable, measurable, and reversible.

## 2. Verified-by-report v0.1 baseline (do not regress)

The supplied implementation report describes:

- A single dynamic `RigidBody3D` climber with four collision shapes, animated biped visuals and IK-driven limbs; no full physical ragdoll.
- Independent LMB/RMB hand states: `FREE`, `REACHING`, `ATTACHED`, `SLIPPING`, `RELEASED`; **hold to grip** is the default.
- Free placement of hand targets on valid surfaces (not restricted to colored holds); local-space contact points follow moving/rotating supports.
- Finite-speed hand reach, line-of-sight/obstruction validation, actual arm reach, contact-aware force calculation, gradual force engagement, shared force/torque budgets and opposite reactions on dynamic supports.
- Third-person ground movement, pendular suspension and limited torso-roll assistance, leg IK and secondary motion, but **feet do not yet generate independent climbing support forces**.
- Charged launch using existing arm actuators; subsequent catches are functional but inconsistent in some poses.
- Three lab scenarios: **Static Climb**, **Swing & Catch**, **Reactive Structure**.
- Existing debugging HUD, JSONL run telemetry, 60/120 Hz checks, and **962 reported automated checks passing** as of the baseline report.
- The GRIP UP folder is reported not to have its own Git repository. The original Janga grabber is separate and should remain unchanged.

### Existing measured tuning (baseline values, not new design targets)

| Parameter | Reported v0.1 value |
|---|---:|
| Climber mass | 12 kg |
| Total hand force limit | 360 N |
| Total climbing torque limit | 150 Nm |
| Attitude assistance maximum | 20 Nm |
| Arm spring stiffness / damping | 6000 / 220 |
| Anatomical selectable hand reach | ~0.65708 m |
| Maximum physical arm extension | ~0.66 m |
| Hand reaching speed | 4 m/s |
| Grip force engagement | 0.10 s |
| Charge duration (nominal) | 0.45 s |
| Measured launch gain in one reported test | ~0.30 m at 120 Hz / ~0.22 m at 60 Hz |

These values are retained as reference measurements. Do not silently retune them all at once.

## 3. Scope and exclusions

### In scope

- More robust post-launch targeting and hand capture.
- Independent physical foot support **without** adding a full leg ragdoll.
- Support-aware posture assistance, with no camera-induced physical motion.
- Directional grip-quality and gradual slip behavior.
- A short reactive-climbing challenge that uses movable supports and body weight.
- Transition improvements for ground → reach → hang, and a prototype edge/mantle solution only after core milestones are stable.
- Instrumentation, regression tests, playtest scenarios and tunable feature flags.

### Out of scope

- New campaign, multiplayer, stamina/food, injury systems, content progression or cosmetic systems.
- Full-body ragdoll or individually simulated finger joints.
- Automatic handholds, forced animation-based climbs or scripted cinematic launch boosts.
- Procedural mountain generation or mobile controls.
- Breaking the existing Janga object-grabber or replacing the established GRIP UP controller wholesale.

## 4. Input and interaction contract

Preserve the default layout in v0.1 unless a user test proves a specific change necessary:

| Input | Existing behavior |
|---|---|
| Hold LMB | Reach/grip with left hand; release to let go |
| Hold RMB | Reach/grip with right hand; release to let go |
| W while attached | Pull by contracting arm actuators |
| S while attached | Extend to lower the body |
| A / D while attached | Lateral effort redistribution/swing |
| Hold then release Space while attached | Prepare and execute physical launch |
| WASD on ground | Camera-relative walking |
| MMB drag | Camera orbit |
| Mouse wheel | Camera dolly |
| R | Restart / checkpoint |
| Tab | Diagnostics |
| F in test scene | Compare fixed versus hinged beam |

**Do not automatically release an existing held grip to switch modes.** Buffered targeting and foot support must not change hold-to-grip semantics. Releasing LMB/RMB still releases the corresponding grip. Mouse and keyboard remapping must remain functional.

## 5. Milestone M0 — Protect baseline and instrument differences

1. Create an independent, versioned snapshot or initialize a Git repository for `GRIP UP` (after checking its current file structure). Do not change the Janga project.
2. Record current configuration files, 60/120 Hz test outcomes and representative JSONL play sessions.
3. Run and preserve the current automated tests; capture the full list of suites and pass/fail results. Baseline count is *reported*, not a substitute for running the suite in this working tree.
4. Add feature flags for `predictive_grip`, `physical_feet`, `posture_solver`, `directional_grip_quality` and `reactive_challenge`.
5. Add a debug recording for each frame or selected sample: input intent, grip state, actual and desired reach, local target position, relative target velocity, per-hand applied force, total applied force, current support, body linear/angular velocity and reason for invalid grip.

**Gate M0:** The existing three scenes remain playable. No change to baseline physics feel has been introduced.

## 6. Milestone M1 — Predictive Grip Targeting and reliable catches

### Problem

The hand may be geometrically reachable yet fail to arrive in time after a charged launch. The existing report documents a launch-and-catch success and failures dependent on posture, arrival speed and physics-step rate.

### Desired player behavior

The player aims at a surface during movement and holds the corresponding grip input. The selected hand moves physically to an actual point of contact. If the hand reaches a valid support under admissible relative motion, it attaches; otherwise it misses, slips or fails with a comprehensible reason.

### Proposed components

- `GripCapturePredictor`: projects likely near-future shoulder and target motion over a **short bounded horizon** (experiment initially with 0.10–0.25 s, not an unbounded trajectory).
- `GripIntentBuffer`: maintains a short-lived requested target for a **currently held** button (test ~0.10–0.15 s); release cancels immediately.
- `GripCaptureEvaluator`: makes the final decision from **current physical** hand location, surface contact/visibility, arm extension, relative velocity, angle and grip load.

### Algorithm outline

1. At input, raycast and classify a candidate surface. If the point belongs to a dynamic body, store the **local-space** point on that body.
2. Estimate shoulder trajectory from current body position, linear/angular velocity and known motion inputs. For dynamic supports, predict movement with conservative bounds rather than assuming they are stationary.
3. Estimate how long the hand, limited to its existing finite-speed trajectory and arm reach, would require to reach that point.
4. Expose one of three UX states: `NOW`, `SOON` (potentially capturable during the imminent movement), `UNAVAILABLE`.
5. While input remains held and the brief buffer is valid, advance the reaching hand physically. Recheck obstruction and geometry throughout.
6. Establish attachment **only on a genuinely valid current contact**. Do not pull the hand through solids, lengthen the arm or teleport the wrist.
7. On attachment, preserve incoming body momentum and apply the same limited physical engagement already used by v0.1. Evaluate load using relative contact-point velocity to avoid an unphysical instant stop.
8. If attach/load limits are exceeded, use existing slip logic; report whether the failure was a miss, loss of visibility, excessive relative speed or overload.

### Tuning and instrumentation

- Log target prediction error and actual time to contact.
- Compare capture success at 60 and 120 Hz across a representative pose matrix: centered hang, offset one-hand hang, crossed-arm reach, high angular speed, dynamic support.
- Detect unintended pull forces before attachment, frame-rate dependent launch energy and large post-capture accelerations.
- Keep predictive UI separate from capture authorization; a green marker must never silently grant a physically impossible reach.

**Gate M1:** Designed reachable catches are repeatable across variations of pose and speed; failures provide consistent reasons. A first experimental target is at least 90% success over repeated, deliberately well-conditioned catch attempts, subject to calibration from the actual test rigs. No teleporting, no wall penetration and no extra launch impulse.

## 7. Milestone M2 — Physical Foot Supports (without a leg ragdoll)

### Problem

The legs presently provide IK and secondary visual motion, but no independent push/support forces. Climbing thus relies heavily on hand actuators.

### Design

Introduce an automatic **contact-and-push** system for the left and right foot. IK remains responsible for presenting the limbs; physical impulses originate from limited actuators on the climber's rigid body and are balanced by reactions on dynamic supports.

### State machine per foot

- `SEARCHING`: evaluate nearby reachable support candidates.
- `PLANTING`: move visual foot toward a valid candidate; do not apply support before contact is achieved.
- `SUPPORTING`: maintain a unilateral compressive contact through bounded forces.
- `SLIDING`: the requested tangential force exceeds friction or support validity declines.
- `FREE`: no planted target; the leg follows secondary movement/IK.

### Candidate selection

- Search near the current foot/hip and within plausible leg extension, knee-angle and collision constraints.
- Require a physically accessible surface, not a point behind a wall or through the body.
- Prioritize candidates that improve support and are compatible with the current body pose; add stickiness/hysteresis to avoid rapidly switching between nearby surfaces.
- Store planted contact in **local coordinates** on the support body; recompute world position and contact-point velocity when the support moves.
- Do not automatically grip arbitrary vertical surfaces by suction. A foot may push into a wall and transmit tangential support through friction, but it cannot pull the wall toward the character.

### Force model

At contact, produce a **nonnegative normal compressive force** `N >= 0` (the foot is not a hand anchor). Tangential effort `T` must respect both a locomotion budget and a friction envelope such as `|T| <= μN`.

The controller can use a compliant target and damping to calculate desired force, then project onto the allowed unilateral friction cone and global leg effort budget. Use the relative surface contact-point velocity when computing damping. Apply corresponding equal-and-opposite forces to dynamic supports at the actual contact points.

No force should be applied before a valid support is planted. No hidden ground-relative upward thrust. Feet can extend or lose contact when geometry moves, and can slip when load exceeds limits.

### User control

Initially **no extra buttons**. W/S still command body ascent/descent through the existing arm controller. When a foot is planted, distribute appropriate effort to the legs as part of the same action. Hand inputs remain fully independent.

Expose one debug toggle: automatic foot contacts ON/OFF, so the same route can be compared fairly.

### First test scene

A vertical wall with two fixed hand targets and two clearly usable footholds. Compare climb with feet on/off using identical initial conditions.

**Gate M2:** At least one planted foot measurably reduces hand-force demand and can contribute upward movement via an actual contact. Feet neither pull surfaces nor remain magically attached across gaps. Dynamic supports receive the opposite reaction. Foot IK stays compatible with visual leg lengths.

## 8. Milestone M3 — Support-aware Posture Controller

### Problem

The existing torso-roll assistance is camera-referenced and bounded. This controls unwanted twisting, but is not yet a posture strategy based on load and contact configuration.

### Design

Add a **posture target generator** driven by physical support geometry, not camera yaw:

- One-hand hang: allow meaningful pendular swing; suppress only extreme unwanted torsion where justified.
- Two-hand hang: consider the line between hand contacts and the climber's center of mass; favor efficient arm-force distribution.
- Hand + foot support: favor orientations that let planted feet push and reduce excessive hand torque.

Generate a preferred orientation/angular-velocity target and feed a **bounded torque request** into the existing global torque allocator. Do not add a second unaccounted torque source or overwrite rigid-body rotation.

### Implementation details

- Sample the body center of mass, support contact positions/normals, actual load and angular velocity.
- Use a weighted, tunable objective (support quality, effort reduction, minimal abrupt change, camera-independent comfort) rather than blindly orienting the torso toward the camera.
- Introduce gradual blends between free fall, one-hand, two-hand and mixed hand/foot states.
- Ensure camera movement alone does not cause physical torque, except insofar as the player gives an explicit movement command whose direction is camera-relative.
- Preserve the deliberate swing required by the existing Swing & Catch scene.

**Gate M3:** In controlled comparisons, supported postures reduce unnecessary arm torque while keeping physically useful swing. Rotating the camera with no movement input should not change climber dynamics. No instability when hands cross or support sets change.

## 9. Milestone M4 — Directional Grip Quality

### Problem

Any valid surface can be grabbed, but identical grip quality across very different geometry makes route choice less meaningful. The current grip-integrity/slipping system is an ideal extension point.

### Design contract

Preserve **free-surface targeting**. Do not revert to numbered/color-coded handholds. Instead, model directional grip *quality* after attachment.

Add a tunable `GripSurfaceProfile` describing properties relevant to the chosen robot-clamp fantasy:

- Basic grip strength / admissible force.
- Preferred versus weak load directions relative to surface normal and local contact geometry.
- Tangential holding capacity and slip behavior.
- Optional geometry cues such as a wrapped pipe or protruding ledge.
- Material modifier, if meaningful to this game's fictional grippers.

A mechanical clamp's behavior on a smooth wall differs from a human hand. The physics model must be internally consistent with the selected fictional mechanism; it need not simulate finger-by-finger biomechanics.

### Runtime

1. Obtain the current force request at each anchored hand.
2. Resolve it into components against the support-frame directions.
3. Compare the load to a directional, smoothly varying strength envelope.
4. Feed excess load into existing overload/slipping behavior.
5. Apply hysteresis so contact does not chatter between safe/slipping from tiny numerical fluctuations.
6. Expose clear feedback: grip confident, near limit, slipping; avoid relying solely on HUD numbers.

Do not randomly drop hands. Do not prohibit all climbing on smooth surfaces unless the level explicitly defines them as non-grippable. Avoid handholds with hidden rules the player cannot read.

**Gate M4:** Players can predict, from geometry and feedback, why one grip is more reliable than another. An exposed ledge, a flat wall, and a rotating cylinder have measurably and intelligibly different support behaviors, without adding unavoidable randomness.

## 10. Milestone M5 — Reactive Climbing Challenge

### Objective

Show that **the climber's own weight is a gameplay tool**. The same force/torque code should handle fixed and moving supports; level-specific scripting must not move a beam on behalf of the player.

### Test 1: Rotating Beam

- One hinged beam, clear safety floor, two reachable approach supports and a target ledge.
- The player climbs onto or hangs from the beam, redistributes weight, and induces useful rotation.
- Victory: climber reaches target zone without manually triggering a scripted platform animation.

### Test 2: Counterweight Transfer

- A second simple mechanism with a beam, mass and reachable goal.
- The player changes load by moving their body between grips and, if necessary, foot supports.
- Observe genuine force transfer from player to mechanism and changed route geometry.

### Test 3: Shifting Structure (stretch goal)

- Two linked dynamic elements; the player must use an intermediate grip to modify their relative alignment.
- Implement only after the first two rigs are stable and enjoyable.

### Win validation

Climber must physically reach a clearly defined goal volume. No auto-snap to completion, no checking exact solution poses. Keep checkpoints close enough for repeated technical experimentation.

**Gate M5:** A player can intentionally use body weight and grip placement to move an object and open a route. The result is understandable, repeatable, and not merely a scripted trick.

## 11. Milestone M6 — Ground transitions and mantle (after the core improvements)

Do not add a full locomotion overhaul yet. After M1–M5:

- Improve walking → reaching → hanging transitions to avoid an abrupt loss of ground control while valid foot contacts remain.
- Preserve v0.1's rule against air-propulsion from the walking motor.
- Prototype a physically assisted ledge mantle: hands pull, a foot plants or the body passes the lip, and ground support takes over when valid.
- Keep collision active and forces bounded; no animation-authored teleport to the top.

**Gate M6:** Short ledges can be climbed onto without needing to release hands and hope the controller switches to walking. Mantle assistance never passes the body through ledges.

## 12. Data and debug requirements

Extend the existing HUD/JSONL data, do not replace it. Minimum new fields:

| Area | Data |
|---|---|
| Capture | Input timestamp, predicted contact time, actual arrival, distance, relative speed, failure reason |
| Arms | Force magnitudes, target/actual lengths, shared-budget utilization |
| Feet | Candidate, contact state, normal/tangential forces, slip state, support body ID |
| Posture | Preferred/current orientation, requested/applied torque, support configuration |
| Grip quality | Directional load ratio, strength limit, slip onset/end |
| Reactive scene | Beam angle, angular velocity, contact force, climber position, success/failure |
| Performance | Physics Hz, step cost, FPS and any detected anomalous displacement |

Add debug visualization for contact normals, anchor positions, predicted hand reach and force vectors. These visual aids must be optional and disabled in normal gameplay.

## 13. Automated and manual testing

### Regression policy

- Preserve current suites and representative success cases at 120 and 60 Hz.
- Test core scenarios at both rates; compare outcomes and distributions, not byte-identical trajectories.
- Include reset while hands/feet are attached, losing a support body, losing window focus, changing cameras, crossed-arm targets and moving-structure contacts.
- Maintain test isolation: feature flags allow every new subsystem to be disabled and compared against v0.1.

### Additional deterministic-style rigs

1. **Catch pose matrix:** stationary body, swing toward support, fast upward launch, angular launch, moving target. Record repeated success rate and causes of misses.
2. **Foot support:** flat foothold, sloped foothold, vertical wall press, disappearing foothold, moving foothold, excessive tangential force.
3. **Posture:** one hand, two hands, crossed hands, one hand + one foot, two hands + two feet, camera rotation only.
4. **Grip quality:** favorable load, oblique load, dynamic cylinder, boundary between safe and slipping.
5. **Dynamic reaction:** same hinged beam unloaded, loaded by one hand, two hands and hand+foot.

Use controlled seeds and starting poses where supported, but do not require bitwise simulation determinism.

### Human testing

Ask test players to complete the same short routes with feature combinations disabled/enabled. Record whether they understand failure causes without looking at diagnostic numbers, how many unnecessary retries they make, and whether the system feels more controlled **without feeling magnetized or automated**.

Do not treat an improved acceleration graph as proof of a better game feel.

## 14. Proposed architecture (extend existing modules)

**Existing modules named in the report:**

- `climbing_controller.gd` — hand states, effort allocation, slipping, attitude assistance and launch.
- `arm_actuator.gd` — arm-force calculation.
- `grip_anchor.gd` — local support contact and contact velocity.
- `grip_targeting.gd` — target selection.
- `biped_visual.gd`, `biped_leg_motion.gd`, `biped_hand_pose.gd` — presentation/IK.
- `ground_locomotion.gd`, `climbing_camera.gd`, `climbing_input_router.gd`.
- `climbing_tuning.gd`, `biped_tuning.gd`, `grip_up_lab.gd` and lab scene logic.

**Proposed additive modules (names indicative):**

```text
features/grip_up/
  climbing/
    grip_capture_predictor.gd
    grip_intent_buffer.gd
    foot_contact_solver.gd
    foothold_candidate_sampler.gd
    posture_target_solver.gd
    grip_surface_profile.gd
    reactive_climb_goal.gd
  tests/
    grip_capture_matrix_test.gd
    foot_support_regression_test.gd
    posture_support_test.gd
    directional_grip_test.gd
    dynamic_support_reaction_test.gd
```

Adapt to the repository's actual structure after inspection; do not create duplicate sources of truth. Keep the force budget centralized. Visualization/IK consumes physical state, never silently drives the rigid-body body transform.

## 15. Milestone order and acceptance gates

| Order | Deliverable | Required gate |
|---|---|---|
| M0 | Baseline snapshot, tests, metrics and feature flags | Existing behavior preserved |
| M1 | Predictive hand targeting and fair capture | Repeated catches with justified failures, no physics bypass |
| M2 | Physical foot contact and leg pushing | Reduced hand demand; no tensile/ghost foot support |
| M3 | Support-aware posture assistance | Stable weight transfer; camera-neutral physics |
| M4 | Directional grip quality | Different grips have readable consequences |
| M5 | Reactive climbing level | Body weight controls actual moving mechanism |
| M6 | Ground transitions + mantle experiment | Smooth, collision-valid transition onto a platform |

**Integration rule:** Complete each gate, test manually, and capture baseline-vs-change evidence before proceeding. A passing unit suite does not replace an interactive feel test.

## 16. Final acceptance criteria for v0.2

- [ ] Original GRIP UP scenes and inputs continue to work.
- [ ] No changes are required to the original Janga project.
- [ ] Charged launches can be followed by reliable, physically legitimate grabs in the target test matrix.
- [ ] Catch outcomes are legible and not arbitrarily frame-rate dependent.
- [ ] Each foot may independently establish and lose contact with a support, with compression-only force and friction-limited tangential effort.
- [ ] Foot supports reduce measured hand load and react appropriately to dynamic objects.
- [ ] Support-aware posture improves climbing without freezing the body or suppressing all swing.
- [ ] Moving the camera does not inject physical torque into an otherwise idle climber.
- [ ] Grip quality depends consistently on surface/load geometry and provides advance feedback.
- [ ] A reactive climbing challenge can be solved by applying weight and force through the character.
- [ ] All force sources remain within documented shared budgets; no teleports or collision bypasses are introduced.
- [ ] Automated regression results and player-feel comparisons are documented at 60 and 120 Hz.

## 17. Guidance to Codex and the physics specialist

**Implement this as an incremental engineering and design validation effort, not as a request to make the game generically “more realistic.”**

For each milestone:

1. Read the current implementation and document the real code path and its constraints.
2. State the physics model and invariants before changing the controller.
3. Identify the smallest isolated change and preserve established interfaces where possible.
4. Implement instrumentation and one test rig alongside the feature.
5. Compare against the preserved baseline at 120 and 60 Hz.
6. Verify no hidden impulses, disabled collisions, instantaneous rotation, unbudgeted forces or force applied only to one side of a dynamic connection.
7. Run an interactive trial and report what is improved, what worsened and what remains uncertain.
8. Leave the feature switchable off until the milestone passes.

### Recommended first work item

**M1 only: predictive hand capture following the existing charged launch.**

Do not begin by building new levels, replacing the rig or adding full leg physics. The known launch/catch inconsistency is the clearest existing functional problem. Once that is controlled, implement the foot support system and proceed through the gates.

---

**Success definition:** The next iteration should not merely make the climber more realistic. It should let players deliberately plan grips, use their feet, control body weight and manipulate moving structures, while preserving the responsiveness and satisfying force-driven feel already achieved in GRIP UP v0.1.
