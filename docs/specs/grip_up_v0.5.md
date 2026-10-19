# GRIP UP — Single-Grip Transfers, Body Control & Reachability
## Physics Climbing Prototype Specification — v0.5

**Status:** Experimental upgrade to the existing playable prototype; not an approved replacement for its current controls.
**Target:** Windows PC, third person, landscape 16:9.
**Engine/backend:** Existing GRIP UP Godot 4.7.2 / Jolt configuration, with 120 Hz primary physics and 60 Hz comparison testing as reported by the project.
**Depends on:** GRIP UP v0.4 *Independent Aim & Physics-Driven Climbing*.
**Implementation:** Main Codex agent plus physics-specialist agent.
**Primary objective:** Make consecutive one-hand-to-two-hand climbing transfers controllable and physically understandable **without increasing strength, snapping the character, or coupling aiming back to arm length**.

---

## 1. Problem statement

Independent mouse aiming is working, but one-hand suspension reveals a separate mechanical problem:

- The body naturally rotates and oscillates around the remaining support.
- Simply shortening that arm does not necessarily put the free shoulder or hand in range of the next hold.
- A potential new grip may be within static geometric reach but impossible to catch at the current body velocity, direction, or available hand travel time.
- Stabilizing too aggressively may remove deliberate swinging, which is an intended skill.
- Ten successful sequential transfers must be evaluated in actual gameplay, not demonstrated only through isolated hand attachment tests.

**Do not interpret this as a request to guarantee every higher grip or make the character automatically climb.** The target is controllable, legible physical motion. Unreachable holds must remain unreachable when the player lacks the appropriate support, momentum, or technique.

### Non-goals

Do not implement a new locomotion engine, full ragdoll, fully physical feet, procedural route finder, stamina system, new character model, new climbing equipment, arbitrary extra grip force, or new level campaign in this iteration.

---

## 2. Frozen baseline and constraints

Before changing anything, inspect the actual current repository and report the settings found. The values below are **from the provided prototype report**, not a claim that the latest working tree is unchanged:

| Parameter | Reported reference value |
|---|---:|
| Character mass | 12 kg |
| Shared total hand-force budget | 360 N |
| Shared climbing torque budget | 150 N·m |
| Attitude assistance torque cap | 20 N·m |
| Selectable arm reach | Approximately 0.65708 m |
| Arm actuator target maximum | 0.62 m |
| Elastic allowance | 0.04 m |
| Hand-reaching speed | 4 m/s |
| Primary physics frequency | 120 Hz |
| Comparison frequency | 60 Hz |

Preserve existing force limits unless a **separate, documented experiment** is expressly authorized. Do not raise forces simply to make the ten-transfer test pass.

### Hard constraints

- **Hold-to-grip only:** held LMB = left hand, held RMB = right hand; button release detaches/cancels its respective hand. No toggle.
- **Aim is independent:** mouse pointer movement must never directly extend, shorten, or retarget the supporting arm.
- **Suspended WASD:** W/S mean camera-relative depth swing intent; A/D mean lateral swing intent. Grounded WASD retains its existing movement role.
- Keep free-surface grip selection, finite-speed hand reaching, obstacle checks, local-space attachment points, grip overload/slip rules, and reactive support forces.
- The physical body remains authoritative. No direct body `transform`, velocity overwrite, kinematic snap, invisible airborne thrust, or infinite rigid constraint.
- For movable supports, apply appropriate equal-and-opposite forces and torques.
- Keep the old v0.4 control profile switchable and playable. Do not alter the original Janga project.
- All new assistance must have explicit enable flags, debug visibility, and bounded activation/deactivation.

---

## 3. Design principle: separate three failures

Each attempted transfer must identify **where the process failed**.

### A. Position / reachability failure

The next handhold cannot be reached from the actual shoulder/body configuration, even if it appears close on screen.

Check anatomical distance, available rotation, obstacle-free approach, and achievable body pose.

### B. Transit / catch-timing failure

The hold is geometrically viable, but the hand cannot physically reach the moving target during the available time.

Check hand travel duration, relative motion, grip approach direction, and time before the hold leaves the reachable envelope.

### C. Grip-retention / load failure

