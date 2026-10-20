# GRIP UP — Auto-Tuning Evaluator Reliability
## v1.3.1 Technical Specification: Catch Reproduction, Lateral Control, Stopping and Baseline Trust

**Status:** Implementation-ready diagnostic and evaluator-repair specification. **No implementation, repaired benchmark, optimization result, or human playtest is claimed by this document.**  
**Language:** English. **Scope:** evaluator and benchmark reliability **before** further automated tuning, reinforcement learning, or reactive challenge M7.  
**Project:** `E:\Godot Games\grip_up` (canonical), `C:\Users\Wynter\grip_up` (reported work mirror).  
**Reported engine:** Godot `4.7.2.stable.steam.ed1daf0bf`, integrated Jolt; primary 120 Hz, comparison 60 Hz. Verify against the checked-out project before running anything.  
**Source of truth:** the user-supplied *GRIP UP — Physics Auto-Tuning Lab v1.3 report* dated 20 October 2026, the preserved v1.3 study receipts, and the actual repository. This specification deliberately supersedes no physical locomotion or game-design specification.

---

## 0. Executive decision

**Keep A0/B1 as the playable reference and suspend parameter searches. Repair the evaluator, not the climbing character.**

The v1.3 pilot was correctly halted after its second random candidate failed a real Swing & Catch target in reproducible 120 Hz headless evaluation. However, the original A0/B1 reference **also** failed the same catch in a native/rendered scripted run. The evaluator therefore cannot yet support a reliable optimization decision on this critical task. The lateral task also yielded negative commanded progress for every trial, and the stop-distance metric was undefined in every episode.

The next job is not “get better optimization scores.” It is to determine whether the benchmark asks a valid question, measures that question correctly, and gives results consistent enough to compare configurations fairly.

### Acceptance goal

Deliver an **auditable, versioned evaluator v1.3.1** that:

1. Explains or isolates the headless/native Swing & Catch discrepancy using synchronized input, physics and acquisition traces.
2. Provides **two distinct lateral tests**: command response from a valid stabilized hanging state, and reversal against an explicitly specified initial swing.
3. Measures **stop, reversal, and settling** with explicit finite / censored / invalid outcomes instead of treating `null` as zero or quietly discarding it.
4. Establishes an appropriately bounded 60/120 Hz and headless/rendered reproducibility envelope, separating exact setup equivalence from acceptable physical outcome variation.
5. Makes the baseline, fixtures, metrics, and evidence defensible **before** any new candidate generation or TPE run.
6. Preserves original gameplay code, physics authority, prior evidence and experiment identity.

**A successful deliverable can conclude `EVALUATOR_NOT_READY` if a real discrepancy remains. Never modify physics, geometry, thresholds or the scoring tape merely to force a PASS.**

---

## 1. Verified reported findings and epistemic boundaries

These are **facts from the v1.3 report**, not fresh measurements performed for this spec.

| Finding | Reported evidence | Consequence |
|---|---|---|
| Playable reference | Profile 4, A0 allocation, **B1 physical feet enabled** in the tuning evaluation. Normal game startup remains profile 2. | Always select and record the comparison profile explicitly. |
| Reference preserved | Tag `baseline/pre-v1.3-auto-tuning`, commit `f865ebf3a95eac983329d43df1a90dd1b7952bbd`. | Do not rewrite the original reference. |
| Experimental study frozen | Commit `1b0a86272a2939452dbe14130df25cde40278a82`; original `stage1_r1`, `train_tape_r3`. | Archive it read-only; evaluator changes require a new study ID. |
| Search outcome | 3 reference runs, 2 random proposals, 1 reproduced failure; 6 evaluator runs / 42 episodes; **0 finalists**. | Do not resume the old study or call the random trials finalists. |
| Headless 120 Hz A0 catch | 3/3 legitimate contacts and retained captures; useful displacement 0.40555 m. | Baseline in that exact mode succeeded. |
| Rendered/native 120 Hz A0 catch | 0/1; `NO_REAL_CATCH`; displacement 0.19213 m. | **Critical mode discrepancy**, no proven cause. |
| Random 2 catch | 0/2 headless and 0/1 native; `NO_REAL_CATCH`. | Known failure, not evidence of cross-mode candidate disadvantage by itself. |
| Lateral task | A0 −0.06679 m at 120 Hz; Random 1 −0.06447 m; Random 2 −0.03594 m; goal missed throughout. | The tape tests reversal from a residual swing, not clean lateral response. |
| Stop-distance | `stop_distance_m` was `null` in every scenario. | Current benchmark has **no demonstrated stop-distance measurement**. |
| Frequencies | Smoke results at 60/120 Hz differed materially in one-hand hang and catch; no candidate validation across both. | Do not demand bit-for-bit equality, but do require attributable setup and outcome evidence. |
| Scoring caveats | `overshoot_m` counted movement while a command was still actively held; previous lateral r2 accidentally counted grounded walking. | Preserve flawed historical results with clear `superseded/contaminated` labels. |
| Search machinery | Optuna/SQLite, runner, overrides, Pareto and holdout definitions exist; holdouts not physically opened. | Reuse infrastructure without starting optimization. |

**Never report** that A0 is optimal, that a candidate improved gameplay feel, that Jolt itself caused the native failure, that the old 120 Hz headless and rendered runs had exactly identical tick-level inputs, or that all 60/120 Hz trajectories must be numerically identical. These were not demonstrated.

### Prior study identity and source hygiene

Preserve `docs/validation/auto_tuning/` archives and their historical hashes. The v1.3 report records a driver hash `19d2f0b93cbf3501dfd05c02d0d46da958cde3307c62b015db254a978f6b2713` and public training tape r3 SHA256 `67c9af636ba97c55846e86d8992e46ed04d2bcdb2153ec9b23dfe1161f25c553`. Do not assert that these hashes match a current checkout without verification.

