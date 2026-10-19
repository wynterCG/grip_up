# GRIP UP — Physics-Driven Mantle & Top-Out
## Implementation Specification v0.8 — Palm Support, Adaptive Leg Clearance & Support Handoff

**Status:** Proposed experimental implementation. No new mantle physics is claimed to be implemented by this document.  
**Language:** English  
**Audience:** Main Codex agent, physics-specialist agent, gameplay/feel reviewer  
**Engine:** Current GRIP UP Godot 4.7.2 / GDScript / integrated Jolt Physics project (verify at runtime)  
**Primary target:** Windows PC, third-person, landscape 16:9, mouse and keyboard  
**Baseline:** Playable M5 and attempted M6 from `physics_report.md`; preserve v0.6 / v0.7 control comparisons  
**Working name:** `M6B` or `Mantle v0.8` until accepted  
**Objective:** A physically supported, controllable transition from hanging at a ledge to standing and walking on the platform, without teleporting the player or bypassing contact mechanics.

---

# 1. Executive decision

**Do not spend another iteration only tuning the current ledge pitch motor.** The reported M6 implementation detects real ledges and requests a limited inward/pitch intent, but it fails to perform a functional mantle. Its failure is not evidence that the force budget should simply be raised.

Introduce, test and integrate two missing physical capabilities:

1. **Load-bearing palm contact:** hands can support the body through physically valid **compression** against an upper ledge surface, not just traction along an attached grip.
2. **Anatomically plausible, collision-valid leg retraction:** lower-body collision geometry can accommodate a crouched/raised-leg pose during the transition, then safely return to standing geometry.

Then introduce a **support handoff coordinator** that redistributes effort across real hands, palms, feet and eventually the ground motor.

**Central design requirement:** The player initiates and maintains mantle intent, but the physical body must earn height and clearance through existing or newly justified contacts and finite actuators. The result is not an animated vault or a predetermined position curve.

---

# 2. Source baseline: what M6 actually proved

The following are observations from the supplied M6 physics report, **not design proposals**.

## 2.1 Existing system

- One dynamic `RigidBody3D` represents the biped torso/body, currently reported at **12 kg**.
- Existing shoulder-to-grip arm actuators produce **traction only**; physical feet are optional, limited compression contacts.
- Existing support interactions use finite force/torque and equal-and-opposite reaction on dynamic supports.
- Existing candidate code: `features/grip_up/scripts/ledge_transfer.gd`.
- `climbing_controller.gd` exposes `intent_auto_mantle_enabled = false`; present M6 operates only with the relevant intent locomotion profile and flag.
- The M6 coordinator adds an inward component to positive W and a limited pitch/attitude command. It does **not** generate palm contact, retract physical leg collision volumes or create a complete path to standing.
- M6 uses real ledge geometry, current contact eligibility and destination-shape queries, and does not move the body by direct transforms.

## 2.2 Reported conserved limits

| Quantity | Reported M6 value | Requirement for v0.8 |
|---|---:|---|
| Character mass | 12 kg | Preserve initially |
| Shared hand effort | **360 N total** | All traction **and** compression from hands share it |
| Optional foot effort | **180 N total** | Preserve separately, no invisible additional feet |
| Resultant climbing torque limit | **150 N·m** | Include all actual modeled limb/attitude effects |
| Shared attitude/swing assistance | **20 N·m** | No new independent torque budget |
| Existing M6 requested pitch torque | 8 N·m | Keep as historical comparison, not baseline for palm force |
| Arm spring | K 6000 N/m, D 220 N·s/m | Preserve traction implementation unless evidence requires change |
| Anatomical reach | approximately 0.65708 m | Do not enlarge |
| Arm target length | 0.18–0.62 m | Preserve initially |
| Elastic allowance | 0.04 m | Preserve initially |
| Hand reach speed | 4 m/s | Do not teleport on palm transfer |
| Target-length planning | 0.24 m/s and 0.9 m/s² | Preserve the existing path where applicable |
| Physics rates | 120 Hz primary, 60 Hz comparative | Test both |

The numbers must be **re-read from the checked-out code before implementation**. Record differences rather than silently assuming this report reflects a later checkout.

## 2.3 Functional failure measurements

The report recorded **45/45 safety/geometry checks at each physics frequency**, but *no successful top contact, no completed hands-free standing, and no 30 cm walk*.

Representative 120 Hz measurements:

- 1.25 m top: maximum body-origin height 1.1674 m with hands only, unchanged by the M6 candidate; 1.2030 m with optional feet.
- 2.10 m top: maximum body-origin height 1.3561 m hands only and 1.4797 m with feet.
- For standing on a 2.10 m platform, the reported fixed standing sole location implies body origin approximately 3.017 m. This is a **standing requirement**, not a target for the pelvis at every intermediate crouching state.

The report **does not prove all mantle strategies are physically impossible**. It proves this candidate, with the tested geometry, controls and existing traction/collider constraints, cannot complete the ordinary top-out.

---

# 3. Out of scope and invariants

## 3.1 Non-negotiable physical invariants

