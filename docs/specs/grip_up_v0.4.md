# GRIP UP — Independent Aim & Physics-Driven Climbing
## Input and Locomotion Experiment Specification — v0.4

**Status:** Proposed experimental control profile. Not an implemented or validated feature.
**Primary target:** Windows PC, third-person, landscape 16:9, mouse and keyboard.
**Project:** Existing `GRIP UP` Godot project (reported as Godot 4.7.2, Jolt Physics, primary physics step 120 Hz; also tested at 60 Hz).
**Reference:** Current playable prototype and the previous v0.3 hold-to-grip / arm-drag / swing experiment.
**Implementation owners:** Codex main agent (input, camera, gameplay integration) and physics specialist (supported movement, force budgets, solver validation).

---

## 1. Why this experiment exists

The previous mouse-drag climbing model has an input conflict:

1. The player holds the **left mouse button (LMB)** to grip a surface.
2. Dragging the mouse **downward** contracts the attached arm and raises the body.
3. The pointer consequently moves down on screen.
4. The player must move the pointer **upward** to select the next higher grip with the right hand.
5. That upward motion **extends the supporting arm**, undoing some of the achieved posture or height.

Simply reversing the sign does not solve the underlying conflict and was judged unintuitive. Ratchet-style one-way contraction, scroll-wheel arm-length input, and modifiers/clutches were discussed but were not accepted as the direction to pursue.

**Decision to test in v0.4:** separate **aiming** from **arm contraction**. The mouse pointer chooses the next point of contact; it must never directly change an already attached arm's target length. The physical climbing controller manages posture and arm effort based on which supports are acquired and the player's movement intent.

The outcome is **not assumed to be better**. A body that climbs too automatically could reduce agency and skill. We will A/B test whether the gain in comfort and clarity is worth the loss of direct manual length control.

### Primary objective

Allow a continuous sequence:

**hold left grip → rise under physically limited effort → freely aim above with mouse → acquire right grip → transfer load → release left → repeat**

The player must not have to move the mouse in the opposite direction just to recover screen space or inadvertently extend a loaded arm while selecting the next contact.

---

## 2. Non-negotiable constraints

- **Keep hold-to-grip.** LMB held maintains the left-hand grip; RMB held maintains the right-hand grip; releasing either button promptly releases/cancels that hand. **No toggle.**
- Keep independently selectable hands and surface-point gripping (not fixed colored grip sockets).
- Preserve finite-speed reaches, line-of-sight / collision checks, anatomical reach limits, and the current hand state machine (`FREE`, `REACHING`, `ATTACHED`, `SLIPPING`, `RELEASED`).
- Preserve the single dynamic character body, current IK presentation, ground locomotion and current suspension/attitude assistance unless a specific measurable issue requires change.
- Preserve the existing spring-damper actuators, implicit-integration work, effective-mass approach, shared hand-force and torque budgets, grip integrity and local-space attachment points on moving supports.
- Physical simulation stays authoritative: **no teleport, direct transform writes, instant velocity assignments, hidden airborne thrusters, or infinite-strength constraints.**
- Preserve equal-and-opposite reactions on dynamic supports.
- Preserve existing charged Space impulse as a separately switchable baseline experiment; do not remove or redesign it in the first pass.
- Do not modify the original `Janga` object-grabber project or regress the playable GRIP UP baseline.
- All proposed assistive behavior must have tunable limits, diagnostics, and an on/off feature flag.

---

## 3. Current systems to integrate with (not rebuild)

The implementation report describes:

- Hand-specific states and hold-to-grip, including immediate release on mouse-up.
- Real surface raycasts, reach checking, local-coordinate anchor positions and valid moving-anchor reactions.
- Two hands sharing a force/torque budget, with progressive force ramp-in, slipping and overload behavior.
- A 12 kg dynamic character; reported hand-force budget **360 N**, climb torque budget **150 Nm**, and posture assistance cap **20 Nm**.
- Approximate selectable arm reach **0.65708 m**; actuator target maximum **0.62 m**, elastic allowance **0.04 m**; hand reach speed **4 m/s**.
- Spring stiffness **6000**, damping **220**, target-length minimum **0.18 m** (reported tuning values, not immutable specification requirements).
- The existing Space hold/release launch, reactive hinged beam, static climb, swing/catch environments, checkpoint/reset, diagnostic HUD, 60/120 Hz suites, and session logging.

Treat these as **baseline values**. Record them before each test. Do not silently tune mass, available force, contact friction, or actuator response to manufacture a positive result.

---

## 4. Player controls — experimental profile

