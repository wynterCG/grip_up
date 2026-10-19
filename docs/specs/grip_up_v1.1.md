# GRIP UP — Locomotion Refinement Before M7
## Implementation Specification v1.1 — Physical Agency, Movement Coordination, Feet, Swing, Transitions, Grip Quality & Camera

**Document type:** Technical game-design / engineering experiment specification  
**Language:** English  
**Primary platform:** Windows PC, mouse and keyboard, third-person, 16:9 landscape  
**Engine / backend reported:** Godot 4.7.2, GDScript, integrated Jolt, 120 Hz default physics with 60 Hz comparison  
**Source baseline:** `SISTEMA_IMPLEMENTADO_PRE_M7_PT.md` (2026-10-20), reporting branch `feature/v1.0-contextual-vault` at commit `d4fcaec07e050593236fc5f81ff5ca51f3b0576f`  
**Audience:** Codex main integration agent, physics-specialist agent, animation/camera implementers, designer/playtester  
**Scope:** Optional locomotion refinements **before** v0.7 M7 reactive counterweight challenge  
**Status:** Proposed experiments; not claims of existing implementation or approved improvements.

---

## 1. Executive decision

GRIP UP already has a technically functional, reportedly enjoyable climbing prototype. **Preserve that experience.** This document does not authorize a locomotion rewrite or a blanket increase in assistance. The objective is to discover whether we can improve physical **agency, precision, transition flow, and movement variety** while retaining gravity, inertia, support-dependent motion, deliberate timing, and the ability to fail.

Six candidate improvements will be evaluated separately:

1. **Constraint-Aware Movement Coordinator** — translate the player's movement intent into more useful bounded actuation with the current supports.
2. **Active Foot Contribution** — let the existing optional physical feet contribute to movement and load transfer, without manual four-limb controls or route automation.
3. **Single-Hand Swing Refinement** — make pumping, redirecting, and braking more understandable and repeatable, without airborne propulsion.
4. **Locomotion Transition Polish** — reduce discontinuities among walking, reaching, hanging, transfers, foot support, and hybrid vault/ground return.
5. **Directional Grip Quality** — experimentally make grip load capacity depend on justified contact geometry and direction, rather than on arbitrary colored hold classes.
6. **Contextual Inspection Camera** — improve the visibility of prospective holds and the body without hijacking camera orientation or changing physical intent.

This work must remain **before** M7; do not build the new counterweight game level as part of this milestone. The existing reactive-beam laboratory can be used for force conservation and camera testing.

**Primary acceptance question:** Do players feel more able to execute their intended physical movement, with no loss of challenge or skill expression?

---

## 2. Source-based implementation baseline — verify before editing

The following is **reported as implemented**, not as a new task:

- A **single dynamic `RigidBody3D`** represents the biped's 12 kg body; arms/legs are visually articulated through IK, not a full articulated ragdoll.
- Two independently held LMB/RMB hands select free contact points on eligible actual surfaces; attachment occurs only after finite hand travel and verified contact.
- Grip anchors follow a support's **local material point**, and supports receive physical equal/opposite responses where appropriate.
- Persistent out-of-reach selection and an optional reachable-surface resolver exist; a pending hand contributes zero force until contact.
- Arm springs are **tension-only**, with effective mass and damping; the two hands **share** a 360 N total effort budget.
- The base biped's assisted attitude/swing torque budget is 20 N·m; resultant climbing moment is bounded by 150 N·m.
- Optional feet have physically modeled **compressive/friction** support (180 N total; 120 N per foot), finite placement and local candidate selection, but lack route-level planning.
- Profile 4 is the v0.7 **intent-driven Tier 1** locomotion coordinator; free cursor aiming is independent from arm extension. WASD requests motion relative to actual support geometry while held. The default startup profile remains contextual profile 2, not profile 4.
- A supported-swing implementation exists. P0/P1/P2 and legacy A/B/C arm-target policies remain comparison options; P2 was **not accepted as a general improvement**.
- A static-platform hybrid vault/top-out is functional through an explicitly scoped cinematic/kinematic interval. It is not a fully physical mantle and does not support moving-platform top-outs.
- Scene 21, **The First Ascent**, combines climbing, traverse, suspension and hybrid top-out, and has passed its scripted test course at 60 Hz and 120 Hz.
- A human comparative feel evaluation is **not yet fully closed**, and automated successful traversal is not proof that movement is better for new players.
- v0.7 M7 (reactive beam + counterweight challenge opening a route) has **not** been implemented.

### Baseline tuning values to inspect, not blindly overwrite

| Quantity | Reported value |
|---|---:|
| Body mass | 12 kg |
| Anatomical shoulder-to-palm reach | ~0.65708 m |
| Arm rest-length range | 0.18–0.62 m |
| Hand forces, combined | 360 N |
| Optional feet, combined | 180 N |
| Climbing assistance moment | 20 N·m shared |
| Resultant climbing moment | 150 N·m |
| Intent Tier 1 virtual requested speed | 0.25 m/s |
| Intent ramp | 0.12 s |
| Intent virtual acceleration limit | 1 m/s² |
| Intent planning horizon | 0.18 s |
| Maximum instantaneous target offset | 0.055 m |
| Arm rest-target change rate | 0.24 m/s |
| Rest-target acceleration limit | 0.9 m/s² |
| Foot support sampler cadence | ~0.10 s |
| Walking target speed | 2.6 m/s |
| Current supported swing nominal request | 18 N·m, subject to shared budget |
| Hybrid vault duration | ~1.15 s with authored presentation |