1. No writing the character body's transform, global position, orientation or velocity to achieve a mantle.
2. No hidden, unconstrained upward or inward force on the body center of mass.
3. No extra force when toggling a candidate flag; all palm force shares the existing hand budget.
4. No independent extra attitude motor outside the existing shared torque budgets.
5. No instant conversion of an edge/front-face grip into a top-surface palm contact.
6. No collision disabled merely because the character is within a mantle zone; no passing through the platform lip.
7. No animation root motion as physics authority. IK must follow actual, attainable physical supports.
8. No hidden automatic regrip across unrelated surfaces; any local top transfer must be physically reached and specifically authorized.
9. No claim of success based only on a discovered ledge, a clear destination, increased body height, or an intermediate phase name.
10. Moving platforms must receive matching force and torque reactions and can fail to support the player's weight.
11. Never change existing climbing behavior when the mantle experiment is off.

## 3.2 Not required for v0.8

- Full skeletal ragdoll / articulated elbows, knees and fingers.
- General IK-based animation solution for arbitrary humanoid locomotion.
- Stamina, inventory, rope systems, multiplayer, character upgrades, or level campaign.
- Automatic planning of a climb to any ledge.
- A perfectly realistic muscle and finger-pressure simulation.
- Mantle support for every ledge orientation, overhang, material, moving assembly and unusually narrow top.

The initial target is a **plain, wide, horizontal ledge with a clear platform beyond it**, followed by adversarial geometry and moving supports.

---

# 4. Player experience and control contract

## 4.1 Desired feel

The player should experience one continuous action:

**Hang → pull up → set the palms → press the body over the edge → bring a foot up → rise → stand → release hands → walk.**

These labels describe phases of effort and contact, **not authored animations**. A valid failure or recovery must remain possible at any stage.

### Existing inputs to preserve

- **LMB held:** left hand targeting/gripping.
- **RMB held:** right hand targeting/gripping.
- **Mouse-up:** releases/cancels the respective hand immediately.
- **Mouse pointer:** selects surfaces; must not secretly set body position or arm length in the independent-aim profile.
- **WASD:** body-movement intent through the existing intent-locomotion profile, grounded walking on valid ground, supported physical effort while climbing.
- **MMB drag / scroll:** camera orbit/dolly.

### Mantle activation

When a real ledge candidate and enough actual support exist, **positive W** may request a mantle-compatible movement intention. No new mandatory mantle key in the first experiment.

W must not complete the maneuver automatically. Releasing W must stop *new* mantle commands after bounded actuator slew; the character may still move under gravity and momentum. Keeping W pressed against impossible geometry must neither create infinite force nor progress a scripted phase.

## 4.2 Local hand transfer: two candidates to compare

The current M6 code does not automatically change grip points, and the new system must not silently bypass that rule. Test these behind separate flags:

**Variant H0 — Explicit release and regrip (baseline):** To put a palm onto the upper surface, the player releases that hand, points to the top and holds the button again, while another hand or foot safely supports the body. This is completely compatible with existing hold-to-grip and early targeting. It is harder, but causally clear.

**Variant H1 — Assisted local palm roll (experimental):** While the player keeps that hand button held and presses W at a verified ledge, allow a **small local contact relocation** from lip/front edge to a nearby valid top palm position. The hand must travel continuously at finite speed along a collision-checked path, remain anatomically reachable, and only develop compressive force after verified contact. If the path is blocked or another support cannot preserve the load during transition, remain in edge-grip state or release according to normal physical rules. No grabbing the underside and teleporting the hand through the top.

Do not promote H1 by default merely because a script can complete the fixture. Test whether it feels more intuitive than H0 and whether its assistance remains visible, learnable and bounded.

## 4.3 Control ownership and interruption

- Mantle coordination acts only on the limbs genuinely supporting the player.
- An off-range **PENDING** hand has zero support authority.
- Grip release, lost support, blocked palm travel, window focus loss, reset and invalid collider must cancel relevant pending commands safely.
- Other locomotion modes must not fight the mantle controller: use one explicit mode arbitration and a shared actuator allocator.
- Player may abort or fall; a false-positive mantle detector must not trap input or cancel normal climbing.

---

# 5. Functional state model

Use a **small observable state machine**, whose transitions require measured physical evidence. Avoid scripted timers that advance without corresponding contact and motion.

| State | Required evidence | Authorized intent | Exit conditions |
|---|---|---|---|
| `NONE` | No applicable ledge | Current climbing/ground system | Real candidate + supported W |
| `LEDGE_CANDIDATE` | Valid top and obstacle checks | Informative only | User requests mantle, geometry changes, or support lost |
| `EDGE_PULL` | Real attached hand(s) / feet; W | Existing traction, supported posture | Shoulders/hand geometry allows palm reposition |
| `PALM_TRANSFER` | A transferable hand and support path | Finite hand relocation; no phantom support | Actual palm contact or abort |
| `PALM_SUPPORT` | Real top-surface contact and load-bearing viability | Finite compressive press effort and attitude | Actual body clearance / foot opportunity |
| `TORSO_OVER_EDGE` | Measured body geometry has passed lip without overlap | Continued palm / other support effort | Real top foot contact or loss of support |
| `FOOT_TRANSFER` | Physically reachable top foot candidate | Finite foot plant and unilateral compression | Foot accepts load; recovery on miss |
| `STAND_RECOVERY` | Valid upper-ground contact, body able to right itself | Bounded support handoff | Hands released, stable upright on top |
| `COMPLETE` | On-top ground support + hands free + stable + meaningful movement | Ordinary ground locomotion | Exit encounter |
| `ABORTED` | Player abort, invalid candidate or unrecoverable loss | Normal fall/recovery handling | Valid new attempt |