The existing historical report also documents GDScript warnings (`INCOMPATIBLE_TERNARY`, `INTEGER_DIVISION`) in the diagnostic laboratory. Fix such warnings **only in a new commit**, with a targeted behavior-parity check, rather than quietly altering frozen receipts.

---

## 2. Scope, controls, invariants and explicit non-goals

### In scope

- Evaluator input/replay, timing and provenance instrumentation.
- Diagnostic traces of grip selection → pending reach → real contact → retention.
- Fixed-purpose lateral, braking, inversion and settling fixtures.
- Read-only movement/force/contact telemetry and per-event comparison tools.
- A new, versioned public benchmark suite and its acceptance criteria.
- Tiny, **evidence-motivated** fixes confined to evaluator/test-harness logic.
- Sensitivity *readiness* and baseline certification; sensitivity probes are conditional and are **not** an optimizer search.

### Out of scope

- Changes to the player's locomotion algorithm (A0/A1), arm actuator, swing motor, ground motor, grip integrity, foot solver, hybrid top-out, IK, camera gameplay behavior, or game balance.
- New handholds, boosted attachment range, extra body forces, altered mass/colliders/gravity/Jolt constants, input assistance, target autoselection or scripted wins.
- Implementing M7, a dynamic-platform top-out, RL, TPE, parameter promotion, or a new optimized controller.
- Opening/using private holdouts to tune public scenarios, or conflating scripted drivers with humans.

### Physical boundaries — must remain unchanged

| Quantity | Reported fixed value |
|---|---:|
| Main `RigidBody3D` mass | 12 kg |
| Anatomical acquisition reach | approximately 0.65708 m |
| Combined hand force budget | 360 N |
| Physical feet | 180 N total, 120 N per foot |
| Shared attitude/swing assistance | 20 N·m |
| Combined climbing moment | 150 N·m |
| Arm spring / axial damper | 6000 N/m / 220 N·s/m |
| Virtual intent acceleration / horizon | 1 m/s² / 0.18 s |
| Planner displacement envelope | 0.055 m |

Current engine/resource inspection must confirm these values. Any discrepancy halts the setup and is recorded; **do not silently rewrite resources** to match this document. Session-local v1.3 tuning overrides must be disabled for reference runs unless explicitly running a named historical comparison.

No pending hand target may apply force. Actual `ATTACHED` contacts and loaded feet are distinct from visual IK and proximity probes. Hybrid assisted traversal is not evaluated as fully dynamic climbing. Dynamic objects receive genuine equal/opposite reactions where applicable.

### Baseline preservation

- Original v1.3 report, failed attempts, JSON/CSV/PNGs/SQLite and study archive are immutable.
- Implement changes on a **new** branch, suggested `feature/v1.3.1-evaluator-reliability` (not an assertion that this branch exists).
- Do not overwrite `stage1_r1`, r2, r3, holdout files or existing results.
- Maintain canonical/mirror source parity and protect Janga's original grabber.
- Preserve runnable reference builds; an exporter smoke does not substitute for a real gameplay test.
- Normal startup after each trial: reported profile 2, A0, 120 Hz, observer/auto-tune drivers OFF.

---

## 3. Core architecture: evaluator with a shared physics-tick contract

```text
Offline diagnostic CLI / Godot MCP scripted renderer
                      |
        Frozen manifest and scenario revision
                      |
         Shared Input-Tape Interpreter
         (commands indexed by physics tick)
                      |
         Real Game Input / Grip Pipeline
                      |
         A0/B1 Motor + Native Jolt World
                      |
        Read-only Tick Snapshot Provider
             |                 |
     Contact Event Trace   Continuous State Trace
             |                 |
              Trace Comparator
                      |
       Outcome Classifier + Gate Summary
```

The **same business-logic command tape and scenario setup** should drive headless and rendered test modes, while the actual world and physics are still allowed to evolve naturally. Prefer to advance testing scripts in `_physics_process` or the existing fixed-tick runner, not through render-frame callbacks or wall-clock sleeps.

### Tick-input semantics (required)

At every physics tick, record separately:

1. Tick index; fixed `delta` and monotonically accumulated physics time.
2. **Requested** input and the exact tick at which it was emitted.
3. **Accepted** input/command after routing, focus handling, profile/state gates and buffering.
4. Mouse position, camera pose/ray, intended collider and chosen material point if selection matters.
5. Result of the targeting/eligibility query and reason for rejection if any.
6. Grip states and contact events, including release/attachment order.
7. Physical state observed before and after the physics integration when feasible with consistent hooks; never compare different phases as if simultaneous.
8. Scripted driver policy version and any state-dependent decision, including its observation.

**No unrecorded input adaptation:** a closed-loop scripted driver may react to the candidate's *actual current state* using one fixed versioned policy. It may not secretly vary thresholds or choose a different target for A0 versus a candidate. If physics divergence causes a ray to select a different surface, report `TARGET_DIVERGENCE` instead of blaming movement quality alone.

### Instrumentation is read-only

Prefer reuse of `locomotion_observer.gd`, `capture_trace.gd`, `transfer_diagnostics.gd`, and existing optimization telemetry rather than duplicate observers. Observers must not affect contact detection, collision layers, input timing, physics forces, camera position, grip targets or body movement. Measure instrumentation cost and run paired observer OFF/ON sanity tests.

---

## 4. E1 — Swing & Catch discrepancy investigation

**This is the blocking investigation.** The report's successful headless A0 catch and failed native A0 catch are not to be explained by assumption.

### 4.1 Preserve and reproduce before changing anything

