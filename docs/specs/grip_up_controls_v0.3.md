# GRIP UP — Hold-to-Grip, Arm Drag & 3D Swing
## Input and Locomotion Prototype Specification — v0.3

**Status:** Implementation proposal and experimental specification, not a claim that the new controls already exist
**Primary platform:** Windows PC, landscape 16:9, mouse and keyboard
**Engine / physics:** Godot 4.7.2 + Jolt Physics, targeting the existing 120 Hz physics configuration
**Purpose:** Replace binary W/S arm contraction with expressive mouse-drag control, map WASD to suspended-body swing, and **retain hold-to-grip** for immediate release and recapture. Mouse movement while a grip is held deliberately changes that arm’s length target, including when aiming toward the next hold.

---

## 1. Product decision — no toggle grips

**HOLD-TO-GRIP IS MANDATORY IN THE NEW CONTROL PROFILE.** Toggle grip is not the default and must not be silently substituted. The player must be able to release a hand immediately, without a second click, particularly during a launch, swing, or rapid regrab.

- **LMB held:** left hand tries to reach and remain attached to the selected surface.
- **RMB held:** right hand tries to reach and remain attached to the selected surface.
- **Mouse-up:** immediately ends the hold; release the corresponding grip (or cancel reaching).
- Both hands remain independently controlled. One hand can support the body while the other reaches, releases, or catches.
- A press on a valid surface starts finite-speed reaching; it never teleports the hand or forms an attachment before contact.

Preserve the current working HOLD profile as a baseline throughout experimentation. The existing optional toggle profile may remain internally available for comparison, but must not be selected by this feature.

## 2. Existing working systems — preserve, don't rewrite

The current game already provides: one dynamic body, left/right hand states (`FREE`, `REACHING`, `ATTACHED`, `SLIPPING`, `RELEASED`); accessible point-based gripping; raycast and clearance validation; local-coordinate anchors on dynamic supports; finite-speed reaches; spring-damper arm actuators; shared force/torque budgets; reaction forces on moving supports; twisting assistance; climbing swing; impulse and catch; third-person walking; IK visual arms and legs; a follow/orbit camera; diagnostics; 60/120 Hz test coverage.

**Integration rule:** Implement the new behavior primarily as an input/intent layer that changes arm actuator targets and supported swing effort. Do not directly set rigid-body transforms or inject arbitrary air velocity. Do not alter the established physical force budgets just to make the new input appear effective.

## 3. Player-facing controls

| Input | Grounded | Reaching / attached / suspended |
|---|---|---|
| Move cursor | Aim | Aim at the next grip or a visible target |
| **Hold LMB** | Start left-hand reach when targeting valid surface | Sustain the left grip; release on mouse-up |
| **Hold RMB** | Start right-hand reach when targeting valid surface | Sustain the right grip; release on mouse-up |
| **Drag mouse downward with a held attached hand** | — | Decrease that arm's target length (contract/pull) |
| **Drag mouse upward with a held attached hand** | — | Increase that arm's target length (extend/lower) |
| **Hold LMB + RMB and drag** | — | Drive both attached arms together by default |
| **W / S** | Walk forward / backward | Request forward/back swing effort (camera-depth axis) |
| **A / D** | Strafe left / right | Request left/right swing effort (camera-right axis) |
| **MMB + drag** | Orbit camera | Orbit camera; suspend arm-drag accumulation during camera movement |
| **Mouse wheel** | Dolly camera | Dolly camera |
| **R** | Restart/checkpoint | Restart/checkpoint |
| **Tab** | Diagnostics | Diagnostics |

**Important:** Clicking and dragging one of the mouse buttons is *not* a click-to-toggle action. The held button always represents an active grip request or attached grip, until mouse-up.

### 3.1 Arm selection for drag