These need not map one-to-one to new classes. Preserve the existing hand states (`FREE`, `REACHING`, `ATTACHED`, `SLIPPING`, etc.); the mantle controller should track *contact mode* and *maneuver phase* orthogonally.

### Hysteresis and state guards

- Short support-contact dropouts must not repeatedly switch phases.
- Use geometric and time hysteresis only to stabilize recognition, never to confer an unearned physical contact.
- When an arm loses load during hand reposition, the other real supports must carry the load or the body falls.
- After a failed attempt, return cleanly to regular climbing without freezing orientation or corrupting pending targets.

---

# 6. Palm support: the new physical capability

## 6.1 Mechanically distinct contact modes

Model each hand as one of:

- `GRIP_TRACTION`: existing captured surface point; axial pulling and limited modeled grip torque.
- `REPOSITIONING`: moving hand with **no force from that hand** until valid contact; any still-attached hand on the other side remains active.
- `PALM_CONTACT`: current surface contact on the top of a ledge, with possible compression and tangential friction.
- `PALM_SLIPPING`: overloaded palm contact losing load-bearing capacity.
- `FREE`: no force authority.

One hand must not be counted as two independent contacts merely because its old edge-grip anchor and new palm point coexist in an internal transition. Total force and torque budgets must be enforced centrally.

## 6.2 Eligibility of a compressive palm contact

Require all of:

1. A real raycast/shape sweep hits a valid upper surface belonging to an approved support object.
2. Surface normal sufficiently upward for the first scenario (initial candidate `n·UP >= 0.85`, configurable; verify against existing geometry rules).
3. Palm point within physical shoulder/hand reach and a valid hand travel path.
4. The palm's estimated contacting surface/footprint fits on the top without extending across the lip or into a wall. A single infinitesimal raycast point is **not sufficient** to represent a palm.
5. Current collision-free placement or permissible shallow contact tolerance; no deep penetration.
6. A valid reaction-capable support (static geometry or dynamic rigid body), not a ghost target or cosmetic mesh.
7. No other incompatible contact state is claiming the same hand's force allocation.

Store the palm anchor in **support-local coordinates**, so it follows a moving/rotating platform exactly as the existing grip anchors do.

## 6.3 Directional compression and friction

Given contact normal `n`, define a compressive force request `F_palm = N*n + T`, where:

- `N >= 0` is the normal reaction received by the player.
- `T·n = 0` is the tangential reaction needed for stabilization or forward travel.
- `|T| <= μ*N` (plus any separately specified tangential hand capacity).
- `N`, `T`, and the total wrench remain within the shared hand and climbing force/torque budgets.

**Do not directly apply an arbitrary upward force to the center of mass.** Forces transmitted through the virtual arm must be applied at a physically defensible body interface (normally the shoulder), with the opposite reaction at the palm point on the support. To preserve the intended internal wrench, account for the moment induced by any separation or non-axial force; use explicit bounded joint/gripper torques or a force-line model that supplies equal-and-opposite physically justified reactions. Log the effective body/support wrench pair. The existing arm is effectively a tension cable; a compression-capable virtual arm is a *new* model and requires its own validation.

For a purely axial compression link between palm and shoulder, the body can only be pushed **away from the palm** along that line. That geometry may not by itself lift a shoulder still below the ledge. Any non-axial ability to lever over the lip must have a documented source of limited joint/grip moment or extra genuine contact. Do not presume that enabling compression automatically solves the mantle.

## 6.4 Contact solver recommendation

Implement a **complementarity-inspired unilateral contact servo** (or equivalent bounded controller) that requests compression only when the actual surface contact is established and the desired press direction is valid:

```text
contact_valid = shape_contact_confirmed && hand_reach_valid && path_valid
normal_effort = contact_valid ? max(0, desired_press_response) : 0
normal_effort = clamp(normal_effort, 0, allocated_normal_budget)
tangent_effort = project_to_tangent(desired_motion_effort, surface_normal)
tangent_effort = clamp_length(tangent_effort, friction_coeff * normal_effort)
F_palm = normal_effort * surface_normal + tangent_effort
```

This is **conceptual**, not final Godot code. Account for relative support velocity, spring damping, effective mass, solver timestep, finite gripping-arm geometry and anti-windup. Prevent oscillating injection of energy when contact is briefly lost.

The new palm solver must not override or bypass the Jolt collision response. Avoid double-counting the normal reaction from standard rigid collision if a physical palm collider is also present. Choose one validated architecture:

- **P-A — Virtual palm support:** an independently validated finite-area contact sample + bounded explicit force pair, with clear limits and no physical hand collision body.
- **P-B — Physical proxy palm:** a small collision proxy/joint with native solver contact and bounded actuator control, if tests show the increased complexity is justified.