1. Reproduce frozen A0/B1 at 120 Hz using the old public `train_tape_r3` and the archived engine/revision, if available. Record whether exact reproducibility is possible; if not, identify what differs.
2. Run *the same catch episode alone* in both modes, then run it **as episode 5 of the seven-episode sequence**. This distinguishes per-episode behavior from session/order/warm-start effects.
3. Repeat with clean process and fresh world per episode. Keep seed, profile, B1 flag, detector configuration and tape revision identical.
4. Include A0 baseline as the primary investigation. The known Random 2 may be used as a **negative diagnostic reference**, not as a fresh tuning contender.
5. Capture actual render/native scripted inputs and physics ticks, rather than relying on screenshots or a claim that Godot MCP “pressed the same buttons.”

Minimum initial matrix at 120 Hz (proposed 3 repetitions per cell; budget can be reduced only with a documented resource limit):

| World/sequence | Headless | Rendered/native |
|---|---|---|
| Isolated Swing & Catch, clean process | 3 | 3 |
| Catch within all seven episodes, fresh world per episode | 3 | 3 |
| Recorder OFF reference, outcome only | 1 | 1 |

Once source cause is isolated, confirm at 60 Hz with the **same semantic input timing**, translating event times to each frequency's tick grid. Do not interpret 60 Hz as tick-by-tick equivalent to 120 Hz.

### 4.2 Compare initial conditions, not just outcomes

Before each episode's first gameplay tick record:

- Verified code, engine, Jolt backend and relevant scene/script/resource hashes.
- Physics tick rate, process/render execution mode, physics interpolation, `max_physics_steps_per_frame`, any fixed-FPS/engine-time-scale settings, startup order, run seed and trial number.
- Body transform, linear/angular velocities, current contact manifold or at least native support/contact IDs, sleep state and collision shapes.
- Hand states `FREE/REACHING/ATTACHED/SLIPPING/RELEASED`, actual anchor collider/point/normal (support-local and world), intended target and reach envelope.
- B1 support state and actual foot forces, not just feet ON.
- Camera pose, cursor ray, target collider/shape and all input binding/focus state.
- Any inherited buffered grip intents, cooldowns, swing histories, controller memory or scenario warm-up phase.

A meaningful paired result requires the same **declared initial-state contract**. If the game cannot produce comparable natural starts in the two modes, label the case `SETUP_MISMATCH`, report its first cause, and stop scoring its performance difference.

### 4.3 Capture a time-aligned chain of custody for the catch

Required ordered event stream:

`REQUEST_SELECTED → TARGET_LOCKED → REACHING → ENTER_REACH_WINDOW → PATH_CLEAR → CONTACT_VALIDATED → ATTACHED → LOAD_ADMITTED → RETAINED / SLIPPING / RELEASED`

Not every case will reach every event. That is the point. Record the **first missing or divergent transition**, not just `NO_REAL_CATCH` at the end.

Include:

- Distance shoulder-to-contact, effective reach threshold and measured hand approach speed.
- Reach window entry/exit times and durations; selected target ID and collider material identity.
- Occlusion / path sweep result and rejection reasons.
- Actual hand/shoulder/target velocities including target support velocity.
- Actuator request, accepted force, shared cap state and grip integrity transition.
- Distance between wrist/palm and target at closest approach; contact normal when present.
- Physical COM velocity, support-relative position, angular velocity and pendulum phase.
- Tick/event ID when the two traces first cease to agree behaviorally.

Use a focused per-physics-tick high-fidelity ring buffer around targeting and the expected catch window, not unbounded recording for an entire long course. Keep an event summary for all episodes; write raw high-resolution windows to trial-local compressed files.

### 4.4 Controlled isolation of causes

Test **one variable at a time**, with paired captures and manifests:

1. Input schedule: render-frame event dispatch vs fixed-physics-tick injection; focus/mouse-up and one-tick buffering.
2. Startup/scene lifecycle: direct scene versus control-panel route, fresh process versus reused instance.
3. Camera and pointing ray: screen-space coordinates, viewport/window size, projection, camera interpolation and final material point.
4. Physics stepping: fixed delta, accumulated wall-clock pauses, dropped/catch-up physics steps, frame cap, physics interpolation (visual interpolation must not become authority).
5. Episode order and initial state: single catch vs seventh/preceded episodes, old support memory, residual velocities and Jolt contact state.
6. Timing of grip reach and attached contact relative to physics ticks; do not increase anatomical reach or hand gesture speed to hide timing errors.
7. Observer effects: trace capture OFF/ON using unchanged control and scene geometry.

Never declare a root cause from a single correlation or a visibly different screenshot. Confirm any alleged cause by toggling only that cause (or by proving that input/state traces converge when corrected), then reproducing the previously failing case.

### 4.5 Outcomes and severity

- `CAUSE_IDENTIFIED_AND_FIXED`: evaluator/source-of-input bug fixed; original locomotion preserved; paired gate met.
- `CAUSE_IDENTIFIED_NOT_FIXED`: exact cause and constrained impact documented; optimizer remains blocked for catch-dependent claims.
- `SETUP_MISMATCH`: two modes did not test equivalent starting conditions; repair setup before scoring.
- `PHYSICS_DIVERGENCE_EXPLAINED`: identical setup and event semantics but contact outcome bifurcates at a measured sensitive threshold; report frequency/robustness envelope and improve fixture diversity, **not** force numerical identity.
- `UNRESOLVED`: continue to block tuning.

A candidate with a clean headless trace and missing rendered capture cannot be called universally superior. The validator may certify a **restricted headless-only diagnostic fixture** but must label it unusable for gameplay improvement claims.

---

## 5. E2 — Lateral movement: split intent response from inertia management

The old r3 lateral result is preserved as a **valid negative outcome for its own tape**, not automatically a bad A0 controller. Do not turn the failed negative into success by changing the goal after results are observed.