- If only LMB is held and the left hand is `ATTACHED` or `SLIPPING`, vertical drag changes the left arm's target length.
- If only RMB is held and the right hand is `ATTACHED` or `SLIPPING`, drag changes the right arm's target length.
- If both buttons are held and both hands are attached, drag changes both target lengths by the same *requested displacement* (each independently clamped to its physical range). Existing effort distribution and total force budget remain in charge.
- If one hand is attached and the other is `REACHING`, the **attached hand continues to respond to vertical mouse drag**. This is intended and physically meaningful: reaching with the second hand may simultaneously change the supporting arm’s extension and the body’s posture. The `REACHING` arm does not respond to length-drag until it attaches.
- Arm-drag is inactive during `FREE`/`REACHING`; it must not accumulate buffered length changes that execute suddenly on attachment.

### 3.2 Intentional coupling: aiming also changes the supporting arm

**This is an intentional control characteristic, not a conflict to suppress.** While the left hand stays attached via held LMB, moving the mouse upward or downward to aim for the right-hand grip also extends or contracts the left arm. That affects the body through the existing physical actuators. The player learns to coordinate support, reach, posture and swing with the same continuous movement.

Expected sequence:

1. Hold LMB over a reachable surface; the left hand reaches and attaches.
2. Move the cursor toward a second surface while **continuing to hold LMB**. Vertical mouse delta updates the attached left arm's target length the entire time.
3. Press and hold RMB over a valid second target. The right hand enters `REACHING`; the left arm **continues responding** to mouse movement.
4. Once the right hand attaches, future vertical motion while both buttons remain held commands **both attached arms**.
5. Release LMB when desired: left grip releases immediately, and continued RMB drag controls only the right arm.

Do not add an automatic aiming freeze, an aiming clutch, an Alt/Shift modifier, or toggle gripping to remove this coupling. The player must remain able to deliberately counteract a change by moving the cursor in the opposite direction. The only exceptions are UI/camera input ownership, window-focus loss and the ordinary rule that an arm in `REACHING` has no arm-length drag target yet.

**Implementation detail:** Never mistake an off-axis move for a pure arm adjustment. Use the raw signed **vertical** pointer delta to update target length; horizontal cursor motion remains available to choose another surface. Aiming and arm-length control are simultaneous, but input must not apply the same delta twice or add an impulse when RMB begins its reach.

**Ergonomics risk to measure:** players may discover that constantly coordinating aim and arm extension is tiring. Record this during playtests, but do not silently simplify the behavior or suppress the coupling. Revisit the rule only after an explicit design decision informed by testing.
---

## 4. Arm-length target mapping

The mouse drives a **target actuator length**, not body translation, velocity, or instantaneous force.

For the requested arm(s), per input update:

```
length_target = clamp(
    length_target + sensitivity_m_per_pixel * mouse_delta_y,
    min_target_length,
    max_target_length
)
```

Positive screen-space `delta_y` means mouse moves downward. Because contraction is expected when dragging down, use a **negative** signed sensitivity in the actual mapping, or implement the equivalent explicit subtraction:

```
length_target = clamp(
    length_target - positive_sensitivity * mouse_delta_y,
    min_target_length,
    max_target_length
)
```

- Mouse **down** → shorter target → greater pull request.
- Mouse **up** → longer target → extension request.
- No mouse motion → hold the last target length; **do not freeze the body**.
- Clamp the rate of change of the target to a configurable *target* speed, not the real body's speed.
- Sensitivity is tunable and should be independent of display resolution or DPI as far as practical (support raw relative pointer movement where feasible).
- Use accumulated motion deltas once per physics step; avoid frame-rate-dependent changes.
- Rebase pointer deltas when switching camera/UI capture, acquiring or losing a hand, or returning from a window-focus change; never rebase the **other already attached arm** in a way that freezes its natural response to subsequent mouse movement.
- No jumps on activation, and no stored drag motion applied after a hand finally attaches.

**Physics remains authoritative:** arm springs, damping, effective mass, shared 360 N total hand-force budget, and existing torque limits determine actual acceleration and motion. The change in target length may demand high effort, but never authorizes unbounded force. A fast drag is a fast *request*, not a teleport or free impulse.

---

## 5. Swing controls: W/S depth, A/D lateral

### 5.1 Intent and reference frame

