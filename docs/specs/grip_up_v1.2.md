# GRIP UP — Locomotion Test Suite & Movement Mastery Evaluation
## Implementation Specification v1.2 — Before M7

**Status:** Proposed measurement and evaluation phase; NOT a new locomotion controller.  
**Audience:** Main Codex agent, physics-specialist agent, and designer/playtesters.  
**Project:** GRIP UP · Godot 4.7.2 / integrated Jolt · Windows PC · third-person, landscape.  
**Primary simulation:** 120 Hz; comparative regression runs at 60 Hz.  
**Predecessor:** v1.1 pre-M7 locomotion refinement, as reported in `report(3).md`.  
**Primary decision:** Identify whether the **existing** physical climbing locomotion allows players to learn, repeat, predict, and deliberately execute useful movement. Do not replace or rebalance movement systems merely to improve benchmark scores.

---

## 1. Executive brief

GRIP UP already has playable climbing with independent hold-to-grip hands, camera-based targeting, a single dynamic body, optional load-bearing feet, supported swing, intent-driven climbing (profile 4), and an animation-assisted static top-out. Version 1.1 added instrumentation and several isolated experiments, but did **not** demonstrate an overall improvement of locomotion feel.

The next phase is **measurement first, design decisions second**. Build a repeatable suite of physical tasks, honest diagnostics, optional visualizations, and a practical human A/B protocol. Then use evidence to decide which existing behaviors to **KEEP**, **REVISE**, or **REJECT**.

### Required outcomes

1. A reproducible baseline on the existing locomotion system, with exact code/settings identity.
2. A family of targeted tasks testing vertical movement, asymmetry, lateral traverse, one-hand suspension, foot support, intentional swing, hand capture, and locomotion transitions.
3. Measurements of *player-directed motion*, separate from numerical physics validity.
4. A compact human playtest that compares key variants without conflating them.
5. A movement-mastery test showing whether repeated practice yields repeatable improvements **without** relying on routes scripted to win.
6. A clear recommendation for whether to proceed with M7 reactive level design, plus targeted follow-up work only where evidence justifies it.

### Explicit non-goals

- No new locomotion solver, automatic route planning, inverse-dynamics optimizer, ragdoll rebuild, mantle rewrite, animation overhaul, stamina, new abilities, or grip-strength rebalance in this phase.
- No automatic promotion of A1 or B2. No assumption that more height, less twist, or a prettier pose is always better gameplay.
- No alteration of hand/foot force budgets, physical mass, body collision shapes, anatomical reach, or Jolt simulation settings in order to make a test pass.
- No M7 reactive challenge until the test program produces a recommendation. Existing dynamic-support labs can still be used as regression fixtures.
- Do not claim that automated test success proves player comfort, enjoyment, or skill progression.

---

## 2. Verified starting point and experimental matrix

The following are **reported** v1.1 states, not promises about a later working tree. Codex must inspect actual project scripts, tuning resources, git branch, and feature flags before implementation.

| Dimension | Reference / present status |
|---|---|
| Playable baseline | `baseline/pre-v1.1-locomotion`, commit `6646cdeda0a0104b723c483905a9a4fc36e00674` (as reported) |
| Branch under study | `feature/v1.1-locomotion-refinement` (as reported) |
| Engine | Godot 4.7.2 with Jolt integrated |
| Primary physics | 120 Hz; compare at 60 Hz |
| Current input for intentional climbing | Profile 4: mouse selects hand contact; W/S climb/down and A/D traverse in support-relative frame |
| Grip behavior | LMB/RMB held independently; releasing detaches; cursor never directly changes arm length under profile 4 |
| A0 | Existing movement planner, **baseline** |
| A1 | Constraint-aware heuristic, currently **REVISE** due to poorer useful progress / increased twist in tested fixtures |
| A2 | Not implemented; do not imply otherwise |
| B0 | Physical feet OFF |
| B1 | Existing physical foot choice, **baseline when feet are ON** |
| B2 | Experimental candidate scoring, **unproven general improvement** |
| C | Optional swing-driving/braking/neutral feedback, measurement only; physical C1/C2 changes absent |
| D | Transition observation/regression, no general new physical transition controller |
| E/F | Directional grip quality and contextual camera improvements deferred |
| Previous checks | v1.1 reported 5,094 headless checks / 159 executions / 0 failures; these are technical checks, not human sessions |

Other documented reference limits (freeze and verify locally): approximately 12 kg body, 0.65708 m shoulder-to-palm reach, 360 N shared hands, 180 N feet total / 120 N per foot, 20 N·m shared assist and 150 N·m resultant moment, 0.24 m/s and 0.9 m/s² arm-target planner rate/acceleration. The exact live resource values take precedence over this snapshot, but **any mismatch must be logged and approved before comparisons**.