Start with P-A for the isolated experiment; do not pre-commit to P-B.

## 6.5 Shared force and torque accounting

For each physics tick:

1. Gather real attachment/support states.
2. Compute desired traction/compression and posture efforts.
3. Allocate **one shared 360 N hand force budget** to both hands and both force types; do not double it when switching modes.
4. Allocate torque under the existing 20 N·m shared assistance and 150 N·m resultant climbing limits, without counting any contribution twice.
5. Apply forces and corresponding reactions at correct world-space points to the actual bodies.
6. Record requested, admitted, saturated and applied forces/torques.

A palm cannot sustain the body without contact, and it must release/slip if the load exceeds its allowed capability.

---

# 7. Adaptive lower-body collision: solve actual clearance

## 7.1 Why visual IK cannot fix M6

The reported biped has fixed rigid-body collision proxies (torso, head, lower legs and sole). The visual knees can fold while the physical shapes stay extended. This makes the lip collision act like a rigid straight leg even when the animation appears crouched.

### Requirement

Change collision geometry only in a way that represents an actually attained and physically supported leg posture. Do not turn off the legs, mask out the platform or shrink all lower-body collision to nothing.

## 7.2 Recommended staged approach

### C0 — Geometry audit and swept-pose feasibility (first)

Before modifying production colliders, build a test harness that samples **candidate crouched shape configurations** across a range of leg flexion values. For each:

- Check body torso, head, lower-body and sole shape clearance against the lip/top.
- Verify no existing penetrations; perform conservative intermediate shape/pose sweeps.
- Render both physical shapes and visual IK skeleton.
- Record the minimum clearance and where the rigid proxies obstruct passage.

**C0 is diagnostic.** Passing a shape fit at the final destination does not validate a continuous path.

### C1 — Articulated collision proxies within one body (preferred experiment)

Keep the main `RigidBody3D` and torso/head dynamics. Create a small set of lower-body collision proxies (e.g., thigh/knee and shin/foot regions) whose *local positions/orientations or validated shape dimensions* reflect a limited crouched pose.

Constraints:

- Do not animate the rigid body itself by editing its transform.
- Do not rely on non-uniformly scaling collision nodes at runtime.
- Apply shape updates at controlled physics synchronization points using engine-supported APIs; avoid editing shapes during unsafe physics callbacks.
- On each requested change, check collision clearance for the **whole interpolated shape path**, not just the final pose.
- If an intermediate shape would penetrate the lip or floor, stop flexion at the last valid configuration; do not tunnel.
- Avoid sudden shape-volume changes that eject the rigid body or create artificial momentum. Inspect contact impulses during transitions.
- Do not let a foot-support force remain active at a contact that has moved or disappeared because its proxy was repositioned.
- Maintain a sensible inertial approximation; record that a single-body proxy does not capture independently moving limb mass/inertia.
- Keep the capsule/sole standing configuration available and reversible.

A physical crouch must correspond to a visible crouch, but a **visual crouch alone does not authorize collider retraction**.

### C2 — Articulated rigid limbs (fallback, not v0.8 default)

If a single-body adaptive collider cannot safely pass through realistic ledges while keeping stable contact and acceptable feel, evaluate an articulated lower-body solution with limited rigid segments and joints. Produce a feasibility study before committing to this substantially larger architecture change.

## 7.3 Retraction policy and input

- When a valid ledge/mantle intention exists and the body is actually approaching the lip, request a **limited knee/leg fold**.
- Folding rate and extent must respect declared anatomical constraints and physics contact clearance.
- If the lower legs are load-bearing on an existing foothold, do not retract that support out from under the player without a verified support-transfer step.
- As the torso moves above the top and feet become placeable, extend the lower collision proxies progressively toward standing geometry.
- An abrupt abort or fall must use a safe return path; no instantaneous collider pop back through a wall.

## 7.4 Collider-vs-pose validation

Record per-frame:

- `desired_leg_flex`, `actual_leg_flex`, and denied/blocked flexion.
- Contacts on torso, head, thigh/shin proxies and sole.
- Minimum penetration/separation and collision impulse spikes.
- Visual-to-physical foot location mismatch.
- Actual top surface clearance under the body.

Make it possible to display collision shapes and skeletal legs together in the developer HUD.

---

# 8. Load transfer and supported rising

## 8.1 Supported contact graph

Use verified load-bearing supports:

- Existing edge/traction hands.
- Compression-capable palms.
- Current physical feet, if genuinely planted.
- Ordinary ground contact only once the body actually settles on an appropriate top surface.

**PENDING**, visually near, or geometrically planned contacts have no force authority.

## 8.2 Distribution policy

The coordinator may reallocate effort as contacts change, but must never create support ex nihilo.

Suggested sequence:

1. Traction hands move the body toward the edge.
2. At least one stable real support keeps the body suspended while one hand reaches a top contact.
3. Top palm accepts compressive load with finite acquisition.
4. The opposing hand can transfer when support geometry and player input permit.
5. Palm press and valid other contact(s) raise/rotate the torso through the lip.
6. The lower collision shape folds enough to clear the edge, without disappearing.
7. The first upper foot approaches and plants on actual walkable top geometry.
8. Once the foot can support load, reduce palm effort progressively as appropriate.
9. The body righting/ground motor may take over **only when genuine ground-support conditions are met**.
10. Hands remain under player hold-to-grip authority; completion requires their actual release and independent standing/walking.

