# GRIP UP v1.4 — Intent-Aware Foot Unloading & Release

**Implementation specification · First Ascent gameplay-feel repair · PC / Godot 4.7.2 / integrated Jolt**

**Audience:** Codex implementation agent, independent physics specialist, animation/IK reviewer, and designer.

**Status:** Proposed, **not implemented or validated**. The player's latest direct observation is: *“I tried the First Ascent and now the foot glues really a lot, I'm struggling to play with.”* Treat this as a high-priority usability regression report, **not** as proof of its root cause.

**Design decision:** Investigate whether the resistance comes from the actual foot actuator, native collider contact, visual foot IK, a different climbing constraint, or a combination. If the physical foot actuator is implicated, implement a guarded, opt-in **B3 intent-aware foot unloading and release** policy derived from B1, without changing B1's placement policy or existing force limits. Restore fluidity without destroying load-bearing footwork.

---

## 1. Why this work is necessary

The core GRIP UP climbing loop already feels enjoyable to its designer. That is the reference experience to protect. The First Ascent is a continuous test route requiring walking, reaching, climbing, lateral transfer, hanging and a hybrid top-out. Physical feet are explicitly enabled in that experience; they are optional elsewhere.

Per the implemented-system report, each physical foot can be `FREE`, `SEARCHING`, `PLANTING`, `SUPPORTING` or `SLIDING`, with candidate sampling and real support-local contacts. Foot actuators are unilateral: they may **push** and provide friction but never pull or glue as a bilateral joint. However, sustained legitimate contact/friction may still resist a player's desired displacement. A visual foot IK target may also appear locked even when no physical foot force exists.

### Observed versus hypothetical

- **Observed directly:** the designer feels that a foot is sticking excessively during First Ascent, making normal play difficult.
- **Documented architecture:** optional automatically selected foot supports, physical reaction forces, support-local anchors, visual leg/foot IK, and separate native body colliders exist.
- **Not yet established:** which foot, which section, whether the body is physically stopped, whether foot load remains nonzero, whether the native `FootBase` collision is responsible, or whether only the visual leg is frozen.

Do not write a fix that assumes the user's symptom proves a specific solver defect.

### Non-goals

- No complete ragdoll, independent rigid-body legs, new manual foot buttons, stamina system, new movement coordinator, trained model or fresh auto-tuning.
- No universal reduction of foot friction or force, no extra climb authority, no handhold auto-selection, no teleporting feet/body, no resetting body momentum, and no change to the hybrid top-out route.
- Do not modify M7 or optimize a benchmark until this gameplay regression is assessed.

## 2. Immutable gameplay and physics reference

Preserve the current playable **A0 movement coordinator + B1 physical-foot policy** as the comparison baseline, alongside the explicit **B0 feet OFF** option. B2's alternative candidate ranking stays experimental and separate. The requested v1.4 candidate is **B3 = B1 placement + intent-aware unloading/release**, not an untracked combination of A1/B2/B3.

Reference contract from the existing reports:

| Property | Preserve |
|---|---|
| Body | One dynamic `RigidBody3D`, 12 kg, no full limb ragdoll |
| Anatomical shoulder-to-contact reach | Approximately 0.65708 m |
| Shared hand force | 360 N |
| Shared posture/swing assistance | 20 N·m |
| Combined climbing moment ceiling | 150 N·m |
| Physical feet | 180 N combined, at most 120 N per foot |
| Foot spring and damping | 1800 N/m and 100 N·s/m |
| Foot preload | 0.025 m |
| Foot contact load-in | Approximately 0.12 s |
| Foot planting speed | 2 m/s |
| Foot nominal friction | 0.85, constrained by the actual material |
| Main input profile | Profile 4: mouse picks hand contacts; WASD requests body motion |
| Input | LMB/RMB hold-to-grip; MMB camera orbit, scroll dolly |
| Physics validation | 120 Hz primary, 60 Hz comparison |

These are historical effective values, not permission to raise budgets. Read the live project and verify the actual current values before implementation. Any discrepancy is an audit finding; do not silently overwrite it to fit this document.

**Production behavior:** untouched by default. The new policy is opt-in only. Keep the B0/B1/B2 mappings and baseline settings reproducible; do not label B3 as improved until a real player confirms it.

## 3. Milestone F0 — Reproduce, isolate, instrument

This milestone is a hard prerequisite for modifying foot dynamics.

### 3.1 Repro workflow