These are **reference reports, not prescriptions for new tuning**. The main agent must inspect the live project, selected profile, tuning resources and runtime overlays first. Record any differences. Never quietly assume old reports override newer code.

### Preservation contract

- Create a reproducible Git checkpoint and record source commit, engine version, relevant flags and hashes of affected scenes/resources.
- Preserve **Janga**, its original `physics_grabber.gd`, existing scenes, profile 2 startup behavior, profile 3 comparison, profile 4 current controls, and the working hybrid vault.
- Feature-flag each new behavior; do not silently replace the existing profile 4.
- Maintain existing player controls: **hold LMB for left-hand grip, hold RMB for right-hand grip, release to detach, mouse pointer for hold selection, MMB orbit, wheel dolly, grounded WASD navigation**.
- While supported in the intent profile, WASD requests climbing displacement. Never re-couple visible mouse position/delta to active arm contraction.
- Keep actual hand capture, load retention, support connectivity, and collision authority unchanged unless a specific test proves a bug.
- No new root-motion climb, body teleport, direct assignment of linear/angular velocity for climbing, invisible jetpack, automatic route planner, or force increase to make a level pass.

---

## 3. Design goals, anti-goals and evidence

### Desired player experience

- The player can predict which way their body will move under a given support configuration.
- A short tap produces a modest, physically plausible adjustment; a sustained request can produce continued supported effort where possible.
- One-hand hanging still feels risky and dynamic; two-hand bracing and real footholds produce recognizable advantages.
- The player can intentionally **accelerate, preserve, redirect, and brake** swings.
- A grip change, grounding change, or top-out handoff does not introduce a surprising jerk or a phantom force.
- Camera framing improves aiming without moving the target or changing the meaning of already held inputs.
- The player can still choose a poor hold, overreach, slip, swing incorrectly, or fail to complete a movement that the available supports cannot physically perform.

### Non-goals

Do **not** add full ragdoll biomechanics, grip/stamina economy, procedural levels, multiplayer, moving-platform mantle, manual independent foot controls, a complete locomotion planner, content production, skill upgrades or new animation styles unless separately approved. **Do not implement a generic physics optimizer for its own sake**: a smaller tested change is preferred over a sophisticated unplayable system.

### Claim levels

1. **Source-confirmed:** fact from the pre-M7 report or verified live code.
2. **Engineering hypothesis:** a proposed mechanism that requires isolated tests.
3. **Observed improvement:** before/after trace and human playtest agree.

Only level 3 justifies promotion to the default gameplay profile. A pass in a headless suite alone does not.

---

## 4. Input and authority contract

### 4.1 Same buttons, stronger meaning

| Situation | Inputs | Required behavior |
|---|---|---|
| Grounded and free | WASD | Existing camera-relative walking and turning; do not regress |
| Grounded, hand is still pending | WASD | Continue grounded locomotion until a **real support** takes load |
| One hand attached | WASD | Request movement relative to that contact; unachievable directions may become swing, limited posture change or no progress |
| Two hands attached | WASD | Request useful body displacement through shared effort and actual geometry |
| Physical foot support present | WASD | May coordinate compressive foot support **only after verified physical planting** |
| Completely airborne | WASD | No new climb-force or ground-force authority; preserve existing legitimate momentum |
| Any climb state | Cursor | Aim/select real candidate surfaces; does not itself drive body movement |
| Hybrid top-out committed | Existing top-out rules | Certified, bounded cinematic traversal owns the body; new optimizers are fully inactive |

### 4.2 Direction reference

Preserve the present `locomotion_support_frame.gd` conventions based on **actual support normals**, tangential wall-up direction, stable lateral direction and material rotation. Locked ongoing input should not reverse due to mid-hold camera orbit. At a convex corner, make any frame transition explicit, gradual where feasible and log frame angular change.

Use a **state-resolved** frame. A free pointer hover over a different wall must not rewrite the frame for an attached character. A pending hand has no load authority.

### 4.3 Ownership / input conflicts

One motor group owns active motion in each phase:

- Ground controller owns ground locomotion when native support is valid and climbing load is absent.
- Supported movement coordinator owns **requests** during climbing; physical actuators still own forces.
- Optional foot solver participates only through real planted supports.
- Supported swing shares the existing 20 N·m assistance budget and cannot add a separate budget.
- Hybrid top-out exclusively owns movement during its committed interval; all normal climbing controllers stand down.
- After restoration, re-enable ground control only on the existing validated support conditions.

No two systems may silently command the same axis with independent full budgets.

---

## 5. Workstream A — Constraint-Aware Movement Coordinator (highest priority)