### No invisible stance

Do not call the movement system `GROUNDED` merely because a destination query predicts a valid upright pose or a foot visual reaches the platform. The actual ground probe/contact must be true.

## 8.3 Ground-motor arbitration

The old ground motor and foot/palm actuators must not simultaneously inject duplicate support forces.

- Decide authority by actual load-bearing contact and state.
- During partial mantle, prefer the currently valid palm/foot system.
- Blend in the existing ground upright/locomotion controller only when a stable upper walkable support is confirmed.
- When hands are released before stable upper contact, allow a fall or recovery.
- If the floor motor activates and begins to propel a mid-air body, fail the physics test.

---

# 9. Ledge detection and geometry planning

Reuse M6 `ledge_transfer.gd` where it is demonstrably correct. Do not discard prior checks or pretend they validate a trajectory.

## 9.1 Existing candidate conditions

The report uses:

- Valid ledge top normal approximately `dot(UP) >= 0.85`.
- Same support object as the acquired hand contact.
- A nearby upper raycast (reported offsets: 8 cm inward, 28 cm up / 12 cm down).
- Additional surface sample 35 cm inside, top-height agreement within 2.5 cm.
- Approximate upright destination 45 cm inward and 93 cm above top.
- Real held hand(s) or hand + loaded foot, positive W.

Treat all values as tunable after code inspection. Preserve the thin-platform and destination-blocked rejections.

## 9.2 Required new checks

A candidate should now expose separately:

- Real **top palm landing region**, finite area and stable surface normal.
- Clear and reachable **hand transfer route** from the current anchor.
- Dynamic support point tracking in local coordinates.
- Player-body/lip collision clearance along plausible movement stages, including crouched shape candidates.
- Potential upper-foot landing region with size, traction and reach limits.
- Walkable space after landing, sufficient for an upright pose and some forward movement.

Output each result as `PASS / FAIL / UNKNOWN`, not one vague `destination_clear` boolean.

### Explicit uncertainty

A collision-free endpoint **does not prove** the whole trajectory is clear. When continuous path feasibility is unknown, the engine must preserve ordinary collision authority and report `PATH_NOT_CERTIFIED`. The system can attempt a physically valid movement, but cannot mark success prematurely.

---

# 10. Physics API / integration plan

Current files (confirm paths in repo):

- `features/grip_up/scripts/ledge_transfer.gd`
- `features/grip_up/scripts/climbing_controller.gd`
- `features/grip_up/scripts/intent_locomotion_coordinator.gd`
- `features/grip_up/scripts/arm_actuator.gd`
- `features/grip_up/scripts/grip_anchor.gd`
- `features/grip_up/scripts/foot_contact_solver.gd`
- `features/grip_up/scripts/foothold_candidate_sampler.gd`
- `features/grip_up/scripts/biped_visual.gd`
- `features/grip_up/scripts/ground_locomotion.gd`
- Existing M6 test harness in `features/grip_up/tests/test_intent_mantle.gd`

Proposed modules (create only as justified):

```text
features/grip_up/scripts/
  mantle_contact_modes.gd            # Per-hand edge / moving / palm state
  palm_support_solver.gd             # Bounded unilateral palm force & contact validity
  mantle_support_coordinator.gd      # Real-load transfer and phase guard orchestration
  adaptive_leg_collision.gd          # Validated lower-collider pose requests
  mantle_path_probe.gd               # Real intermediate contact and clearance probes

features/grip_up/tests/
  test_palm_compression.gd
  test_mantle_leg_clearance.gd
  test_mantle_support_handoff.gd
  test_mantle_full_sequence.gd
  test_mantle_adversarial.gd
```

Keep the architecture small. A separate script is useful only if it owns a distinct testable responsibility.

## 10.1 Engine safety notes

- Confirm the actual Godot/Jolt version and available contact/sweep APIs before choosing exact implementation methods.
- For body force calls, verify **whether the API expects a world-space offset from the body origin or an absolute point**, and consistently compute it rather than silently passing a global contact position.
- Collision shape transforms/dimensions must be updated safely relative to the physics server, with explicit broadphase refresh and overlap tests where necessary.
- Do not assume contacts from shape-query results are identical to native solved contact impulses.
- Native rigid-body contact response and explicit virtual limb forces must not be double-counted.
- Keep deterministic assertions limited to invariants and tolerances; 60/120 Hz can produce slightly different trajectories.

## 10.2 Suggested public interface

```text
MantleCandidate evaluate_ledge(body_state, supports, world)
MantleIntent make_mantle_intent(player_input, candidate, actual_contacts)
PalmContactResult try_transition_hand_to_palm(hand, candidate, dt)
PalmWrench solve_palm_support(hand, current_contact, intent, allocation, dt)
LegClearanceResult request_leg_flex(body, desired_flex, current_contacts, dt)
SupportPlan distribute_support_load(actual_contacts, intent, force_budgets, dt)
MantleStatus evaluate_completion(actual_ground, actual_body, hands, walk_progress)
```