1. Open **Controls → PLAY / The first ascent** and record the exact profile, hand controls, foot setting, movement policy and other flags actually activated.
2. Execute the exact same short sequence under:
   - **B0:** A0, physical feet OFF;
   - **B1:** A0, existing physical feet ON;
   - **B3:** not yet available; reserve for comparison after diagnosis.
3. Use the real player controls, not synthetic foot anchors. Record at least one location where the designer experiences a stick.
4. Include: vertical push, lateral movement left/right, release one hand while retaining one or both feet, and intentional movement away from a planted foot.
5. Replay from fresh attempts. Reset between trials and retain the same level geometry, camera, input profile and physical caps.
6. If the problem only appears after a particular route sequence, preserve that preceding sequence; do not replace the situation with an unrealistically perfect initial pose.

### 3.2 Diagnostic snapshot per foot

Record on physics ticks (optionally downsample normal exports):

- state; `left/right` identity; candidate and current support collider IDs; material-local/world contact point and normal; current foot transform and distance to pelvis/hip;
- foot normal compression force, tangential friction force, net body-applied force, matched equal/opposite force on dynamic supports, actual load-in weight;
- available anatomical workspace and whether foot reach/path is valid; planted/sliding state and why it persists;
- support velocity/angular motion at point; body linear/angular velocity; desired WASD direction in the existing support frame, real movement along that direction, and input strength/held duration;
- true `FootBase` native ground/contact indicators (when available), leg lower-collider proximity or conservative clearance; **mark native contact `UNKNOWN` when the API does not report it**;
- foot IK weight, target, actual rendered foot position, and owner of animation/IK during the sample;
- hand status/forces, support budget saturation, ground motor authority, and whether a hybrid top-out is already in control.

Provide a debug HUD with independently toggleable **actuator load**, **native collision**, **visual IK**, and **intent opposition**. Never display a nonzero cached force during hybrid/disabled ownership.

### 3.3 Fault classification

| Evidence | Interpretation / next action |
|---|---|
| B1 resists body movement; B0 releases resistance; planted foot carries force | Investigate foot actuation/retention; B3 is relevant |
| Body motion is normal; rendered foot/leg remains stuck or overextends | Fix presentation/IK ownership, not physical loading |
| B0 still resists and `FootBase`/other collider is touching | Investigate native collision and collider friction/geometry; do not claim actuator release solves it |
| Feet have no load, but a hand/ground motor is saturated or blocked | Investigate another locomotion constraint separately |
| B1 visibly supports the body and moves correctly | Preserve that state; do not make B3 release it indiscriminately |

**Gate F0:** collect a reproducible failing moment and classify the contributing subsystem(s). If B1 is not implicated, do not implement B3 as a speculative fix; produce a focused diagnostic report and recommend the relevant corrective track.

## 4. Milestone F1 — B3 policy and safe integration

Introduce `foot_release_policy.gd` or an equivalently isolated component, wired into `foot_contact_solver.gd` through guarded calls. Keep the baseline B1 branch byte-for-byte behavior-equivalent when B3 is disabled. Use the existing `intent_locomotion_coordinator.gd` and support-frame representation for intended motion; do not create a second competing locomotion controller.

### 4.1 Core player contract

- When the player is neutral, a genuinely useful planted foot may maintain support.
- When the player intentionally moves **toward or along** a useful support, a foot may stay planted and contribute load.
- When the player intentionally moves **away from a restrictive contact**, the leg should unload and release soon enough to avoid a sticky, pinning sensation.
- Holding a direction should not leave the foot pinned indefinitely just because the old point is still technically load-bearing.
- Releasing a foot **may cause a fall** when it was the final support; do not invent another grip, floor or impulse to save the body. Avoid accidental falls from one noisy input tick.
- Feet remain subordinate to the hands and chosen movement direction. The player still chooses handhold positions and timing.

### 4.2 Evidence-based decision, not a force-only heuristic

An opposing foot force alone is **not** proof of unwanted sticking: friction may be performing useful braking or stabilizing a posture. Evaluate a combination of signals:

1. **Deliberate motion:** nontrivial, sustained movement intent in the established climb support frame.
2. **Planted foot becoming obstructive:** one or more of:
   - the support-to-hip vector trends toward anatomical overextension as the player commands movement away;
   - maintaining the current planted point requires an unfavorable leg orientation/path;
   - the foot's measured force/work tends to oppose the requested displacement while progress is insufficient;
   - the body is genuinely stalled with hands/other supports able to move, and the held foot is a plausible restricting constraint.