**Problem:** Tier 1 mostly chooses geometrically desirable small arm-length targets, not which physically achievable supported actuation best advances the requested body motion. In asymmetric positions, useful input may yield mostly twist, saturation or a direction the player did not intend.

**Hypothesis:** A small local support-aware optimization over the existing actuators can increase purposeful response while leaving the real physical solver authoritative.

### 5.1 Required variants

- **A0 BASELINE:** current profile 4 coordinator, unchanged.
- **A1 LOAD / GEOMETRY HEURISTIC:** improve target allocation from real current support vectors, axial capability, load, and arm saturation, without a general optimizer.
- **A2 LOCAL CONSTRAINED SOLVER:** optional experimental improvement if A1 proves insufficient; solves for a small set of actuator target changes under current feasibility limits.

A2 is not automatically better. A1 may win on predictability and development cost.

### 5.2 What the solver may control

The output is a set of **bounded intentions**, not physical state updates:

- Delta/rest target rate for left/right arm (already existing tension-only springs).
- Foot placement/pressure requests **only for truly planted or reachable candidate foot contacts**, if feet enabled.
- A requested supported orientation/swing influence, **inside the already shared torque budget**, where physically justified.

The algorithm must never output a direct body translation, direct rotation, unpaired force, magic velocity, or grip attachment.

### 5.3 Feasibility pre-check

At each relevant physics tick, assemble actual support state:

1. Actual `ATTACHED` grips only (not pending/hovered/slipping beyond their remaining allowed authority).
2. World positions, normals and velocities of material contact points; support dynamic/static flags.
3. Shoulder-to-contact vectors; free/loaded length, tension direction, max spring/actuator authority, remaining force budget.
4. Available feet, contact normal, friction cone and compressive capacity if enabled.
5. Current COM/body velocity, orientation, angular velocity and collision state.
6. Input direction in the stable support frame and whether the request is tangentially feasible.

Classify requested motion as `AVAILABLE`, `PARTIALLY_ACTUATABLE`, `GEOMETRICALLY_BLOCKED`, `SATURATED`, or `NO_SUPPORT`. This classification is advisory; do not claim mathematical proof of reachability from a one-step model.

### 5.4 Local solver proposal

Represent small prospective actuator adjustments as a vector `u`. Derive an approximate, local sensitivity `J` mapping those adjustments to a **short-horizon estimate** of useful supported body velocity and unwanted angular response.

Possible first implementation: a lightweight analytical/contact-geometry heuristic. If justified, estimate sensitivities using finite changes in a **separate prediction model**, never by temporarily mutating the live physics body. Do not claim forward predictions are exact in a contact-rich world.

Example conceptual cost:

```text
minimize_u
    w_move  * || P_useful * (J_linear * u - v_desired) ||^2
  + w_twist * || J_twist * u ||^2
  + w_effort* || u ||^2
  + w_change* || u - u_previous ||^2

subject to:
    arm_target_min <= next_target_lengths <= arm_target_max
    |target_length_rate| <= existing rate cap
    |target_length_accel| <= existing acceleration cap
    predicted tension is non-negative (arms never push)
    grip and shared force/torque allocation limits remain enforced downstream
    no authority is assigned to pending supports
```

`P_useful` projects onto the requested supported tangent direction. `v_desired` is an intention derived from input, **not a velocity imposed on the body**. Choose weights by comparing behavior, not by optimizing only completion time. If the output is inconsistent or infeasible, return to A0/A1, and log why.

### 5.5 Anti-windup and stopping behavior

- Limit target rate and acceleration with the currently configured coordinator (`0.24 m/s`, `0.9 m/s²` as reported), unless separately studied.
- Clamp persistent position error so a blocked W does not store a large future pull.
- Stop accumulating progress when the real body stalls or the arm saturates.
- Neutral input preserves the currently achieved actuator posture; it does **not** freeze physical velocity.
- Do not turn a poor hold into a good one by moving the anchor, silently selecting a different surface, or reducing the load.
- When one hand is attached, a geometry-dependent reduction in available axes is expected. The optimizer must accept non-achievement.

### 5.6 Acceptance tests

- Vertical movement with two high supports: command should produce useful vertical response, not excessive twist.
- Asymmetric left/right supports: A/D should preserve directional semantics when torso/camera rotates.
- One-hand hang: some requested directions remain limited; physically generated swing should remain possible.
- Zero-support request: no climb acceleration.
- Rigid obstruction: no accumulated impulse burst after the obstruction clears.
- Dynamic beam: opposite contact reaction, with identical global effort budget.
- A0/A1/A2 trace comparison on **the same scenes, same input**, and both 60/120 Hz.

**Promotion gate A:** player-perceived response/precision improves without disproportionate loss of swing or increased automatic correction. If it merely makes the avatar more vertically efficient while feeling less physical, **REJECT**.

---

## 6. Workstream B — Active Physical Foot Contribution

**Problem:** The optional feet can physically support load, but placement is local and not sufficiently influenced by intended movement. Visual leg activity can be mistaken for effective weight transfer.

**Hypothesis:** Direction-sensitive local candidate ranking and load coordination will make climbing with footholds noticeably different from hanging, without manual foot micromanagement.