### 5.1 Two new public fixtures

#### `lateral_clean_v1` — stabilized hanging lateral control

- Two physically valid hand anchors on a static support, no native ground walking authority, feet B1 declared and measured (or a separately named feet-OFF comparison).
- Build the entry from genuine attachment physics or a formally declared synthetic initialization. If synthetic, label it `FIXTURE_SYNTHETIC`; do not call it a natural human acquisition.
- Observe until support-relative lateral velocity and body angular velocity fall inside **predeclared low-motion bands for a sustained window**; do not freeze the body, zero velocities or teleport after scoring begins.
- If it cannot settle under those bands without intervention, classify `PRECONDITION_NOT_MET` and collect diagnostics instead of altering the support or claiming a valid start.
- Apply a held A or D command over a fixed physics-time window. Mirror left/right to detect directional bias.
- Measure signed lateral COM displacement in the true support frame at 0.25/0.50/1.0 s and at episode end, command-onset latency, path length, twist and grip retention.

#### `lateral_counter_swing_v1` — direction reversal against inertia

- Same actual supports and physical authority; start with deliberately measured lateral velocity **opposite** the coming input, produced through a reproducible supported swing or clearly named fixed-condition preparation.
- At `t0`, verify that initial signed velocity is opposing the intended direction and within a pre-registered speed interval.
- Apply opposite command and measure **deceleration, first velocity sign crossing, displacement before crossing, first sustained positive progress, and recovery time**.
- Preserve the old r3 counter-swing tape as historical comparator; new fixture has its own ID, revision and provenance.

### 5.2 Lateral measurement rules

For each sample define:

- `d_lateral`: unit lateral axis in the actual support frame frozen at input onset (also log live support-frame projection as an auxiliary metric).
- `x(t)`: physical COM position, not skeleton/IK root.
- `v_d(t) = dot(v_COM(t) - v_support_at_COM(t), d_lateral)` when support velocity matters.
- `progress(t) = dot(x(t) - x(t0), d_lateral)` for static support, with documented material-relative integration for moving supports.
- `reversal_crossing`: first zero/sign-crossing with a minimum persistence/velocity band to avoid counting noise as recovery.

Never count grounded walking as lateral *climbing*. If native ground authority is present, the case is either `INVALID_SUPPORT_STATE` or a separately declared mixed-support test. Preserve negative progress, and **separate direction-following from inertia-overcoming scores**.

### 5.3 Pass/fail interpretation

A negative clean-start progress is a **controller response finding** only if the start was valid, the requested command was accepted and the support-relative direction was measured correctly. A negative counter-swing progress at a short time window may be expected; the important result is whether/when velocity and longer-horizon progress recover.

Do not require both tests to exhibit identical displacement, or penalize the pendulum merely for rotating.

---

## 6. E3 — Stop / brake / neutral / reversal: make every metric observable

The old `stop_distance_m = null` does not mean zero stopping distance. Replace its use as a ranking value with explicit outcome status and a measured window.

### 6.1 Required challenge tapes

| ID | Phase sequence | Primary question |
|---|---|---|
| `stop_release_v1` | Gain reproducible motion → input **neutral** → observe | Does motion eventually settle without active input? |
| `brake_counter_v1` | Gain motion → issue commanded opposite effort for a fixed window → observe | Can the player deliberately reduce existing motion? |
| `reverse_command_v1` | Gain directed motion → command opposite direction → observe | How quickly does useful velocity reverse? |
| `stop_low_energy_control_v1` | Begin with low verified motion → neutral → observe | Does the event detector detect known small-motion windows? |

Use both supported one-hand swing where appropriate and a two-hand traverse where a real stop is physically plausible. Distinguish *neutral* from active braking; a pendulum left neutral may keep moving for longer than an arbitrarily short window. Explicitly check that one-hand fixtures have the intended loaded-hand/foot support state; B1 feet can otherwise carry load during nominal “hang.”

### 6.2 Define measurements prospectively

At command transition `t0`, capture support-relative speed, COM and support frame. For each tape:

- **Release drift distance:** signed and absolute integrated motion after the neutral transition until settled or deadline. This is not equivalent to overshoot while W/A/D remains held.
- **Active braking distance/time:** until speed decreases through predeclared fractions of initial speed, while opposite effort is commanded.
- **Reversal time:** from accepted opposite command to velocity exceeding a signed positive threshold for an uninterrupted confirmation window.
- **Settling time:** first instant from which speed stays within predeclared translational and angular bands for the full confirmation interval.
- **Stop distance:** travel between accepted stop request and confirmed settling (if achieved). Also report displacement at fixed horizons, even if settling never occurs.
- **Overshoot after stop:** motion past a declared spatial stop target **only after stop was actually requested**, separately from goal-corridor overshoot under held movement input.
- **Oscillation:** supported swing amplitude decay and per-cycle velocity/energy proxies; do not conflate reduced motion with eliminated physics.

Thresholds must be chosen from sensor noise, task meaning, and reference pilot traces **before** comparing tuning candidates. The former 0.25 s confirmation duration may be retained or revised with documented calibration; do not silently alter it to manufacture more non-null values.

### 6.3 State and censoring contract

Every metric returns an explicitly typed outcome:

```json
{
  "metric": "stop_distance_m",
  "status": "CENSORED_TIMEOUT",
  "value": null,
  "observed_duration_s": 2.0,
  "observed_path_length_m": 0.41,
  "reason": "settling condition not maintained before observation deadline"
}
```

Allowed status values:

- `MEASURED`: full physical criterion satisfied in the recorded interval; value finite.
- `CENSORED_TIMEOUT`: observation was valid but criterion not reached before deadline; report partial path and duration.
- `INTERRUPTED`: grip lost, collision/other event changed the task, player/test ended or authority switched; report event.
- `PRECONDITION_NOT_MET`: required initial speed/support or target state was not achieved.
- `INVALID_MEASUREMENT`: timestamp, frame, phase or data integrity invalid; report exact reason.
- `NOT_APPLICABLE`: no stop/reversal requested by the declared tape.

No metric silently maps a censored or invalid outcome to **0.0**. Do not substitute an arbitrary large penalty into raw telemetry. If a later optimizer needs a bounded ranking surrogate, define that in a separate explicitly versioned scorer after trust certification.

### 6.4 Detector tests

Create synthetic unit traces with known onset, release, monotonic deceleration, underdamped oscillation, threshold chatter, temporary settling, sustained settling, interruption and timeout. Verify value, unit and status exactly. Also test real physical episodes at both tick rates; synthetic traces verify the metric algorithm, not the game's braking ability.

---

## 7. E4 — Cross-mode and cross-frequency reliability

### 7.1 Compare like with like

There are **three separate comparisons**:

1. **Exact manifest/setup identity**: schema, resources, trial input policy, knobs, geometry, seed, startup flags, requested tick rate. Any mismatches must be recorded, never normalized away.
2. **Same-frequency headless vs rendered**: compare accepted event timing, real acquisition transitions and physical state through the catch window using the same tick-indexed driver. A critical discrete difference requires explanation or a block.
3. **120 Hz vs 60 Hz**: compare outcomes and time-normalized distributions, **not identical tick numbers, velocities or event-frame indices**. Discrete action semantics, physically possible contacts, and safety invariants must be stable enough for the declared claim.

Run with instrumentation enabled and disabled; annotate CPU/dropped-step evidence. A rendering FPS difference is not proof that Jolt is responsible; investigate accepted tick inputs and initialization first.

### 7.2 Comparison trace format

Minimum fields in each per-tick record:

```json
{
  "schema_version": "1.3.1",
  "run_id": "unique-trial-id",
  "scenario_id": "swing_catch_train",
  "scenario_revision": "verified-at-runtime",
  "engine_mode": "headless",
  "physics_hz": 120,
  "tick": 123,
  "physics_time_s": 1.025,
  "sample_phase": "after_controller_before_physics_or_verified_equivalent",
  "command_requested": {"left_hand_held": false, "right_hand_held": true, "w": 0, "a": 0, "d": 1},
  "command_accepted": {"right_hand_held": true, "intent_lateral": 1},
  "target": {"collider_id": "stable-fixture-id", "material_local_point_m": [0, 0, 0]},
  "hands": {"right": {"state": "REACHING", "attached": false}},
  "body": {"com_m": [0, 0, 0], "linear_velocity_m_s": [0, 0, 0]},
  "contact_events": [],
  "diagnostic": {"first_difference_reason": null}
}
```

All numeric values and IDs above are **illustrative schema examples**, not recorded game data. For every sampled physical phase, identify whether the values are pre-step or post-step. Use stable **fixture-specific collider labels** plus actual runtime IDs; raw object instance IDs may differ across process launches.

### 7.3 Comparator behavior

- Verify hashes/schema/step schedule first; classify `NOT_COMPARABLE` rather than produce a spurious trajectory error.
- Compare command and event sequences in event-time units; allow declared tick quantization when comparing 60/120 Hz.
- Locate the **earliest divergence**: setup → requested input → accepted input → ray/target → reach → contact → support load → resultant motion.
- Quantify positional, velocity and event-time differences **after** ensuring equal sample phases.
- Report individual contact-event disagreements even when final COM displacement happens to be similar.
- Avoid hiding different task completions in a mean/standard deviation of path lengths.
- Do not require bitwise-identical Jolt trajectories across different physics frequencies or real-time render conditions.

### 7.4 Repetition and thresholds

A proposed **minimum release qualification**:

- **Catch:** at least three clean A0 reference repetitions per headless and rendered condition at 120 Hz, and three per condition at 60 Hz **once the cause is understood**. Record valid initial-state matching; publish success rates and first divergence. If outcomes still disagree critically, the optimization gate remains closed.
- **Lateral:** repeat each left/right mirror with stabilized and counter-swing starts, both frequencies and both modes where supported. Ensure each fixture can actually enter its specified precondition.
- **Stop/reversal:** all detector unit traces pass; real episodes produce a declared `MEASURED`, `CENSORED_TIMEOUT` or other explicit outcome, never unexplained `null`.
- **Invariant checks:** no illegal contacts, force/reach budget violation, NaNs or unauthorized movement.

Do **not** invent strict 1 mm / 1 frame physical-equivalence thresholds without calibration. Derive prospective numeric tolerance bands from repeated A0 traces, task geometry (e.g. reach/catch margins), event timing and sensor resolution, and freeze them in the **new benchmark contract** before viewing new candidate results.

---

## 8. E5 — Metric validity, benchmark contamination and scoring safety

### Metric definitions to repair

- `overshoot_m`: distinguish **held-command corridor excursion**, **post-stop overshoot**, and **post-reversal counter-motion**; never use one ambiguous field to score all three.
- `stop_distance_m`: use the typed status contract above; partial observation remains visible.
- `useful_progress_m`: signed COM projection in a declared fixed support-relative frame; do not clamp negative progress.
- `directional_efficiency`: progress / COM path length only above declared epsilon; otherwise `UNDEFINED_NO_MOVEMENT`.
- `catch_success`: actual `ATTACHED` event **and** retention window; selection or a pending target is not a catch.
- `one_hand_hang`: report loaded feet and ground contact. “One hand” does not imply hands-only suspension with B1 enabled.
- `swing_braking`: distinguish actual negative incremental work in the chosen pendular degree of freedom from mere opposite-button press; document partial work estimation.
- `jerk`: record whether target acceleration derivative or body acceleration derivative; exclude or tag legitimate contact impulses, not all spikes.
- `assisted_traverse`: flag hybrid ownership separately and exclude it from dynamic locomotion optimization measurements.