3. **Support utility:** the same foot may be currently reducing hand load or supporting a deliberate upward push. Compare the benefit of maintaining it against the evidence of obstruction.
4. **Measured progress:** recent COM progress in the *intended* support-frame direction; don't punish legitimate initial rotations, setup motion or transient momentum merely for low instantaneous projection.
5. **State stability:** time since last plant, load-in, intentional release, replant, slip, and changes to active grips/support.

A policy may use a small scored/hysteretic decision based on these observations, but must expose its terms and decision reason. Avoid hidden stateful magic coefficients. **Do not use a single `dot(foot_force, intent) < 0` rule.**

### 4.3 Candidate v1 settings — experimental, not universal tuning

These are initial design ranges for *isolated tests*, not established gameplay constants. Read existing tuning and choose one conservative initial profile with logged values:

| Variable | Suggested trial range | Role |
|---|---:|---|
| Minimum intentional hold time | 0.12–0.25 s | Ignore one-frame input noise |
| Progress evaluation window | 0.20–0.40 s | Recognize persistent resistance |
| Intentional unload duration | 0.08–0.16 s | Smoothly remove foot actuation |
| Same-patch replant suppression | 0.25–0.60 s | Prevent glue/unload/replant loops |
| Replant position hysteresis | 0.10–0.20 m support-local displacement | Require a meaningfully new point |
| Minimum foot support time before ordinary discretionary release | 0.08–0.15 s | Reduce capture churn, except hard invalidity |

All durations are real time, evaluated per physics tick at both 60/120 Hz, not fixed frame counts. Hysteresis thresholds should be inferred from real foot sizes and measured contact stability where possible. Do not copy these values into production untested.

### 4.4 Explicit per-foot lifecycle

Prefer a narrow policy lifecycle around the current foot states rather than rewriting contact acquisition:

`SUPPORTING → UNLOADING → FREE/SEARCHING → REPLANT_ELIGIBLE`.

- `UNLOADING` is a physically active transient policy state or an equivalent tag; load capacity decreases monotonically from the **current** allowed compression/friction toward zero.
- During unload, recompute the *actual* force and equal/opposite reaction each tick using the current gated capacity. Do not apply the full reaction while reducing only the player's side.
- A released foot does not continue to apply compression/friction through cached actuation. Preserve independent native collision rules.
- Do not directly write `RigidBody3D` pose/velocity or material anchor position to free a foot.
- After release, suppress immediate replanting on the same **support-local patch**. Do not blacklist an entire huge wall or dynamic collider globally; use a bounded local region and expiry.
- Let a genuinely new support point be sampled normally. If all candidates are suppressed, staying free is preferable to relatching the same obstructive contact.
- If the current support is invalid, unload or release using existing safety semantics without waiting for comfort-oriented hysteresis.
- Repeated reversals, changing active hand, and released held input must not produce stale release commands.

The foot solver already has compression-only behavior. Its force sign, per-material friction cone, shared foot limit and combined torque budgets must remain enforceable **at every intermediate unload tick**.

### 4.5 Two feet and transitions

Make decisions per foot, not per body. Avoid dropping both useful supports because one direction input briefly changes. Prefer the more obstructive foot to unload first when both are candidates, unless a support became invalid or a physical slip occurred. Any short sequencing guard must be bounded and may not permanently override deliberate movement. Do not swap an existing loaded anchor to another point without unloading and physically planting anew.

For walking-to-climbing handoff, preserve the existing sharing of ground motor, hands and feet. A foot release must not grant new ground authority, incorrectly enable walking in the air or reactivate an old grip.

For static hybrid top-out, the current hybrid controller has exclusive movement authority during commitment: **B3 must stop issuing forces and release/replant decisions**, leaving hybrid actuator ownership untouched. Clear pending timers/cooldowns appropriately on return and when a fresh level/retry starts.

For moving support geometry, use current support-local anchor transforms and support-point velocity; avoid comparing stale world-space positions. If the existing foot solver supports physical reaction to a dynamic support, the B3 force reaction must remain symmetric. Do not extend hybrid top-out onto moving platforms.

## 5. Milestone F2 — Presentation must follow physical truth

Physical release alone does not guarantee that the character *looks* free.