### Official comparison variants

**Primary human comparison:**

- `V0` = Profile 4 + A0 + B1 + physical feet ON; optional feedback OFF; measurement tools OFF during normal user trials.
- `V1` = Profile 4 + A0 + B2 + physical feet ON; all else identical.
- `V2` = Profile 4 + A1 + B1 + physical feet ON; **diagnostic comparison only**, not a presumed upgrade. Exclude from long human sessions if it demonstrably breaks progress; document why.

**Isolation variants:**

- `V3` = Profile 4 + A0 + B0 / feet OFF, to estimate how much feet add versus no physical foot support.
- `V4` = Same as V0 but swing feedback ON, to test whether the information changes understanding or performance, without changing motion.

Do **not** compare A1+B2 directly against A0+B1 and attribute the difference to either component. Use paired single-factor comparisons.

### Version provenance

Each run must save: branch, commit, dirty-tree status, build ID, relevant resource hashes, Godot/Jolt build, physics FPS, scenario ID/revision, profile, A/B variants, feet flag, swing feedback flag, assistance/mantle flags, control bindings, player/tester ID (pseudonymous), and whether input was **scripted**, **human**, or **developer exploratory**.

---

## 3. Architecture: observation must never control the body

Add a separate testing feature boundary rather than adding gameplay logic to diagnostics.

```text
Player Input / In-Game Actions
            |
            v
Existing Input Router -> Existing Locomotion & Grip Controllers
            |                            |
            |                       Physics / Jolt
            |                            |
            +------> Read-only Observation Snapshots
                                         |
                  +----------------------+-------------------+
                  |                      |                   |
             Task Evaluator        Telemetry Recorder   Debug Visualizer
                  |                      |                   |
             Outcome/Events       JSONL + Summaries    Optional In-Game UI
```

### Non-invasive guarantees

- An observer cannot modify arm target lengths, contacts, body pose, momentum, force allocation, camera state, input events, or control mode.
- Any capture buffer must be bounded and disabled by default. Existing v1.1 observation windows are limited; preserve or tighten these bounds.
- On frames owned by the hybrid top-out controller, show and log the **actual active authority**; normal hand forces must be zero when its actuators are suspended. Do not report stale cached forces as applied physical work.
- Debug/UI must never add geometry affecting raycast selection or create a support; mark debug nodes non-colliding/non-targetable.
- Distinguish sampling frequency, physics ticks, events, renderer frames, and elapsed monotonic time.
- Any telemetry overhead is measurable and can be switched off without changing physics results beyond normal nondeterministic tolerance.

### Sources of truth

- **Intent:** movement command in the active support frame, not mouse motion inferred afterwards.
- **Motion:** actual physical body or COM pose and velocities, not authored animation or IK alone.
- **Support:** real `ATTACHED` hands, loaded feet, native ground contacts; pending hand targets are not support.
- **Load:** actually applied forces/torques after global allocation, not pre-cap requests.
- **Completion:** live world geometry, contact state, released controls if required, and stable supported progress; never only route animation progress.

---

## 4. Measurement definitions

All motion comparisons need more than completion yes/no. Implement the metrics below with precisely documented frames and normalization.

### 4.1 Coordinate frames

At input onset, record:

- `d_world`: normalized intended direction based on the **actual current support frame**. For climbing, this may be wall-tangent rather than camera up.
- `x0`: physical COM or body-origin position; use one named reference consistently throughout that test. Prefer COM for general locomotion; record body origin separately.
- `v0`, support material velocity, camera orientation, real support IDs/contact normals.

For a directional task, measure in the chosen frame and record whether it was fixed at input onset or followed moving support material. Do not silently change frames halfway through a measurement window.

### 4.2 Signed useful progress

`useful_progress(T) = dot(x(T) - x0, d_world)` in meters, with an additional support-relative measure for moving supports.

Positive is motion in the requested direction; negative is movement against it. Preserve negative values; never clamp to zero for presentation.

### 4.3 Directional efficiency

`path_length(T) = sum( |x[i] - x[i-1]| )` over sampled physical COM positions.

`directional_efficiency(T) = useful_progress(T) / path_length(T)` when path length exceeds a documented epsilon (e.g. 1 cm). Otherwise mark **NOT_DEFINED / NO_MOVEMENT**, not 100% efficient.

This lies near +1 for movement aligned with intent and may be negative when motion is opposite. **It is diagnostic, not a universal performance score:** loops, deliberate preload, swing, and necessary rotations can temporarily lower it.

### 4.4 Response and controllability

