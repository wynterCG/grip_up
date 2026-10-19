# GRIP UP — Intent-Driven Physical Locomotion
## Detailed Engineering and Game-Feel Prototype Specification — v0.7

**Status:** Proposed, opt-in experimental control model. **Not implemented or approved as the new default.**  
**Prepared:** 19 October 2026  
**Language:** English  
**Target:** Windows PC, keyboard + mouse, third-person 3D, landscape 16:9  
**Engine:** Existing Godot 4.7.2 project / integrated Jolt Physics  
**Physics test rates:** Existing 120 Hz primary and 60 Hz comparison  
**Project:** GRIP UP, `E:\Godot Games\grip_up` / `wynterCG/grip_up`  
**Input evidence:** `SISTEMA_IMPLEMENTADO_V06_PT.md`, `FISICA_IMPLEMENTADA_V06_PT.md`, and previous v0.4–v0.6 prototype specifications.  
**Intended audience:** Main Codex agent, dedicated physics agent, game designer, playtesters.

> **Core hypothesis:** GRIP UP is already a capable physical suspension and gripping system. Making climbing compelling requires a higher-level locomotion interface: players specify a direction and choose support points; existing bounded physical actuators determine whether and how the body moves. This must improve agency without generating motion from impossible contacts or turning climbing into autoplay.

---

# 1. Executive brief and decision to test

## 1.1 Current design problem

The present prototype successfully demonstrates free-surface hand grips, single- and dual-grip suspension, finite arm forces, inertia, reactive supports, dynamic pre-selection of out-of-range holds, optional physical feet, independent aiming, posture policies, and swinging. However, the designer reports that **the activity of climbing does not yet feel compelling**. Technical correctness, many passing regression checks, and a successful scripted ten-transfer route have not established human enjoyment.

**Working diagnosis:** The gameplay pipeline often expresses movement as changes to arm rest lengths and posture assistance. These are useful implementation variables but are not necessarily the actions a player wants to think about. Climbing should be experienced as *moving a body through a route using real supports*, not as managing two servos.

## 1.2 Proposed change

Add a new **Intent-Driven Physical Locomotion (IDPL)** controller above the existing physics. In this experiment:

- Mouse = inspect, precisely select a hold, and command either hand to grip.
- Hold LMB/RMB = keep the respective hand's grip or persistent reach request active (no toggle).
- While physically supported, WASD = intended body traversal relative to the climbing surface, rather than direct arm-length or raw swing commands.
- The locomotion coordinator converts traversal intent into attainable actuator objectives, distributes effort through actual attached hands and optional planted feet, and records when the request is not physically achievable.
- Physics continues to determine the actual body trajectory, velocity, load, slips, collisions, reactions, and failures.

**Do not change the current default.** Build this as an isolated, switchable v0.7 experimental profile, compare it against the actual v0.6 baselines, and promote it only after human testing.

## 1.3 Target fantasy

A single-player physics climbing game in which:

1. The player finds the next viable handhold.
2. The player chooses when to hold/release each hand.
3. The player requests a direction of body travel.
4. The character uses supporting hands and feet to attempt that travel with finite effort.
5. The player must still manage support transitions, timing, momentum, reach, and moving scenery.

The system must never choose the next handhold or complete a transfer without player input.

## 1.4 Success / rejection premise

**Keep** the experiment if human players can more reliably perform an intentional step, controlled traverse, swing-catch and top-out, with equal or better perceived physical agency and without assistance cheats. **Reject or revise** if holding W near a climbable wall amounts to automatic climbing, if motion occurs without valid reaction support, or if the controller feels sluggish and uncontrollable despite clean telemetry.

---

# 2. Grounded v0.6 baseline — do not rebuild

The following is extracted from the supplied v0.6 implementation reports. **Verify all live values and file names against the current checkout before editing**, since the documents report a historical snapshot rather than guaranteeing present source state.

| Subsystem / attribute | Reported actual state |
|---|---|
| Physical body | One 12 kg dynamic `RigidBody3D`, compound colliders, custom COM at pelvis origin; not a full ragdoll |
| Rendering | Quaternius mannequin, animations, IK and palm alignment following physical result; bones do not drive rigid-body movement |
| Hand acquisition | FREE / REACHING / ATTACHED / SLIPPING / RELEASED; left/right independent; hold-to-grip |
| Attachment point | Material point and normal saved in the support body's local coordinates, including dynamic moving supports |
| Arm force | Implicit damped, tension-only axial actuator with effective mass; fixed budget shared by both hands |
| Force caps | **360 N total hand force**, **20 N·m total attitude/swing assistance**; **150 N·m resulting torso moment** |
| Arm geometry | ~0.65708 m anatomical contact reach; arm rest target 0.18–0.62 m; 0.04 m elastic margin |
| Actuator parameters | K 6000 N/m, D 220 N·s/m, bounded error 0.12 m; reach gesture up to 4 m/s shoulder-relative in v0.6 |
| Hand capture | Real finite hand travel, line/path obstruction, capture evaluator, grip load/slip state, nonteleporting contact |
| Out-of-reach selection | v0.6 opt-in, independent-aim profile 3; a held pending target stays attached to the selected *intention*, but exerts **zero** force until real contact |
| Current default input | Report says **profile 2 contextual** by default; profile 3 independent aim is separately selectable |
| Support-aware length policies | A hold length, B bounded auto-pull, C load-aware pull; implemented but experimental |
| Posture variants | P0 reference, P1 twist refinement, P2 tested but **rejected as default** due to side effects |
| Ground locomotion | Dynamic rigid-body motor, camera-relative walking, no generic in-air walk propulsion |
| Supported swing | Bounded grip-transmitted swing/attitude moment, with reaction on movable supports |
| Optional physical feet | Candidate sampler and unilateral foot solver, **OFF** by default; 180 N shared feet / 120 N per foot, friction-limited |
| Existing tests | Static climb, swing/catch, reactive beam, foot support, ten-transfer lab, swing-required route |
| Verification | Reports state **3,116 automated checks** for v0.6; these do not certify human feel |
| Missing | Dedicated mantle/top-out, full biomechanics, final controls and campaign, finished human v0.6 comparison |

### 2.1 Baseline features to preserve

- Original Janga physics grabber and source project unchanged.
- Existing GRIP UP profiles 0/1/2/3, the v0.6 distant-target feature switch and rollback.
- Mouse aim physically independent in profile 3; moving cursor cannot secretly command arm length.
- Left and right hands remain independently hold-controlled.
- Reaction forces to attached dynamic objects and local-space anchor tracking.
- Current grip integrity model; real contact is distinct from successful retention.
- Automatic foothold sampler and foot solver available for controlled experiments, **not silently enabled** in all profiles.
- Current debug/telemetry, Godot MCP Pro testing and 60/120 Hz test routines.

### 2.2 Known pitfalls from previous experiments

1. **Contextual mouse coupling** was not comfortable enough: pointing to a new hold also changed the supporting arm. Do not reintroduce it.
2. **P2 upright preference** made visual posture appear better but degraded some reach windows and dynamics. Do not promote it indirectly under a new class name.
3. **A/B/C auto-length planners** can achieve local rest targets without moving the body to a useful next position. Do not equate `target settled` with `climb accomplished`.
4. **Early-target selection** solves command timing, not locomotion. A pending target must never pull the body.
5. **Scripted routes** demonstrate mechanical feasibility, not intuitive input or player skill. Human testing is mandatory.

---

# 3. Design pillars and non-negotiable invariants

## Pillar A — Intent, not animation