The hand physically reaches the surface and attaches, but the incoming load or unfavorable force direction causes slipping or immediate detachment.

Check force peaks, load distribution, grip capacity, catch deceleration, and actuator target initialization.

**Do not classify all three as “missed grip.”** They require different fixes and different player feedback.

Recommended event codes:

`POSE_UNREACHABLE`, `PATH_OBSTRUCTED`, `HAND_TOO_SLOW`, `TARGET_LEFT_REACH`, `CONTACT_REJECTED`, `CATCH_OVERLOAD`, `GRIP_SLIP`, `SUPPORT_LOST`, `SUCCESS`.

---

## 4. Single-grip body dynamics

The character is a single dynamic rigid body, with hands connected to physical anchor points through limited arm actuators. Under one-hand suspension, rotation around the support can be legitimate.

### 4.1 Keep useful movement

Preserve:

- Natural pendular motion under gravity.
- Physically generated angular velocity.
- Deliberate swing pumping, braking, and timing.
- Tilting/rotation that follows from actual contacts and force application.
- Distinct behavior when the anchor belongs to a dynamic object.

### 4.2 Suppress only unhelpful instability

Measure separately:

- Pendulum motion around the grip.
- Trunk twist/roll that harms aiming and visual readability.
- High-frequency oscillation or solver chatter.
- Oscillation introduced by actuator target resets, grip transitions, or camera rotation.

Do not treat all angular velocity as a defect. **A smooth, skillful swing should survive the improvement.**

### 4.3 Physical authority audit

A single ideal point connection cannot arbitrarily transmit a full 6DOF orientation command. If the desired control requires a moment at the hand, the implementation must identify the actual modeled mechanism:

1. A finite-size/torque-capable mechanical gripper, with a clearly limited reaction torque; **or**
2. Body/arm geometry that generates a moment using physically applied forces; **or**
3. Contact from another support, such as a foot (deferred to later versions).

If a one-point grip is intentionally modeled as moment-free, do not silently add a camera-oriented body motor that effectively creates free-space torque.

Record the torque source and its reaction path. Existing attitude assistance may remain as a **measured comparison**, not as unquestioned physical ground truth.

---

## 5. Support-aware body-posture experiment

**Hypothesis:** A bounded posture objective informed by real supports can improve shoulder placement and suppress harmful twist without automatically carrying the player to the next hold.

### 5.1 Inputs

- Current physical body transform, center of mass, velocity, and angular velocity.
- Attached grip point(s), support-body velocity, contact normal, and load.
- Actual shoulder positions, arm lengths, and feasible limits.
- Current camera-relative swing intent from WASD.
- Current grip/slip states.

**Do not use mouse pointer motion as a hidden “go to next hold” target.** The pointer remains a targeting device only.

### 5.2 Posture output

Compute a conservative **preferred torso attitude / support-relative configuration** that favors:

- Avoiding useless axial trunk twist.
- Keeping the free shoulder accessible for aiming where physically possible.
- Respecting the current hand's arm range and torque budget.
- Allowing pendular movement and preserving useful angular momentum.
- Minimizing abrupt changes at one-to-two and two-to-one grip transitions.

This output is a soft objective, not a directly imposed transform.

### 5.3 Controller behavior

- Smoothly blend posture intent on grip acquisition or release.
- Use only existing physically justified actuators or an explicitly modeled limited grip moment.
- Apply capped torque and damping with anti-windup/saturation safeguards.
- Do not use the camera's instantaneous orbit direction to forcibly turn the physical character.
- A single grip may remain unable to reach an overhead or lateral hold. In that case, preserve failure and expose the reason.

### 5.4 Required variants

| Variant | Meaning |
|---|---|
| P0 — Baseline | Existing v0.4 suspension and attitude assistance unchanged |
| P1 — Twist-only refinement | Better isolate unhelpful axial twist while preserving pendulum motion |
| P2 — Support-aware posture | P1 plus a feasible posture objective informed by grip geometry and actual load |

Test all variants with identical force budgets and level geometry. Do not jump directly from P0 to a complex automatic reach planner.

---

## 6. Deliberate 3D swing control

Suspended **W/S** command forward/backward swing intention in camera-relative horizontal depth; **A/D** command lateral swing intention.

