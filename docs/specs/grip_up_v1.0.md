# GRIP UP — Contextual Vault & Top-Out
## Prototype Improvement Specification v1.0 (PC / Godot / Jolt)

**Status:** Proposed v1.0 design experiment; not an already-implemented feature.  
**Purpose:** Make the currently functional, vault-like assisted top-out feel intentional, visually credible, and consistent with the player's approach, **without replacing the successful v0.9 traversal architecture**.  
**Source of truth:** The user's latest `report(1).md`, *GRIP UP v0.9 — hybrid mantle prototype*. Inspect the actual working tree, source commits, test receipts, and authored animation before implementation.  
**Main platform:** Windows PC, third-person, landscape 16:9, keyboard + mouse.  
**Engine:** Existing Godot 4.7.2 / integrated Jolt project.  
**Working assumption:** Original physical climbing mechanics and grip system remain authoritative until a valid assisted top-out commits.

---

## 1. Executive decision

The correct next step is **refinement, not a new mantle solver**.

The existing v0.9 already achieves, at both 60 and 120 Hz, the functional transition from a real hand-gripped hanging pose to an upper static platform, restoration of a dynamic rigid body, verified upper ground contact, and 30 cm of normal walking. The reported final automated matrix is **4,356 checks in 139 runs, 0 failures**; 4,032 are preserved earlier checks and 324 are new v0.9 checks. Automated success does **not** substitute for independent human-playtest approval.

Its visual movement resembles a **monkey/kong vault** because the authored sequence tucks the legs, releases hands relatively early, and lifts/traverses across the lip through an assisted route. That motion can be desirable if the situation warrants it. The problem is not that it is non-biomechanical: the problem would be if the same acrobatic style plays after every slow, high, fully hanging approach.

**Recommended v1.0:**

1. Preserve v0.9 unmodified as an opt-in baseline and collect a small human quality assessment first.
2. Refine the existing fast **Vault-Style Top-Out** with better contact timing and presentation, without changing its safety certification.
3. Only if playtests show a meaningful context mismatch, add an **Assisted Climb-Over** variant for slower / higher / less momentum-rich approaches.
4. Reuse one transition framework, one authority model, one safety validator, one restore sequence. Additional style does **not** mean a second physics system.
5. Do not promote v1.0 as the default before reliability, visual quality, and player-feel gates pass.

This is a context-aware **animation-assisted locomotion transition**, not a claim that every new pose was produced by the character's physical muscles.

---

## 2. Explicitly preserved v0.9 baseline

The following details are documented in the supplied report; verify them before editing:

- The character is the **same 12 kg `RigidBody3D`** used by ordinary climbing and walking.
- `hybrid_mantle_controller.gd` currently owns: `DYNAMIC`, `PREPARE`, `COMMIT`, `ASSISTED_TRAVERSE`, `RESTORE_DYNAMIC`, `DYNAMIC_GROUNDED`, `BLOCKED_RECOVERY`.
- `mantle_candidate_detector.gd` accepts only appropriate **static** geometry under specific reach / facing / clearance / motion conditions.
- `hybrid_mantle_route.gd` provides a single ledge-aligned physical-body route, with independently certified trajectory and collision-profile changes.
- `mantle_kinematic_motor.gd` manages the temporarily frozen body in `FREEZE_MODE_KINEMATIC`, with motion/collision validation.
- `mantle_animation_driver.gd` samples a genuinely authored skeleton clip at the same normalized approved progress.
- `resources/mantle_authored.tres` has 17 bone-rotation tracks and seven phases; animation duration approximately **1.05 s** against an assisted body route of approximately **1.15 s**. It has **no independent root translation**.
- Full normal/tucked body-collision shape sweeps are validated: bounded point travel per interval of up to **3 mm**, conservative inflated midpoint occupancy, and endpoint checks. Collision checks cover torso, head, lower capsules, and full sole.
- The accepted shallow native-contact recovery is **restricted**: prior native-proven static contact, outward-only monotonically decreasing penetration, limited by the actual Jolt penetration-slop setting. It is not a blanket allowance for intersection.
- Existing restore requires original collision shapes and flags back in place, real upper sole/native support, a valid dynamic handoff, and at least **0.30 m** ordinary post-transition walking.
- Incoming pendular velocity is **not** blindly replayed; the outgoing linear velocity comes from the last approved assisted motion, capped in the existing system at **3 m/s**; angular exit currently is zero because route rotation has ended.
- The starting supported contexts are **static platforms** only. Dynamic/Animatable/moving supports, narrow/blocked corridors and ceilings are rejected. No automatic dynamic-platform support is authorized by v1.0.
- The current `hybrid_mantle_v09_enabled` flag defaults **false**. Original profiles, approved route, earlier v0.8 experiment, Janga source and builds are preserved.