WASD requests a movement direction, **not** an immediate body position. No IK chain or animation clip may drag the physical body to the destination. A failed or impossible request may cause little/no motion.

## Pillar B — All movement has a physical reaction path

A hand can pull through an attached grip; a foot can push through valid compression/friction; a modeled gripper may transmit a finite reaction moment. Airborne movement without valid support must follow inertia, gravity and collisions, not input-driven propulsion.

## Pillar C — Choose your holds

Hand targeting and attachment remain explicit player decisions. Never algorithmically select a new handhold to solve the route. Existing optional feet may find **local**, physically reachable supports, but cannot path-plan the entire climb.

## Pillar D — Preserve mechanical individuality

One hand, two hands, hands + feet, a fixed wall, and a rotating beam must feel materially different. Do not use a universal camera-space movement force to make them all respond the same way.

## Pillar E — Sufficient control, not guaranteed success

Players should distinguish insufficient reach, insufficient available force, loss of friction, excessive momentum, incorrect timing and impossible support geometry. Controllers need bounded error, saturation handling and readable feedback.

## Hard rules

- Preserve mass, contact, limits and physical backend for initial comparisons.
- No `transform` or `linear_velocity` assignments to achieve climb movement.
- No invisible world-space force or torque acting without a justified reaction on a support.
- No infinite constraint stiffness or no-limit 6DOF joints.
- No extra force simply because two hands are attached; their **sum** still obeys shared capacity.
- A pending grip is a **desired future point**, not a physical hand attachment.
- IK never extends anatomical reach, drives contacts, or authorizes capture.
- Camera orbit must not change the world direction of a held movement command instantly.
- New work must be feature-flagged, separately testable, and reversible.

---

# 4. Player control contract — new opt-in profile

**Profile name:** `INTENT_DRIVEN_CLIMB_V07` (proposed enum/display label; map to existing settings framework).

| Input | While grounded | While climbing / hanging | Notes |
|---|---|---|---|
| Mouse movement | Aim at potential grips | Aim at potential grips | **Never** controls arm rest length |
| Hold LMB | Left hand reaches/holds | Left hand reaches/holds | Release cancels reaching or detaches |
| Hold RMB | Right hand reaches/holds | Right hand reaches/holds | Same independent behavior |
| W | Walk forward | Request movement **up the climbing frame** | Not direct shortening |
| S | Walk backward | Request movement **down the climbing frame** | May be gravity-assisted extension, not foot suction |
| A/D | Strafe/steer | Request lateral traverse | On free hang may result in pendulum motion if mechanically feasible |
| MMB drag | Camera orbit | Camera orbit | Camera motion is not body motor |
| Mouse wheel | Dolly | Dolly | No hidden climb action |
| Space | Existing jump/dyno controls in legacy profiles | Existing experimental dyno in v0.7 **OFF initially** | Only re-enable in dedicated comparison |
| R | Reset/checkpoint | Reset/checkpoint | Existing behavior |
| Tab | Debug overlay | Debug overlay | Show desired versus actual movement |

**Hold-to-grip is mandatory.** Do not change it to toggle, latch, one-click auto-grab or auto-release.

### 4.1 Input semantics

- Holding W is a **continuous locomotion request**, not a key-repeat of discrete steps.
- Keyboard input is digital: use a small configurable command ramp for continuity. **Do not market this as analog acceleration control.** Actual acceleration results from physics.
- Diagonal movement is normalized before planning; W+D must not supply twice the request authority.
- When only an early-selected pending grip exists and the character is still grounded, normal ground locomotion remains active; pending selection alone is not climbing support.
- Distinguish `W/S for up/down traversal` in the new profile from `W/S for depth swing` in earlier experimental profiles. Never silently remap an existing profile.
- When the body is fully airborne with no real hand/foot/ground contact, WASD must not inject movement.

### 4.2 Suggested optional later experiments — not v0.7 blockers

- Gamepad dual-analog magnitude as genuinely analog movement intent.
- Small technique modifier for deliberate swing in high-skill contexts **only if** locomotion intent cannot produce controllable swing.
- Alternative input sensitivity curves and accessibility settings.

---

# 5. Coordinate frames and movement directions

A 3D climbing controller cannot assume that global `+Y` and camera `+X` always describe a usable climb direction. Walls, corners, sloped slabs, overhangs and moving supports need a stable local frame.

## 5.1 Preferred climbing frame

Build a frame from actual supporting contacts, not the pointed-at target:

- `n`: stable, appropriately weighted outward normal of current material hand/foot supports.
- `u`: a world-up vector projected onto the support tangent plane: `normalize(world_up - dot(world_up,n) * n)`.
- `r`: tangent lateral axis, orthogonal to `u` and `n`, sign-aligned with a stable camera-right reference.

Requested climbing direction:

`d = normalize_or_zero(W_minus_S * u + D_minus_A * r)`.

The actual calculation must use weighted normal blending/hysteresis and enforce valid handedness. The signs must be verified in scene tests.

## 5.2 Degenerate and complex configurations

- **Overhang/ceiling:** world-up projected into the tangent plane can vanish or become unstable. Fall back to the last valid tangent frame, then to a camera/body-derived direction that changes smoothly.
- **Inside corner with two different support normals:** average normals may cancel or point between surfaces. Choose a dominant support frame or continuous per-support frame; do not normalize a zero vector.
- **One hand in free hang:** there is no meaningful wall plane if the grip is on a bar. Use a support-relative pendulum/traverse frame: requested movement projects into currently physically actuable directions.
- **Moving support:** anchor points and normals follow their supports. Frame rotation must be transported smoothly, without creating input energy.
- **Camera orbit:** freeze world-space movement direction while the same input is continuously held, or use rate-limited interpolation after a measured test. Never rotate a held motor request instantaneously.
- **Changing which hand bears most load:** avoid sudden frame flips through reference hysteresis or sign continuity.

Add a developer overlay that shows `u`, `r`, `n`, active support IDs and support-frame quality.

---

# 6. Support-aware locomotion states

Movement state must be inferred from **real contacts and load**, not hand-button counts alone.

| State | Physical support | Allowed interpretation |
|---|---|---|
| `GROUNDED` | Walkable ground; no load-bearing grip | Existing ground locomotion |
| `GROUNDED_REACHING` | Real ground; pending hand target or finite hand travel | Ground movement remains; reaching exerts no force before catch |
| `CLIMB_HANDS_FEET` | ≥1 real hand grip and ≥1 genuinely planted foot | Up/down/traverse via hands and foot compression/friction |
| `CLIMB_TWO_HANDS` | Two attached hands, feet not load bearing | Traversal through bounded arm force and grip moments |
| `HANG_ONE_HAND` | One attached hand, no other support | Traction, limited grip moment, pendulum; feasible movement only |
| `FOOT_TRANSITION` | Contact moving between ground/support/air | Progressive blending; no double motor |
| `LEDGE_TRANSFER` | Valid ledge contacts and torso nearing supported top surface | Optional mantle experiment; see section 13 |
| `AIRBORNE` | No real support | Physics only, aim and reach allowed, no locomotion propulsion |
| `FALLING_RECOVERY` | Airborne after support loss | Pending hand capture may succeed through real contact; no thrust |

### 6.1 State priority and blending

- Real support/contact and effective load determine authority.
- Preserve the ground motor while only a far-away pending grip exists.
- When a real grip begins taking load, ramp down ground motor as appropriate, rather than switching completely on the first `REACHING` frame.
- If real hands plus a valid foot are loaded, coordinate both, rather than summing an independent ground motor and climb motor.
- A brief loss of contact should use bounded hysteresis and explicit confidence; hysteresis cannot authorize forces through nonexistent contacts.
- Record state transitions and which controller owned each force budget.