| Input | While grounded, hands free | While reaching, attached or suspended |
|---|---|---|
| Move mouse pointer | Aim at geometry | **Aim at next potential contact; does not change arm length or effort directly** |
| Hold LMB | Left hand reaches toward the clicked valid contact | Maintain left grip; release on LMB-up |
| Hold RMB | Right hand reaches toward the clicked valid contact | Maintain right grip; release on RMB-up |
| Hold LMB + RMB | Both hands may be acquiring support | Two independently maintained grips; load sharing through physics |
| **W / S** | Walk forward/back relative to camera | Request **forward/back supported swing**, in camera-relative horizontal depth |
| **A / D** | Strafe left/right relative to camera | Request **lateral supported swing**, in camera-relative horizontal right/left |
| MMB drag | Orbit | Orbit; does not change grip state or arm effort |
| Mouse wheel | Dolly | Dolly |
| Space hold/release | Existing action, if available | **Legacy charged impulse**, enabled only as an explicit A/B option |
| R | Restart/checkpoint | Restart/checkpoint |
| Tab | Diagnostics | Diagnostics |

**There is no direct player control of arm length in this experimental profile.** A new higher handhold and a physical posture controller provide the climbing drive. The player chooses the reachable surfaces, hand sequence, release timing and supported swing effort.

### 4.1 Click and cursor ownership

- On a hand-button **down**, sample the pointed contact and initiate a finite-speed reach if it is valid. A hand already attached should remain on its existing material point until release; pointer movement never drags that anchor across a wall.
- While that button is held, its grip request/attachment persists regardless of pointer position.
- If LMB is already attached, moving the pointer toward a higher target for RMB does not alter the left arm target length.
- During `REACHING`, the free hand follows its established target; avoid silently retargeting from every cursor movement. A new target requires an intentional new press/attempt under the existing state rules.
- Release of LMB/RMB cancels reaching or disconnects the relevant anchor promptly, even if UI/camera input has focus.
- Pointer may freely move across the entire screen while either or both hands remain attached. Reaching screen edges does not accumulate length requests.

### 4.2 Camera-reference handling

- On a suspended W/S/A/D input start, project camera forward/right onto the horizontal plane and cache the world-space command frame until that input gesture ends (or blend directions slowly, if testing demonstrates an advantage).
- Orbiting the camera does not rotate an existing world-space grip, move the anchored contact, inject motion or change the body’s posture target by itself.
- Neither mouse motion nor mouse button ownership may accidentally become camera orbit. Preserve MMB orbit and scroll dolly.

---

## 5. Supported climbing: the proposed controller

### 5.1 Key distinction

**We are NOT proposing that the game automatically translates the body toward the next hold.** It only computes *physically feasible actuator goals* from the current attachment configuration. Force-limited servos try to move the body; collisions, momentum, slipping, available support and moving structures determine whether anything actually happens.

The player retains control over **which anchors are used, the order in which they are acquired/released, and when to pump or brake swing**.

### 5.2 Proposed architecture

1. **Grip Targeting:** mouse pointer chooses a world-space surface contact.
2. **Grip State System:** existing hand states decide whether the contact has been physically reached and attached.
3. **Support-Aware Posture Planner (new):** on meaningful support changes, estimates a comfortable/reachable body target and a feasible target length for each currently attached arm.
4. **Arm Target Coordinator (new):** drives the existing arm target lengths toward the planned values with rate and acceleration limits, blending on acquisition/loss.
5. **Existing Arm Actuators:** convert target-length errors into force-limited physical action; two hands share the existing budgets.
6. **Existing Jolt Bodies/Joints/Contacts:** resolve actual body/support movement and reaction forces.
7. **IK Visual Layer:** follows the resulting body and arm targets; no IK pose may teleport or propel the physics body.

### 5.3 Initial behavior when a grip attaches

On successful attachment:

- Record the anchor material point, current shoulder-to-anchor length, current body state, current target length, and time.
- Build a candidate **supported, comfortable pose** from the actual reachable geometry. Do not instantly request a minimum-length contraction.
- Estimate modest available contraction toward the candidate supported pose. Apply the desired target gradually, with a clamp on target change per second and on target acceleration.
- Stop advancing the target if the pose is reached, a solver/contact limit is exceeded, the player is slipping, or the posture is judged infeasible.
- When the cursor moves to seek the next handhold, **hold the current planned target** (or continue an already initiated, bounded movement) independently of mouse position.
- Adding/removing a grip triggers a fresh plan and smooth redistribution, not a sudden gain in available force.