**Do not relax any of these mechanisms merely because a different-looking animation is requested.**

---

## 3. Target player experience

Top-out should behave as a **clean reward for successfully reaching a valid ledge**, not a separate difficult dexterity minigame.

Player-facing goal:

> Reach a ledge using normal physical climbing. With a secure grip and a viable clear route, press/hold W to transition over it; the character performs a short, believable contextual movement and immediately resumes ordinary walking.

Desired qualities:

- **Legible:** player understands when a top-out is possible and what W does.
- **Immediate but not snapping:** short initiation; readable grip-to-traverse-to-stand sequence.
- **Stylistically consistent:** fast vault on dynamic/favorable approaches; controlled climb-over on hanging/high approaches if a second variant is eventually justified.
- **Continuous:** camera, body motion, authored skeleton, hand contacts, and return to walking agree.
- **Safe:** no unvalidated overlap, through-wall torso, ghost foothold, invented upper-ground completion, or uncontrolled snap on restore.
- **Respectful of physical climbing:** prior climb and arrival at edge are earned, even though the top-out crossing is deliberately assisted.

Not goals: simulating shoulder muscle force during each frame of the top-out, full ragdoll, independent ragdoll limb masses, dynamic moving-platform mantle, parkour combo systems, jump vaults from arbitrary ground distances, animation blending across an entire parkour library, multiplayer, or new stamina mechanics.

---

## 4. Contextual movement policy

### 4.1 Two possible presentation styles (staged delivery)

**Style V — Vault-Style Top-Out** (existing behavior to refine first)

- Short, flowing, compact movement: hands briefly brace; knees tuck; torso clears; legs pass over; feet land; stand.
- Best suited to strong approaches when the upper surface is close relative to the climber's actual body configuration and there is a safe clear corridor.
- Not necessarily a realistic street-level monkey vault, because the actual start can be from a hanging grip.
- Initial stage: retain current body's certified route and improve presentation only, unless a measurable physical envelope defect requires route changes.

**Style C — Assisted Climb-Over** (conditional second-stage experiment)

- Clearer feeling of effort: hands stay visually engaged longer; torso moves over lip first; knees/legs clear more deliberately; stand follows.
- Intended for higher, slower, fully hanging entries where fast tuck-and-vault reads implausibly athletic.
- Still assisted and route-driven, using the same body, guardrails, and restore logic.
- **Do not implement until a human test demonstrates the existing fast style is repeatedly inappropriate in valid high/slow entries.**

### 4.2 Avoid hard-coded platform height as the sole selector

Absolute world deck heights (1.25 m vs 2.10 m) are scenario information, **not** sufficient to classify motion. Consider actual body-relative facts:

- Height of ledge above current physical body origin / shoulders.
- Current hand arrangement and secure ATTACHED anchors; slipping/pending hands do not qualify.
- Approach velocity relative to the static support, including vertical/upward and inward components.
- Body orientation and angular velocity; posture stability.
- Feasibility of a certified *variant-specific* body/shape path.
- Current ground/foot support, if any, but do not invent one to select a more athletic style.

Define a `MantleContext` snapshot at commit. Initial prototype selector should use **broad author-tunable bands and hysteresis**, not brittle single threshold values. Example candidate ranges for *experimentation only*:

- Vault-style if body is relatively close to ledge and incoming forward/upward motion is favorable, **and** the vault route passes preflight.
- Climb-over if the character is substantially below lip or near-stationary, **and** its dedicated route passes preflight.
- If the preferred style is invalid but the other passes, log and use a documented fallback only if the other style is visually and mechanically credible for that start.
- If neither route is valid, **refuse** and retain ordinary physical climbing.

Do not silently alter reach, body height, anchor location, collision profiles, or support classification to force a preferred animation.

### 4.3 First production experiment

Ship only refined Style V with its current static envelope for initial A/B testing. Add Style C later as a separate feature flag, not because two styles merely look attractive on paper.

---

## 5. Input and authority contract

### Before commit — ordinary physics

- LMB held: left grip; RMB held: right grip (existing hold-to-grip).
- Mouse points at valid free-surface contact; no mantle sockets.
- W is positive climb-up intent and can request a mantle when a valid candidate is detected.
- MMB orbit and scroll dolly remain available, with unchanged grip and mouse input ownership.
- Character remains fully dynamic until the actual commit decision succeeds.
- Invalid candidates show restrained feedback and **do not** prevent normal climbing.

### Commit

- Require a secure actual grip and a candidate validated against live world geometry and the route.
- Consume commit idempotently; snapshot physical/visual state and selected surface-local contacts.
- Retire/transfer physical grip and pending-control ownership exactly once.
- Suspend arm/feet/ground forces from old controllers before assisted body authority takes over; avoid any physics tick with two conflicting movement owners.
- Movement may complete if the player releases W or the grip buttons after commit, matching current v0.9.
- Ignore old still-held buttons for reacquisition until fresh input.

### Assisted traverse

- Same physical gameplay body, frozen in kinematic mode, body movement authorized only by the swept route motor.
- Animation is sampled from approved progress; it must not independently translate the root.
- Camera remains third-person, no cinematic cut or camera teleport.
- Inputs cannot apply concurrent walking / swinging / climbing forces.
- Esc / UI pause suspends body-route and visual-pose clock together.

### Restore

- Restore original collision morphology before returning to full dynamics.
- Verify actual native upper platform support, not proximity-only floor rays.
- Reenable walking only after native support is established.
- Finish criterion includes ordinary 0.30 m walk on the support-local frame (not platform carriage or animation progress).
- Reset or subsequent grip clears old result flags.

---

## 6. Motion design and authored animation

### 6.1 Preserve one authority clock

`hybrid_mantle_route.gd` remains the positional authority, and `mantle_animation_driver.gd` the presentation authority, synchronized by one monotonically advancing **approved normalized progress**.

Avoid independent animation playback that can outrun physics, root-motion additive displacement, frame-count-dependent curves, or unbounded catch-up during low FPS.

### 6.2 Refine current Vault-Style clip

The seven existing phases should be reviewed and renamed to reflect their *actual* appearance rather than asserting biomechanical correctness:

1. **Grip brace** — preserve initial hand attachment appearance.
2. **Approach clearance** — start from physically observed body pose; no pop.
3. **Load / pre-traverse** — visible intent to move over edge; avoid sudden chest teleport.
4. **Leg tuck** — bring knees/feet into a compact collision-safe pose.
5. **Cross lip** — body moves through certified corridor; hands may blend away only after a plausible support-to-traverse visual handoff.
6. **Foot presentation / unfold** — visible legs correspond to current collision profile trajectory.
7. **Stand / locomotion blend** — feet and pelvis align to final verified dynamic stance.

**Critical improvement:** the report notes **early hand release**. Improve hand contact readability before adding entirely new movement styles. If holding hands visually longer is desired, do not merely pin wrist bones while the torso's route carries them out of anatomical reach. Either (a) change the visual blend within existing reachable windows or (b) re-author and separately certify a compatible body route.

### 6.3 Contact fidelity

- Remember actual initial support-local hand points and their interpolated world locations.
- Blend IK from real grips into authored hand trajectories over a bounded window.
- Maintain contact visuals while the palms can plausibly occupy those points.
- Once contact ceases, clearly animate release; **never leave hands glued to an edge across an impossible arm stretch**.
- Align feet with the actual current physically allowed final stance. Avoid long-lived IK sole targets after release to dynamic locomotion.
- Foot and hand presentation error should be logged separately for the period in which a contact is *supposed to be visually maintained*.
- Use existing silhouette/IK and collision debug overlays when judging apparent penetration.