These signatures are conceptual contracts, not instructions to create unrelated abstractions or bypass the existing climbing controller.

---

# 11. Milestones and hard gates

**Every milestone must have an opt-in flag, independent scene, 120/60 Hz runs, and a visible measured acceptance result.** The next milestone may not be marked successful just because a previous one passed.

## M0 — Snapshot and physical diagnosis

- Inspect working tree and verify baseline M5/M6 behavior and exact tuning parameters.
- Create a safe commit/branch/snapshot; keep the existing playable control profile and Janga unchanged.
- Capture current 1.25 m and 2.10 m failures with force/contact, collision and body-path overlays.
- Confirm which surfaces and colliders cause the block and which limbs would physically need new contact modes.

**Gate:** Reproducible failure, attributable to traction-only support and/or rigid lower-body clearance; no baseline regression.

## M1 — Palm compression in isolation

Test a body near a **wide fixed horizontal support** with one already valid palm contact. A fixture may initialize a physically non-overlapping test posture, but **must not teleport the body during the simulation** or count setup positioning as successful movement.

- Implement finite, unilateral compressive palm force, tangential limitation and wrench reaction.
- Test a palm loading/unloading, slipping, pushing and losing surface contact.
- Compare force accumulation with an existing traction hand; budget remains 360 N total.
- Test static and free dynamic platform cases.

**Gate:** Palm compression can contribute genuine body lift in a mechanically favorable posture, within force limits, while invalid/unloaded palms contribute zero and the support receives proper reaction. If not, stop and revise the arm/palm mechanical model.

## M2 — Lower-body collision flexibility in isolation

- Build C0 clearance visualizer and swept checks.
- Implement C1 cautiously: bent and extended lower-body proxy configurations that remain collision-valid.
- Run fold/unfold tests adjacent to fixed ledges and on top of a platform.
- Detect and stop blocked transitions; verify stable standing collider after restoration.

**Gate:** A crouched physical configuration can gain real clearance without disabling the entire leg/sole collision, tunneling through the lip, or injecting large uncommanded impulse. If impossible with one-body proxies, present C2 feasibility instead of faking success.

## M3 — Local edge-to-palm transfer

- Implement H0 manual regrip first.
- Preserve second hand/foot support, including dynamic reaction while the first hand repositions.
- Test H1 assisted palm roll only as a separate optional input variant.
- Require finite, visible hand path and real contact; preserve button hold semantics.

**Gate:** Player can move at least one hand from an actual edge/front contact to a valid upper palm contact and have it support real load, with no instant attachment or duplicate force authority.

## M4 — Full physics-supported top-out on a static platform

- Integrate traction, palm compression, collision flexion and load handoff.
- Verify actual torso clearance, upper-foot landing, recovery to standing geometry, release of both hands and walkability.
- Run the 1.25 m platform first, then 2.10 m. Treat each as a separate goal, not interchangeable fixtures.
- If a single posture cannot produce enough leverage, classify the missing mechanical capability and revise carefully; do not push the body with a hidden force.

**Gate:** **From a valid hanging start**, complete the full sequence **hands-free and stable on top**, then move the character at least 0.30 m under normal ground locomotion. All support contacts must be real, no penetration. No phase may be counted as completion based only on proximity.

## M5 — Dynamic platforms and adverse geometry

- Repeat on a moving/rotating ledge. The palm anchor must follow the same material point and transmit reactions.
- Thin top, obstructed upper volume, unreachable top hand point, insufficient foot area, slipping palm, support disappearance, aborted/early release, single hand and tilted platform cases.
- Validate recovery and failure behavior as seriously as successful ascent.

**Gate:** Static success does not regress; moving supports respond physically; impossible or blocked mantles fail cleanly without fake contact.

## M6 — Human playtest and keep/revise/reject

- Several attempts from an ordinary approach, not only prepositioned fixtures.
- Compare H0/H1, palm support on/off, collision adaptation on/off where safe.
- Observe whether players know when to pull, push, shift their weight and release hands.
- Collect time to first top-out, success rate, number of stuck states, false-positive completion, camera/input burden, feel and recovery.

**Gate:** Mantle is *reliably controllable* by a human, not merely possible in an automation. Keep as opt-in if comfortable control remains unproven.

---

# 12. Formal test matrix