### 6.2 Support quality inputs

For each current real support record: body identity, contact point, normal, relative velocity, available traction/compression capability, grip integrity, foot friction margin, load, moving-body state and time since establishment.

The result is an **actuation feasibility estimate**, not an autonomous pathfinding score.

---

# 7. IDPL architecture and physical authority

**Proposed layering:**

```text
Human input / hold-to-grip
      |
      +-- Mouse targeting ---------> Existing grip selection, pending target, capture evaluator
      |
      +-- WASD traversal intention
                        |
             MovementIntentFilter
                        |
             SupportFrame & SupportState
                        |
             Feasibility / Constraint Assessment
                        |
             IntentDrivenLocomotionCoordinator
                        |
          +-------------+--------------+
          |                            |
    Arm Target Planner          Foot Support Planner (optional)
          |                            |
    Existing ArmActuator         Existing FootContactSolver
          +-------------+--------------+
                        |
              Existing ClimbingController
                        |
                  Jolt physics world
                        |
             Physical body + support reactions
                        |
        IK / visual representation + debug telemetry
```

The **new controller is a planning/coordination layer**, not a replacement for the proven actuator, attachment, collision, capture or slip code.

## 7.1 Movement intent

Define filtered `MoveIntent` including:

- `planar_input`: normalized W/S/A/D intention.
- `world_direction`: stable support-relative desired body displacement direction.
- `intensity`: 0–1 keyboard command ramp (not analog input).
- `desired_speed` / movement envelope: testable design values, dependent on support mode.
- `timestamp`, `originating_support_frame`, `active_support_mode`.

Do not store a world destination at the clicked handhold as the locomotion destination. Aimed grips are for hand acquisition only.

## 7.2 Desired movement envelope

As a **controller planning objective**, calculate:

`v_des = max_speed_for_mode * intensity * world_direction`.

`a_req = clamp_magnitude(k_vel * (v_des - v_body_projected), a_plan_max)`.

These are **virtual objectives** for planning; **never apply `mass * a_req` directly as a free-space body force**.

Rate-limit changes, enforce maximum intended displacement per simulation step and clamp integral accumulations; if the character does not move because the geometry is impossible, the controller must stop building up stored effort.

Begin with a very conservative tunable envelope (for example, walking-like climb requests well below 1 m/s) and compare actual movement; these are proposals, not a claim that the physics supports any target speed.

## 7.3 Constrained actuation

The real available actions are:

- **Attached hand:** axial tension along shoulder-to-anchor; no physical compression by a slack hand.
- **Finite gripper moment:** a limited reaction couple supported by the attached material and current budget, not arbitrary free torque.
- **Planted foot:** positive normal compression and tangential effort within the friction cone and foot budget.
- **Ground contact:** existing bounded walk motor, but never simultaneously double-count with the climbing feet/controller.

Map the movement intent to changes in **legitimate actuator goals**. The actual solver (arm spring, foot contact) still computes the forces.

### Required two-tier approach

**Tier 1 — Minimum viable coordinator (implement first).** Use existing B/C target length planners and optional foot contacts, adapting their feasible targets based on movement request; control velocity of the *target* (not body), track actual progress, and abort on saturation. No global optimization required.

**Tier 2 — Optional constrained load allocation (only if Tier 1 is insufficient).** Build a small active-set/weighted least-squares allocator over allowed hand traction, limited grip moments and foot reaction components. The optimizer must honor all current capacity constraints and feed bounded objectives back to the existing actuators. It must not apply its theoretical wrench as an extra force on top of the actuator solver.

Example generalized desired wrench:

`w_requested = [F_desired, tau_desired]`

`w_realizable = B(support_geometry, actual_actuator_directions) * a`

Minimize `||W * (w_realizable - w_requested)||^2 + lambda * ||a - a_previous||^2`, with constraints including:

- Each hand axial magnitude ≥ 0, and both hands' **sum** ≤ 360 N.
- Shared assisted grip/swing moment ≤ 20 N·m.
- Resulting torso moment ≤ 150 N·m.
- Optional feet: normal ≥ 0, total foot capacity ≤ 180 N, each foot ≤ 120 N, tangential components inside `||F_t|| ≤ mu * F_n`.
- Grip overloading/slipping reduces actual available capacity; no optimizer may command the full theoretical cap through a failed grip.
- The source body receives equal-and-opposite wrench where applicable.

**Critical:** an arm length target does not provide arbitrary instantaneous axis force. The theoretical allocator must respect what the existing tension-only spring can *actually* produce, and follow-up measurements must use realized, not commanded, force.

## 7.4 Saturation and no hidden energy

- Clamp goals, target rates, actuator force and torque exactly as existing contracts require.
- Prevent integrator wind-up while blocked or at max reach.
- When unavailable force makes requested velocity impossible, report limitation rather than forcing motion.
- Do not accumulate a future burst when the movement command is held against an obstruction.
- Preserve body, support velocity and inertia during controller transitions.
- On loss of physical support, remove climb motor authority without lingering impulses.

---

# 8. Limb contributions and cooperation

## 8.1 Hands

One or both hands remain player-selected. The coordinator may:

- Modify **bounded target rest lengths** to request a physically possible displacement.
- Redistribute shared effort between already attached hands.
- Apply finite and physically reacted gripper moment within the existing common allowance.
- Hold current state when the requested movement is infeasible.

It must not switch the hand's contact to another location, move the anchor over the wall, create a third hand, attach to a pending target, or adjust independent aim.

## 8.2 Feet

The current optional foot module already searches local supports and applies positive normal/contact friction effort. The coordinator may use its **actual supporting** status and available compression to help advance the torso.

Rules:

- Feet may find **local** reachable placement candidates near the current body, using existing collision/visibility checks.
- No autonomous upward route selection, no foot teleports, no suction, no wall-normal pulling.
- Do not allow foot forces before finite physical planting/contact.
- After support is planted, the leg may push only to the extent allowed by its existing contact model.
- If the foot slips, smoothly reallocate available effort; do not clamp the foot rigidly to the previous world point.
- The model's IK feet remain visual representations, not independent evidence of support.

**Compare with `physical_feet=OFF` first**, then enable it for a second experiment. The difference should be visible in arm load and attainable movement, not only animation.

## 8.3 One-hand special case

If the player has only one real attached hand:

- Reduce the set of feasible traversal directions; do not promise the full WASD intent vector can be achieved.
- Allow arm shortening to lift the body where the geometry and effort permit.
- Allow pendular swing when legitimate limited grip moment and gravity can produce it.
- Do not always rotate or translate the torso toward the cursor's target hold.
- The player may need to use momentum, another grip, or a foot support before a requested direction becomes feasible.

This is **intentional gameplay depth**, not a malfunction.

## 8.4 Two-hand special case

With two valid grips:

- Both hands share the 360 N total, with the same load/slip model.
- The two-support geometry may improve orientation and lateral leverage, but must not produce unbounded rigidity.
- Transition in/out of dual grip with existing ~0.10 s acquisition blending and ~0.14 s allocation response unless tests justify changing them.
- A newly attached hand must not reset the surviving hand's rest length or impulse the torso.

---

# 9. Desired posture vs. physically achieved posture

Intent-driven traversal needs a coarse idea of a **useful** body pose, but this must not become a new pose-teleporting system.

## 9.1 Minimal posture guidance