- **Command onset latency:** time from actual accepted input to the first sustained, measurable acceleration or velocity component in the intended direction; state the detection threshold and persistence window.
- **Displacement at fixed windows:** e.g. 0.25 s, 0.5 s, 1.0 s, plus task-end result. Use the same windows for comparisons.
- **Overshoot:** excess beyond a spatial target corridor or desired stop location.
- **Settling:** time until measured motion stays under specified translational/angular thresholds for a continuous interval.
- **Unwanted axial twist:** RMS/peak in a support-relative body axis, separated from legitimate swing and body translation.
- **Input reversals/corrections:** directional reversals and newly commanded opposite intent; do not count automatic oscillation as a manual correction.
- **Angular/linear jerk:** optional diagnostic, computed from filtered velocity/acceleration and annotated with legitimate collision spikes; do not optimize blindly for minimum jerk.

### 4.5 Support / contact contributions

For each support, log actual contact position, force vector, moment, normal, type, contribution to command direction, loaded duration, and support-body velocity. Measure:

- Fraction of time a foot is actually load-bearing, not visually touching.
- Fraction of net support load provided by feet versus hands, where mechanically meaningful.
- Handoffs, invalid contacts, slip, extension releases, catch attempts and successes.
- Energy/work proxies using actual admitted force and velocity at application point; label as **partial actuator work**, not whole-system energy conservation.
- Global budget saturation time and actuator tracking error.

### 4.6 Player performance

- Attempts, retries, falls, slips, missed catches, reset count, completion and completion time.
- Number of distinct hand transfers, foot contacts, and deliberate swing cycles.
- Recovery time after a failed grip that does not end the run.
- Optional perceived control/comfort scores: 1–5, grounded with written anchors.
- Repeated attempts over time to estimate improvement / retention.

### 4.7 Baseline-vs-variant validity

For each reported improvement provide at least: absolute result, difference, percentage where meaningful, variation across repeated seeds/initial states, frequencies tested, and any trade-offs. A tiny difference smaller than run-to-run variation is **INCONCLUSIVE**, not a success. Do not aggregate unrelated metrics into one hidden weighted score.

---

## 5. Task suite: isolated locomotion capabilities

Implement small, readable **greybox** fixtures with start state, support layout, task goal, expected permissible behavior, fail reasons, and reset. Test geometry should be data-driven, not scattered magic transforms in test scripts.

### T01 — Vertical Pull (two hands)

**Setup:** Vertical static surface, two comfortable valid handholds, optional footless and foot-supported comparison; stationary settled initial state.  
**Player goal:** Move COM upward by a specified modest vertical distance while keeping support.  
**Automation:** Apply a held climb intent for equal durations on A0/A1 under identical initial configurations.  
**Measures:** Progress at fixed times, useful progress, hand load, vertical speed, unwanted twist, overshoot, saturation.  
**Validity:** No synthetic velocity or body transform; if a variant cannot climb, preserve the failure.  
**Human question:** Does W feel reliably connected to actual upward movement?

### T02 — Asymmetric Pull

**Setup:** Two attached hands at different heights or fore/aft positions; fixed, reproducible camera and support geometry.  
**Goal:** Make useful upward progress without being thrown into uncontrolled twist.  
**Measures:** Signed useful progress and axial twist RMS/peak over the same time interval.  
**Known v1.1 baseline observation:** A1 reduced useful progress and increased twist in one asymmetric fixture. New test must reproduce and explain this before A1 is considered for changes.  
**Acceptance for variant:** Improvement cannot be claimed if height improves but contact load/twist becomes materially worse, or vice versa, unless explicitly justified by player results.

### T03 — Diagonal Intent / Lateral Traverse

**Setup:** Fixed wall with offset handholds; corridor target left/right; separately test pure lateral, pure vertical, and diagonal commands.  
**Goal:** Traverse without losing contact and reach corridor.  
**Measures:** Signed projection onto intended direction, opposite-direction progress, task completion, corrections, handoffs and camera rotations.  
**Regression:** A1 previously produced negative useful diagonal progress in a tested fixture. Preserve this as a mandatory known failure case until corrected.  
**Avoid:** Artificial constraint on route that forces one precise sequence.

### T04 — One-Hand Hang / Recovery

**Setup:** Character hanging by a single real hand, the other free; initial conditions sampled across left/right, relative orientation and pendulum phase.  
**Goal:** Hold, reduce unhelpful twist, move intentionally, and aim at another valid contact.  
**Measures:** Pendulum amplitude and plane, axial twist separately, aim burden, free-hand reach windows, accidental slips, time to second grip.  
**Non-success:** A rigidly frozen body passing the test is a failure of physical expressivity.

### T05 — Foot Push / Candidate Discrimination