### 6.4 Momentum presentation

The current v0.9 exit samples the last approved route velocity rather than replaying the pre-commit swing. Retain this safe rule. Improve *visual* continuity (body anticipation and animation pacing), not by injecting unexplained outgoing impulses.

If movement looks unnaturally abrupt at entry, experiment with a bounded **speed-sensitive route duration** after full safety revalidation; never alter interpolation alone to hide collision failures.

### 6.5 Timing proposals

Use current approximately **1.15 s route** as baseline. Prototype a limited pacing range (e.g. 0.95–1.35 s) **only as an explicit feature-flagged experiment**, keeping all sample/sweep validation at each duration and 60/120 Hz. These are test candidates, not shipped targets.

Do not add more speed merely because players reported “slow”; determine whether delay is in *candidate recognition*, *commit response*, *mid-route movement*, or *return to walking*.

---

## 7. Safety, collision profiles, and trajectory proof

All v0.9 safety properties remain mandatory.

- Maintain swept-certificate checks for full body volumes, body rotation, and lower-collider morphology.
- Enforce the same maximum bounded movement per sweep interval (current up-to-3-mm certificate) or stricter if necessary.
- Evaluate both initial and target occupancy and the *continuous path*. Clear standing endpoint alone does not authorize travel.
- Keep existing `HEEL_BACK` lower-profile route unless a new silhouette changes collision behavior; in that case author/certify a matching collider path.
- Do not disable limb/sole collisions, change body layers/masks, or teleport around a blocker.
- Preserve the tightly scoped **native-proven outward-only contact recovery**; no generalized 20-mm overlap permission.
- A moving or invalidated static support aborts and does not silently become a supported moving-platform vault.
- If runtime obstruction appears, hold the last certified pose and follow v0.9 recovery semantics (bounded wait or visible retry), not unchecked forced completion.
- Never use an authored animation event as proof of top ground contact.

**Style-specific certification:** any Style C trajectory, retimed Style V, or altered tucked-foot motion must receive fresh sweep, runtime obstacle, and restore testing. A shared motor does not imply the second path is automatically safe.

---

## 8. Architecture — minimal refactor

Keep existing modules:

- `hybrid_mantle_controller.gd` — state and ownership; stays canonical.
- `mantle_candidate_detector.gd` — live top/lip validation; extend only with context metrics if needed.
- `hybrid_mantle_route.gd` — per-move certified physical route generation.
- `mantle_kinematic_motor.gd` — swept movement, profile and runtime blocker authority.
- `mantle_animation_driver.gd` — authored pose and contact blending.
- `mantle_authored.tres` — existing working fast/vault-like authored clip.

Potential minimal additions, **only once needed**:

```text
features/grip_up/
  scripts/
    mantle_context_classifier.gd       # optional after human pilot
    mantle_style_profile.gd            # timing / animation / route config
  resources/
    mantle_authored.tres               # existing working fast movement
    mantle_climb_over_authored.tres    # optional second-stage clip
```

Suggested `MantleContext` fields:

```text
support_id
support_material_point
support_local_up / inward
body_origin_to_lip_height
body_to_face_distance
approach_linear_velocity_relative_to_support
approach_angular_velocity
attached_hand_count
attachment_geometry
candidate_corridor_bounds
standing_destination
selected_style
style_choice_reason
route_preflight_result
```

Suggested presentation profile fields:

```text
style_id                 # VAULT_STYLE | CLIMB_OVER
animation_resource
route_profile             # exact corresponding certified path
nominal_duration
blend_in_duration
hand_release_window
leg_tuck_window
stand_blend_duration
minimum_clearance_policy
```

No general-purpose “parkour framework,” new locomotion engine, or animation-state overhaul. All optional fields must be backwards compatible with v0.9 baseline.

---

## 9. Candidate classification details

Keep candidate detection conservative and auditable:

1. Acquire actual ATTACHED contact on a valid upper-lip-supporting static collider.
2. Compute support-local top plane, lip, inward vector, and relevant corridor extents.
3. Check body pose range and motion envelope; reject slipping/pending-only starts.
4. Verify the real route for the proposed style against occupied world geometry.
5. If two styles are enabled, rank style based on approach context **only among physically valid candidates**.
6. Lock style at COMMIT; do not switch styles mid-flight as movement changes.
7. Log candidate reason and route failure separately.

Do not add invisible grab sockets or require the player to select a special ledge hotspot. All approved grips are real free-surface contacts.

Rejecting a mantle must leave the character free to continue normal physical climbing, unless another explicit gameplay hazard occurs.

---

## 10. Handling difficult and adverse contexts

| Situation | Correct behavior |
|---|---|
| High ledge from almost stationary hang | Existing Style V may work technically; assess if visual reads awkward. Consider Style C only after player evidence. |
| Lower lip approached with upward momentum | Fast Style V candidate, if its route passes full preflight. |
| Insufficient top depth / narrow shelf | Reject; retain physical climbing. |
| Low ceiling above ledge | Reject if either certified body route intersects. |
| Occupied destination | Reject or runtime-block safely; no teleport. |
| Platform starts moving | Reject / abort (v1.0 remains static only). |
| Character reaches lip while slipping | Do not commit from slipping-only support. |
| Player releases grip before commit | Do not start assisted traversal. |
| Player releases grip during assisted traversal | Continue valid committed route; do not reacquire automatically. |
| Camera or UI changes | No mutation of selected world contact/route; synced pause. |
| New obstruction during traversal | Safe blocked pose and explicit recovery/retry. |
| Head/torso can stand at destination, but knee clips during crossing | Reject; full-path certificate must catch. |
| Dynamic restore before native top ground | Walking remains disabled until contact confirmed. |
| Rapid repeated trigger | Commit guard: one active transition only. |
| Two ledges in succession | Each attempt must originate from fresh real grips and reset result/authority data. |

---

## 11. Debugging and telemetry

For each top-out attempt capture:

**Eligibility:** hand/contact states, support ID, top normal, static classification, body-to-lip height, inward distance, approach linear/angular velocity, facing status, route checks, selected style and rationale.

**Authority:** active controller, freeze status, input ownership, commit/retire times, old grip teardown, duplicate-commit detection, camera behavior.

**Route/collision:** normalized progress, body pose, lower proxy pose, swept intervals / minimum clearance, runtime blockers, native-proven recovery scopes, certificate failures, dynamic restore clearance.

**Visual:** authored phase, hand world error only when IK contact should remain, shoulder/wrist plausibility, corrected foot-to-sole deviation, visible pops and timing of hand release.

**Exit:** precommit relative velocity, last route velocity, restored velocity, actual native sole contact, 0.30-m walking confirmation, final state and stability.

**Human pilot:** style appropriateness 1–5, start clarity 1–5, perceived responsiveness 1–5, continuity 1–5, animation credibility 1–5, return-to-control 1–5, and reason for any annoyance.

Keep debug graphics toggleable and separate from player-facing feedback. Logs and screenshots should clearly label automated vs human sessions.

---

## 12. Scenarios and test matrix

### Existing regression contexts (must remain)

- Low static platform top at 1.25 m.
- High static platform top at 2.10 m.
- Consecutive two-ledge course (documented upper top at 3.25 m in final working v0.9 course).
- Narrow 0.12-m shelf, ceiling obstruction, occupied destination, static support moved, dynamic/Animatable support refusal.
- Native penetration recovery on initial valid stationary contact; wrong direction/new penetration refusal.
- Reentry/fresh grip/old buttons held, focus loss, pause, reset, runtime blocker, duplicate commit.
- 60 Hz and 120 Hz runs and rendered evidence.

### New quality contexts

**Q1 — Low dynamic-looking approach:** same static platform, player reaches lip with moderate upward/inward velocity; evaluate if vault looks and feels fluid.

**Q2 — High controlled approach:** player reaches lip from a stable hanging grip below top; evaluate whether fast tuck/release reads unnatural.