Compute a support-aware preference based on:

- Body COM relative to actual anchors and ground/foot contacts.
- Real shoulder positions and anatomical limits.
- Collision clearance for the torso/head.
- Stable material contact normals and load direction.
- Current momentum and resulting force budget.

Use it only to set feasible, soft actuator goals. The target pose may remain unachieved.

## 9.2 Reuse P0/P1 before redesigning attitude

- P0 is the reference.
- P1 can be compared for excess twist on moving supports.
- P2 was previously rejected as a default; do not turn it on automatically inside v0.7.
- Do not stack several independent 20 N·m attitude motors; they share the exact same budget.

## 9.3 Legibility without automatic climbing

A well-positioned body should make the next player's chosen grip easier to reach, but the coordinator **must not** optimize toward that next grip's world position merely because the player points at it.

The player must still supply traversal intent and timing. A no-input character may settle or hold, but must not climb to a higher position simply because a grip is pending.

---

# 10. Suspended swing as a consequence of movement control

The v0.6 supported swing already applies a bounded, reacted moment to actual supports. It must be preserved for comparison.

In v0.7, WASD represent body traversal intention. When static translation is constrained by a single grip, a direction request may instead yield **tangential pendular effort**, if that effort can be generated by a legitimate gripper/actuator reaction.

### Required behavioral distinctions

- **Pull up:** shorten arm with physically admissible tension and move COM only as physics allows.
- **Traverse sideways:** under stable multi-support contacts, redistribute support and move laterally; under one-hand free hang, a request may alter swing rather than translate directly.
- **Descend:** allow real arm-length increase and gravity-assisted motion; a traction-only arm cannot push downward through empty space.
- **Pump swing:** alternating supported input at the correct phase may increase swing energy; counter-phase input may brake.
- **Unsupported flight:** once no real support remains, stop powered input immediately.

### Swing acceptance

On the same hanging configuration, players must be able to distinguish: neutral dynamics, deliberate pumping and deliberate braking. Constantly holding W or D must not produce unlimited energy.

### Mechanical audit

Log applied moments, corresponding reaction on the support, relative angular velocity, incremental actuator work, angular momentum change and damping. This is an engineering diagnosis, **not** a claim of exact energy conservation from the entire Jolt simulation.

---
# 11. Reaching, early targeting, handoff and capture

Keep v0.6's advanced selection system separate from physical locomotion authority.

## 11.1 Reach requests

The player may hold LMB/RMB while aiming at a visible eligible contact that is presently outside the hand's anatomical workspace. `PendingGripTarget` retains the **same exact local material point** on the support and continues trying to approach within current reach and path constraints.

The pending hand:

- Exerts **no force or torque** on the body or the target support.
- Does not count as an actual support or enable climb locomotion by itself.
- Never automatically redirects to a more convenient nearby hold.
- Cancels on mouse-up, support invalidation, UI/focus handling as in the existing baseline.

## 11.2 Interaction with movement intent

While left hand is attached and right hand is pending:

1. The locomotion coordinator can use the **left** grip and any genuine planted feet.
2. Player WASD intention changes the physically achievable body trajectory.
3. The pending right hand follows the selected target through its independent existing finite reach system.
4. On real contact, the hand capture evaluator can transition it to ATTACHED.
5. The shared arm force budget is redistributed via the normal blend.
6. Subsequent intent may use two real supports.

**No anticipatory autopilot:** the controller must not move the body toward the pending target on the player's behalf. Any progress must be attributable to the player's movement input and real forces.

## 11.3 Moving-target and obstruction safeguards

- Evaluate the actual support point every physics step from its local attachment coordinates and current support pose.
- Use existing world-space swept/path collision tests; do not pass through obstacles because the target was initially visible.
- Honor the existing finite 4 m/s hand-gesture limit relative to the shoulder reference in the v0.6 mode.
- Preserve distinction between current reachable volume, planned approach path, actual hand endpoint and final capture tolerance.
- A catch must pass the real `GripCaptureEvaluator` and can still subsequently fail from slip/load or excessive extension.
- If the existing workspace-sweep conflict is triggered, report the explicit conflict; do not warp the hand to make it pass.

## 11.4 During rapid motion

Maintain a short-window predictor as a **diagnostic/advisory** tool only. It cannot grant extra reach or authorize a contact in advance. A player can pre-select a distant hold and still miss it because the hand cannot arrive before the body passes.

Log the stages separately: `REQUEST → PENDING → IN_RANGE → TRANSIT → CONTACT → RETAINED` or stage-specific failure/cancel.

---

# 12. Walking-to-climbing and climbing-to-walking transitions

A meaningful game flow requires controlled handoffs. A character that walks well and hangs well but abruptly loses locomotion when touching a wall will still feel unfinished.

## 12.1 Walk toward a wall and reach

- While a requested handhold is pending without load-bearing contact, **keep walking** with the existing grounded motor.
- The hand can travel toward its selected point with finite reach animation and no climb reaction before capture.
- When ATTACHED actually loads, reduce ground locomotion motor authority based on measured support participation, not a frame-level boolean tied to REACHING.
- Preserve walking momentum; do not suddenly erase horizontal velocity.

## 12.2 Mixed support

When a foot is on walkable ground but one hand is attached to a higher surface, coordinate both systems:

- Avoid double-applying locomotion from `GroundLocomotion` plus the climb coordinator.
- The hand can stabilize or pull; ground contact can push within current ground motor capacity.
- As the ground unloads, climbing actuators assume responsibility smoothly.
- If the hand is released while the feet remain firmly on ground, restore the ground motor without a pop or sudden change of orientation.

## 12.3 Hang-to-ground landing

- While hands support most load, allow feet to establish real ground contact.
- Transfer load progressively based on measured contact and posture.
- When the feet are supporting the body and hands release, transition to the grounded motor.
- Do not enable full walk thrust while the body is still floating a significant distance above ground.

## 12.4 Camera continuity

Do not snap from climb camera to walk camera. Blend focus, distance and collision avoidance while preserving the mouse's aimed world target during an active grip request.

---

# 13. Mantle / top-out as a separate gated feature

**Existing v0.6: no dedicated mantle.** This is a key missing piece of the movement fantasy, but must not be built before the basic step and one-hand swing show improved human feel.

## 13.1 Desired behavior

When both hands (or a hand plus foot) reach a ledge:

1. The player deliberately requests upward travel toward the top surface.
2. The system identifies whether a real top surface and reachable support path exist.
3. Arm traction and legitimate ground/foot compression attempt to raise the pelvis and transfer COM over the edge.
4. The dynamic body rotates/translates by the resulting forces while maintaining collision.
5. Feet can become valid supports on the top surface.
6. Once stable ground contact carries the load, normal walking resumes.

No single button may teleport the pelvis onto the platform. If the current two-arm/optional-foot model cannot perform a realistic top-out, **report insufficient physical capability**. Do not conceal it with a `transform` animation.

## 13.2 Narrowly allowed assistance

- IK for visual transitions only.
- Limited and physically reacted posture torque, sharing the existing budget.
- Constraint-aware choice of which existing grip/foot contact to load more heavily.
- Very small collision-tolerance handling that does not move the rigid body through solid geometry.

## 13.3 Test variants

- Mantle without physical feet: document whether physically possible and how.
- Mantle with existing `physical_feet=ON`: verify that feet really push and stay within compressive/friction limits.
- Failure under overhang or lip geometry that provides inadequate reaction support must remain possible.

This work is a **separate milestone after v0.7 basic locomotion passes**; it is not permission to expand the initial experiment into a full procedural parkour system.