- While suspended, **W/S requests front/back swing in camera-relative horizontal depth**.
- **A/D requests left/right swing in camera-relative horizontal space**.
- Use camera-forward/right vectors projected onto the horizontal plane, normalized and orthogonalized as needed. Do not use the player's body-local axes (which may rotate unpredictably during swing), and do not assume world Z always matches camera depth.
- When the player starts a movement input, cache that world-space direction for the current held key gesture; don't abruptly change the direction mid-gesture when orbiting the camera. On key release, a new press may use the updated camera frame.
- When grounded with hands free, retain camera-relative WASD walking as implemented.

### 5.2 Force generation — no air thrusters

**Never map WASD to free acceleration of the body's center of mass while suspended.** A suspended-body swing command represents an attempted change in posture, lateral effort, or grip reaction. The applied force/torque must go through an active anchor and respect the current hand and support budget.

Initial implementation candidate:

1. Convert the player input vector into a desired supported swing direction, tangent to the geometry of the current anchor-to-body relationship.
2. Command limited support-relative torque/posture effort through existing arm actuators (with equal/opposite reaction on dynamic supports), rather than applying direct air acceleration.
3. Couple the requested effort to a shared global force/torque limit, with smooth ramp-up/ramp-down and anti-windup.
4. With two anchors, resolve input to a feasible distribution of arm loads without adding new net force capacity.
5. With no active grip/ground support, **no WASD air propulsion**.

This is a **controller hypothesis** requiring physics validation. A fixed-length ideal pendulum cannot be pumped tangentially by an arbitrary radial spring alone. If the present single-rigid-body model cannot produce convincing swing with supported forces/torques, use a deliberately limited **grip reaction torque or posture offset** model, with reaction on any dynamic gripped body. Do not disguise a world-space thruster as physical swing.

### 5.3 Skill and momentum

- A short directional effort should visibly change the body's momentum when physically possible.
- Correctly timed alternating effort can increase swing amplitude; opposite effort can brake it.
- Simply holding W indefinitely must not accelerate the player forever.
- Sudden camera rotation, reaching state changes, and loss of a grip must not create impulses.
- Preserve a way to swing using a single hand without requiring two-handed support.

---

## 6. Grip, reach and catch timing

- On button-down, raycast the candidate grip surface; reject physically unreachable or occluded points with clear feedback.
- `REACHING` moves the hand at finite speed, using current clearance rules and anatomical reach.
- Attach only after physically valid contact. `mouse-up` at any time cancels or releases that hand promptly.
- Preserve the existing 0.65708 m approximately anatomical selectable reach, 0.62 m target limit plus 0.04 m elastic allowance, and current 4 m/s hand reach speed as baseline values unless a measured problem justifies tuning.
- Keep predictive targeting/brief input buffering separate from grip mode. Any short catch window may keep an *attempt* alive while the button remains held; it must not silently maintain a grip after release.
- Preserve velocity/momentum at a successful catch. Force ramp-in can attenuate numerical spikes; it must not zero body velocity or erase impact energy.
- During new grip acquisition, initialize the newly attached arm without queued deltas; preserve the existing attached arm's continuous response to real pointer movement and preserve its support.
- A hand must not reacquire instantly after its button is released; a new press is required.

---

## 7. Existing charged impulse: retain for A/B testing only

The current Space hold/release impulse uses the same arm actuators and is known to work in some postures but not all. **Do not delete it in this control experiment.**

Expose two testing profiles:

- **Control Profile 0 (baseline):** existing hold-to-grip + W/S contraction/extension + A/D lateral effort + Space charge/launch.
- **Control Profile 1 (experimental):** hold-to-grip + mouse drag arm length + WASD supported 3D swing. Leave Space impulse enabled only as an explicit optional comparison setting, not required for normal climbing.

We are testing whether drag contraction plus timed supported swing can create useful launches by itself. Do **not** increase force limits, add a hidden impulse, or change object mass to produce a favorable demo.

---

## 8. Camera and UI interaction