- The visual foot IK target remains anchored only while valid physical planting/support warrants it.
- During `UNLOADING`, IK weight may fade with measured support weight, without creating a visual slide or abrupt snap.
- After release, the limb transitions to the existing passive leg behavior; do not keep a stale world-space IK target or pin the ankle while the pelvis moves.
- Avoid obvious knee inversion, catastrophic limb stretch, and foot teleport. Existing IK reach limits remain intact.
- Keep the IK on a genuinely load-bearing foot stable during player-neutral support.
- Distinguish a visual foot contacting a surface from the **physical solver** actually carrying load.

Add a temporary overlay showing **actual sole position**, **IK target**, **physical contact/anchor**, and **IK weight**. Measure separation while SUPPORTING and after release, but do not mistake an intentionally blended-off target for a live planted-foot error.

If F0 identifies a *visual-only* fault, make the smallest isolated F2 fix without introducing B3 load changes, and preserve that distinction in the changelog.

## 6. Milestone F3 — Real gameplay scenarios

Implement repeatable opt-in comparison entries in the existing Controls UI, ideally:

- `First Ascent / Feet OFF (B0)`
- `First Ascent / Physical Feet CURRENT (B1)`
- `First Ascent / Intent Release EXPERIMENT (B3)`

Keep the same course, spawn, camera, profile 4, A0 arm planning, collisions, hand capture policy and permitted physical budgets. Do not silently change any setup flag between comparisons. If the current UI architecture cannot offer three buttons safely, provide an explicit policy selector and display all active flags in the run receipt.

### Required test situations

| Scenario | What it demonstrates | Failure to avoid |
|---|---|---|
| S1 — Vertical climb with a good ledge | Foot can carry weight and assist upward push | Foot prematurely lifts whenever W is pressed |
| S2 — Lateral traverse left/right | Obstructive foot unloads under deliberate direction | Repeated sticking/replanting, asymmetric deadlock |
| S3 — Move away from planted foothold | Foot releases within a reasonable human-perceptible delay | Indefinite pinning or artificial hip motion |
| S4 — Neutral hold | Useful support remains stable without input | Twitching feet, auto-release or unrequested fall |
| S5 — Reverse W/A/D rapidly | Hysteresis and old timers reset correctly | Foot oscillation or wrong-way retention |
| S6 — One hand + one physical foot | Load transfers remain physically truthful | Magic support or loss of a valid useful foot |
| S7 — Two feet on adjacent patches | Per-foot arbitration makes progress possible | Both feet lock the torso or release unpredictably |
| S8 — No reliable footholds | Hands and swing still behave normally | Phantom planted contact or false foot force |
| S9 — Dynamic/rotating foot support where existing rules allow | Support-local tracking and reactions | Frozen world contact or one-sided impulse |
| S10 — First Ascent entire route + hybrid top-out | Flow, completion and normal return to walking | B3 continues forcing during hybrid or causes stuck state |

Also test a ledge lip/native-body-contact reproduction if F0 implicates `FootBase`, and a visual-only rig test if F0 implicates IK.

## 7. Milestone F4 — Objective telemetry and comparisons

Do not reduce gameplay feel to a single optimizer score. Capture per attempt:

- **Intent-to-progress response:** elapsed time from sustained WASD request until confirmed COM movement along requested direction; separate intentional setup rotations from unrequested delay.
- **Foot-lock episode:** a consecutive interval with one foot SUPPORTING, player demanding motion away, insufficient useful progress, and evidence that the foot may be obstructing. Mark as an *inferred diagnosis* rather than asserting force causation without a controlled B0 comparison.
- **Unloading latency:** from qualified release request to physical load reaching zero; include onset/confirmation separately.
- **Replant thrash:** successive contacts on the same support-local patch within the suppression window.
- **Support quality:** time and magnitude of legitimate foot compression, change in hand load, upward progress; B3 must not just remove all footwork.
- **Grip integrity:** genuine hand acquisition, retaining, slip/release, no forces in REACHING/FREE.
- **Body response:** signed COM displacement, actual speed, angular velocity, swing energy proxies, unintended ground motor activation.
- **Visual quality:** foot/IK error during valid planting, IK lag and stretching after release; classify stale targets appropriately.
- **Functional outcome:** First Ascent checkpoints and top-out/walking result; assisted hybrid movement excluded from claims of purely physical locomotion progress.
- **Safety:** finite values, support-local forces/reactions, clipping/clearance, state ownership, body/profile restore and any abnormal collision.