---

# 14. Reactive environments — the main differentiator

A major differentiator of GRIP UP is that the thing being climbed may move because the character pushes or pulls on it.

## 14.1 Minimum test structure

Reuse the existing 15 kg hinged beam laboratory structure as the baseline moving-support test. The report also contains fixed-versus-hinged comparisons; preserve those.

Required comparison:

1. Same handhold geometry on a fixed support.
2. Same support made dynamically articulated.
3. Same body and intention sequence.
4. Observe whether shortening/pulling moves the player, the support, or both.

No special-case scripted rotation of the beam.

## 14.2 Force and torque reaction

For an attached hand applying `F_hand` to the body through its shoulder, the support receives an opposite force at the **actual material grip contact**. Resulting torques must be handled using world-space application points and actual COM, as in the existing implementation. Finite grip moments require equal-and-opposite reaction moments on the support.

The total forces of both hands cannot exceed 360 N merely because both grab a moving beam. Foot compression contacts similarly impart reactions to their supporting body.

## 14.3 Prevent 'physical autopilot'

The player must intentionally use the structure as a mechanism, for example by choosing which end of a beam to grip and when to redistribute load. The controller must not search for a magical rotation that makes the next target reachable.

## 14.4 Reactive challenge proof

Build one tiny scenario where moving the character's supported weight causes a beam/counterweight to reposition, thereby opening a new climbing route. Provide a fixed-support control version in which the same movement cannot produce that effect.

---

# 15. Control feedback and player comprehension

The v0.6 project has detailed debug overlays. **The new controller must not require players to understand its solver.** Instead communicate what the body is trying to do and why it cannot.

## 15.1 Minimal player-facing vocabulary

During ordinary gameplay, use subtle cues for:

- Hand: reaching, attached, overloaded/slipping.
- Feet: visibly planted and pushing versus visually swinging freely.
- Intent: a tiny hint of requested traversal direction **only when useful**.
- Blocked request: a brief effort or strain animation/sound, without a deceptive sliding progress bar.
- A selected distant grip: distinct from an already attached grip.

Keep HUD minimal; do not add permanent numerical force meters as a substitute for expressive physical feedback.

## 15.2 Diagnostic labels (developer only)

- `NO_REAL_SUPPORT`
- `DIRECTION_UNACTUATABLE`
- `ARM_FULLY_EXTENDED`
- `ARM_FORCE_SATURATED`
- `GRIP_LIMIT / SLIPPING`
- `FOOT_NO_CONTACT`
- `FOOT_FRICTION_LIMIT`
- `BODY_COLLISION_BLOCKED`
- `MOVING_SUPPORT_YIELDED`
- `TARGET_PENDING_ONLY`
- `POSTURE_TARGET_NOT_REACHED`
- `MOTOR_HANDOFF_ACTIVE`

Do not emit one generic `CAN'T MOVE` label for unrelated failures.

## 15.3 Skill feedback

Players should be able to notice when:

- Their next handhold is poorly placed.
- A foot genuinely reduced hand load.
- Reversing movement intent changed swing amplitude.
- One hand cannot produce a requested traverse until a second support is obtained.
- A moving beam responds to their weight and can be manipulated intentionally.

---

# 16. Prototype test arenas — movement before campaign

Build **small, separate repeatable tests**; do not initially create a long vertical mountain. Existing labs remain regression cases and can be reused as a foundation.

## Arena 01 — THE STEP (first playable priority)

**Purpose:** Prove that a player can move their body upward in a useful, controllable manner with a foot support.

**Setup:** One near-vertical wall, two handholds selectable on a free surface, one broad real foothold and one higher reachable hand target. A safe base and simple checkpoint.

**Player task:** Grab, use W to lift while transferring load, target a higher hold with the free hand, catch and stabilize.

**Measure:** COM height gained, time to first higher grip, actual hand/foot forces, unnecessary oscillation, number of voluntary corrections, and human-reported sense of control.

**Required variants:** old v0.6 independent aim + A/B/C as reference; v0.7 with feet OFF; v0.7 with existing physical feet ON. The OFF variant may fail the designed foothold challenge — report that as an expected capability difference rather than a controller regression.

## Arena 02 — THE HANG

**Purpose:** Verify one-hand authority boundaries and avoid a hidden fly controller.

**Setup:** Fixed horizontal bar, one attached hand, no foot support, distant side handhold.

**Player task:** Try W/S/A/D, learn what movements the grip can physically generate, deliberately pump or damp swing and make a catch if reachable.

**Measure:** pendulum amplitude, actuator work, unsupported energy, grip moment cap, reaction on support, transfer success and control legibility.

**Critical negative:** If the player can travel sideways steadily with no viable torque path or indefinitely accelerate while holding a key, reject the implementation.

## Arena 03 — THE TRAVERSE

**Purpose:** Prove side-to-side supported climbing rather than vertical-only climbing.

**Setup:** Two laterally offset handholds and a sequence of physical footholds, with a corner variant.

**Player task:** Move laterally with A/D, alternate LMB/RMB while aiming, optionally plant a foot and adjust body posture.

**Measure:** direction fidelity, camera yaw consistency, transfer time, handoff spikes and corner-frame discontinuities.

## Arena 04 — THE MANTLE (later milestone)

**Purpose:** Connect climbing to grounded locomotion without a teleport animation.

**Setup:** A ledge with a walkable top surface and sensible support geometry.

**Player task:** Reach the lip, gain height, move COM over it, gain foot support and stand/walk away.

**Measure:** transition smoothness, collision integrity, actual support load, controller handoff, time-to-complete, number of falls.

## Arena 05 — THE REACTIVE BEAM

**Purpose:** Validate that movement intent acts on dynamic geometry via real reactions.

**Setup:** Existing fixed/hinged beam fixture, configured identically except for articulation.

**Player task:** Move the body while holding the beam and deliberately alter its angle to expose the next reachable surface.

**Measure:** joint angle, COM trajectory, work, actuator saturation, force-pair residuals, load redistribution and actual player agency.

## Arena 06 — TEN TRANSFER REGRESSION

**Purpose:** Keep the v0.5/v0.6 route for repeatability and compare control strategies.

**Setup:** Existing 11-guide free-surface route, configurable 0.08–0.16 m offsets, benchmark 0.12 m, plus 0.14 m setting.

**Player task:** Ten actual hand-to-hand transfers.

**Measure:** successful transfers, incomplete grasps, reason for failure, time, recoveries, positional effort and subjective comfort.

**Important:** This arena must not be the **only** basis for approving v0.7. It is an engineering benchmark, not the full climbing fantasy.

---

# 17. Regression, invariants and numerical QA

Every test should run at the physics rates already covered by the project (120 Hz main, 60 Hz comparison) wherever deterministic fixtures allow. Numerical traces may differ; behavioral invariants must hold.

## 17.1 Unit-level checks

1. Input normalization: diagonals do not exceed a unit vector; changes are rate-limited.
2. Camera frame invariance: orbit during a held key never injects a torque spike.
3. Support frame: walls, ceiling, overhang, two perpendicular support normals, moving support, and frame hysteresis.
4. Pending hand exerts exactly zero climb force while not in contact.
5. One attached hand cannot exceed shared force/torque limits.
6. Two hands cannot sum above 360 N and cannot gain double grip-moment authority.
7. Foot force normal is nonnegative; tangential effort respects material friction, foot force caps unchanged.
8. Ground and climb motors never double-count authority for a single physical contact state.
9. Climb input without support cannot accelerate the body in midair.
10. New posture command stops accumulating unreachable demand during saturation.
11. Grip slip / support invalidation immediately removes corresponding authority.
12. Arm length target changes stay inside 0.18–0.62 m with permitted rate/acceleration.
13. Existing rest preload and 0.65708 m anatomical contact limit remain distinct.
14. Current rig IK cannot extend anatomical limits or move the physical body.
15. New profile OFF reproduces current behavior within the project's existing tolerances.