- Preserve the current third-person follow camera, MMB orbit, scroll dolly, collision avoidance and interpolation.
- MMB camera manipulation takes precedence over arm-length drag while held. Neither grip is automatically released by camera orbit.
- When MMB is released, reset drag motion origin; no accumulated hidden mouse movement may suddenly contract an arm.
- The user can point at the next hold while continuing to alter the attached arm’s length, by design; the camera must not orbit unexpectedly.
- UI focus, pause, alt-tab, or window deactivation must clear input state safely and follow the existing grip-release safety behavior.
- Expose a compact debug HUD: left/right grip state, current and target lengths, effective arm forces, swing intent vector, body velocity, camera-frame vectors, input clutch state, and grip acquisition events.

---

## 9. Implementation boundaries

Suggested changes (adapt existing paths and APIs after inspecting the repository):

- `climbing_input_router.gd`: hold-to-grip mapping; raw mouse-delta capture; simultaneous aim-and-arm control; camera priority; gesture rebasing.
- `climbing_controller.gd`: consume continuous per-arm length requests, map suspended WASD to supported swing intent; maintain hand states and shared budgets.
- `arm_actuator.gd`: consume existing target length; **do not** move the physics solver into UI input code.
- `climbing_camera.gd`: publish stable camera frame for suspended input; maintain MMB priority.
- `grip_up_lab.gd` / diagnostics: profile switches, live values, structured test logs.
- Existing physics decision notes: record assumptions, compromise choices, and regressions.

Create a separate feature branch or a checkpointed working state before changes. Do not modify the old Janga grabber. Do not refactor every hand system or visual IK chain in order to ship a control experiment.

---

## 10. Vertical-slice tests

### T1 — One-hand fine control

Hang from one fixed support. While holding LMB, drag slowly down and up. Verify smooth continuous target length changes, body motion generated through physics, no teleports or hand-length snapping. Repeat with RMB. Test releasing during contraction and while moving downward.

### T2 — Two-hand asymmetric positioning

Hold both grips, drag to contract both. Release one button: that hand immediately releases, the remaining hand stays attached without force-budget jumps. Confirm the still-attached arm retains its current target and responds to new drag. Compare different support spacings.

### T3 — Catch and rapid release

From a controlled swing, release one mouse button at a chosen instant, move the cursor to another reachable surface, press and hold that button again, and catch using finite-speed reaching. **No extra click should be necessary to let go.** Count premature captures, misfires, and failures attributable to input timing.

### T4 — Suspended 3D swing

Using one fixed anchor, compare W/S, A/D and combinations. Confirm camera-relative direction, limited physically supported effort, natural pendulum response, ability to increase and brake momentum, and absence of thrust when no hands are attached. Repeat with two anchors.

### T5 — Camera while gripping

Hold one or both grips. Orbit with MMB, release MMB, resume arm drag. Ensure that no spurious length change, support force or swing direction jump occurs. Begin W, rotate camera while still holding W, verify world direction remains stable for that key hold.

### T6 — Reactive beam

Grip a hinged beam and command arm drag and WASD swing. Verify action/reaction forces on the support, no hidden world-space propulsion and no solver explosion when both hands attach to the same moving object.

### T7 — Simultaneous aim and arm movement

With LMB attached, move the cursor vertically toward a new right-hand target, then press and hold RMB. Confirm that the supporting left arm's target length **continues changing throughout** the aim and the right-hand `REACHING` state. Once RMB attaches, confirm that both target lengths respond to future drag. Check there are no jumps, duplicate deltas or changes caused merely by pressing RMB. Measure grip-transfer success, perceived control, physical compensation and ergonomic fatigue during a longer session. Do not freeze the supporting arm to improve scores.

### T8 — Physics rates, long sessions and resets

Repeat core tests at 60 and 120 Hz, in-window and after mouse-cursor boundary encounters, after focus loss and after restarting. Compare observed motion in tolerances (not frame-identical output). Include a 10–15 minute ergonomic session.

---

## 11. Acceptance criteria