### Benchmark versioning contract

Keep:

- `train_tape_r2`: historical, contaminated by ground walking on lateral task.
- `train_tape_r3`: historical, valid as measured but confounded by counter-swing and missing stop observations.
- `benchmark_eval_v131`: **new** public evaluation definition, not a rewrite of r3.

On each new fixture record `fixture_id`, `revision`, world geometry hash, start-state setup policy, input driver hash, eligible support states, phases, metric formula version, threshold contract, expected failure modes and physical tick schedule.

Publish a **migration table** mapping old episode names to new fixtures with `non_equivalent` when meanings differ. Do not compare v1.3 scores and v1.3.1 scores as if they share the same rubric, and do not carry the old score's thresholds forward without revalidation.

### Holdout protection

Private holdouts from v1.3 have not been physically run; leave them closed during evaluator repair. The public diagnostic catch/lateral/stop fixtures are sufficient to repair trust. If testing leaks holdout geometry into training or thresholds, record the contamination and author a new holdout split before any future generalization claim.

---

## 9. E6 — Limited parameter sensitivity readiness (conditional)

Do **not** run a new Optuna study under v1.3.1. Do **not** use the broken evaluator to compare hundreds of candidates.

Once E1–E5 pass, a **small, audit-only** one-at-a-time perturbation check may be performed to verify the evaluator detects changes and that the v1.3 four knobs actually affect intended measurements:

| Registered field | Frozen A0 reference | v1.3 approved range |
|---|---:|---:|
| `traversal_speed_m_s` | 0.25 m/s | 0.18–0.32 |
| `traversal_input_ramp_s` | 0.12 s | 0.07–0.20 |
| `traversal_target_max_rate` | 0.24 m/s | 0.16–0.30 |
| `traversal_target_max_acceleration` | 0.90 m/s² | 0.60–1.20 |

Respect the v1.3 coupled condition `rate² / (2 × acceleration) <= 0.055 m` and an input ramp spanning at least four 60 Hz ticks. Only valid, predeclared small perturbations should be tested; change **one field at a time**, keep all others at A0 and record exactly which changed. Where the coupled constraint prevents symmetric deltas, label the comparison asymmetric or skip it.

**Purpose:** prove causal observability of the evaluator and identify dead/overly sensitive knobs, **not** select a tuning winner. Do not include Random 1/2 as optimized seeds or promote any value based on these probes. If a probe fails a vital catch or a safety contract, preserve the negative evidence and stop that probe.

If the evaluator is not certified, do not run sensitivity on it; report `SENSITIVITY_BLOCKED_BY_EVALUATOR`.

---

## 10. Implementation map and proposed files

First inspect the actual tree and reuse existing functionality. The paths below are **proposals**, not claims of files currently present:

```text
tools/auto_tuning/
  reliability.py                 # orchestrates reference comparisons, no optimizer
  compare_traces.py              # manifest identity, first divergence, delta plots
  metric_contracts.py            # typed stop/reversal/overshoot outcomes
  reliability_report.py          # report writer, gates, metrics migration
  configs/reliability_v131.json  # immutable public matrix and thresholds
  tests/test_reliability.py
  tests/test_metric_status.py
  tests/test_trace_alignment.py

features/grip_up/scripts/
  optimization_trial_runner.gd   # inspect existing; add tick semantics only if needed
  optimization_telemetry.gd      # inspect existing; reuse with explicit sample phase
  locomotion_observer.gd         # read-only ring buffer and accepted command

features/grip_up/tests/
  test_catch_equivalence.gd
  test_lateral_clean.gd
  test_lateral_counter_swing.gd
  test_stop_release.gd
  test_brake_counter.gd
  test_reverse_command.gd

features/grip_up/scenes/       # add only minimal fixtures if existing ones cannot isolate causes

docs/validation/auto_tuning/v131/
  baseline_manifest.json
  benchmark_contract.json
  migration_from_v13.md
  catch_investigation.md
  movement_metrics.md
  cross_mode_report.md
  physical_review.md
  decision.md
  attempts/                     # numbered immutable raw receipts
```

Project-specific script names and command-line integration must be discovered and verified before implementing. The v1.3 report confirms a Python runner, Optuna/SQLite and a native Godot MCP Pro scene, but it does not document a generic `--reliability` CLI command; do not assume one exists.

### Python interface proposal (new commands, not currently certified)

```powershell
# After implementing and validating the new entrypoints:
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/reliability.py --suite baseline --output builds/auto_tuning/reliability_v131/baseline_001
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/reliability.py --suite catch --output builds/auto_tuning/reliability_v131/catch_001
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/reliability.py --suite lateral-stop --output builds/auto_tuning/reliability_v131/lateral_stop_001
uv run --frozen --project tools/auto_tuning python -m unittest discover -s tools/auto_tuning/tests -v
```

All commands above are **requested interfaces to implement**, not proof they work yet. Use fresh output folders and test project path discovery (`tools/project_config.py`). Never overwrite historical `stage1_r1` or resume a frozen experiment with a new evaluator implementation.

---

## 11. Data, provenance and reporting requirements

### Mandatory per-run manifest