### 6.1 Variants

- **B0:** feet off.
- **B1:** current foot solver and candidate sampler, on.
- **B2:** same physical foot forces, but **intent-aware local selection and support-aware load sharing**, no new muscle budgets.

### 6.2 Candidate selection

Sample only the collision-validated local foothold candidates that current anatomy, geometry and finite planting trajectory make reachable. Keep the existing path/visibility checks and actual contact requirement. Rank candidates using:

- Ability to oppose gravity and favor the *requested* movement direction.
- Expected compressive normal and friction-cone feasibility.
- Short finite travel distance/time of the foot.
- Structural stability and support velocity.
- Separation from existing foot/hand contacts.
- Hysteresis against thrashing between near-equal candidate footholds.
- Known load capacity/material where the physics model provides it.

**Do not** pick a foot destination because it belongs to the designed path or next painted guide. This is local biomechanics, not route-solving AI.

### 6.3 Support and release mechanics

- SEARCHING and PLANTING carry **no load**.
- Once real contact is verified, foot reaction is unilateral compression and tangential force stays within `|Ft| <= mu * Fn`.
- A foot cannot pull upward on a vertical wall or act as a suction cup.
- Respect reported total **180 N foot budget** and **120 N per-foot limit**, in addition to existing **360 N arms**; the total resulting moment still obeys the existing **150 N·m** cap.
- Differentiate independent leg capacity from duplicated arm force; do not secretly raise arm effort.
- On loss of foothold, smoothly remove its authority and preserve dynamics.
- Hand-to-foot / foot-to-hand transition blending should be driven by measured load and real contact, not only state labels.

### 6.4 Tests

Build a small identical wall with paired handholds and optional foot ledges. Compare B0/B1/B2 while repeating the same climb. Monitor foot normal/tangential load, arm tension, COM displacement, shoulder access, slip events, candidate switches and failed plant reasons.

Acceptance is **not** simply a faster ascent. The player should observe a comprehensible advantage to using a good foothold, and an intentional disadvantage when no suitable foothold exists. If B2 reduces challenge too much or moves feet implausibly, leave B1 available and reject B2.

---

## 7. Workstream C — One-Hand Swing & Braking

**Problem:** The system technically distinguishes pumping and braking, but that does not demonstrate player control or intuitive phase response, especially in 3D one-hand suspension.

**Hypothesis:** A clearer mapping from movement intent to **physically supportable pendulum behavior** increases mastery and reduces unexplained oscillation.

### 7.1 Variants

- **C0:** existing `supported_swing.gd`, unchanged.
- **C1:** revised reference-frame, damping and phase readout only; identical nominal torque.
- **C2:** optional support-geometry-aware distribution of requested torque to reduce useless twist while preserving the same shared cap.

Do not implement a phase-locked auto-pumping controller that selects the optimal swing timing for the player. **Timing belongs to the player.**

### 7.2 Force/energy constraints

- Torque must be reacted through actual eligible hand/support mechanisms; when the last real grip is lost, supported swing torque must fall to zero.
- Retain current nominal request (~18 N·m) inside the combined 20 N·m assistance budget; respect total climbing moment.
- Derive an active tangent plane around the real support and COM, accounting for moving supports.
- Separate pendulum swing from trunk axial twist and arbitrary yaw. Do not suppress useful angular momentum just to improve pose cosmetics.
- Record actuator power `P = torque · relative_angular_velocity` as a diagnostic proxy, distinguishing `PUMPING`, `BRAKING`, `NEUTRAL`; this is **not** a complete conservation-of-energy proof.
- Camera orbit mid-held input must not flip the world-space input reference or inject torque.
- Changing direction should not leave a previous filtered request active for a surprising length of time.

### 7.3 Play tests

1. One fixed bar: player increases swing amplitude through deliberate alternation.
2. Same bar: player actively brakes to prepare a catch.
3. Two supports: player intentionally redirects lateral to depth swing.
4. Moving beam: support reacts, player does not gain energy from an unpaired motor.
5. Slip and last-hand release: no lingering midair authority.

Judge phase controllability, repeatability and player interpretation; do not optimize purely for maximum apex height.

---

## 8. Workstream D — Locomotion Transitions & Momentum Continuity

**Problem:** Separately correct controllers can still create visible/control discontinuities when ownership changes. Player comfort depends strongly on these handoffs.

### 8.1 Transitions to audit

- `GROUND → GROUNDED_REACHING`: waiting for a hand must not unexpectedly disable grounded walking.
- `GROUND → HAND_LOADING`: transfer authority according to actual hand load, not merely button-down.
- `TWO_HANDS → ONE_HAND`: preserve surviving anchor, current velocity, and shared budget redistribution; avoid abrupt impulse or arm target reset.
- `ONE_HAND → TWO_HANDS`: finite arrival and graded force blend; no extra strength.
- `FEET + HANDS → NO_FEET`: loss of a planted support should remove compressive reaction smoothly and produce a plausible change of motion.
- `HANG → GROUND`: actual native ground contact before restoring ordinary locomotion authority.
- `DYNAMIC_CLIMB → HYBRID_VAULT → GROUND`: preserve the **existing certified** v1.0 static-only route and its collision/authority gates.
- `AIRBORNE/FALL → GROUND`: avoid duplicate ground and climbing motors on first contact.