The previous benchmark instrumentation and freeze directories are not to be overwritten. If reused, record new flags, source hash, policy B0/B1/B3, frequency, and method of input. Do not demand bitwise comparability between 60 and 120 Hz or between a new B3 run and B1. Use fixed input tapes only for controlled physical comparisons; an adaptive driver must be labelled adaptive.

### Practical performance gates

Use **relative gates against the same-scene B1** after confirming the sticky symptom. Proposed gates, subject to review *before* pilot:

1. For S2/S3, player-initiated movement must become perceptibly less obstructed than B1; report elapsed delay and progression, not just a code-level release event.
2. For S1/S4, useful load-bearing support and stability must remain credible; quantify loss in support and unexpected foot releases.
3. Zero illegal foot tensile force; no new body teleport/velocity assignment; all force/reaction/torque/combined budgets honored.
4. No infinite unload/replant loops, stale foot anchors or replant on a suppressed local patch.
5. First Ascent completes and hands/hybrid/walking restore correctly at 60 Hz and 120 Hz in tested reproductions.
6. No material performance regression in physics tick cost attributable to F1 telemetry when normal observers are OFF.

Do not publish invented universal numeric feel thresholds. Calibrate with the measured B1 defect and compare B3 via A/B human play; a benchmark PASS cannot overrule a player-reported sticky feel.

## 8. Milestone F5 — Automated tests and physics review

Implement suites for F0 through F4, plus regressions of existing playable A0/B1, B0 and B2 isolation. Test at both 60 Hz and 120 Hz with independently reported results.

Required unit/contract cases:

1. No deliberate input → do not mark normal planted support obstructive solely from contact force.
2. Sustained away-intent and verified workspace growth → unload without moving the body directly.
3. High genuine support utility under W → preserve useful compression unless persistent obstruction is demonstrated.
4. Unload ticks decrease or cap force monotonically as configured, never introduce suction or exceed friction cone.
5. Reaction on dynamic supports matches body-applied foot force at the real material point.
6. Suppress immediate same-patch replant; permit genuinely different contact after proper path/planting.
7. Changing support frame, camera orbit, invalid collider and hand release cannot leave stale world anchors.
8. Alternating WASD / one-frame impulses do not thrash support states.
9. Last-foot release does not secretly create walking authority or prevent an otherwise legitimate fall.
10. No positive contact force in `FREE`, `SEARCHING`, `PLANTING` before valid support; respect actual baseline state semantics.
11. Hybrid kinematic ownership has exclusive authority and B3 cannot reapply forces during or immediately after handoff.
12. B3 OFF / B1 selected preserves B1 behavior and original setup, with no hidden policy evaluation that changes outputs.
13. Visual IK transitions follow physical release and do not freeze an obsolete planted target.
14. Reset, pause/focus-out and retry clear transient state without automatic regrip.
15. Different physics frequencies yield legitimate behavior within budgets; **never** force identical frame counts/results across Hz.

Have the physics specialist independently audit the implementation of force gating, actuator reaction balance, support velocity, torque budget, foot workspace and authority handoff. Keep negative tests and traces. A script completing without crashes is not sufficient evidence of a pleasant or physically correct outcome.

## 9. Milestone F6 — Human feel gate

A brief designer pilot is mandatory before any promotion.

**Suggested session:** Three short passes in randomized/counterbalanced order using B0, B1 and B3 on the same First Ascent route. Play each condition long enough to encounter the originally sticky spot. Repeat the most disputed comparison, ideally without knowing which of B1/B3 is currently active until after the rating.

After each condition, record 1–5 ratings for:

- ease of moving away from planted footholds;
- climbing flow/continuity;
- trust in load-bearing feet;
- precision and predictability;
- sense of weight and physical credibility;
- willingness to play another route.

Also record objective attempts, unexpected foot locks, accidental falls, completion time and unplanned camera/input corrections. Ask the designer for one timestamped example of the sticky foot before and after, ideally short video.

**Acceptance requires:** the designer says the sticky obstruction meaningfully improved, physical support remains useful, and automated physics regressions pass. If B0 feels clearly better than both B1 and B3, consider whether physical feet should remain opt-in for the main route until a better foot design exists. Do not silently promote B3 merely because it scores higher in fixtures.

## 10. Source audit and likely files

Read real source files in the current checkout; names below originate from the implemented-system report and must be verified before editing:

| File / module | Intended scope |
|---|---|
| `features/grip_up/scripts/foot_contact_solver.gd` | Foot states, load caps and force/reaction application; add guarded B3 hook only |
| `features/grip_up/scripts/foothold_candidate_sampler.gd` | Existing B1 placement kept; add local-patch cooldown eligibility only when B3 |
| `features/grip_up/scripts/intent_locomotion_coordinator.gd` | Read-only access to established intent and support frame; avoid changing A0 |
| `features/grip_up/scripts/locomotion_support_frame.gd` | Existing frame interpretation and validity |
| `features/grip_up/scripts/climbing_controller.gd` | Policy ownership, flags, actuator coordination, diagnostics |
| `features/grip_up/scripts/biped_leg_motion.gd` | Passive leg behavior after release |
| `features/grip_up/scripts/biped_visual.gd` | Foot IK ownership/weight on valid contacts |
| `features/grip_up/scripts/grip_up_lab.gd` | B0/B1/B3 comparison controls, run identity and First Ascent scene |
| `features/grip_up/resources/foot_tuning.gd` | Isolated B3 policy defaults/ranges; no B1 mutation |
| New focused policy/diagnostic scripts | Keep intent-release decision separate and independently testable |

Never edit Janga's protected original grabber, old baseline versions, historical validation receipts or unrelated gameplay to accommodate the experiment. Save an exact source/scene/export snapshot and test rollback path before code changes.

## 11. Delivery phases and stop rules

| Phase | Deliverable | Decision |
|---|---|---|
| F0 — Baseline reproduction | B0/B1 A/B clips or traces, root-cause classification | Must pass before actuator work |
| F1 — B3 policy | Opt-in intent-aware load/unload/replant logic | Technical candidate only |
| F2 — Visual coupling | Foot IK tracks actual loaded/free status | Separate visual findings |
| F3 — First Ascent comparisons | Same-route B0/B1/B3 selectable | Human usable |
| F4 — Telemetry | Measurements, failure reasons, traces by source/Hz | No invented zeros |
| F5 — Physics tests | 60/120 Hz safety, regression and independent review | GO/NO-GO technical |
| F6 — Human pilot | Recorded designer observations and ratings | GO/NO-GO feel |
| F7 — Decision | KEEP_B1, TRIAL_B3, PROMOTE_B3, or FEET_OFF_FIRST_ASCENT | Explicit decision |

### Stop early if:

- F0 shows only visual IK sticking while the physical foot actuator is already off; use an isolated visual fix.
- The sticky behavior remains with B0 feet disabled; inspect native collider / other support constraints rather than B3 heuristics.
- B3 requires increasing hand/foot budgets, silently removing native collisions or imposing body velocities to pass; reject it.
- B3 destroys useful upward foot pushing, causes frequent unwanted falls or repeated load cycling, even when movement displacement improves.
- Tests contradict human feel; preserve both the failed trial and the current playable B1 without changing production defaults.

## 12. Handoff and acceptance checklist

The Codex integration agent must produce:

- an initial `F0_ROOT_CAUSE.md` with what is **observed**, inferred and not known;
- a clean opt-in B3 implementation, with B0/B1 intact and explicit settings;
- small fixtures plus the unchanged real First Ascent for meaningful comparisons;
- independent physics specialist findings on friction/reaction/authority;
- per-tick diagnostic evidence and a concise human A/B recording form;
- a final report with source identities, exact tests executed, 60/120 Hz, observed outcomes, known limitations and an explicit decision;
- normal game startup and export sanity check, confirming B3 is not silently enabled.

**Acceptance checklist:**

- [ ] Sticky symptom reproduced and correctly classified.
- [ ] Physical force vs visual foot IK vs native collider distinguished.
- [ ] B0/B1 preserved; B3 opt-in.
- [ ] Physically justified unload/release and support-local replant hysteresis.
- [ ] No foot force after release and no one-sided dynamic reaction.
- [ ] Legitimate foot support remains helpful.
- [ ] No direct body motion or hidden increased force.
- [ ] Tests at both 60/120 Hz and existing regression coverage pass.
- [ ] First Ascent end-to-end and hybrid top-out restore pass.
- [ ] Designer A/B pilot completed and reported honestly.
- [ ] Decision recorded; promotion only with explicit human approval.

---

## Final product principle

**The player controls where they go; the feet help them get there.** A foothold should feel like a temporary, load-bearing opportunity—not a magnet anchoring the character against the player's wishes. The right solution must preserve the weight, inertia and skill ceiling of GRIP UP while removing genuinely obstructive foot retention.