**Setup:** One or two hands attached, **two anatomically reachable foot candidates** with different directional utility; both real, visible and physically supportable. Use mirrored left/right fixtures and different surface normals.  
**Goal:** Move in indicated direction with foot contribution.  
**Compare:** B0 versus B1; then B1 versus B2 under identical physical-feet ON settings.  
**Measures:** Candidate selected, actual planting/loaded contact, positive normal and friction-limited tangent reaction, reduction in hand load, useful COM displacement, time to goal, replant frequency.  
**Gate:** B2 changing the chosen contact is not sufficient; show improvement in movement or usable stability across **more than one** valid geometry.  
**Anti-cheat:** A foot in SEARCHING/PLANTING has zero support load until physical contact is valid.

### T06 — Swing Build / Swing Brake

**Setup:** One fixed handhold with sufficient clear space for a physical pendulum; no new support geometry needed.  
**Goal A:** Starting near rest, deliberately increase amplitude to a visible target band.  
**Goal B:** Starting with a reproducible swing, deliberately reduce amplitude to a target band.  
**Measures:** Pendulum plane, amplitude over cycles, time/cycles to bands, phase relative to input, actual actuator power sign and budget use.  
**Cases:** Correctly timed pumping, deliberately opposite commands, neutral input, camera orbit mid-swing, no-grip airborne case (must not accelerate).  
**Human question:** Does the player understand how to accelerate and brake rather than just mash WASD?

### T07 — Swing & Catch Beyond Static Reach

**Setup:** Initial valid grip; next visible destination exceeds current shoulder reach but can enter reach during a plausible swing.  
**Goal:** Deliberately generate sufficient motion, pre-select with free hand (if enabled), catch and **retain** grip for a meaningful interval.  
**Measures:** Reach window duration, hand arrival, actual contact, retained hold, incoming relative speed, overload, attempt count, swing cycles.  
**Fail classification:** POSE_UNREACHABLE, PATH_OBSTRUCTED, HAND_TOO_SLOW, CATCH_OVERLOAD, GRIP_SLIP, SUPPORT_LOST, etc.; distinguish them.  
**Guard:** No auto-latching from forecast and no extension of hand beyond anatomy.

### T08 — Locomotion Transitions

Test distinct boundaries, with a ±0.5 s instrumentation window around each event:

1. WALK → REACHING with real ground still loaded.
2. REACHING → ATTACHED and gradual transfer from ground to hands.
3. TWO_HANDS → ONE_HAND with momentum preserved.
4. HANDS → FOOT-SUPPORTED climbing, both support systems engaged without double authority.
5. HANGING → GROUNDED after actual contact.
6. Certified HYBRID TOP-OUT → native sole support → resumed WALK.

**Measures:** authority ownership, hand/foot/ground force continuity, acceleration spikes including their source, control response time, slide/penetration, camera discontinuities, frame-to-frame velocity.  
**Special guard:** During kinematic hybrid ownership the suspended dynamic actuators must report **zero applied force**, not stale cached requests.

### T09 — Camera / Aim Burden

**Setup:** Same reachable climbing sequence presented with standard camera and optional visualization aids; do not add contextual camera behavior yet.  
**Measures:** mouse travel, number/duration of manual camera corrections, failed cursor selection, time with next valid grip occluded, handoff success.  
**Purpose:** Determine if camera intervention is genuinely a bottleneck before implementing F contextual camera.

### T10 — Fixed vs Dynamic Support Sanity

**Setup:** Equivalent grip geometry as both fixed anchor and a known moving/hinged support already available in labs.  
**Goal:** Confirm local-material anchors, reciprocal reactions and stable tracking in both cases.  
**Measures:** support velocity, anchor-follow error, force/wrench pair, slip/extension failure.  
**Purpose:** Physics regression **only**, not construction of M7 level. Existing hybrid mantle on dynamic support must remain ineligible.

---

## 6. Movement Mastery Test — the main gameplay experiment

A climbing controller can pass thousands of checks and still fail to give players an understandable path to skill. This test asks whether **players improve through practice and can intentionally reproduce movements**.

### 6.1 Course layout

Create one compact course with three sequential segments, using current abilities:

- **Segment M-A — Controlled ascent:** a short safe wall with several valid hand choices, basic alternating hand transfers and an obvious finish.
- **Segment M-B — Asymmetric traverse:** offset grips and one or two optional foot supports; successful player must manage orientation/load, but there is more than one valid sequence.
- **Segment M-C — Swing catch:** a visible destination outside static reach that is accessible via a physically plausible swing and real catching behavior.

Add fast checkpoints/reset per segment. The primary score is segment completion and mastery; total course time is supplemental. Keep final top-out only if the test is not dominated by its authored animation.

### 6.2 Attempt protocol