### 8.2 Audit technique

For each transition, capture a 0.5 s window before and after the event at the active physics step. Record:

- Individual hand, foot, ground and assistance forces and resulting moments.
- Body linear/angular acceleration and an appropriate jerk proxy (finite-difference acceleration; interpret noisy contact spikes carefully).
- Controller ownership bitset per physics tick.
- Desired versus actual arm target lengths and derivatives.
- Grip states, release cause, native ground status, input state and support velocity.

Look for **unexpected** discontinuities attributable to ownership, old target reuse, stale buffers or contradictory input. Legitimate collision impulses remain allowed; never force all transitions to zero acceleration.

### 8.3 Fix approach

Fix only demonstrated discontinuities. Use load-based crossfades of existing capped authority, safe reset of stale integrators, and support-local velocity references. Keep the current mantle animation/trajectory untouched for this workstream unless a separately isolated bug is confirmed. Do not re-open physical-mantle research in a locomotion-polish milestone.

---

## 9. Workstream E — Directional Grip Quality (optional, game-design sensitive)

**Problem:** Many eligible points on a surface behave similarly even when intuitive load direction and real shape differ. The current `directional_grip_quality` property is reported as an unimplemented research hook, not an approved mechanic.

**Hypothesis:** A *small, readable* directional-strength model creates meaningful grip choice without arbitrary punishment or stamina systems.

### 9.1 First decide the fiction

Is the character using robotic grippers, adhesive pads, magnets, or human-like hands? The chosen attachment fiction determines which physical directions can plausibly hold load. **Do not impose human fingertip rules on a clamp-style robot without explaining the mechanism.**

### 9.2 Minimal controlled experiment

Create only two or three authored contact categories on otherwise comparable surfaces, e.g. well-engaged lip, smooth slab, cylindrical grasp. Each contact's allowable load depends on:

- Validity of the grasp surface/patch and available occlusion-free approach.
- Contact normal and the direction of load relative to the intended grip axis.
- Material/attachment type and a **bounded** directional strength function.
- Existing grip integrity/slip state (do not create a second conflicting slip solver).

A proposed conceptual model:

```text
capacity_directional = base_grip_capacity * strength_factor(normal, grip_axis, load_dir, grip_type)
strength_factor ∈ [configured_min, 1]

existing_grip_load_limit := min(authored_limit, capacity_directional)
```

The above changes **retention capacity**, not the 360 N force budget or available physical reach. If a category reduces strength, the player must receive timely and comprehensible feedback. No hidden sudden break merely for touching a different triangle on the same surface.

### 9.3 Constraints

- No false precision derived from a single mesh triangle normal, especially on beveled/curved geometry. Use stable patch classification or authored data where necessary.
- Changes to a loaded grip must be filtered/conditioned to avoid jitter across patch boundaries.
- Geometry that a mechanical clamp can grip from behind must not be modeled as equivalent to a flat adhesive hand without explicit distinction.
- Keep original grip behavior as a selectable baseline.
- Reject the system if it mostly causes unexplained slipping or forces the player to memorize invisible rules.

### Tests

Two identical routes differing only in surface type; compare hold choice, successful transfer, measured load, failure clarity and player understanding. Do not make it a prerequisite for the movement coordinator or feet workstreams.

---

## 10. Workstream F — Contextual Camera & Visual Legibility (low-risk, optional)

**Problem:** A technically sound climb can feel imprecise if upcoming grips, current body, and movement intention compete for limited screen space.

### 10.1 Variants

- **F0:** current `climbing_camera.gd` follow/orbit/dolly/occlusion.
- **F1:** subtle, capped camera focus offset based on **actual** supported movement direction, with low-pass filtering.
- **F2:** optional distance/framing changes for high swing and traverse, without automatic yaw rotation.

### 10.2 Behavior

| Situation | Small optional camera bias |
|---|---|
| Vertical climb | Show more above while keeping actual hands/body visible |
| Traverse | Look modestly ahead in supported lateral direction |
| One-hand swing | Give room around apex trajectory and the free hand |
| Grounded walk | Keep existing third-person framing |
| Committed vault | Keep existing certified body/camera continuity; avoid cinematic cut |

### 10.3 Safety and input clarity

- Camera movements must not retarget an already selected material point or change actual grip locations.
- Do not auto-orbit while a mouse button is held for a grip or while the player is manually orbiting; if any automatic focus offset remains, limit it and blend out under manual camera input.
- A held WASD intention retains the present stable support-frame rule during camera motion.
- Detect and avoid near-plane clipping/occlusion with existing world collision checks.
- F1/F2 cannot change physics results for identical world/input conditions, except through intentional differences in later player decisions.

### Tests

Timed grip selection, manual orbit frequency, off-screen target incidents, cursor visibility and subjective nausea/disorientation. Reject any camera behavior that makes aiming less predictable, even if screenshots look more cinematic.

---