The existing body may lag or fail to reach the planned pose. The controller must not increase force without limit in response to that lag.

### 5.4 Avoiding automatic climbing that trivializes the game

The planner is a **bounded settling/pulling action per support acquisition**, not an automatic “go upward forever” policy:

- No continuously increasing upward goal merely because the hand remains attached.
- No autonomous path choice, automatic replacement of hands, or invisible grab assistance that jumps to a better point.
- A grip at the same height must not grant free elevation every time the player releases/regrabs it (no regrip pumping exploit).
- Desired arm lengths must depend on current geometry, center-of-mass position, contact validity and reachable pose; not a scripted height delta.
- A support at an unfavorable angle or on a movable beam may result in little/no rise or may move the beam instead of the body.
- At rest the servo may maintain a physically supportable configuration; it may not freeze the body or resist arbitrarily large external loads.

**Open question to validate:** whether this level of automatic arm effort retains enough manual expressiveness. The first prototype must not quietly promote it to final design.

### 5.5 Proposed small A/B variations (same physics budget)

- **Variant A — Hold Current Length:** attachments preserve the current arm target length; automatic changes are only those needed to prevent initialization discontinuities. Acts as a minimal-control reference.
- **Variant B — Supported Auto-Pull:** attachments compute and gradually pursue a bounded posture/length goal. This is the proposed main experiment.
- **Variant C — Contextual Load Sharing:** Variant B plus a posture plan that accounts more explicitly for two-anchor load sharing, without granting additional total force.

Do not alter the underlying physical strength between variants. Determine whether the added assistance is genuinely useful rather than merely faster.

---

## 6. Suspended WASD is swing, not climb

### 6.1 Direction mapping

- **W/S:** camera-relative forward/back swing intent (depth axis of the current view, projected horizontally).
- **A/D:** camera-relative lateral swing intent.
- **Grounded, hands free:** preserve existing camera-relative walking.
- **No valid support / airborne:** WASD cannot generate artificial horizontal air propulsion.

### 6.2 Mechanical implementation requirement

Suspended WASD may request limited **support-relative posture changes, supported torque and/or arm-load distribution**, but must not directly assign body velocity or apply an unpaired free-space thrust.

If applying an effect on a movable grip target, transmit the opposing force/torque to that `RigidBody3D`. Respect the **shared** global climb budgets.

A constant held key must not produce unbounded swing energy; player timing, angle and contacts determine whether the input adds or removes energy.

**Solver feasibility note:** a single rigid body and one radial arm linkage do not automatically supply controllable swing from arbitrary WASD input. If the current actuator geometry cannot create supported tangential movement, investigate a bounded grip-reactive torque/posture actuator, with equal-and-opposite reactions, rather than adding a covert thruster. Document energy flow and constraints.

---

## 7. Hand reach, predictive catch and handoff

Preserve finite-speed reaches and the current reach envelope. A projected point within an anatomical sphere is not necessarily catchable at current relative velocity.

- On press, validate visibility, surface, reach envelope and plausible hand path.
- Predict shoulder/anchor relative movement over a short horizon (experimental) to classify whether the hand may physically arrive before the opportunity passes.
- If using a short input buffer, keep it active only while that hand button remains held. No sticky grip after release.
- Attach only when the hand reaches a valid contact; preserve body velocity and establish force progressively.
- Transfer force budget smoothly from one hand to two and back, preserving the surviving grip’s physical state.
- Do not erase speed or snap the body to a “caught” position.

**Crucial new test:** while LMB remains attached, freely move the mouse up to a new RMB target. The supporting left arm must not extend as a result of pointer motion. The right hand must complete its finite-speed reach, and both must be able to share the body load without an impulse discontinuity.

---

## 8. Ground-to-grip transition

The existing ground motor is disabled during `REACHING`, `ATTACHED`, and `SLIPPING`; retain baseline behavior initially so this experiment does not simultaneously change locomotion.

After the new aiming/climbing loop is stable, separately evaluate whether beginning a reach should blend ground support into hand support more gradually. This is **outside the core of v0.4** and should not be used to disguise failure of the new movement scheme.

Similarly, physical foot support and mantle are scheduled in the broader v0.2 roadmap but are **not prerequisites** for this control experiment. Keep them disabled or unchanged when performing input A/B tests.

---

## 9. Space charged impulse — isolate for comparison

The current impulse prepares extension and pulls using the existing actuators, then releases the prior grips. It works in some postures and remains posture-dependent.

In v0.4:

- Preserve the existing implementation unchanged.
- Provide a single explicit option `enable_legacy_space_impulse` in experiments.
- **Default for first independent-aim test: OFF**, so automatic/postural ascent and supported swing can be evaluated on their own.
- Re-enable for a second pass to measure whether it adds useful skill and reach without duplicating the normal climbing action.
- Never add a hidden upward velocity or change global force limits to replace a missing impulse.

---

## 10. Diagnostics and tuning

### 10.1 Expose per arm

- Grip state, anchor object/point, shoulder and anchor positions.
- Actual shoulder-to-anchor length and planned target length.
- Force magnitude, force vector and effective distribution.
- Slip state, load ratio and actuator saturation.
- Whether an arm target changed because of **support acquisition**, **posture replanning** or **physics correction**.
- Explicit assertion/log marker: **`aim_input_does_not_change_length = true`** in this profile.

### 10.2 Expose body/support

- Body linear/angular velocity and height, center of mass and current support count.
- Desired posture and distance/error relative to it.
- Actual movement achieved, solver force saturation and abort/failure reason.
- Supported swing request, requested direction frame, reaction forces on movable structures.
- Grip/reach/catch events with timestamps, successful transfers, slips and falls.

### 10.3 Configuration flags

Suggested configuration names (adapt to project architecture):

```text
input_profile = BASELINE_W_S | DRAG_ARMS_V03 | INDEPENDENT_AIM_V04
independent_aim_enabled = true
posture_policy = HOLD_LENGTH | BOUNDED_AUTO_PULL | LOAD_AWARE_AUTO_PULL
legacy_space_impulse_enabled = false
supported_wasd_swing_enabled = true
```

All policies use the same base physics parameter values unless an experiment explicitly documents a changed variable.

---

## 11. Test matrix

### T0 — Baseline preservation

Record version/build, mass, force/torque budgets, spring constants, physics frequency, current grip reach and camera behavior. Run existing headless and rendered checks. Keep a working branch or commit to revert to.

### T1 — The original conflict is gone

1. Grip a reachable hold with LMB and keep it pressed.
2. Acquire a supported, physically achieved higher body position (if Variant B permits it).
3. Move the pointer significantly upward to target a higher hold.
4. Initiate RMB reaching and attach.
5. Release LMB and continue upward.

**Pass:** mouse movement used only for aiming never extends/contracts the supporting arm. No position/velocity spikes during handoff; no new grip before the hand physically reaches its target.

### T2 — Ten consecutive transfers

Climb a simple vertical wall using ten alternating hand transfers, with no modifiers, scroll-driven arm-length changes, or pointer recenter tricks.

Log time, failed transfers, extra input actions, moments of apparent autopilot and user-reported comfort. Repeat with at least two different hold spacings.

### T3 — Single-grip physics

With one hand attached, confirm that the body remains dynamically suspended, can pendulum and cannot float upward without a feasible force path. Try unfavorable anchor geometry and overload conditions.

### T4 — Two-grip load sharing

Attach both hands with asymmetric placement, replan the supported posture and release either hand. The remaining grip must retain load without double-force exploits or instantaneous snapping. Verify total effort budget remains unchanged.

### T5 — Dynamic support reaction

Repeat T1 and T4 on a hinged beam. Pulling against the beam may move it instead of the body. Ensure equal-and-opposite reactions and no infinite anchoring strength.

### T6 — W/S depth and A/D lateral swing

Test one and two grips, then rotate the camera while keys remain held. Confirm the requested direction is stable across orbit and supported forces do not act as air thrusters. Verify the player can intentionally grow and brake swing, where physically possible.

### T7 — Catch during motion

After a supported swing or existing impulse, target a higher grip and attach during relative motion. Log hand travel time, shoulder trajectory, velocity at catch, successful holds and overload failures. No midair snap or velocity reset.

### T8 — Physical frequencies and lifecycle

Run relevant cases at 60 and 120 Hz, including dynamic supports, restart, loss of focus, UI use and changing camera view. Compare functional outcomes within tolerances rather than requiring identical floating-point trajectories.

### T9 — A/B feel session

Compare baseline v0.3/control profile and independent-aim variants on the same wall, with the same character/force budgets and checkpoint rules. Ask testers: “Can you deliberately climb?”, “Can you choose when to rise?”, “Did you ever feel the game climbed for you?”, “Can you reach the next higher hold without cursor gymnastics?”

Include short and longer play sessions; measure comfort and desire to repeat, not just completion speed.

---

## 12. Acceptance criteria

### Required technical acceptance