- One guided familiarization run and one untimed practice run; do **not** score them as clean mastery attempts.
- Five measured attempts of each segment with same input profile and difficulty. Rest between attempts if needed.
- At least one later re-test after a brief unrelated task or break, where practical.
- For learning comparisons, use the **same participant** and record order, practice and route familiarity.
- Capture voluntary alternative solutions rather than forcing every player to copy a reference path.

### 6.3 Mastery outcomes

Compare across attempts:

- Success rate and time-to-completion for each segment.
- Fewer falls, fewer accidental grip losses, and fewer corrective camera gestures.
- Lower effort / fewer oscillation cycles only when the player accomplishes **the same intended outcome**.
- Greater repeatability of the same deliberate swing-and-catch maneuver.
- Subjective feeling of agency: ability to explain *why* a move succeeded or failed.
- Evidence of new player-discovered techniques, not just rote memorization of the level.

**Never claim skill mastery solely from one faster run**. Players may learn level geometry, input quirks, or a forgiving exploit. Use multiple attempts, a second comparable layout where possible, and narrative observation to distinguish these.

### 6.4 Failure review

When participants fail, allow a compact post-attempt tag:

`MISREAD_HOLD`, `CURSOR_SELECTION`, `CAMERA`, `UNEXPECTED_PHYSICS`, `MISTIMED_SWING`, `BAD_SUPPORT_CHOICE`, `GRIP_OVERLOAD`, `FATIGUE`, `OTHER`.

Players describe causes in their own words before the test observer assigns any technical reason from logs. The two may differ; that discrepancy is useful evidence about feedback/readability.

---

## 7. Human A/B playtest protocol

### Target group

Start with the developer for exploratory iterations, followed by **3–5 people unfamiliar with the project** when available. This is a small qualitative sample, not a statistically powered consumer study. Record expertise with third-person games, mouse accuracy and physics-climbing games without collecting unnecessary personal data.

### Conditions

Use the same machine, resolution, mouse sensitivity, input mapping, simulation frequency, scene revision, and starting states wherever feasible. Hide technical overlay except when explicitly studying its effect; do not alter physics to match trial times.

### Comparisons (one factor at a time)

**H1 — A0 versus A1:** limited diagnostic session for developer/technical testers first. If A1 shows the already documented negative progress or an unplayable high ledge, stop that variant; mark it REVISE/REJECT without wasting new-player sessions.

**H2 — B1 versus B2:** same A0, profile 4 and feet ON. Primary human foot comparison.

**H3 — Feet OFF versus B1:** same A0; determine whether existing feet make locomotion genuinely more expressive/control-friendly.

**H4 — Swing feedback OFF versus ON:** same physics; discover whether the indicator helps novice interpretation or distracts.

**H5 — Diagnostic camera burden:** observe existing controls; only prototype a contextual camera if players repeatedly need costly camera intervention.

### Order and learning effects

- Counterbalance variant order across participants (e.g. AB and BA). If three conditions are involved, rotate the first condition rather than always starting with baseline.
- Offer equal familiarization time under each variation.
- Avoid doing all easy baseline trials first, making the newer variant benefit unfairly from practice.
- Prefer paired comparisons within each person, then describe variation across people.
- Allow session breaks and record hand/wrist fatigue, especially because LMB/RMB remain hold-to-grip.

### Ratings, with anchors

Ask after each *measured* block, using 1–5 and a short verbal note:

| Item | 1 | 5 |
|---|---|---|
| Control response | Hard to relate input to movement | Movement reliably matches intent |
| Predictability | Failures are inexplicable | I can anticipate the physical result |
| Grip aiming | Frequently fighting pointer/camera | Can select desired hold quickly |
| Swing agency | Mostly accidental | I can deliberately pump/brake and catch |
| Comfort | Physically tiring/confusing | Comfortable for repeated runs |
| Skill expression | Mostly luck or automation | Practice reveals deliberate techniques |
| Replay desire | Would stop after this segment | Want to try it again |

Do not collapse all scores into a single unexamined average. Keep precise notes on why scores differ.

### Interviews

Ask short open questions after performance, not before: "Which action felt hardest to make the character do?", "What caused the last failed catch?", "Did the foot do what you expected?", "Could you repeat the swing on purpose?", "When did the camera interfere?". Avoid asking leading questions such as "Was B2 smoother?".

---

## 8. Observability and tools

### 8.1 Optional debug overlay

A minimal on-demand developer HUD with:

- Active profile, A/B foot settings, feedback flag, physics frequency, current test segment.
- Accepted movement intent (support frame and world frame), actual COM velocity, signed progress.
- Body angular state: pendulum angle, angular speed, axial twist.
- Per-hand/per-foot `FREE / PENDING / ATTACHED / SLIPPING / LOADED` indicators, actual forces and shared budget use.
- Ground/hand/foot/kinematic ownership and transitions.
- Reach/catch failure code, most recent support transition, elapsed time.