## 11. Shared test arenas — reuse existing content

Use the existing laboratory before authoring new scenes.

| Scene ID / name | Principal test |
|---|---|
| 0 — Static Climb | Basic force/aim regressions |
| 3 — Foot Support | B0/B1/B2 load transfer |
| 4 — Ten Transfers | Reach precision and consecutive handoffs |
| 5 — Swing-required route | Deliberate swing, braking, catch |
| 6 — The Step | Useful vertical movement with real feet |
| 7 — The Hang | One-hand suspension/oscillation |
| 8 — The Traverse | Asymmetric lateral response |
| 9 — The Corner | Support-frame continuity |
| 10 — The first route | Historical comparison without new mantle |
| 14–15 — Hybrid low/high | Regression only; do not redesign |
| 20 — DOUBLE | Consecutive vault handoff regression |
| 21 — The First Ascent | End-to-end feel and reliability |
| 2 — Reactive Structure | Equal-and-opposite reactions, **not** M7 level completion |

New isolated fixtures are permitted only when existing scene geometry cannot test a claim, e.g. an identical wall with controlled foot ledges, friction patch, or asymmetric suspended grip.

---

## 12. Telemetry and playtest methodology

### 12.1 Technical trace fields

At suitable fixed intervals and on every transition, record:

- Selected profile and flags; physics tick and observed frame timing.
- Movement input and stable support reference frame.
- Requested vs achieved COM/body velocity projected on useful movement axis.
- Body position, tilt, yaw, axial twist, angular velocity, and current ground/support state.
- Both hand states, local anchors, requested/actual lengths, force allocation and slip reasons.
- Physical feet: candidates, state, compression, friction force, support normal and plant/release reason.
- Requested vs applied motor torques, caps, reactions on movable supports, saturation/anti-windup events.
- Camera focus, offset, orbit input ownership and candidate grip screen position.
- Vault ownership/status and restored physical-ground confirmation.

Prefer existing `CaptureTrace` and `TransferDiagnostics` JSONL; add only necessary fields. Be explicit that incremental actuator power estimates are not a full energy-conservation certificate.

### 12.2 Human testing

At least one **designer-led real-input** baseline is mandatory before making changes to the default profile. When practical, recruit 3–5 unfamiliar players and counterbalance the order of A/B variants on the same geometry. Do not claim these samples have occurred unless they really happened.

For each run record:

- Time to first successful grip and time to finish.
- Unexpected releases, failed captures and recovery attempts.
- Number of manual camera corrections.
- Count of intentional versus unintended direction changes.
- Number of supported swing pumps needed for a repeatable catch.
- Amount and purpose of actual foot loading.
- Subjective 1–5 ratings for **precision, comfort, physical readability, agency, sense of weight, flow, and desire to replay**.
- Qualitative notes: *what I tried to do / what the avatar did / why I think it failed*.

Use identical start, collision geometry and force budgets. Compare a workstream **one at a time** to avoid attribution errors. Record settings and run order. Automated full-course success is a technical gate, not a proxy for feel.

### 12.3 Measurement philosophy

Do not establish invented universal thresholds for "good" responsiveness, jerk or efficiency. First capture baseline distributions, then judge whether the tested variants meaningfully improve human performance/comfort while preserving challenging physical behavior.

Where regression tolerances are needed, derive them from existing test tolerances and actual 60/120 Hz numeric variation. Do not claim bit-for-bit deterministic physics between runs.

---

## 13. Integration interfaces and files

Use and inspect the real project before finalizing names/signatures. Likely existing touchpoints from the source report:

| Existing file | Intended integration |
|---|---|
| `features/grip_up/scripts/intent_locomotion_coordinator.gd` | A1/A2 intent-to-actuator policy, feature flags and diagnostics |
| `.../locomotion_support_frame.gd` | Stable real-support direction and corner transitions |
| `.../climbing_controller.gd` | Central force/torque budget, support states, priority and cancellation |
| `.../arm_actuator.gd` | **Preserve** physical spring; modify only if directly required by a proven issue |
| `.../foot_contact_solver.gd` | Foot force limits, contacts and actual load |
| `.../foothold_candidate_sampler.gd` | B2 candidate scoring with hysteresis |
| `.../supported_swing.gd` | C1/C2 support-dependent mapping and diagnostics |
| `.../ground_locomotion.gd` | Transition authority, unchanged walking baseline |
| `.../grip_anchor.gd` | Material-point contact data; no invented anchors |
| `.../grip_capture_evaluator.gd` | Grip retention/feedback experiments only if needed |
| `.../climbing_camera.gd` | F1/F2 framing, user manual-input precedence |
| `.../climbing_input_router.gd` | Existing hold inputs and action mapping preserved |
| `.../hybrid_mantle_controller.gd` | **Regression only**, preserve v1.0 certified static top-out |
| `.../grip_up_lab.gd` | Variant controls, scene routing and recording |
| `.../capture_trace.gd`, `.../transfer_diagnostics.gd` | Event and sample instrumentation |
| `.../resources/*_tuning.gd` | New isolated tuning/configuration; no silent change to reference values |