- [ ] Toggle grip is not used in experimental profile; mouse-up releases that hand immediately.
- [ ] Hold LMB/RMB continues to support independent grip reach, attachment, release and reacquisition.
- [ ] Vertical mouse drag controls the chosen arm target length continuously, with per-step rate limiting and no jumps.
- [ ] Dragging the pointer downward contracts and dragging upward extends a held, attached arm; releasing the mouse button releases that grip immediately.
- [ ] With both hands held and attached, a shared drag changes both arm targets without doubling effort budget.
- [ ] New grip acquisition does not apply buffered drag to the newly attached arm or duplicate pointer deltas.
- [ ] Aiming with the other hand deliberately continues changing the already attached arm’s length target, including during `REACHING`.
- [ ] This coupling has been playtested for comfort and intentional coordination without an automatic freeze or modifier.
- [ ] Suspended W/S and A/D generate controllable supported swing in camera depth and lateral directions, respectively.
- [ ] Swing input with no contact cannot accelerate the character in midair.
- [ ] Camera orbit does not introduce forces, angular impulses or sudden arm-length changes.
- [ ] Dynamic supports receive reaction forces when the player uses grip/arm/swing effort.
- [ ] Existing input mappings, IK visuals, collision validity, checkpoint/reset, diagnostics and tests remain functional.
- [ ] A/B logs distinguish changes in input ergonomics from unrelated modifications to physical tuning.

---

## 12. Parameters to expose for tuning

| Parameter | Starting policy |
|---|---|
| `arm_drag_sensitivity_m_per_px` | Tune by measured target-length travel per physical mouse movement |
| `arm_target_max_rate_m_s` | New limit, tune without changing actual servo force budget |
| `arm_drag_deadzone_px` | Low value to suppress click jitter only |
| `swing_input_ramp_s` | Start from smooth response; tune to avoid abrupt forces |
| `swing_max_support_torque` | Explicit bounded value within existing global torque allowance |
| `camera_basis_capture` | Freeze basis per held movement gesture |
| `input_profile` | Legacy baseline / experimental hold-drag-swing |

Preserve existing model mass (12 kg), shared maximum grip force (360 N), overall climb torque (150 Nm), existing 20 Nm attitude-assist cap, arm stiffness/damping and anatomically justified reach as comparison baselines unless separately approved to retune.

---

## 13. Milestones and delegation

**M0 — Freeze baseline.** Record existing build, settings, user feel, tests, and a restore point. Verify the hold-to-grip baseline remains unchanged.

**M1 — Mouse arm drag.** Implement single-hand drag, two-hand drag, continuous aim-and-arm coupling, MMB priority, safe pointer rebasing, and coordination/comfort instrumentation. Complete T1, T2, T5, T7.

**M2 — Supported 3D swing.** Implement camera-relative W/S/A/D suspended intention through the arm/grip physics. Complete T4, T6; validate forces at fixed and dynamic anchors.

**M3 — Interaction polish.** Grip reach/catch consistency, release/catch timing, cursor comfort, visual and audio feedback, profile comparison. Complete T3, T8.

**M4 — Feel review.** Compare against the previous W/S actuator control and Space impulse in the same scenes. Choose a default only on the basis of observed reliability, comfort, precision and enjoyment.

**Agent roles:** Physics specialist owns supported swing and actuator/constraint behavior. Main Codex agent owns input routing, camera precedence, mappings, logging, UI and integration tests. Both should inspect the actual project before editing; this document does not assert any method names beyond those supplied by the implementation report.

### Non-goals

No ragdoll conversion, new foot-support system, climbing stamina, procedural level generation, multiplayer or world-design expansion as part of this input experiment. Those are separate research tracks and must not obscure whether the control scheme is better.

---

## 14. Design hypothesis and decision gate

**Hypothesis:** Holding the mouse button to retain each grip, dragging vertically to control arm length and using camera-relative WASD for supported 3D swing yields more precise, expressive and satisfying climbing than discrete W/S contraction — without losing rapid release and recapture.

Do not call the hypothesis validated merely because automated tests pass. It is validated only if players can deliberately (a) reposition with one/two arms, (b) release and catch at speed, (c) create and brake swing, and (d) deliberately coordinate arm-length changes while re-aiming for the next grip.

If the coordination feels uncomfortable, report the problem and the measured evidence rather than silently freezing arm length, adding a modifier or changing to toggle grip. Any alteration to this fundamental control rule requires a new, explicit design decision.