Avoid a permanent full-screen dashboard while playing; allow opening only during inspection and replay.

### 8.2 Timeline charts

Expose readable per-run visualizations **outside active gameplay**:

1. Requested directional intent vs actual signed COM progress over time.
2. Body linear/angular velocity and axial twist vs time.
3. Hand and foot actual forces plus total budget saturation.
4. Grip-state events and transfer timeline.
5. Swing amplitude and pump/brake input phase.
6. Authority owner transitions (ground, arm, feet, hybrid mantle).

The chart must distinguish scripted tests from human runs. Use resampled data and consistent axes/units for side-by-side comparisons. For comparisons involving rotation or contact impulses, annotate the change in support and impacts rather than smoothing them into nothing.

### 8.3 Data layout

Suggested artifact folder, subject to existing project conventions:

```text
docs/validation/v12/
  baseline/
  scenarios/
  automated/
  human/
  analysis/
  decision.md

user://locomotion_v12/
  sessions/<session-id>/events.jsonl
  sessions/<session-id>/samples.jsonl.gz
  sessions/<session-id>/summary.json
```

Use existing `capture_trace.gd`, `transfer_diagnostics.gd` and v1.1 `locomotion_observer.gd` whenever possible. No duplicate physics observers. Ensure generated files aren't accidentally committed with identifying player data.

### 8.4 Example summary schema

```json
{
  "schema_version": "locomotion_v12_1",
  "source": "human",
  "scenario": "T06_SWING_BUILD_BRAKE",
  "scenario_revision": "1",
  "variant": {"profile": 4, "allocation": "A0", "feet": "B1", "physical_feet": true, "swing_feedback": false},
  "physics_hz": 120,
  "result": {"completed": false, "duration_s": 0.0, "retries": 0},
  "movement": {"useful_progress_m": null, "path_length_m": null, "directional_efficiency": null},
  "capture": {"attempts": 0, "contacts": 0, "retained": 0},
  "assessment": {"confidence": "not_evaluated", "notes": ""}
}
```

This is an authoring example, **not** a real test result. Record missing metrics as `null` with reasons rather than making up zeros.

---

## 9. Automated validation matrix

All test changes must preserve existing v1.1 gameplay code and run its core regression suites. Add automated tests for **measurement correctness**, not only locomotion outcomes.

| Suite | Core assertion |
|---|---|
| METRIC_01 | Signed displacement reverses when intended direction reverses |
| METRIC_02 | Stationary/no-path efficiency returns NOT_DEFINED |
| METRIC_03 | Frame invariance under an equivalent world/camera orientation transformation |
| METRIC_04 | Support-relative metrics exclude platform carry when intended |
| METRIC_05 | Samples and event timestamps align with physics ticks |
| OBSERVER_01 | Observer disabled does not create extra forces or grip transitions |
| OBSERVER_02 | Hybrid-owned frames publish zero applied arm forces |
| OBSERVER_03 | Capture buffers remain bounded; memory does not grow without limit |
| VARIANT_01 | A0/B1 unchanged; variants isolated by independent flags |
| VARIANT_02 | A1 known asymmetric/diagonal regression remains visible in comparisons |
| FEET_01 | Foot search/planting alone does not count as loaded support |
| FEET_02 | Left/right mirrored candidate test uses corresponding mirrored result frame |
| SWING_01 | No airborne propulsion without physical support |
| SWING_02 | Supported pumping/braking produce honestly signed partial work |
| CAPTURE_01 | Contact vs retention is explicitly distinguished |
| TRANSITION_01 | No simultaneous competing dynamic and hybrid authority |
| TRANSITION_02 | Return from mantle requires actual upper native ground and walking |
| INPUT_01 | Camera orbit does not change held grip target or inject impulse |
| INPUT_02 | Hold-to-grip mouse-up cancels/ releases as expected |
| EXPORT_01 | Windows export launches and displays test UI |

Test at 120 Hz and 60 Hz where physics is relevant. Compare physics invariants and toleranced outcomes; do not require deterministic floating-point equality or identical contact timing between solvers/frequencies.

### Initial-state robustness

Each physics scenario should have:

- A canonical deterministic setup where feasible.
- Several controlled alternate postures, hand orders, small starting velocities, and mirrored geometries.
- Runs at both supported frequencies.
- At least one intentionally impossible / invalid request, verifying a transparent failure rather than a forced success.

**Do not mutate level geometry or player force values after an unsuccessful test solely to make a comparison pass.** If a reference fixture is flawed, document a corrected fixture revision with both old and new outcomes.

---

## 10. Fairness rules and statistical interpretation

A small sample is for finding flaws and promising hypotheses, not proof of broad consumer preference.