A new helper is justified only when it enforces a real separation of responsibilities (for example `constraint_aware_allocation.gd` or `foot_candidate_ranker.gd`). Do not over-fragment the project just to fit this suggested list.

### Suggested experimental switches

```text
locomotion_refinement_enabled = false
movement_allocation = BASELINE | GEOMETRY_HEURISTIC | LOCAL_SOLVER
foot_policy = OFF | EXISTING | INTENT_AWARE
swing_policy = BASELINE | FRAME_REFINED | SUPPORT_AWARE
transition_polish_enabled = false
directional_grip_quality_enabled = false
camera_policy = BASELINE | SOFT_CONTEXT | SWING_CONTEXT
```

These are **new proposed options**, not a claim that they currently exist. Never reuse old placeholder flags as evidence that a feature is implemented. Existing profiles/flags continue to work without conversion.

### Recommended ownership

**Main Codex agent:** baseline preservation, input/UI, feature flags, scenes, integration, telemetry, automated regression, playtest protocol, manifests and final KEEP/REVISE/REJECT report.

**Physics specialist:** audit constrained actuation, contact feasibility, torque/force budgets, foot friction cone, pendulum authority, support reaction conservation, saturation, and transitions. Must separately identify approximations and unresolved non-physical behavior.

**Animation/camera work:** visual improvements must remain downstream from simulated movement, except for the already certified short hybrid vault; no IK drive applied to body physics.

---

## 14. Milestones (LP0–LP8) and stop conditions

### LP0 — Baseline freeze and genuine feel session

- Inspect latest working tree and compare with reported pre-M7 source.
- Create source checkpoint and record the current experimental profile settings.
- Run the existing targeted regression suites at 60 and 120 Hz.
- Complete a designer-led baseline of Step, Hang, Traverse, Corner and First Ascent; note precise discomfort points.

**Gate:** a playable, reproducible control baseline plus a prioritized list of observed issues. No rewriting before this gate.

### LP1 — Instrumentation and diagnosis

- Capture useful projected movement, actuator authority, force budget saturation, foot load and transition ownership.
- Add concise on-screen explanation for cases like `NO_SUPPORT`, `AXIS_NOT_ACTUATABLE`, `ARM_SATURATED`, `CONTACT_BLOCKED`, `FOOT_NOT_PLANTED`.
- Separate actionable player errors from limitations of the system or of the greybox.

**Gate:** the team can explain why W or A/D fails to produce expected movement in repeatable fixtures.

### LP2 — Movement Coordinator A1 first

- Implement the smaller geometry/load heuristic on current capped actuators.
- Compare with current Tier 1 using identical fixtures/input.
- Evaluate A2 only if A1 fails to deliver a demonstrable improvement.

**Gate:** human-feel benefit and physical-budget parity. Roll back if movement becomes more automated or less readable.

### LP3 — Active Feet B2

- Keep B0/B1 comparators.
- Add direction-sensitive local candidate scoring and hysteresis while preserving finite planting/contact validation.
- Re-run movement and load-transfer traces.

**Gate:** genuine supported locomotion benefit; no phantom foot forces or route-solving placement.

### LP4 — Single-Hand Swing C1/C2

- Keep C0 and input authority unchanged.
- Focus on swing phase comprehension, action reversals, braking and moving-support reaction.

**Gate:** player can intentionally increase and decrease swing under the same limits; no jetpack-like control.

### LP5 — Transition refinement

- Fix observed ownership discontinuities, stale targets and unnecessary motion loss.
- Regression-test ground, reach, one-to-two, two-to-one, fall and hybrid top-out.

**Gate:** fewer unintended discontinuities without suppressing legitimate collision dynamics.

### LP6 — Optional grip-quality and camera pilots

- Implement E and F independently and **only after earlier systems are accepted**.
- Evaluate whether each adds comprehension or depth instead of hiding poor level design.

**Gate:** no unexplained grip failures; no automatic camera aim conflict.

### LP7 — Controlled human A/B evaluation

- Compare unchanged reference and each retained variant in counterbalanced sessions.
- Include both isolated arenas and complete First Ascent; log time, failures and 1–5 ratings.
- Observe specifically whether skilled players retain the ability to improve through timing, route choice and posture.

**Gate:** documented KEEP/REVISE/REJECT per feature. Do not aggregate a single pass/fail from all changes.

### LP8 — Narrow integration / pre-M7 decision

- Enable only successful changes as an explicit candidate build; leave defaults recoverable.
- Re-run targeted regression, full existing suites, exported Windows startup and actual rendered gameplay.
- Confirm static hybrid mantle unchanged and dynamic support reactions remain correct.
- Obtain designer approval before promotion and before M7 content work.

**Stop and revert** if any variant compromises grip correctness, force/torque budgets, collision authority, camera aim independence, or the current enjoyable control feel.

---

## 15. Adversarial and regression checklist

All variants must pass relevant versions of the following:

- [ ] No contact or force is provided by a pending, unreachable or obstructed hand.
- [ ] Only actual gripped materials can support climbing forces.
- [ ] Shared hand strength stays bounded at 360 N; foot support remains separately capped at 180 N; climbing assistance and resultant moments remain bounded.
- [ ] Force/torque reaction reaches dynamic supports; no unpaired airborne propulsion.
- [ ] One-hand hang remains dynamically possible and not silently upright-locked.
- [ ] A/D semantics survive body rotation and camera orbit mid-input.
- [ ] Neutral input does not freeze velocity or erase pendulum momentum.
- [ ] Blocked motion cannot store a large delayed impulse.
- [ ] No foot support before finite planting + actual contact.
- [ ] Feet never pull a surface; friction respects normal load.
- [ ] Losing one hand does not reset the other hand's attachment target.
- [ ] No duplicated ground/climb motors in transition ticks.
- [ ] Out-of-reach selection and reachable-contact resolver still behave as before.
- [ ] Existing 10-transfer path remains playable, with documented reasons for missed catches.
- [ ] The First Ascent retains real grips, correct region progression and static hybrid top-out with walking on top.
- [ ] Hybrid vault retains its collision checks and refuses dynamic/moving platforms as before.
- [ ] Camera auto-framing cannot retarget grip points or alter support physics.
- [ ] Old startup/controls/profiles remain available until explicit approval.
- [ ] Relevant checks pass at both 60 Hz and 120 Hz, without claims of exact numeric determinism.

When testing scene 2 Reactive Structure, remember: this is the **existing lab**, not proof that the new M7 counterweight level has been implemented.

---

## 16. Acceptance and documentation deliverables

The milestone is not finished merely because an optimizer compiles, a test path succeeds or an avatar moves faster. Deliver:

1. Source revision/branch checkpoint and list of files changed.
2. Exact selected runtime flags and baseline parameters.
3. A table of features, baseline behavior, new behavior, physical changes and failure modes.
4. Baseline and A/B numeric trace summaries with screenshots or live rendered video evidence where possible.
5. Separate results for 60 and 120 Hz, especially support/momentum handoffs.
6. Record of actual human test runs and player-rated precision, comfort, readability, agency, sense of weight, flow, desire to replay.
7. Explicit per-workstream **KEEP / REVISE / REJECT** decision, including why an apparently smoother feature might be rejected.
8. Remaining unresolved issues and how to reproduce them.
9. Confirmation of correct rollback path and no changes to Janga.
10. A concise pre-M7 **GO / NO-GO** recommendation for gameplay, not just code safety.

### Example decision template

```text
Workstream: A — Constraint-Aware Movement Coordinator
Baseline: profile 4 / A0, feet [OFF/ON], other new flags OFF
Variant: A1, same constraints
Physical budgets changed: NO
Automated regression: PASS / FAIL
Observed human benefit: [specific evidence]
Unexpected downsides: [specific evidence]
Decision: KEEP / REVISE / REJECT
Default promotion authorized by designer: YES / NO
```

---

## 17. Final success definition

GRIP UP's distinctive quality should be **physical movement that responds intelligibly to player intent**. The player decides where to grip, when to release, how to transfer support and when to generate momentum; the simulation decides what is feasible. Better planning must produce **more controllable expression of existing physics**, not a character that climbs on the player's behalf.

**Ship the smallest set of changes that genuinely improves the climb.** If the current Tier 1 and existing feet/swing already feel better than the proposed refinements, preserve them and proceed to M7 with confidence.

---

## Appendix A — Suggested short test plan for the designer

**Session 1 — Baseline (no new changes):** play The Step, The Hang, The Traverse, The Corner and The First Ascent. Write three observations: what was intended, what happened, whether the result felt fair.

**Session 2 — Movement A/B:** repeat Step/Traverse/Corner with A0 and A1, feet held to the same setting. Focus on response and unwanted rotation, not just speed.

**Session 3 — Feet A/B/C:** compare B0/B1/B2 on the same geometry with A fixed; note whether leg contacts explain or obscure progress.

**Session 4 — Swing:** compare C0/C1 (optionally C2) with exactly the same grip and level; try both pumping and braking.

**Session 5 — Full course:** replay First Ascent using only accepted changes. Ask: does the climb feel more deliberate, or is the game doing too much?

**Session 6 — Negative testing:** try intentionally poor holds, unfavorable one-hand configurations, missing footholds and a reactive beam to ensure difficulty and physics survive.

Record subjective results honestly. An improvement to numerical movement efficiency that feels worse should not be kept.

## Appendix B — Provenance and open uncertainties

Baseline implementation facts were taken from `SISTEMA_IMPLEMENTADO_PRE_M7_PT.md` (2026-10-20) and prior supplied mantle audit reports. This document does not independently inspect the live Git repository or prove that every report detail remains true after subsequent edits. Codex must verify live modules before implementation.

The following are **proposed, not implemented** as of the supplied baseline: constraint-aware A1/A2 allocation, intent-aware foot candidate scoring, new swing variant C1/C2, systematic transition polish, directional grip quality and contextual camera F1/F2. Similarly, the named LP0–LP8 gates are **this document's** milestones, not the older v0.7 M0–M7 identifiers. The old v0.7 M7 reactive level remains a **separate future gameplay milestone**.