## 17.2 Physics integration checks

- Real contact before force; no spring attached to a candidate grip.
- Body/camera/IK transform authority remains properly separated.
- Reactive supports receive opposite forces/moments at correct world-space points.
- A movable hinge support changes response versus an otherwise fixed support.
- Head, torso and foot colliders do not tunnel through simple ledge geometry.
- One-to-two-to-one grip transitions do not reset velocity or surviving arm state.
- Foot support acquires and releases without popping the COM.
- No enormous delayed release from controller integral after prolonged blockage.
- Leg solver and ground motor do not combine into an unearned double jump or hover.

## 17.3 Test fixtures must expose impossibility

Include at least one explicitly impossible movement per mode (e.g. no support, insufficient force, out-of-reach target, blocked chest, poor foot friction). Acceptance requires **correct failure and reason**, not forced completion.

## 17.4 Performance and stability

Capture per-step solver time, frame time, spikes, collision errors, contact churn, and actuator budget saturation. Preserve baseline performance on the same machine. Do not claim a platform-wide FPS guarantee from the existing 3,116 check count.

---

# 18. Telemetry and experimental comparison

The current project already records structured JSONL traces and per-session summaries. Extend those rather than creating a separate telemetry system.

### 18.1 New data fields

| Group | Fields |
|---|---|
| Input | `control_profile`, `movement_intent_local`, `movement_intent_world`, `intent_strength`, `input_frame_id` |
| State | `locomotion_support_mode`, `mode_transition_reason`, active hand/foot support IDs |
| Desired | `desired_com_velocity`, `desired_direction`, `planned_arm_rest_lengths`, `planned_foot_action` |
| Actual | physical COM trajectory, projected velocity/progress, torso angle, angular velocity |
| Limits | force/torque usage, arm spring saturation, gripper moment, foot compression, friction margin |
| Failure | primary `movement_block_reason`, reach/catch failure reason, support-loss reason |
| Reactivity | support-body linear/angular velocities, hinge angle, point-local reaction forces |
| Agency | voluntary reversals, deliberate pumping/braking events, corrections, handoffs, input-to-movement latency |
| Performance | physics-step CPU time, contact/constraint instability markers |

### 18.2 Distinguish player intent from realized movement

An input request of `W=1` is **not proof of upward motion**. Log requested movement, actual net height/displacement and actual actuator effort separately. A planner that updates targets without moving the body must not report `CLIMB_PROGRESS`.

### 18.3 Baseline conditions

Use exactly the same body mass, support layout, hand force caps, torque caps, capture evaluator, and camera sensitivity across comparisons, except for the intended experimental variable. If physical feet are enabled as a comparison variable, record that difference prominently.

### 18.4 Human sessions

Minimum initial study: **three to five testers**, ideally including at least one person unfamiliar with the controls. These numbers are practical pilot targets, not statistical proof. Compare:

- Baseline v0.6 profile 3 with a clearly specified A/B/C policy.
- v0.7 movement-intent profile, feet OFF.
- v0.7 movement-intent profile, feet ON.
- Optional v0.6 profile 2 for historical feel comparison, but do not conflate its mouse-coupled aiming problem with the new locomotion hypothesis.

Counterbalance the order when possible, keep familiarization time comparable, and use the same arenas.

After each scenario, collect 1–5 ratings for **Control**, **Physical Credibility**, **Clarity**, **Comfort**, **Skill Expression**, and **Would Play Another Level**. Also ask one unprompted question: *What did you feel you were controlling?*

---

# 19. Acceptance gates — behavior and human feel

## 19.1 Engineering invariants — mandatory

- [ ] New profile is opt-in and old baseline is recoverable.
- [ ] No cursor motion modifies arm length through an implicit coupling.
- [ ] Existing hold-to-grip and distant-target pending rules still hold.
- [ ] No requested movement physically moves the character without real support.
- [ ] Existing hand (360 N), attitude (20 N·m), total torso moment (150 N·m), and optional foot (180 N total, 120 N each) caps are unchanged in baseline trials.
- [ ] Every applied support force/moment has the correct reaction on dynamic objects.
- [ ] Gravity, inertia, contact and friction remain active at all times.
- [ ] A step-up can be driven by hands/feet without assigning body transforms or velocity.
- [ ] The unsupported one-hand case can honestly refuse an unattainable command.
- [ ] Continuous W does not climb automatically when support geometry does not permit it.
- [ ] Camera rotation never adds physical energy or silently changes a held movement axis.
- [ ] Stable ground ↔ gripping transitions do not double-apply movement motors.
- [ ] Regression suites pass at intended 60/120 Hz rates.

## 19.2 Human-play success hypotheses — to validate, not assume

- [ ] Players can explain how to move upward within one brief tutorial encounter.
- [ ] Players can identify why they cannot move in a genuinely impossible situation.
- [ ] Players can perform the Step and Traverse tests without repeatedly fighting cursor and arm-length controls.
- [ ] Players can intentionally pump and brake a one-grip swing where physical authority permits.
- [ ] Hand-target choice, regripping timing, and support geometry still materially affect success.
- [ ] Players describe the experience as controlling a **climber**, not two servo lengths or an autopilot.
- [ ] Human ratings for control/comfort improve versus comparable v0.6 trials, without a meaningful decline in skill expression or perceived physics.

There is no automatic promotion on scripted-route success alone.

---

# 20. Architecture and file responsibilities

**Do not rename or reorganize the entire existing project.** Add isolated modules or small explicit interfaces only where needed; confirm actual locations in the working tree.

| Existing module | Required v0.7 responsibility |
|---|---|
| `climbing_input_router.gd` | New profile, movement intent normalization, stable per-key camera frame; preserve hold-to-grip |
| `grip_up_lab.gd` | Experiment toggles, UI, arena selection, session/replay metadata |
| `grip_targeting.gd` | Retain independent aiming; do not modify targeting to steer movement |
| `pending_grip_target.gd` | Retain existing out-of-range persistence and zero force before contact |
| `grip_anchor.gd` | Retain local material points, normals and moving support velocity |
| `arm_actuator.gd` | Keep existing implicit tension-only force model; expose diagnostic capability/saturation signals if needed |
| `support_posture_planner.gd` | Reuse/extend bounded target planning, no artificial new pose authority |
| `arm_target_coordinator.gd` | Bounded target velocity/acceleration and anti-windup on infeasible requests |
| `foot_contact_solver.gd` | Use existing unilateral/friction-limited reactions only when actually planted |
| `foothold_candidate_sampler.gd` | Restrict to reachable local footholds; no route-solving foot AI |
| `ground_locomotion.gd` | Blend ownership with climbing; avoid ground/climb double motors |
| `supported_swing.gd` | Retain reacted finite torque and swing diagnostics; test v0.7 intent translation |
| `climbing_controller.gd` | Orchestrate support states and distribute admissible efforts to existing systems |
| `climbing_camera.gd` | Maintain camera continuity and movement-frame stability |
| `biped_visual.gd` | Render/IK only; no physical transform authority |
| `capture_trace.gd` / `transfer_diagnostics.gd` | Add intent vs actual, support mode, reason codes, capacity and feel metrics |
| `climb_test_level.gd` / `transfer_test_level.gd` | Reuse core arenas and add dedicated Step, Traverse, Mantle fixtures as needed |