- Report **within-player paired deltas** and raw distributions (or ranges), not only averaged scores.
- For each condition include the number of valid attempts, failures and completions.
- If an intervention changes difficulty, describe the trade-off between *agency* and *ease*.
- Do not claim B2 improves locomotion because one fixture moved ~8 mm in the intended direction while the complete Step test differed by less than 1 mm.
- Do not conclude A1 is better because it is more mathematically "efficient" if it produces less ascent or more twist.
- Learning effects must be called out. An improving time across trials can come from understanding the obstacle layout rather than better locomotion.
- Performance metrics and subjective ratings are **separate evidence streams**; disagreement is a reason to investigate rather than discard either stream.

Suggested decision classification per feature:

- **KEEP:** Clear benefit on its intended capability in multiple conditions, no material regressions, and at least positive or neutral human assessment.
- **REVISE:** Benefit limited to certain states, contradictory evidence, or meaningful cost in feel/clarity.
- **REJECT:** Repeated negative progress/instability or players consistently prefer baseline without compensating value.
- **INCONCLUSIVE:** Tests too small, noisy, invalid or not yet conducted; do not promote.

No feature becomes default based only on regression counts.

---

## 11. Performance budget

Telemetry and visual diagnostics must be inexpensive enough not to contaminate the experiment.

- Default OFF in normal gameplay and performance samples.
- Measure physics step time and render frame time separately with observer OFF and ON.
- Prefer event-driven snapshots; sample high-frequency traces only in explicit benchmark/playtest capture.
- Bounded ring buffers; optional compressed output; avoid allocations on every physics tick when diagnostics disabled.
- Test one 10-minute session to detect memory growth/log backlog, without promising network or cloud analytics.
- If charting/rendering diagnostics measurably changes frame pacing, move analysis offline or reduce sampling.

---

## 12. Milestone plan (before M7)

### LP12-0 — Preserve and inspect

- Snapshot and verify source/version; don't alter Janga.
- Audit actual A0/A1, B0/B1/B2, swing-feedback, observer, foot state and input defaults.
- Archive the v1.1 report and validate its reported known regressions can be reproduced.
- Capture one ordinary human-played baseline if possible.

**Gate:** explicit config matrix and comparison fixtures signed off; code unchanged.

### LP12-1 — Define task geometry and metrics

- Author T01–T10 with named test states, mirrored variants, success/fail conditions, and configurable numeric thresholds.
- Implement metric definitions and unit tests before building charts.
- Freeze a revisioned task set for fair comparisons.

**Gate:** the same setup yields analyzable signed metrics and no ambiguous direction frame.

### LP12-2 — Integrate read-only instrumentation

- Reuse existing observer, capture trace and diagnostic events.
- Add explicit accepted-intent frame, actual admitted forces, per-contact work, task/transition event IDs and solver authority.
- Prove observer OFF preserves the baseline and observer ON does not control it.

**Gate:** instrumentation safety and data correctness pass at both frequencies.

### LP12-3 — Movement & foot A/B technical studies

- Repeat A0/A1, B0/B1/B2 in isolated scenarios.
- Focus on asymmetric pull, negative diagonal progress, foot candidate quality, and true contribution to ascent.
- Keep all regressions in the record.

**Gate:** technical report with paired absolute results, variance and candid interpretation. No new default.

### LP12-4 — Swing and transitions

- Test swing build, swing brake, timing-based catch and input phase.
- Instrument ground ↔ hands ↔ feet and top-out handoff.
- Study current camera aiming burden; do not build contextual camera yet.

**Gate:** player-intent events and actual movement are explainable without invented forces.

### LP12-5 — Movement Mastery Course

- Build the three-segment route with quick retry and optional checkpoint.
- Validate it is physically feasible using unmodified baseline with real inputs.
- Prepare scored and practice modes; record individual attempts.

**Gate:** course can be finished with meaningful choices and no arbitrary script-only success.

### LP12-6 — Human A/B pilot

- Run baseline and comparison variants with balanced ordering.
- Collect per-attempt metrics, 1–5 ratings, written observations and fatigue reports.
- Include users unfamiliar with the game when available.

**Gate:** authentic human evidence explicitly identified; missing participants not fabricated.

### LP12-7 — Decision and handoff to M7

- Produce per-feature KEEP/REVISE/REJECT/INCONCLUSIVE decisions.
- Recommend zero or a small number of **measured, scoped** follow-up changes.
- Explain whether M7 should start on baseline A0/B1 or a validated alternative.

**Gate:** a defensible design decision, not an arbitrary numerical completion target.

---

## 13. Responsibilities and guardrails

### Main Codex agent

Own test scenes, UI control, measurement schema, reporting, experiment configuration, game integration and human protocol artifacts. Keep source regression checks and Windows export healthy. Never silently swap default control schemes.