```json
{
  "schema_version": "1.3.1",
  "experiment_name": "evaluator_reliability",
  "run_id": "unique-id",
  "scenario_id": "lateral_clean_v1",
  "fixture_revision": "real-revision-id",
  "code_commit": "verified-runtime-commit",
  "dirty_tree": false,
  "engine_id": "verified-godot-jolt-id",
  "mode": "rendered_scripted",
  "physics_hz": 120,
  "controller": {"profile": 4, "allocation": "A0", "foot_policy": "B1", "physical_feet": true},
  "override_hash": "verified-complete-baseline-parameter-hash",
  "input_driver_hash": "verified-hash",
  "initial_state_hash": "verified-hash",
  "metric_definition_version": "benchmark_eval_v131",
  "run_seed": 101,
  "observer_enabled": true,
  "data_kind": "scripted_not_human"
}
```

Keys and values here illustrate the **required semantics**. Record real hash values from source and runtime; do not use placeholder strings in accepted evidence. `initial_state_hash` should cover only stable, well-defined physical setup fields (transforms, velocities, support identity/poses, grips, effective controller state); avoid process-local object IDs or unconstrained serialization noise. Also write raw initial fields for debugging.

### Per-run outputs

- `manifest.json`: complete, validated, immutable provenance written before run.
- `result.json`: run status, scenario outcome, input/authority states, metric status objects, code/scene hashes and evidence pointers.
- `events.jsonl` / `events.jsonl.gz`: complete ordered event timeline.
- `trace.jsonl.gz`: bounded high-frequency state windows with sample-phase declarations.
- `stdout.txt`, `stderr.txt`, `diagnostics.json`: full process warnings, crashes, parser/compile warnings and callbacks.
- `screenshots/`: selected original frames for rendered runs, tied to tick/physics-time identifiers.
- `comparison.json` / `comparison.md`: aligned headless/rendered first divergence with per-field evidence and visual plots.
- `checksums.json`: SHA256 for every receipt; verify archived retrieval.
- `decision.md`: human-written or agent-generated recommendations clearly separated from hard test facts.

Writes must be atomic (write temporary, fsync where practical, rename); directories must be unique. Timeouts, crashes, skipped/inapplicable windows and missing receipts count as explicit failed or incomplete attempts. Preserve previously failed executions rather than cleaning them away.

### Label every result correctly

- `automated_headless`
- `automated_rendered_scripted`
- `manual_developer_exploratory`
- `human_controlled_playtest` **only** when a person supplied the control inputs.

Do not rename automated scripted results as a human assessment.

---

## 12. Safety and regression contracts

Every new harness feature must preserve the existing game physics and test policies:

1. No new direct writes to normal climbing body pose, rotation, linear/angular velocity during evaluated phases.
2. No body freezes, resets, teleports or synthetic contact injection within a measured phase; fixture construction is allowed **before** the measurement if explicitly documented.
3. Arm/foot forces remain within observed shared budgets, including reaction forces on real moving supports.
4. No virtual/pending grip applies force. A hand must pass actual contact validation before `ATTACHED` and admitted load.
5. Leg IK / authored mantle pose is not load-bearing data. Hybrid mantle is excluded from dynamic movement scores.
6. Valid and invalid task outcomes are measured independently of process exit status.
7. Original code hashes and default startup are restored when experimental tooling is closed.
8. No game export accidentally bundles Python/Optuna, raw experimental fixtures or private holdout files.
9. No overwrite of the Janga protected grabber or legacy comparators.
10. Existing regression suites remain green; if a new diagnostic reveals a **pre-existing** physical failure, report it separately from a change-induced regression.

For catch failures, instrument the exact reason without extending reach, making contacts stickier, lifting the body, changing the camera's gameplay targeting or repositioning a handhold. If a gameplay bug becomes unavoidably implicated, stop and request a **separate, evidence-backed gameplay-change review**; this spec does not authorize silently correcting it.

---

## 13. Milestone plan and gates

| Gate | Work | Required result | Decision if failed |
|---|---|---|---|
| **ER0 — Freeze & audit** | Source provenance, baseline reconstruction, existing runner inventory | Auditable identity of old evidence and new working revision; normal defaults preserved | `BLOCKED_SETUP` |
| **ER1 — Trace validity** | Tick input, event and state recorder, synthetic comparator tests | Complete monotonic timestamps, stable event ordering, observer isolation | `BLOCKED_TRACE` |
| **ER2 — Catch investigation** | Isolated/sequence and headless/native reproduction; causal isolation | Exact first divergence and documented root cause or bounded physical sensitivity; critical outcome gate as defined | `BLOCKED_CATCH` |
| **ER3 — Lateral fixtures** | Clean vs counter-swing, mirror controls, real support checks | Valid preconditions and signed movement/reversal measurements at 60/120 Hz | `BLOCKED_LATERAL` |
| **ER4 — Stop metrics** | Release/brake/reverse and synthetic detectors | All outcomes typed; no unexplained `null`, no conflation of neutral/brake | `BLOCKED_STOP` |
| **ER5 — Cross-mode certification** | Paired A0 repetition, comparison tolerances, runtime smoke | Evidence-based cross-mode envelope and predeclared acceptance thresholds | `BLOCKED_EQUIVALENCE` |
| **ER6 — Scoring/benchmark freeze** | New public benchmark revision, metric migration, regressions | `benchmark_eval_v131` frozen, old r2/r3 preserved and holdouts unopened | `BLOCKED_BENCHMARK` |
| **ER7 — Decision/report** | Full receipts, specialist review, recommendation | Explicit `GO_FOR_NEW_SEARCH` or `NO_GO`, limits and open risks | `NO_GO` |

**Order matters:** ER2 can proceed to diagnostic investigation even if source of discrepancy is unknown; ER5 cannot certify a new search while a critical headless/native catch disagreement remains unexplained. ER6 can publish a reliable *partial* benchmark with a `NO_GO` decision, provided it does not falsely claim candidate-readiness.

### Proposed conservative go/no-go contract

The exact thresholds must be frozen **before** new tuning candidates are inspected. At a minimum:

- All new metric/parser/unit/comparator tests pass, plus relevant original GRIP UP/Jolt regressions at 60 and 120 Hz.
- The primary A0 Swing & Catch fixture has *reproducible, valid setup* and **no unexplained success/failure disagreement** between headless and rendered modes at the same physics Hz. If an explainable numerical threshold sensitivity causes genuine divergence, characterize it and either redesign a less knife-edge **new public fixture** or exclude the original from ranking; never overwrite the original tape.
- Both lateral fixtures enter their declared preconditions and report signed progress/reversal honestly; reaching a positive goal is **not mandatory** for certifying a measurement, but the test must distinguish controlled direction-following from a forced counter-swing and must be sensitive to known-direction inputs.
- Every stopping experiment emits a typed metric status, and at least one deliberately achievable low-energy control case yields a `MEASURED` settling result to validate the real-world event pipeline. Hard real-world cases may legitimately be censored.
- No force, torque, contact, anatomy, hybrid ownership, source-protection or default-startup invariant regressions.
- Baseline variability and tolerance envelopes are declared separately for each tested mode/Hz; no fabricated global equality threshold.
- No new random/TPE optimizer trials, no candidate promotion, no unsealed holdouts, no false human-playtest claims.

`GO_FOR_NEW_SEARCH` means the evaluator is sufficiently reliable to **design a separate new study**, not that the game is now tuned, that RL is authorized or that M7 can be implemented automatically.

---

## 14. What the two specialist agents should do

### Codex / integration agent

- Audit the live repo and v1.3 archived driver before editing.
- Maintain preservation tags, branches, parity checks and unique output paths.
- Own runner/CLI schemas, metric status objects, trace alignment, comparison reports and integration tests.
- Ensure every scripted Godot/MCP event maps to an accepted physics-tick command and a declared scenario revision.
- Publish old/new benchmark migration and restore the normal startup mode.
- Never run a new optimization study under the guise of a reliability check.

### Physics / Jolt specialist

- Independently audit the catch's native contact/reach timing, body and support state, solver stepping, actuator-force exclusion on pending grips and source of any episode-order dependence.
- Confirm instrumentation reads actual admitted forces, not cached stale actuator requests. Preserve same-body top-out authority separation.
- Validate clean lateral and counter-swing preconditions, positive/negative signed motion, damping semantics, real foot load and force reaction on supports.
- Review contact-sensitive cross-mode differences without demanding impossible numerical identity.
- Sign off on any proposed diagnostic thresholds or fixture changes **before** their outcome is used to justify another search.

Neither specialist may infer “better feel” from headless passes. The designer should personally replay the baseline once the tests become credible, but human feedback is a separate gate from evaluator reliability.

---

## 15. Required final deliverables

A finished v1.3.1 handoff contains:

1. **Baseline audit** with verified source/engine hashes, frozen historical artifacts and changed-files manifest.
2. **Catch investigation report** showing per-mode repetitions, the first divergent event/tick, whether setup matched, causal tests and remaining uncertainty.
3. **Two lateral fixture reports** (stabilized and counter-swing) with real support authority, input acceptance, signed displacement and reversal results.
4. **Stop/reversal contract report** including successful measured detector/control cases, censored examples, synthetic unit tests and observed native values.
5. **Cross-mode comparison report** at 60/120 Hz, covering the same-frequency headless/rendered comparisons and time-normalized cross-frequency differences.
6. **Benchmark migration + versioned schema**, with old contaminated/ambiguous results preserved and scores never falsely compared across revisions.
7. **Regression/safety evidence** on the unmodified playable controller, including native Godot MCP Pro evidence when available.
8. **Explicit decision**: `GO_FOR_NEW_SEARCH`, `EVALUATOR_NOT_READY`, or `NO_GO` with exact reasons and any quarantined fixtures.
9. **Proposed next-study outline only if GO**: a separately authorized, limited parameter-sensitivity/random/TPE budget, using a newly frozen evaluator and untouched holdouts.

### Suggested decision page

```markdown
# Evaluator v1.3.1 — Final Decision

- Historical study: frozen, unchanged [verified SHA256/commit]
- A0/B1 gameplay: unchanged [verified source/runtime evidence]
- Swing & Catch equivalence: PASS / BLOCK / QUARANTINED
- Lateral clean: VALID / INVALID (separate from performance)
- Lateral counter-swing: VALID / INVALID
- Stop/reversal metrics: VALID / CENSORED_WITH_REASON / INVALID
- 120 Hz headless/rendered: [distribution and first divergence]
- 60 Hz headless/rendered: [distribution and first divergence]
- Original regressions: PASS / FAIL / NOT_RUN
- Private holdouts accessed: NO (or detailed incident)
- Human feel validated: NO (unless genuine human evidence)
- Search readiness: GO_FOR_NEW_SEARCH / EVALUATOR_NOT_READY / NO_GO
- Open blockers: [evidence-backed list]
```

---

## 16. Final instruction to Codex

> Implement a **diagnostic reliability revision**, not another locomotion or AI-tuning revision. Keep A0/B1 and the physics source immutable. Reproduce the v1.3 headless/native Swing & Catch discrepancy with synchronized fixed-tick inputs and traces, identify its first cause or accurately block the evaluator. Separate stabilized lateral control from counter-swing reversal. Replace unusable stop-distance nulls with typed, time-bounded measurements. Freeze a new benchmark only once the measurements are honest, run headless/rendered and 60/120 Hz paired validation, archive all passing and failing evidence, and report a strict GO/NO-GO for **a future** optimization study. Never change grip reach, force caps, scene geometry or success conditions to make evaluation results look better. Do not start TPE, RL, M7 or automatic gameplay integration in this assignment.

**End of specification — GRIP UP Auto-Tuning Evaluator Reliability v1.3.1.**