### Proposed new modules

```text
features/grip_up/scripts/
    movement_intent.gd                     # raw -> normalized/ramped intent
    climb_support_frame.gd                 # stable tangent/support frame
    locomotion_support_state.gd            # grounded / hanging / mixed / airborne
    intent_driven_locomotion.gd             # small coordinator, OFF by default
    actuation_feasibility.gd               # support geometry and reachability checks
    locomotion_failure_classifier.gd       # why requested motion cannot happen

features/grip_up/tests/
    test_intent_support_frame.gd
    test_intent_no_airborne_propulsion.gd
    test_intent_single_dual_grip.gd
    test_intent_foot_handoff.gd
    test_intent_reactive_support.gd
    test_intent_mantle.gd                   # later milestone
    test_intent_camera_frame.gd
    test_intent_routes.gd

docs/validation/v07/
    baseline_snapshot.md
    movement_controller_physics.md
    regression_results.json
    human_playtest_protocol.md
    comparison_summary.md
    decision.md
```

These are names for separation of concerns, not a demand to create empty boilerplate files. Keep the actual implementation minimal.

### Feature flags (illustrative)

```ini
control_profile = "INTENT_DRIVEN_CLIMB_V07"      # opt-in
intent_climb_enabled = false                     # OFF until selected
physical_feet = false                           # controlled experiment
out_of_reach_targeting = false                  # v0.6 opt-in, compare on/off
posture_variant = "P0"                          # P2 must not become default
arm_target_policy = "A"                         # baseline A/B/C explicitly logged
swing_intent_conversion_enabled = false         # enable after support audit
intent_auto_mantle_enabled = false               # not part of initial test
```

Avoid simultaneously changing several flags in the same A/B measurement.

---

# 21. Implementation plan — milestones and stop/go gates

## M0 — Protect and measure current v0.6

**Tasks**
1. Inspect current source, profiles and real tuning values; do not rely on this document's snapshot alone.
2. Verify repository cleanliness and save a separate working branch/commit for the experiment.
3. Run full relevant existing regression and export/smoke tests.
4. Human-play baseline: Static Climb, Swing/Catch, Ten Transfers, Reactive Beam; record actual complaints and input traces.
5. Capture exact baseline flags/settings, recordings and JSONL sessions.

**Gate:** baseline reproducible and old behavior recoverable.

## M1 — Standalone input semantics and stable support frame

**Tasks**
1. Add opt-in `INTENT_DRIVEN_CLIMB_V07` profile.
2. Preserve LMB/RMB and existing independent targeting unchanged.
3. Map W/S to support-relative up/down and A/D to side traverse, respecting camera frame continuity.
4. Add degenerate/overhang/corner frame logic and debug axes.
5. Implement no-support negative tests.

**Gate:** player intent is consistent, no cursor-to-arm coupling, no airborne propulsion.

## M2 — Minimum viable locomotion coordinator

**Tasks**
1. Implement simple real-support state machine and support capability interface.
2. Generate bounded movement objectives from W/S/A/D.
3. Translate objectives to existing hand target planners; refuse impossible requests and avoid wind-up.
4. Preserve one-/two-hand force budgets and dynamics.
5. Compare basic upward and lateral movement with feet OFF.

**Gate:** movement results from actual actuator forces, and impossible actions fail honestly.

## M3 — Coordinated physical feet and mixed-contact states

**Tasks**
1. Activate existing physical feet as an explicit experiment.
2. Blend local foot push and hand tension under valid contact.
3. Implement load-based ground ↔ climb handoff, including reach requests while grounded.
4. Ensure no double motor or hidden upward assist.
5. Validate The Step and The Traverse with feet OFF/ON.

**Gate:** real feet reduce measured hand load and unlock physically possible movement; no wall suction.

## M4 — Swing and one-hand agency

**Tasks**
1. Audit physically available swing axes and reaction paths.
2. Translate movement intent into limited pendulum effort only where supported.
3. Verify pumping, braking, one-hand refusal of impossible directions.
4. Test moving supports and support-frame changes during swing.
5. Keep old swing implementation as baseline for A/B.

**Gate:** players intentionally control swing, and the controller neither freezes the pendulum nor becomes a jetpack.

## M5 — First human-feel decision

**Tasks**
1. Run three primary arenas: The Step, The Hang, The Traverse.
2. Compare v0.6 baseline and v0.7 with the same settings/geometry.
3. Measure actual body progress, time, transfers, comfort and effort readability.
4. Diagnose any new unwanted oscillation, contact loss and impossible postures.
5. Write `KEEP / REVISE / REJECT` report before more features.

**Gate:** real player agency and flow improved — not just automated pass rate.

## M6 — Mantle / top-out (conditional)

Proceed only if M5 justifies further investment.

**Tasks:** tiny ledge arena, support transition, load transfer over lip, collision-safe top-out, return to grounded movement. No teleport animation. If current actuators cannot perform it, document the missing capability, do not hide it.

**Gate:** player can intentionally finish a climb onto an ordinary platform and immediately walk away, with valid physical support throughout.

## M7 — Reactive climbing challenge (conditional)

Use the proven hinged beam and a small counterweight to create one level where body weight deliberately changes the path. Preserve fixed-versus-dynamic comparison.

**Gate:** the moving structure creates a player-discovered skill, not merely spectacular accidental physics.

---

# 22. Testing procedure and reporting protocol

Each completed milestone must contain:

1. **What was changed:** files, algorithms, new config defaults, side effects.
2. **What was not changed:** mass, caps, existing gripper and pending-target authority, old profiles.
3. **Baseline vs new:** same fixtures at same physics settings, all relevant flags recorded.
4. **Machine metrics:** real vs requested motion, forces, work, contacts, handover discontinuities, frame/step timings.
5. **Human evaluation:** if playable, short video and direct play notes on comfort, precision and fun.
6. **Regression results:** at 120 and 60 Hz where applicable, including failure cases.
7. **Explicit decision:** KEEP / REVISE / REJECT, with evidence and next question.

Do not erase failed tests from the evidence folder. Do not mislabel scripted passes as human play sessions. Do not turn a weaker/more assisted control result into a “physics improvement” without recording the changed authority.

### Protocol for the designer's first manual comparison

**Session A — existing:** independent aim profile 3, specified posture/length policy, same arena, no v0.7 coordinator.

**Session B — v0.7 hands-only:** move intent, existing hands, physical feet disabled.

**Session C — v0.7 mixed:** same as B but optional feet enabled.

Play each for a few minutes after equal familiarization. Try: climb one ledge, traverse two grips, deliberately swing to a higher hold, release onto safe ground. Record any moment where you know what you want to do but cannot express it through the inputs.

### Decision logic

**KEEP** if climbing genuinely becomes more direct, physically readable and enjoyable while preserving restrictions.  
**REVISE** if only a subset (e.g., grounded climbing) improves, or feet/one-hand movement creates controllability problems.  
**REJECT** if it replaces skill with autopilot, behaves like unsupported directional propulsion, or feels substantially worse than the simpler baseline.

---

# 23. Physics specialist: specific research tasks

The physics agent must answer these practical questions from **the working implementation**, not from general simulation theory alone:

1. Which movement directions are mechanically actuable with a **single tension-only arm**, an attached gripper's limited moment and a 12 kg body? Show infeasible directions explicitly.
2. What locomotion requests can the existing **two arms** achieve at fixed attachment points with the shared 360 N cap?
3. How can the optional **compression-only, friction-limited feet** contribute to climb-up intent while preserving existing force caps and reaction pairs?
4. Can the coordinator re-target existing arm lengths to produce useful COM motion without causing severe oscillation or invisible force accumulation?
5. Does a simple constrained allocation improve actual motion relative to the existing A/B/C planners, or would it duplicate their efforts?
6. Does the moving hinged support receive the exact opposite force/moment, including when grip and foot reactions are combined?
7. How do integration rate (60 vs 120 Hz), contact transitions and actuator damping affect physical authority and usability?
8. Can torso orientation remain readable without using P2's previously harmful always-upright preference?
9. How can the controller identify a physically impossible request quickly and prevent wind-up without freezing legitimate momentum?
10. Where is the exact boundary between **physically aided posture** and **automatic locomotion**? Demonstrate it with negative tests.

Deliver a short technical note with actual measurements and file references for each chosen algorithm. If the current hardware/solver cannot deliver something robustly, report that fact rather than increasing forces or hiding the effect.

---

# 24. Main Codex agent: implementation and coordination instructions

The main agent owns:

- Keeping existing project baseline intact and creating a safe experiment branch.
- Input profile, camera behavior, UI and scene integration.
- Arena construction and automated + human test instrumentation.
- Separating speculative new systems from confirmed features.
- Scheduling physics-specialist handoffs and preserving their measurements.
- Reviewing diff size, integration assumptions and all force-authority violations.
- Returning final evidence: build, tests, actual play notes and explicit design recommendation.

**The physics specialist owns** support feasibility, constraint modeling, force/torque auditing, controller stability and saturation semantics. Neither agent should silently increase physical budgets or rewrite the reliable hand capture system.

### Collaboration rule

A controller milestone is complete only when **both** conditions hold:

1. Physics agent: physical constraints and negative tests pass.
2. Main agent / human play: the movement is comprehensible and better, not merely different.

---

# 25. Open design choices (explicitly unresolved)

The following questions cannot be answered from the reports alone and must remain experiments:

1. Does up/down W/S over a wall feel natural enough compared with manual arm-length control?
2. How much of swing should fall out of standard traversal input, and when is a distinct advanced movement tool justified?
3. Is `physical_feet=ON` essential for enjoyable climbing, or can the hands-only model already carry a compelling game?
4. Should body alignment be entirely emergent or moderately supported through finite gripper moments?
5. Which control convention remains understandable on ceilings, overhangs and moving structures?
6. How much automatic foothold selection is acceptable before players feel that the character climbs itself?
7. Does the existing biped rig and compound collider give enough visual feedback for top-out without a full articulated body?
8. Does v0.7 actually outperform the simple v0.6 on five-minute, human-play sessions?

**Do not answer these with arbitrary implementation decisions disguised as confirmed design requirements.**

---

# 26. Final definition of success

The prototype succeeds if players can consistently recognize and execute **three physical movement verbs**:

1. **Step:** use hands and a legitimate foot support to raise the body.
2. **Swing:** deliberately build/manage pendular motion when a stable step is not possible.
3. **Transfer:** choose and acquire a new grip at the moment the body makes it reachable.

A fourth verb, **Top-out**, becomes a follow-on gate once the first three feel good.

The character must remain a dynamic body with real mass. The player must still earn changes in position through supports, timing and sensible choices. **The improvement sought is not 'more physics' or 'more automation': it is a more effective relationship between human intention and physically achievable movement.**

---

# Appendix A — Simulation-step pseudocode (architecture illustration only)

```gdscript
# Pseudocode, not a drop-in Godot implementation.
# Continue to use project-specific physics integration and lifecycle.
func physics_step(dt: float) -> void:
    input_router.sample_and_filter(dt)
    grip_system.update_pending_hands_without_force(dt)
    grip_system.evaluate_real_contacts_and_transitions(dt)

    var supports = support_state.collect_actual_supports()
    var mode = support_state.resolve_mode(supports, dt)

    if mode == AIRBORNE or supports.has_no_load_bearing_contact():
        intent_coordinator.disable_climb_actuation()
        physics_world.integrate_existing_inertia_gravity_and_collisions()
        return

    var frame = support_frame.compute_continuously(supports, camera, dt)
    var move_intent = intent_filter.map_to_support_frame(frame, dt)
    var feasible = feasibility.estimate_supported_actions(
        move_intent, supports, real_body_state, existing_caps)

    var actuator_goals = intent_coordinator.propose_bounded_goals(
        move_intent, feasible, actual_body_state, dt)
    actuator_goals = limits.anti_windup_and_sanitize(actuator_goals, dt)

    # Existing physics modules retain force authority.
    arm_actuators.apply_limited_tension_and_reactions(actuator_goals, dt)
    foot_solver.apply_only_real_compressive_contact_forces(actuator_goals, dt)
    support_moments.apply_only_bounded_reacted_torque(actuator_goals, dt)

    telemetry.record_intent_actual_forces_failures(dt)
```

The example intentionally omits input/physics callback plumbing. Avoid duplicate `apply_force` calls if the existing controller already executes them during its standard physics update.

---

# Appendix B — Diagnostic scenario examples

### Case B1 — One-hand reach to a hold that remains too high

- Player holds the left grip and requests W upward.
- Controller uses physically valid left-arm traction and capped gripper moment only.
- COM rises until strength, geometry, range, gravity and momentum reach equilibrium.
- Right hand remains pending, cannot reach surface, and applies zero force.
- **Correct result:** does not succeed unless the body physically approaches enough; reason reflects the actual limitation.

### Case B2 — Moving a camera while pressing D

- Player starts a lateral traverse with D.
- Camera orbits by 90° while D is continuously held.
- Current world movement request stays stable or smoothly bounded according to tested frame policy.
- **Correct result:** no sudden lateral motor torque / no axis flip.

### Case B3 — One foot produces a useful step

- Player is attached with two hands and plants one foot on a ledge.
- Player presses W; foot can push while hands stabilize and contribute limited traction.
- Measured arm load falls or COM upward progress improves compared with feet OFF, where physical geometry allows.
- **Correct result:** benefit comes from real contact forces, not IK or vertical body impulse.

### Case B4 — Body suspended on a movable beam

- Player grabs articulated beam and requests movement.
- Beam rotates or resists based on real hinge and its inertia.
- **Correct result:** opposite reaction on beam and no hidden fixed-world anchor.

### Case B5 — A player holds W against a fully blocked wall

- Body has real grips but an obstacle prevents upward motion.
- Planner saturates, force caps stay valid, error does not integrate forever.
- On release or obstacle removal, no stored impulse launches the body.
- **Correct result:** honest constraint and stable recovery.

---

# Appendix C — Source grounding and document precedence

This specification is an **experiment proposal**, not a description of functionality already delivered. Its grounded baseline comes from the following user-provided reports:

1. `SISTEMA_IMPLEMENTADO_V06_PT.md` — full implemented system, profile and scene inventory, v0.6 validation and open human-feel questions.
2. `FISICA_IMPLEMENTADA_V06_PT.md` — force-law details, reaction paths, cap semantics, optional feet, existing P0/P1/P2 results and physical limitations.

If a v0.7 instruction conflicts with an actual verified engineering safety constraint, the existing implemented physical invariant wins until a measured, documented design change is approved. This file supersedes earlier **design suggestions** about v0.7 intent control but does not overwrite existing v0.6 settings, sources, source-control history or validation evidence.