### Physics specialist

Audit the interpretation of forces, support frames, loaded contacts, useful progress, torque work, pendular phase and 60/120 Hz behavior. Confirm no observer-induced forces, coordinate errors or stale force caches. Independently review physically impossible trial requests and capture failure categories.

### Gameplay/designer review

Identify which movements felt intentional, enjoyable and repeatable; compare subjective notes with measured behavior. Approval of a new default is a **design decision following playtests**; neither specialist can infer it from a zero-failure automated matrix.

### Reporting after every milestone

For each deliverable, provide: commit/build identity, variants changed, fixture revisions, scripts modified, new tests, regressions, human sessions (if any), summary numbers, surprising failures, unverified claims and recommended next action. Archive failed attempts, do not overwrite them with the successful run.

---

## 14. Acceptance criteria

- [ ] Existing baseline A0/B1 and all prior playable routes remain available without change.
- [ ] Inputs remain hold-to-grip; the mouse is targeting only in profile 4.
- [ ] At least T01–T10 are measurable with documented start states, frames, success and failure reasons.
- [ ] Signed COM progress and path-length efficiency are calculated correctly and safely for stationary cases.
- [ ] Asymmetric and diagonal known A1 regressions are preserved and directly comparable.
- [ ] B2 is evaluated on foot-contact quality **and** resulting body motion, not just contact selection.
- [ ] Intentional swing pumping and braking can be assessed independently from accidental oscillation.
- [ ] Contact, capture and grip retention are distinct events.
- [ ] Ground, climbing and hybrid top-out states have nonoverlapping movement authority in logs.
- [ ] No pending hand/foot incorrectly supplies load.
- [ ] Debug observer has no physical authority and can be disabled with negligible residual cost.
- [ ] Tests run at 60 and 120 Hz with appropriate tolerances.
- [ ] Mastery route supports repeated attempts and stores per-attempt outcomes.
- [ ] Human playtests, if performed, are identified as real participants rather than scripted input.
- [ ] Every experimental option ends as KEEP, REVISE, REJECT or INCONCLUSIVE with reasons.
- [ ] The final decision explicitly says whether M7 can proceed and which control configuration it should use.

---

## 15. Known constraints and honest interpretation

The available v1.1 report supports strong evidence about technical safety and certain fixture-specific regressions. It does **not** establish player-level improvements, overall B2 superiority, a completed swing-feedback human pilot, or a proven contextual camera benefit. This spec proposes measurements and future tests; it does not assert their results.

Some challenging movement emerges from the geometry of one-handed suspension. A slower, more rotational route may be physically necessary. Do not reward only straight-line ascent or suppress all twist at the expense of useful momentum.

The current top-out is deliberately hybrid/assisted. It must remain separately labelled when evaluating purely physical locomotion. The physics controller should not be blamed for movement authored by the hybrid motor, nor should a smooth animation be credited as physically generated climbing.

**Success for v1.2 is not a prettier graph or a larger check count. It is evidence that players can understand, intentionally produce, repeat, and improve the core climbing motions—and knowledge of exactly which existing systems help or hinder them.**

---

## Appendix A — Suggested initial dashboard

Use a simple comparison view with one scenario at a time:

- Header: scenario/revision, variants, physics frequency, recording type, build hash.
- Main panel: useful progress vs time, with A0/A1 or B1/B2 overlaid using the same axes.
- Secondary panels: twist vs time, actual support loads, and annotated events.
- Outcome row: completion, elapsed time, handoff count, slips, retries, comfort rating (if human), and confidence notes.

No dashboard work should block running the textual/CSV/JSONL reports. Prioritize correct measurements over visualization polish.

## Appendix B — Recommended Codex task statement

> Implement GRIP UP Locomotion Test Suite v1.2 **as instrumentation, reproducible test scenarios and a human evaluation harness only**. Inspect the latest working project and use the v1.1 report as historical evidence, not a mandate to promote A1/B2. Preserve A0/B1 gameplay, all physical force budgets, input bindings and the static hybrid top-out. Build the task suite, metric definitions, optional read-only overlays, mastery route, honest experiment logging and comparative report. Validate both 120 and 60 Hz and preserve failed fixtures. Do not start M7 or refactor locomotion until the results identify a specific change worth testing.

## Appendix C — Source basis

- User-supplied `report(3).md`, **GRIP UP v1.1 — experiências de locomoção antes de M7** (the immediately preceding implementation report).
- Earlier user-provided GRIP UP pre-M7 implementation report for input profiles, physics caps, climbing modes and current First Ascent.
- Existing source/test files and manifests are to be inspected by the implementing agent. This specification does **not** claim to have independently inspected the live repo or executed new Godot tests.