### Mechanical requirements

- Inputs must be translated into physically supported action: variations of supported actuator length, load sharing, or a properly modeled limited reaction torque.
- No free-space forces or unpaired impulses.
- With no attachment or other valid contact, WASD cannot generate new airborne propulsion.
- If current attachment geometry cannot produce a requested direction of swing, do not fake it. Log `SWING_AXIS_UNACTUATED`.
- Player timing must matter: input at different phases of the swing should be able to amplify or damp motion where mechanically feasible.
- Constantly holding one direction must not generate unlimited energy.
- On dynamic supports, the support must react to player-generated forces.

### Camera control frame

Cache a world-space horizontal direction frame at the beginning of each held directional command, or use a tested gradual blending rule. Rotating the camera mid-command must not inject a sudden mechanical impulse or reverse intended motion.

### Quantities to monitor

Track angular position around the attachment, angular velocity, relative swing energy, input phase, actuator work, and force saturation. Compare increasing, decreasing, and neutral swing attempts.

---

## 7. Predictive reach and moving-contact capture

A simple distance check is insufficient when the player is moving.

### 7.1 Short-horizon prediction

On an intentional hand press, estimate over a configurable short time horizon:

- Future shoulder trajectory from current position/velocity and current support configuration.
- Target's future world position using its local attachment point and supporting body's motion.
- Hand arrival time under existing finite reach speed and collision-safe path.
- Reachable time window during which the target can be physically contacted.
- Relative velocity at the expected catch.

Use a conservative approximation rather than assuming the full physics trajectory can be predicted exactly. For dynamic, rotating supports, record confidence or explicitly decline to predict.

### 7.2 Input buffering — optional A/B experiment

Test a short bounded input window (initially 100–150 ms, tunable), **only while that hand button remains held**. The hand must still travel physically and meet the target at a valid point. A buffer is not permission to grab through space or after mouse-up.

Keep buffering disabled in the baseline variant.

### 7.3 Contact and load transfer

When a hand catches:

- Preserve body and support momentum.
- Initialize the new actuator using the **actual instantaneous separation**, not a distant stale target.
- Blend the new actuator's force contribution in smoothly.
- Preserve the surviving arm's existing state and target.
- Share the same total force/torque budgets across both hands.
- Allow overload/slip when the catch is physically unsustainable; do not reset velocity to make it stick.

### 7.4 Reach feedback

Show a restrained debug classification during testing:

`IN RANGE`, `PREDICTED CATCH WINDOW`, `NEEDS SWING`, `OBSTRUCTED`, `UNSAFE CATCH`.

Not all of these require final-game HUD indicators. First verify the underlying classification is useful.

---

## 8. Transfers as the main gameplay test

Build a repeatable climbing route that can be completed with the currently available body capabilities.

### 8.1 Reference transfer route

Create **ten alternating hand transfers** along a fixed wall:

- Early transfers: straightforward reachable support changes.
- Middle transfers: asymmetric left/right positions.
- Later transfers: one-handed moments with modest natural oscillation.
- Keep anchor distances and collision envelopes documented and configurable.

At least one fully instrumented successful route must be demonstrated with human input, not only scripted attachment calls.

### 8.2 Swing-required route

Create a **separate** route with one or two holds that are intentionally outside static reach but plausibly reachable with deliberate swing.

Do not place these on the basic ten-transfer route and then blame the controller for failing an impossible sequence.

### 8.3 Three required diagnoses per attempted handoff

1. Was the candidate pose/geometric reach physically available?
2. Could the hand arrive during the reachable window?
3. Could the hand retain the resulting load?

Every failed transfer must have a primary reason and recorded supporting measurements.

---

## 9. Test matrix