- [ ] Hold-to-grip remains mandatory for LMB/RMB; mouse-up immediately releases/cancels only that hand.
- [ ] Mouse motion while attached is **aim only**, with no direct effect on arm target length, arm contraction speed, posture goal or pull force.
- [ ] A left-hand grip can remain active while the cursor moves freely upward to select a right-hand hold; the first arm does not extend merely because the pointer moved.
- [ ] Grip acquisition, movement, attachment and release still respect finite hand speed, valid collision/access geometry and real body momentum.
- [ ] Posture assistance is force-limited, bounded, smooth, explainable, and never teleports or pins the body.
- [ ] Automatically planned contraction does not continuously pump height or reward meaningless repeated regrabs at the same anchor.
- [ ] Two hands never grant more than the existing total hand-force/torque budget.
- [ ] Dynamic supports react physically to climbing forces.
- [ ] W/S and A/D serve 3D supported swing while suspended, not direct arm extension or free-space propulsion.
- [ ] A suspended camera orbit cannot modify attachment points or apply physical impulses.
- [ ] Existing baseline behavior can be restored with a profile switch; existing automated checks remain valid or changes are reviewed and documented.

### Required gameplay acceptance (must be observed, not assumed)

- [ ] Alternating higher grips becomes practical without moving the pointer in a direction that reverses prior progress.
- [ ] Players understand how their choices create upward movement.
- [ ] Moving up feels intentional, not like the game playing automatically.
- [ ] Players can stabilize, recover and catch without control ambiguity.
- [ ] No substantial degradation in precision, swing feel or physical response compared with the present working prototype.

If the technical tests pass but gameplay feels passive or less skillful, **do not ship the design as final**. Record the failure, preserve the baseline, and investigate a separate continuous effort input rather than adding covert forces.

---

## 13. Implementation milestones (strict sequence)

### M0 — Protect the current prototype

- Commit or snapshot the project, record baseline configuration and run existing tests.
- Preserve the existing GRIP UP controller and original Janga physics code.

### M1 — Input independence only

- Introduce the `INDEPENDENT_AIM_V04` profile.
- Remove pointer-delta-to-arm-target mappings from this profile, without deleting v0.3 behavior.
- Validate two-hand aiming and release in the existing scenes.
- **Gate:** cursor motion alone never changes an attached arm target.

### M2 — Support-aware arm target coordinator

- Add per-grip acquisition/release callbacks and bounded posture target planning.
- Blend goals into existing actuators with speed/acceleration caps and anti-windup.
- Implement Variant A, then B, then optional C.
- **Gate:** physical rise follows only real supported actuator forces; no automatic infinite climb or discontinuity.

### M3 — Suspended WASD swing

- Keep W/S in camera depth and A/D laterally, using support-relative limited physical effort.
- Preserve ground WASD behavior and existing camera input.
- **Gate:** supported swing is controllable, no artificial airborne thrust.

### M4 — Moving supports, impulse comparison and catch

- Confirm reaction forces on movable beams, transfer continuity and optional legacy Space profile.
- **Gate:** no hidden positional snaps or new force-budget exploit.

### M5 — Feel comparison and decision

- Run the test matrix and produce short recorded demonstrations with quantitative diagnostic logs.
- Present a recommendation with the observed pros/cons, not only technical test counts.
- **Gate:** keep the independent-aim design only if it improves aiming and preserves satisfying agency.

---

## 14. Agent responsibilities and delivery format

**Main Codex agent:** inspect the actual Godot code before editing; own input profile switching, camera routing, surface targeting, UI/debug, test-scene setup, regression automation and integrated acceptance testing.

**Physics specialist:** design and validate the posture/arm-target planner, force-limited blending, feasible load sharing, swing actuation and dynamic support reactions; assess 60/120 Hz behavior and document solver limitations.

**Handoff rule:** no agent should change shared physics parameters silently. Each milestone produces: the changed files, the reason for the algorithm, a before/after test table, observed failures, solver/tuning changes, and whether the previous profile remains playable.

**Expected deliverables:** one opt-in independent-aim control profile in the existing project, three posture variants selectable for testing, functional static/swing/reactive test scenes, automated verification plus human feel notes, and a concise decision report recommending **keep, revise or reject**.

---

## 15. Design truth to protect

Separating aim from contraction **solves an input conflict, not the entire climbing game**. It trades some direct manual control for clarity. The experiment succeeds only if that trade creates movement the player still feels they deliberately caused.

**Target player fantasy:** *“I choose where and when to grip; my body responds physically to my supports, posture and momentum. I can aim for the next hold freely without undoing the climb I just achieved.”*