**Q3 — Near-zero velocity:** secure hold, no significant motion, request W; check no sudden unnatural snap or ineligible style selection.

**Q4 — Off-center ledge entry:** secure left or right offset hand; test orientation, IK entry pose and collision route.

**Q5 — Repeated mixed styles (only if C exists):** low/high/top-out succession alternating style without stale grip or animation ownership.

### Test evaluation

- **Functional**: real dynamic-to-assisted-to-dynamic handoff; certified traversals; native grounded state and minimum 0.30-m walking; no false success.
- **Safety**: no unauthorized overlaps, no support-force creation from pending hand, no ghost attachments, no dynamic restore inside geometry.
- **Visual**: predictable arm release; no visible huge IK stretch or knee-through-deck; clear weight-transfer impression appropriate to selected style.
- **Control**: player understands trigger, can initiate from real grips, and regains control without hesitation.
- **Robustness**: identical feature profile at 60/120 Hz, repeated starts and reset.

Note that **exact bit-for-bit physics identity** across frequencies is not required. Safety and functional outcomes are.

---

## 13. Acceptance criteria and go/no-go gates

### A. Engineering gate — mandatory

- [ ] Existing v0.9 low and high complete from normal input at 60 and 120 Hz.
- [ ] Existing v0.9 approved route/profiles remain unchanged when v1.0 flag is off.
- [ ] Existing known failure (pure v0.8 mantle) remains accurately reported, not reclassified as a success.
- [ ] Player remains dynamic until a verified COMMIT.
- [ ] Full body-route sweeps authorize all assisted motion; animations never move the root independently.
- [ ] Narrow, moving, blocked, unsafe and ineligible ledges refuse without breaking ordinary climbing.
- [ ] Restore includes original geometry + actual native top sole support + normal walking.
- [ ] Consecutive mantle attempts reset all ownership and success conditions.

### B. Visual quality gate — mandatory before promotion

- [ ] In at least the Q1/Q2/Q3 scenes, the selected movement style is legible and contextually appropriate.
- [ ] Hand release occurs after a plausible brace, not as a visible uncontrolled pop.
- [ ] Leg tuck/unfold does not visibly collide with the lip or contradict physical proxies.
- [ ] No large discontinuity between physical hanging pose and first authored animation frame.
- [ ] No conspicuous pop when ordinary walking resumes.

### C. Human player gate — mandatory before setting default ON

Run at least **three brief manual sessions** including low/high and two-ledge play. These sessions may be performed by the developer plus other testers if available, but they must be clearly labeled; do not call them independent unless they are.

Record successes, failed initiations, manual camera adjustments, perceived responsiveness, confidence in the transition, and comfort ratings (1–5). Suggested initial target: no serious control-loss/reentry issues and average feedback **at least 4/5** for trigger clarity and control return; the target is a decision heuristic, not an existing measured result.

### D. Conditional second style gate

Only create Style C when repeated Q2 results show the current vault movement looks contextually wrong or uncomfortably fast **despite tuning the existing style**, and there is a clear player-experience benefit from a second animation and fully certified corresponding body route.

No GO based solely on prettier screenshots or additional technical test count.

---

## 14. Implementation roadmap — strict order

**M0 — Audit and preserve working v0.9**

- Locate and confirm the current v0.9 branch/commit, `verification.json`, scripts/resources and passing logs.
- Tag/commit a recoverable checkpoint and preserve all baseline tests.
- Play low/high/two ledges manually and capture the existing vault-like movement.
- Record the observed quality issues precisely: early hand release, mid-route float, foot tuck silhouette, or awkward end blend.

**Gate:** the *working* assisted top-out is still reproducible; the report is not treated as proof of unmeasured human quality.

**M1 — Refine existing vault presentation**

- Retain Style V's certified body route as first preference.
- Audit hand contact blend windows and initial pose entry against actual supported geometry.
- Adjust authored bone timing/poses where possible without changing body path.
- Verify IK target lifetimes, no stale sole/hand target, and synchronized pose/motor progress.
- Improve camera framing only if visibly necessary and without clipping or affecting input.