| ID | Test | Required observation |
|---|---|---|
| T0 | Baseline snapshot | Existing prototype still playable; parameters captured |
| T1 | Pointer independence | Large mouse movements do not directly modify arm lengths or posture plans |
| T2 | One-hand suspension | Natural pendulum retained; no unexplained high-frequency twist |
| T3 | Camera orbit during suspension | Orbit cannot inject torque or move an existing grip |
| T4 | Ten-transfer static route | Transfers work repeatedly without aim recentering or unintended arm extension |
| T5 | Lateral and asymmetric reach | Body posture improves reachability only through real physical motion |
| T6 | Deliberate swing | Player can build and brake swing when mechanically possible |
| T7 | Moving/rotating support | Correct local anchor behavior and equal/opposite force reactions |
| T8 | Catch at speed | Reach timing and contact load classified separately; no snap/velocity erase |
| T9 | One-to-two-to-one transition | Smooth budget redistribution; surviving grip never resets |
| T10 | Frequency comparison | Run relevant tests at both 60 Hz and 120 Hz |
| T11 | Human feel | Precision, comfort, recovery, and sense of agency compared with v0.4 |

### Suggested pilot success targets

Use these as **validation targets, not claims about the existing build**:

- Repeat the basic ten-transfer route in **three sessions**; aim for at least **two uninterrupted successful completions** once players understand the controls.
- Zero grip attachments created without physically valid hand contact.
- Zero direct changes to body transform/velocity as a climbing shortcut.
- Zero over-budget force/torque commands beyond documented numerical tolerances.
- No involuntary arm-length change caused solely by moving the aiming cursor.
- Every failed capture produces a meaningful diagnostic reason.
- A clearly observable difference between swing pumping and swing braking.
- Functional outcomes should be broadly consistent between 60 and 120 Hz; numerical traces need not match exactly.

If the route cannot be completed, first establish whether it is designed to be physically feasible with existing capabilities.

---

## 10. Debugging and telemetry

Log time-stamped per-attempt snapshots:

**Hands and anchors**
- Hand state, grip side, anchor object and local point.
- Actual and target arm lengths, distance to candidate grip.
- Hand movement time, target-relative velocity, catch moment.
- Contact validity, grip load, slipping status, reason for release.

**Body and motion**
- Body transform, velocity and angular velocity.
- Center of mass, shoulder positions, body orientation relative to supports.
- Pendulum angle and angular speed, axial twist amount.
- Posture objective and actual achieved attitude.

**Actuators**
- Linear force and torque, saturation, grip reaction on dynamic supports.
- Global hand force budget and torque budget use.
- Supported swing request, phase, estimated work and camera-relative input frame.

**Gameplay**
- Transfer index (1–10), attempts, recovery events, route completion.
- Reasons for failed aim, reach, catch and retention.
- Optional player rating for comfort, precision and physical readability.

Expose a developer overlay and compact JSONL logs. Do not turn all diagnostic values into final-player UI.

---

## 11. Implementation architecture

Integrate with the existing modules instead of creating a replacement climbing engine.

Suggested responsibility changes (adapt names to verified project structure):

| Module | Work |
|---|---|
| `grip_targeting.gd` | Optional short-horizon reach/catch assessment; never control attached arm length from aim |
| `grip_anchor.gd` | Keep local material point and target velocity on moving supports |
| `arm_actuator.gd` | Preserve limited servo mechanics; add robust handoff initialization/anti-windup only if needed |
| `climbing_controller.gd` | Support-aware posture variant, swing coordination, grip transition orchestration |
| `climbing_camera.gd` | Maintain aim and orbit independence; no camera-induced physical torque |
| `grip_up_lab.gd` / test scenes | Ten-transfer route, swing-required route and diagnostics |
| Optional `supported_posture_solver.gd` | Small, self-contained feasible posture planner; no full IK/physics rewrite |
| Optional `reach_prediction.gd` | Conservative predictor that never authorizes impossible attachment |

Keep new behavior behind flags:

```ini
control_profile = "INDEPENDENT_AIM_V04"
transfer_assist_enabled = false
posture_variant = "BASELINE" # BASELINE | TWIST_REFINED | SUPPORT_AWARE
reach_prediction_enabled = false
catch_buffer_enabled = false
swing_diagnostics_enabled = true
```

Introduce a new opt-in profile only if needed for clear A/B testing. Keep `INDEPENDENT_AIM_V04` recoverable.

---

## 12. Implementation milestones — strict order

### M0 — Freeze and measure existing behavior
1. Inspect live scripts, tuning resources and recent test results.
2. Create a safe project commit/snapshot; confirm Janga remains untouched.
3. Run existing automated and rendered checks.
4. Capture footage and diagnostics from the current ten-transfer failure.