| ID | Scene or condition | Expected result |
|---|---|---|
| P01 | Palm on level static top, valid load | Bounded compression produces physical reaction/lift where geometry allows |
| P02 | Palm suspended above top, no contact | **Zero** palm reaction and zero support |
| P03 | Palm tries to pull away through top | No adhesive suction in compression mode |
| P04 | Hand with traction then palm transition | Never duplicated hand force or stale contact |
| P05 | Both palms active | Sum of hand forces remains within existing 360 N budget |
| P06 | Palm on free dynamic block | Equal/opposite reaction and physically evolving platform motion |
| P07 | Palm near platform corner | Reject insufficient palm footprint |
| P08 | Palm reaches blocked top path | No teleport/penetration; hand remains unsupported or aborts |
| P09 | Palm under overload | Slips/releases using declared integrity rules |
| C01 | Standing → crouched proxy near clear space | Smooth safe shape change; body stays dynamic |
| C02 | Lower leg meets ledge during fold | Flexion stops; shape does not tunnel through lip |
| C03 | Crouched → standing under ceiling | Denied until shape can expand collision-free |
| C04 | Foot carrying load during retraction | Contact transferred or retraction blocked, not deleted silently |
| C05 | Moving support collision during flex | Shape query and real contacts remain valid |
| T01 | Hang at 1.25 m ledge | Full top-out, real upper-ground support, release both hands, walk 0.30 m |
| T02 | Hang at 2.10 m ledge | Same functional test independently |
| T03 | Release all hands before stable support | Fall/recover normally, not complete |
| T04 | Keep W against impossible clearance | No infinite buildup, clipping, or completion |
| T05 | Candidate flag OFF | Exact behavioral equivalence within defined tolerances to pre-v0.8 profile |
| T06 | Fixed vs articulated support | Correct force and torque transfer with no phantom supports |
| T07 | Narrow 0.12 m top | Reject or fail safely; never stand on imaginary space |
| T08 | Occupied destination top | Candidate blocked; no forced body insertion |
| T09 | Shoulder cannot physically reach top palm | No contact until actual reach |
| T10 | Abort, focus loss, restart | Hands, forces, flags and shape state reset safely |
| T11 | 60 Hz versus 120 Hz | Core safety and functional results consistent within reasonable tolerances |
| T12 | Human ordinary approach | Reproducible intuitive completion; no scripted exact-pose dependency |

**Automated test pass definitions must distinguish** geometry check, contact check, physical progression, functional top-out and human usability. They are not interchangeable.

---

# 13. Instrumentation and acceptance evidence

Extend `telemetry().ledge_transfer` rather than discard existing fields. Suggested additions:

```text
mantle.phase                  # Actual current phase, with transition reason
mantle.eligible                # Geometric eligibility only
mantle.top_support_id          # Current material/collider identity
mantle.top_normal              # Real measured normal
mantle.top_point               # Verified material point
mantle.palm_left / right       # FREE / TRACTION / TRANSFERRING / PALM / SLIPPING
mantle.palm_validity           # Geometric and contact checks
mantle.palm_force_requested    # Before allocation
mantle.palm_force_applied      # After all shared caps
mantle.palm_tangent_limit      # Friction-bound lateral limit
mantle.palm_reaction           # Measured support wrench
mantle.leg_flex_requested      # 0..1 or physical angle
mantle.leg_flex_achieved       # Actual collision-authorized value
mantle.leg_clearance_reason    # Why a fold/unfold was allowed or blocked
mantle.actual_supports         # Real traction, palm, foot and ground contacts
mantle.lip_clearance           # Measured torso/lower collider clearance
mantle.upper_foot_contact      # Real vs planned
mantle.body_origin_height      # Measured, not goal proxy
mantle.body_com_position       # Actual COM
mantle.destination_clear       # Endpoint-only check
mantle.path_clearance_status   # PASS / FAIL / UNKNOWN
mantle.hands_released          # Both actual hand inputs/supports cleared
mantle.ground_support_top      # Actual physical top-ground contact
mantle.ground_walk_distance    # Post-release ground locomotion achieved
mantle.functional_completion   # Final strict gate
mantle.failure_reason          # Explicit failure classification
```

Log in existing JSONL traces, with milestone/version flag, physics Hz, script versions and test provenance. Preserve failed attempts; do not delete failing logs after a later fix.

### Quantitative acceptance

Hard invariants:

- No unsupported hand/palm/foot produces nonzero supportive force.
- No new force/torque budget exceeds the configured project limits.
- No sustained deep collider overlap or path-through-lip event.
- No direct transform or velocity overwrite to finish top-out.
- No stale grip/reaction after support loss or button release.
- Functional completion requires **actual** top ground support, both hands released, stable orientation and 0.30 m of walking.

Engineering diagnostics:

- Report maximum palm force, peak collision impulse, peak body velocity, torque contributions, number of contact oscillations, and blocked collider-flex requests.
- Report 60/120 Hz differences honestly; don't invent a guaranteed identical physical trajectory.
- Define physically meaningful tolerances in the implementation according to shape scale and Jolt contact behavior; do not hard-code fake zero-tolerance claims based only on an ideal mathematical model.

Human-feel acceptance:

- The player can tell why a mantle is progressing or stuck.
- Pressing W does not feel like waiting for an unpredictable cutscene.
- Supporting hands visibly change function as the body reaches the top.
- Releasing a hand requires awareness of load, but not subpixel point targeting.
- The character reaches ordinary standing/walking smoothly enough that the player does not need to fight controller modes.

---

# 14. Risks, tradeoffs and alternatives

## 14.1 Single rigid body is an intentional approximation

A movable lower-body collider can improve clearance, but the entire body still has one dynamic mass/inertia. This can be acceptable for a stylized physics climbing game if its collision behavior is honest and the player learns it. It is not a full humanoid physical skeleton.