**Gate:** player-facing quality improves while all old physical outcomes and safety checks remain intact.

**M2 — Motion pacing experiment (optional)**

- Flagged A/B of current nominal timing versus a modest retime.
- Recertify all path/collision intervals for each candidate duration.
- Keep authored sequence and motor on the same progress clock.
- Compare feel and apparent loss of momentum; preserve original if improvement is unconvincing.

**Gate:** verified quicker/cleaner feel, not just smaller animation duration.

**M3 — Context audit and variant decision**

- Sample actual low/high/slow/fast entries, grounded in body-to-lip/approach data.
- Determine whether the refined single style is acceptable everywhere in the current authorized static envelope.
- If yes, **STOP**: ship one style. If no, write the exact mismatch and add Style C only behind a separate flag.

**Gate:** concrete human-observed reason for a second variant.

**M4 — Conditional slow climb-over variant**

- Author pose and separate certified compatible body route.
- Add deterministic context classification and hysteresis, with human-readable decision logs.
- Reuse the exact existing transition motor/authority and restore code.
- Validate both styles across static envelopes, obstacles, restart and two-ledge sequences.

**Gate:** both variants are safer, clearer and more appropriate than using one everywhere. Reject C if that is not demonstrated.

**M5 — Human acceptance and default decision**

- Play realistic end-to-end routes and compare against unchanged v0.9.
- Validate manual input, player expectations, mistakes and restart behavior.
- Recommend `KEEP V`, `KEEP V+C`, or `ROLL BACK` with supporting logs and observations.
- Promote default ON only after functional, safety and human gates pass.

---

## 15. Agent ownership / handoff

### Main Codex agent

- Own repository audit, feature flags, animation/UX integration, authored test scenes, telemetry, automated regressions, rendered checks, builds and comparison report.
- Do not refactor underlying climbing physics to chase vault visuals.
- Document exact files changed, toggles, source baseline, confirmed tests and manual-test status.

### Physics specialist

- Own any change to swept motion, collision profiles, initial native-contact recovery, restoration of dynamic authority, velocity handoff and moving-support eligibility.
- Audit all new body routes and collision morph sequences; reject endpoint-only shortcuts.
- Reject ungrounded “safe because animation played” assertions.
- Ensure old 12-kg body and original climbing forces remain unchanged outside committed assistance.

### Animation / gameplay responsibility

- Create or refine actual bone poses; do not fabricate root translations in animation tracks when the body route already owns translation.
- Validate frame-by-frame against collision overlays and real anchor positions.
- Label style changes as visual/assisted motion, not physical lifting improvements.

### Milestone report format

Each milestone must report:

1. Commit/branch and file list.
2. Existing baseline behavior verified.
3. Functional, safety and rendered test results, including frequencies.
4. Before/after video or captured frame references where available.
5. Human test outcome or explicit `PENDING`.
6. Known limitations and `KEEP / REVISE / REJECT` recommendation.

---

## 16. Rollback and player-facing language

Maintain separate switches, for example:

```ini
hybrid_mantle_v09_enabled = false         # existing opt-in baseline
contextual_vault_v10_enabled = false       # new experiment
climb_over_variant_enabled = false        # optional, gated
mantle_style_debug_enabled = false
```

Exact locations/serialization of flags must follow verified existing code; do not assume these are already implemented.

Use player-facing **“Climb Up”** or a discreet contextual upward cue. The player does not need to distinguish technical “mantle,” “vault,” and “top-out” labels.

Do not claim “fully physically simulated vault” in internal release notes or public descriptions. It is a deliberately assisted transition from real physical climbing back to real dynamic walking.

---

## 17. Final recommendation

**Keep v0.9's functioning system and make it look and feel deliberate.** The immediate deliverable is a refined single Vault-Style top-out with better hand and leg animation timing, camera/IK continuity, and reliable control return.

Only after playing it against controlled high/low approaches should we add a slower climb-over style. The best implementation is the **smallest validated set of transitions** that preserves player confidence and keeps the main gameplay focused on gripping, swinging, and climbing—rather than a new biomechanical subsystem that again blocks progression.