**Gate:** one reproducible baseline issue and a classification of its likely failure stage.

### M1 — Diagnostics before assistance
1. Add separate reasons for pose, transit, catch and retention failures.
2. Visualize actual shoulder reach and hand travel in the debug overlay.
3. Add ten-transfer route instrumentation.
4. Re-run unchanged controls.

**Gate:** a failed transfer can be explained by measured conditions.

### M2 — One-grip stability study
1. Evaluate unwanted twist versus useful pendulum movement.
2. Implement P1 twist-only refinement; compare directly with P0.
3. Only if necessary, implement P2 support-aware posture with physically justified reaction paths.
4. Do not change hand strength or gravity.

**Gate:** less harmful twist or easier aiming, while swing freedom and valid torque behavior remain.

### M3 — Supported swing and recovery
1. Test whether W/S/A/D can produce and brake swing via current supported forces.
2. If a requested swing axis cannot be actuated, report the missing physical mechanism.
3. Verify fixed and moving anchor behavior, with a recorded energy/force audit.

**Gate:** swing control is intentional, reproducible and does not behave like a jetpack.

### M4 — Reach/catch consistency
1. Add conservative prediction and precise failure diagnostics.
2. Compare input buffering off/on.
3. Fix handoff initialization only where evidence identifies a discontinuity.
4. Evaluate catch loads at a range of incoming speeds and poses.

**Gate:** better capture consistency without unrealistic extra reach or force.

### M5 — Ten-transfer validation and recommendation
1. Repeat ten-transfer and swing routes at 120 Hz and 60 Hz.
2. Collect human feel ratings and session diagnostics.
3. Compare P0/P1/P2 and buffering variants on the same geometry.
4. Produce a concise `KEEP / REVISE / REJECT` decision for each system.

**Gate:** evidence that the new behavior improves player control, rather than just making the route easier.

---

## 13. Acceptance criteria

- [ ] The working v0.4 input scheme remains available.
- [ ] Hold-to-grip is preserved and cursor movement remains aim-only.
- [ ] One-hand swings remain dynamic; unwanted twist is distinguished from desired swing.
- [ ] Any new posture assist uses a documented physical reaction path and existing force/torque limits.
- [ ] The character cannot be pulled directly toward the next mouse-targeted handhold.
- [ ] New grip acquisition respects anatomical reach, travel time, collision checks and incoming load.
- [ ] Two-grip transitions do not double strength or produce impulse spikes.
- [ ] Moving platforms and beams still respond to character forces.
- [ ] W/S and A/D only affect swing through actual supported mechanics.
- [ ] Ten-transfer failures have actionable, specific diagnoses.
- [ ] Static transfers and swing-required captures can be demonstrated without cheating.
- [ ] All changes are feature-flagged, documented and regression-tested.
- [ ] Human testers report improved control without a noticeable loss of physical agency.

---

## 14. Instructions to Codex and the physics specialist

**Main Codex agent**
- Inspect code before editing. Own scene/test harness, instrumentation, camera/input integration, flags, regression checks and final validation.
- Do not rewrite the core actuator or silently introduce a different climbing control model.
- Keep a reproducible route and structured before/after report.

**Physics specialist**
- Audit the physical authority of single-grip torque and supported swing.
- Quantify legitimate pendulum dynamics versus servo-induced instability.
- Design minimal bounded stabilization, reach prediction and safe force transition algorithms.
- Preserve force conservation on dynamic supports and the shared force/torque caps.
- Reject any proposed fix that only conceals impossible reach, failed attachment or load failure.

**Required report after every milestone**
- Files changed and algorithm summary.
- Baseline vs new parameter values.
- Test cases, outcomes and failure traces.
- Recorded video or reproducible headless test where applicable.
- Whether behavior improved the human-played ten-transfer sequence.
- Known physical approximations and unresolved limitations.

Do not report success solely because a headless test passed.

---

## 15. Final design target

**Aiming must stay effortless, but the climb itself must remain earned.**

The player decides where and when to grip, how to transfer load, and when to swing. The character must respond through physical support, real momentum, finite muscle-like effort and visible constraints. Improving posture and catch handling must make these actions readable and controllable—not automatic.