**Go/no-go question:** Can safe adaptive proxies support a wide range of ledges without visually obvious, gameplay-breaking collisions? If not, investigate articulated lower-body dynamics rather than introducing phantom clipping.

## 14.2 Palm support needs mechanically valid leverage

A surface normal force alone is not a guaranteed route over a ledge. If shoulder and palm geometry are unfavorable, the player may need to reposition hands, tilt the body, change support or place a foot. Study force lines and torques explicitly before adding compensating force.

## 14.3 Continuous collider mutation can destabilize Jolt

Rapidly moving internal collision proxies may create penetration or impulse spikes. If that occurs, prefer validated low-rate shape pose changes, collision-aware phase guards or a different physical representation rather than arbitrarily raising solver iterations until it appears stable.

## 14.4 Assisted hand transfer can undermine grip mastery

The prototype's appeal includes deliberate hand selection. H1 palm roll may improve ergonomics but must not erase the strategy of choosing contact points. Keep H0 as reference and test both with humans.

## 14.5 Automatic stance handoff is a frequent source of cheating

Ground locomotion must be conditioned on real top contact. A state-machine transition to `STAND_RECOVERY` must not apply airborne walking force, snap the body upright or forcibly move it over the lip.

---

# 15. Agent assignment and delivery requirements

## Main Codex agent

- Inspect and preserve current M5/M6 working state and repo layout.
- Own test fixtures, UI/debug overlays, input arbitration, feature flags, integration and 60/120 Hz regression matrix.
- Capture visual evidence of successful and failed attempts; include human-playtest instructions.
- Prevent integration changes from overriding ordinary climbing when the experiment is off.

## Physics specialist

- Own analysis and implementation of the compressive palm force model, finite-area contact validation, correct applied force/reaction wrench and shared budget allocation.
- Audit feasibility of collision proxy retraction within a one-body rigid character.
- Verify every force originates in real physical contact and every support mutation has explicit constraints.
- Reject solutions that rely on body teleport, unpaired upward force, hidden platform collision masks or unmodeled unlimited gripper torque.

## Required handoff artifact after each milestone

1. Changes made and touched files.
2. Exact feature flags, defaults and rollback procedure.
3. Equations/force conventions and physical assumptions.
4. Tests run at 120 Hz and 60 Hz, with results and traces.
5. What remains physically impossible and why.
6. Whether the milestone gate passed, with strict functional evidence if appropriate.
7. Recommended `KEEP / REVISE / REJECT` decision.

**Stop rather than claim completion** if Palm Support and lower-body clearance individually pass but a real top-out still cannot be achieved. A failed honest physical experiment is actionable information.

---

# 16. Suggested opt-in configuration

```ini
# Experimental example: adapt to the project's actual tuning resources.
intent_auto_mantle_enabled = false           # Legacy M6 comparison
physics_mantle_v08_enabled = false           # Master gate, OFF by default
palm_compression_enabled = false             # M1
adaptive_leg_collision_enabled = false       # M2
palm_transfer_policy = "EXPLICIT_REGRIP"      # H0; optional H1 LOCAL_PALM_ROLL
mantle_support_handoff_enabled = false       # M3/M4
mantle_path_diagnostics_enabled = true
mantle_force_debug_enabled = true
```

Keep existing profiles 0–4 and other experimental flags recoverable. Feature flags must not silently change unrelated force limits or control semantics.

---

# 17. Final prototype success definition

A complete v0.8 mantle is demonstrated only when a player starts hanging from a valid ledge, intentionally applies movement, establishes physically valid palm compression and/or other real supports, clears the platform lip with true collision geometry, transfers weight to a real upper foot/ground contact, releases both hands and **walks at least 0.30 m on the actual platform**.

The world must remain dynamic throughout. If the ledge is movable, it reacts to the player; if the contacts are inadequate, the player stalls, slips or falls.

**Design thesis:** A mantle should be an earned physical maneuver, not a hard-coded vault. The physics must explain the motion, while player controls and feedback make that motion understandable and satisfying.

---

## Appendix A — Evidence and provenance

**User-provided reference:** `physics_report.md`, “M6 — relatório físico da tentativa de mantle / top-out”. All baseline figures above derive from that report and must be verified against the current repository before editing. This v0.8 document introduces experimental approaches; it does **not** imply they are implemented or validated.

Existing documentation from previous project reports may be consulted for current `ArmActuator`, `FootContactSolver`, `ClimbingController`, `GroundLocomotion`, input profiles and physical budgets, but it does not authorize silently replacing M6 observations.

## Appendix B — Smallest possible proof-of-concept

Before the full mantle, a narrow experiment must demonstrate **one palm + one simple ledge + one body**:

- A verified top contact produces a limited compressive reaction that acts upward on a body **only when the geometry allows it**.
- A dynamic ledge experiences the matching downward reaction.
- Releasing contact removes palm effort immediately.
- A currently unsupported palm is incapable of suspending or lifting the body.
- The result is consistent with existing mass, force and torque budgets.

Then separately prove **physical leg clearance** before integrating both capabilities. If either experiment fails, diagnose it in isolation instead of hiding its defect in a full mantle state machine.
