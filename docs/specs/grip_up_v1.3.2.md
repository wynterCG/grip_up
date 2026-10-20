# GRIP UP — Evaluator Qualification
## v1.3.2 Technical Specification: Fixed-Input Replay, Adaptive Robustness, Coverage Repair, and Search-Readiness

**Status:** Proposed implementation specification, not an implementation report.  
**Project:** `wynterCG/grip_up` · Godot 4.7.2 / integrated Jolt · Windows PC · 120 Hz reference, 60 Hz comparison.  
**Intended implementers:** Codex/integration agent and independent physics/Jolt specialist.  
**Authoritative source for this request:** `report(6).md`, *GRIP UP — relatório final de fiabilidade do avaliador v1.3.1*, dated 20 October 2026.  
**Scope:** Qualify the existing offline evaluator **before** any new optimization search. Preserve the playable A0/B1 baseline.  
**Suggested development branch:** `feature/v1.3.2-evaluator-qualification` (create only after auditing the working tree).  
**Baseline identity to recover and verify:** v1.3.1 measured code `24b18d760604fffe3455c5b4c9b8b72f37577b4d`; historical v1.3 study tag `baseline/v1.3-study-frozen` → `afa04c9c322864dd75a32a1fcc6a87e6c9225864`. These are **reported** identities: verify against Git and manifests rather than assuming the local checkout matches.

---

## 0. Executive decision and philosophy

The v1.3.1 evaluator made real progress: newly prepared Swing & Catch scenarios achieved **32/32 real destination acquisitions and retentions**, clean left/right lateral motion was valid **24/24**, and stop/settling became explicitly measurable in several cases. Existing physics and gameplay regressions remained green. However, **v1.3.1 ended `EVALUATOR_NOT_READY` / `NO_GO`** for another Random/TPE study, not because the playable climbing controller failed, but because the evaluator could not yet defend numerical comparison across execution modes and did not cover important one-hand 60 Hz states.

In particular, two rendered 120 Hz catch runs selected **W+D** at tick 419 while comparable headless runs selected **W+A**. Contact, release and retention were consequently delayed by approximately 40 physics ticks, and the largest paired COM divergence was about **0.1505 m**. These are **different accepted control histories**, not a certified Jolt discrepancy. An arbitrary 15 cm equivalence tolerance would be invalid.

**v1.3.2 must answer two different questions through distinct test modes:**

1. **Fixed-input physical response:** Given the same valid world initialization and reproducibly accepted player commands, does Godot/Jolt produce a sufficiently stable result across headless vs rendered runs at the **same physics frequency**?
2. **Adaptive task robustness:** When the same versioned scripted policy observes each actual state and legitimately chooses different commands, does it complete the intended task reliably, with honest timing, contact and motion metrics?

The outputs of these modes **must never be collapsed into a single generic equivalence score**. Fixed-input replay may isolate motor sensitivity; adaptive evaluation measures end-to-end behavior. Neither alone establishes enjoyable game feel.

**Success condition for this assignment:** an independently reviewable `GO_FOR_NEW_SEARCH` **or** a defensible `NO_GO`/partial qualification with precisely scoped blockers. Do not tune the game, promote an experiment or initiate optimization in this assignment.

### Hard non-goals

- No Random, TPE, CMA-ES, sensitivity *search over gameplay knobs*, RL, Jev inference, or candidate promotion.
- No physical-controller rewrite or new Movement Coordinator (A2), B2 promotion, dynamic top-out, M7, new climbing mechanics or new level progression.
- No increase in strength, torque, reach, grip tolerances, mass modification, spring settings, adhesion or scripted body transport to rescue a test.
- No silent change in pass criteria, scenario geometry, reference run, baseline source, or private holdout scenarios after seeing outcomes.
- No claim that automated agents are human playtests.
- No requirement that 60 Hz and 120 Hz yield bit-identical trajectories.

---

## 1. Evidence boundary: what v1.3.1 established

Treat the following as **reported historical findings**, to be reproduced/audited when relevant. Do **not** present them as new v1.3.2 measurements.

| Area | v1.3.1 reported observation | Why it matters for v1.3.2 |
|---|---|---|
| Catch binary outcome | 32/32 real captures/retentions in `catch_002` across the declared conditions | Binary success has local evidence, but continuous scoring remains unqualified |
| Catch input divergence | Rendered chose W+D vs headless W+A at tick 419 in two 120 Hz outliers | Isolate accepted-command differences before attributing COM differences to physics |
| Catch motion dispersion | Example progress ~0.4506 vs 0.5342 m; peak pair COM deviation ~0.1505 m | No data-grounded global trajectory-equivalence band yet |
| Clean lateral | 24/24 valid positive signed progress | Protect this as a reference capability |
| Counter-swing right | 12/12 valid completed observations | Preserve inertia-management comparator |
| Counter-swing left | 12/12 interrupted by actual ground contact, ~1.68–1.91 s | Geometry/support confounds result; keep historical failure visible |
| One-hand 60 Hz | 24/24 relevant preparation attempts had `PRECONDITION_NOT_MET` | No one-hand stopping/braking/reversal equivalence claim possible |
| Two-hand release | ~0.115–0.117 m stop path depending on mode/frequency | Example of a measured, repeatable control; do not use as universal threshold |
| One-hand 120 Hz release | ~0.286–0.366 m rendered stop path, ~1.32–2.12 s settling | Meaningful variability requiring its own assessment |
| Metrics | Typed status codes, path lengths, settling, reverse and active-brake fractions implemented | Preserve distinctions; do not coerce unknown results to zeros |
| Instrumentation | Headless POST probe ~1.17–1.19 ms with trace ON vs ~0.27 ms trace OFF in isolated samples | Measure overhead across multiple trials; no proof this caused divergence |
| Regression | 75 Python tests, 43 Godot contract checks, 884 existing checks passed | Preserve, expand only where qualification requires it |

### Source/runtime invariants to keep

- One gameplay `RigidBody3D` of **12 kg**; original body anatomy, collision profiles and native Jolt response.
- Hand anatomical contact reach approximately **0.65708 m**; combined hand force **360 N**, foot force **180 N** total / **120 N per foot**, shared angular assistance **20 N·m**, combined moment **150 N·m**.
- A0 reference tuning: `traversal_speed_m_s=0.25`, `traversal_input_ramp_s=0.12`, `traversal_target_max_rate=0.24`, `traversal_target_max_acceleration=0.9` (source unit conventions retained).
- Explicit test configuration: **profile 4, A0, physical feet B1**; ordinary startup remains **profile 2** with historical defaults.
- Actual hand material points, valid grip states, honest pending zero force, native support authority, physical foot reactions and unmodified hybrid top-out isolation.
- Physics mutations confined to existing controllers; test-only readers/recorders may not change game physics.
- Original Janga grabber, prior build and current source snapshots protected; C:/E: mirror parity checked where applicable.

Any deviation requires a separately authorized gameplay change; this specification does not grant one.

---

## 2. Architecture: two evaluation lanes, one truth source

```text
                         Frozen scenario + source/engine manifest
                                           |
                             Fixed physics-tick test runner
                                           |
                +--------------------------+---------------------------+
                |                                                      |
     LANE R — Fixed-input replay                            LANE A — Adaptive policy
     Recorded command chronology                            Frozen state-reactive policy
     No branch-on-live-state input                            Branches on real observations
                |                                                      |
                +--------------------------+---------------------------+
                                           |
                  Existing input routing / acquisition / physical actuators
                                           |
                         Unmodified A0/B1 gameplay + Jolt
                                           |
                 Per-phase snapshots + accepted-command + contact events
                                           |
                    Integrity checker / first-divergence comparator
                                           |
                   Separate R-equivalence and A-robustness reports
                                           |
                         Independent search-readiness decision
```

**Lane R and Lane A must share** the same audited world construction, physics clock contract, observation schema, clean process isolation and safety monitors. They differ **only in how requested inputs are generated**. No lane may force `ATTACHED`, inject body velocity, pin a hand, overwrite a transform, or claim collision clearance absent actual native evidence.

### 2.1 Do not confuse three input layers

1. `REQUESTED`: proposed logical action/cursor input from a tape or scripted policy.
2. `ACCEPTED`: what the real input router and gameplay state gates actually accepted for this physics tick.
3. `EFFECTIVE_ACTION`: consequence after targeting/raycast/grip validation, for example `REACHING`, material point selected, real `ATTACHED`, hand actuator effort.

A replay that reproduces only `REQUESTED` commands is a **requested-input replay**, not proven accepted-command identity. The instrumented comparison must verify equality of the accepted stream; otherwise label the first mismatch and **block the physical-response equivalence claim from that tick onward**.

### 2.2 Two replay levels; require a transparent choice

**R0 — End-to-end input replay (required).** Record and replay action holds/releases, normalized cursor coordinates or exact input-event coordinates as supported, mouse/camera controls and their physics-tick scheduling through the **normal input path**. This measures behavior of the full real acquisition and movement system. Compare `ACCEPTED` streams and material-target outcomes; do not force them equal.

**R1 — Accepted-command seam diagnostic (optional, high value).** Only if a genuine, audited input-controller seam exists, inject a previously accepted *logical intent* after the input-router normalization but **before** ordinary grip validation and actuator force calculation. It must still honor current live grip eligibility, distance, contact, load, slips, collisions and support changes. If the seam would require bypassing these checks or modifying gameplay, do **not** implement R1; record `UNSUPPORTED_SEAM` and use R0. R1 must never simulate contact by reusing a historical `ATTACHED` value.

R1 and R0 have separate manifest identifiers and outcomes. Their data may not be combined into one baseline distribution.

### 2.3 Camera/target fidelity

- Record camera transform, ray origin/direction, cursor position, target stable fixture ID, actual runtime collider ID, material-local hit point, selection/reach phase and disqualification reason.
- In R0, replay real camera/orbit/cursor commands rather than pasting historical ray hits into the targeting solver.
- If different body/camera states produce different targets despite identical requested inputs, classify `TARGET_OR_CAMERA_DIVERGENCE`; do not call it a physical-controller failure.
- A fixed reference camera is acceptable as an *explicit fixture condition* where it already exists or can be provided entirely by test-scene setup; never silently reorient the player's camera to secure a catch.
- For fixed replay, distinguish state-sensitive target and controller interactions from input identity. Same controls do not guarantee the same physical contact.

---

## 3. EQ0 — Freeze, audit and experiment identity

Before any modification:

1. Verify the local branch, source commit, engine/Jolt version, current game startup and resource A0 values against v1.3.1 report and manifests. Fail on unexplained differences.
2. Create a **recoverable baseline tag** for the exact pre-v1.3.2 source; do not rewrite the historical v1.3.1 or v1.3 study tags.
3. Inventory v1.3.1 tick driver, PRE/POST recorder, `movement_metrics.md` definitions, benchmark `benchmark_eval_v131` revision 3, `catch_002` and `control_analysis_002` archived outputs.
4. Preserve prior `stage1_r1`, `catch_001`, `catch_002`, `control_analysis_001/002`, private holdouts and all failed historical receipts; never reuse their output directories.
5. Record actual source file hashes; identify all allowed evaluator-only changes in a new manifest. Gameplay physics source should be unchanged and checked against the baseline.
6. Assert default startup, remapping and profile continuity before experiments; after experiments, restore the initial project config byte for byte and rerun a normal-startup smoke.
7. Enforce a clean fixed physics step **before creating bodies**, including the previously observed obsolete callbacks at rendered 60 Hz. Do not rename a 120 Hz tick as 60 Hz, skip mismatched ticks or warm-start a world into a claimed clean condition.

A successful `completed` evaluator process is not the same thing as a successful physics task.

**Failure code:** `BLOCKED_BASELINE` or `BLOCKED_CLOCK` with relevant receipts, not a fabricated pass.

---

## 4. EQ1 — Implement a fixed-input replay recorder and runner

### 4.1 Source tape contract

Record a clean A0/B1 reference episode using the existing real input route and tick recorder. Each tape contains:

```json
{
  "schema": "grip_up_replay_v132",
  "replay_lane": "R0_REQUESTED_INPUT",
  "source_trace_id": "hash-of-canonical-trace",
  "scenario_id": "swing_catch",
  "scenario_revision": "verified-source-revision",
  "engine_build": "verified-engine-identifier",
  "physics_hz": 120,
  "ticks": [
    {
      "physics_tick": 419,
      "requested": {"w": true, "a": true, "d": false, "left_hold": true, "right_hold": false},
      "cursor_normalized": [0.51, 0.40],
      "camera_input": {"orbit_dx": 0.0, "orbit_dy": 0.0, "dolly": 0.0},
      "accepted_reference": {"intent_forward": 1.0, "intent_lateral": -1.0}
    }
  ],
  "tape_sha256": "computed-by-runner"
}
```

**All values are schema examples, not actual measured input for tick 419.** Do not derive the tape from the demonstrably divergent adaptive runs by pretending the accepted streams matched. Preserve their actual recorded values and provenance. Include held-state transitions and releases, not only sparse button-down events. Store timing as integer ticks and fixed physics time with explicit sample phase.

The recorder must preserve the source policy version, actual action bindings, focus/input gating, camera state, and target-selection observations. Handle pause/focus, synthetic inputs, event buffer and frame order explicitly.

### 4.2 Execution and audit sequence

1. Verify fresh process/world and matching scenario/physics-step manifest **before** replay begins.
2. Build body, supports and test driver after the validated rate is active; establish first comparable PRE-state and no stale physics objects.
3. Feed R0 commands in the same physics-tick order through the normal input router. Render frame cadence cannot advance logical action state.
4. Sample `REQUESTED`, `ACCEPTED`, effective targeting, grip events, supported feet, dynamic-body native state and current phase.
5. Compare accepted logical commands by tick. If they differ, report earliest mismatch and classify the physical comparison **only up to** the last comparable tick.
6. For any episode failing preconditions, mark `PRECONDITION_NOT_MET` and include evidence; never auto-correct posture mid-run.
7. Recompute metric values from stored trace in an independent parser and compare to the runtime metric output.
8. Clean up synchronously and verify no world bodies, old event queues or source overlays persist.

**Replay integrity contract:** the tape must be immutable and content-addressed. A run manifest records source-tape hash, actual accepted-stream hash, engine/mode/Hz, scene version, fixture ID mapping, reader/recorder state, clock phase and run seed. Never report `SAME_INPUTS` merely because the source tape hash is equal.

### 4.3 Identity and mismatch taxonomy

- `MATCHED_INPUTS_TO_TICK_N`: exact accepted logical command match for the stated interval only.
- `REQUEST_MISMATCH`, `INPUT_ROUTER_MISMATCH`, `CAMERA_TARGET_MISMATCH`, `GRIP_DECISION_MISMATCH`.
- `SETUP_MISMATCH`, `CLOCK_MISMATCH`, `PHASE_MISMATCH`, `OBSERVER_STATE_MISMATCH`.
- `SAME_ACCEPTED_COMMANDS_DIFFERENT_NATIVE_RESPONSE`: only when equal accepted streams, comparable initial/pre-step state and matching physical phase are proved.
- `NOT_COMPARABLE`: missing hashes, unknown sample phase, incorrect geometry, state identity or incomplete trace.

Never convert one class to another because it gives a more convenient optimization result.

### 4.4 Synthetic tests and adversarial cases

Test a dropped tick, duplicate tick, held input continued over a release, late `mouse_up`, wrong camera input, mismatched cursor, focus-loss cancellation, stale target, wrong fixture instance map, trace corruption, nonfinite value, wrong engine Hz, wrong physics phase and changed source-tape hash. Every case must fail closed with a clear reason.

---

## 5. EQ2 — Qualification of the Swing & Catch behavior

### 5.1 Frozen dual-lane protocol

Use one verified A0/B1 Swing & Catch reference scenario at **each physics Hz**. For every lane, run:

| Axis | Values |
|---|---|
| Engine mode | Headless, rendered/native |
| Physics frequency | 120 Hz, 60 Hz |
| Episode context | Isolated, after prior episodes |
| Instrumentation | Trace ON, trace OFF control; observer ON/OFF separately where meaningful |
| Repetition budget | Minimum 3 runs per primary mode × Hz × context cell, unless runtime/cost gate blocks |

The baseline case is **not** a candidate optimization. A trace-OFF run still needs a low-cost event/summary audit, and must not be reported as equivalent to a trace-ON run if the comparison evidence is insufficient.

### 5.2 Lane R questions

- Are setup and initial pre-solver physical state equivalent within documented starting tolerances?
- Are real accepted input streams identical up to the claimed comparison window?
- Is there any first divergent camera/target/raycast/hand-state event?
- If input and setup match, at which earliest integration boundary do native position/velocity/contact/torque differences emerge?
- Do both modes still achieve actual destination `ATTACHED` and retention, not merely a selected target or pending hand?
- How much COM path, signed progress and catch event time differ **within** valid aligned windows?

If accepted inputs diverge, Lane R has still supplied useful diagnostics but **has not** certified the physical trajectory after that divergence.

### 5.3 Lane A questions

Run the exact same versioned policy with honest feedback in both modes. Expect it may choose W+A in one run and W+D in another. Report:

- Task outcome: source grip released, destination captured and retained for a declared duration, actual supports loaded, no hidden floor-assisted claims.
- Probability of task completion within **this observed scenario set**, separated by mode, Hz and isolated/sequence context.
- Accepted action distribution, decision-switch counts, contact latency, grip load/retention, path variation and outlier frequency.
- First state observation that caused policy branches to disagree, with logged policy rule and thresholds.
- If a policy is too sensitive to small physical perturbations, identify a **test-policy** robustness issue, not an automatic gameplay controller defect.

Do not tune feedback thresholds to make runs match in this assignment. If the existing adaptive policy itself needs changing for diagnostic value, version it as a **separate proposed new public benchmark**, retain old outcomes and request explicit benchmark-gate review before adoption.

### 5.4 Required catch decision

Possible conclusions:

- `CATCH_R_MATCHED_RESPONSE`: strong observed fixed-input comparability for stated setup/mode/Hz window, with measured limits.
- `CATCH_R_INPUT_DIVERGENCE`: same requested tape but accepted/effective actions diverged; no downstream physics-equivalence claim.
- `CATCH_A_ROBUST`: adaptive completion is repeatably successful under the measured test conditions, with a separately declared continuous-score envelope.
- `CATCH_A_BINARY_ONLY`: capture outcome is usable but continuous scores are too variable for fair candidate ranking.
- `CATCH_QUARANTINED`: not a valid optimization objective pending redesign; retain as a diagnostic/regression test as applicable.

Quarantining a continuous catch score must **not** erase the essential real-contact/capture safety gate from future search. A candidate that fails genuine destination contact cannot get credit for larger displacement.

---

## 6. EQ3 — Repair and qualify one-hand tests at 60 Hz

v1.3.1 reports **24/24 one-hand 60 Hz cases** with unmet preconditions. These are not measured failures of the stop/brake/reverse movement: they are failures to reach the required starting state. Fix the **test setup**, not the biped's physics.

### 6.1 Distinguish preparation from task

Create a versioned, logged preparation stage:

1. Enter the intended active profile, foot configuration and same fixture surface explicitly.
2. Acquire a real hand grip through existing input and finite reach.
3. If a two-hand entry is used, release the designated other hand using the real input transition, verify its contact state and admitted force reach zero.
4. Confirm native ground-contact and foot load state required by the specific test. **One hand ATTACHED is not synonymous with pure arm-only suspension** when B1 feet can load a wall.
5. Reach the planned directed velocity band **0.15–0.50 m/s** for stop/brake/reverse, or a full velocity/spin low-energy band for low-energy controls; require the same valid physical duration used in the metric contract.
6. Record the actual PRE and accepted onset states; only then begin the evaluation window.

Do not position the character in mid-air by writing to `global_transform`, adjust grip reach or set initial velocity to pass the readiness gate. Test-scene **spawn placement before physics starts** is allowed only with a documented fixture revision and normal collision clearance, followed by a genuine dynamic preparation sequence.

### 6.2 Bounded diagnostic search for valid preparation

Test a small, **predeclared** set of lawful preparation scripts (e.g., different durations/orderings of existing W/A/D/hand-release inputs). This is fixture design, **not parameter auto-tuning**: do not alter gameplay parameters or use reward optimization. Require symmetrical or clearly labelled left/right variants. First run the same scripts at 120 Hz and inspect the 60 Hz failure causes. Check expected real hand force, foot loading, body spin, ground contact, wall clearance and elapsed dynamic time.

If no candidate enters the required preconditions after the declared budget, publish `ONE_HAND_60HZ_UNQUALIFIED` with denominator, failure reasons and traces. Do not repeatedly loosen readiness bands until one passes.

### 6.3 Required test outcomes

The release, active-brake, reverse and low-energy controls should, where entered, produce typed `MEASURED`, `INTERRUPTED`, `CENSORED_TIMEOUT`, etc. A measurement must retain the correct onset, confirmation duration and genuine dynamic forces. No `null` without status/reason. Do not credit post-brake passive damping as completed active braking.

**Gate:** the one-hand 60 Hz family is either validly measurable across both modes or explicitly excluded from candidate ranking with documented consequences. If this family is essential to the intended optimization claim, exclusion means **NO_GO for that claim**, not blanket `GO`.

---

## 7. EQ4 — Lateral movement, mirror invariance and ground contamination

### 7.1 Retain existing cases unchanged

Historical controls are immutable:

- Clean left/right: 24/24 positive signed progress in v1.3.1.
- Counter-swing right: 12/12 valid.
- Counter-swing left: 12/12 interrupted by actual ground contact approximately 1.68–1.91 s.

Do not relabel the interrupted left case as a success or delete it from historical reports.

### 7.2 Create a **new** clearance-qualified comparison, not a silent repair

Propose a new mirrored public fixture with sufficient ground clearance for both lateral counter-swing directions, **verified by swept collider geometry and actual native contacts**, and otherwise as symmetric as possible: wall, handles, span, face offset, entry procedure, camera frame and target lane. Geometry changes are allowed **only to a newly named test fixture**, never to an existing gameplay level or historical benchmark revision.

Predeclare both variants, record their source hashes and keep the old geometry archived. Validate the dynamically achieved counter-swing entry velocity band and lack of ground-motor authority. Do not allow hidden ground walking to count as sideways climbing.

### 7.3 Scoring separation

- `clean_lateral_left/right`: signed movement under stabilized preconditions.
- `counter_swing_left/right`: braking/reversal against measured prior momentum.
- `ground_interrupted`: retain onset and genuine pre-contact reversal metrics; mark later path metrics `INTERRUPTED`.
- `mirror_balance`: compare left/right distributions after transforming to mirrored local support coordinates, not world-axis signs alone.

Cross-mode comparisons only use trials with valid, like-for-like support and input conditions. Do not require equal numerical paths between two mechanically different contact configurations.

**Gate:** the new mirror fixture must enter relevant conditions at both frequencies and modes or explicitly report the missing cells. A persistent ground interruption can still be valid information, but not a complete symmetric reversal benchmark.

---

## 8. EQ5 — Stopping, braking, reversal and metric integrity

### 8.1 Preserve the truthful v1.3.1 measurement contract

Typed statuses: `MEASURED`, `CENSORED_TIMEOUT`, `INTERRUPTED`, `PRECONDITION_NOT_MET`, `INVALID_MEASUREMENT`, `NOT_APPLICABLE`.

Distinguish:

- **Release/neutral:** driver stops issuing directed effort, existing inertia persists.
- **Active brake:** an explicit, accepted opposite input attempts to reduce velocity during a declared window.
- **Reverse:** velocity crosses a declared zero/negative threshold in the target direction while valid support persists.
- **Settling:** speed and spin remain within full-band criteria for a confirmation interval of **0.25 s**; time is reported relative to the beginning of that stable interval, as described in v1.3.1.
- **Path to stop:** integrated 3D COM path from onset to confirmed stop (not merely final displacement); retain separate signed drift and max excursion.
- **Brake fractions:** time to 50% and 10% of initial directed speed **during active brake only**; a later passive settle does not fulfill an active-brake threshold.

### 8.2 Expand checks with controlled perturbations

Use synthetic event traces and real native reference cases to establish:

1. Already-low-energy control can validly report settling time zero **only** when the confirmation interval occurred after onset.
2. An active brake interrupted before 10% speed returns `INTERRUPTED`, even if later passive damping reaches rest.
3. A ground collision before reversing preserves qualified pre-contact reversal data and interrupts subsequent climb-only motion.
4. Out-of-order frames, duplicate ticks, incomplete samples and source/trace hash mismatch are rejected as invalid inputs.
5. `overshoot_m` is *not* described as user-goal accuracy where no spatial goal was specified; label it onset-referenced excursion.
6. Variable-length episodes report censoring and observation coverage; no fabricated zero distances.
7. Release/brake/reverse under one or two hands correctly report feet B1 contribution; mixed support is not renamed arm-only.

### 8.3 Pairing and comparison

For fixed-input lane, compute stop-path, settling and reversal separately with identical accepted commands while the window remains comparable. For adaptive lane, report distributions and completion rates rather than raw frame-to-frame equality.

A high variance one-hand 120 Hz condition must remain visible. The v1.3.1 rendered path range **0.286–0.366 m** and settling **~1.32–2.12 s** are motivating historical observations, not pre-approved acceptance bands for new runs.

---

## 9. EQ6 — Instrumentation effects and runtime integrity

### 9.1 Independent switches

Compare, with repeated paired runs and frozen test cases:

- Trace ON + observer ON.
- Trace OFF + observer ON.
- Trace ON + observer OFF.
- Trace OFF + observer OFF, keeping the minimal result-integrity probe needed to detect contact/outcome and step correctness.

Do not assume that turning off the recorder also disables the snapshot reader. Preserve identical gameplay-control code/parameters, world setup and intended requested commands. Never disable safety monitoring silently just to improve timing.

### 9.2 Measurements

Capture actual physics step duration, pending/backlogged steps, per-phase probe/serialization cost, whole-run wall time, frame cadence in rendered mode, CPU spikes, accepted-command divergence and task outcomes. Report average, median, tail/high percentiles or raw extrema with sample counts; do not infer statistical equivalence from a single run. Distinguish measured costs of the probe from whole-engine overhead.

If instrumented mode changes input-accepted chronology or physically affects catches, diagnose why. Observer isolation is an **empirical property to test**, not a presupposition. Isolate frame pacing/worker load with paired process ordering and clean start; avoid presenting OS scheduling conjecture as a proven cause.

### 9.3 Reference compatibility

Maintain basic tick read contracts while tracing is disabled. If a complete raw trajectory is not captured, mark the comparison dimension unavailable; do not infer that no trajectory difference occurred.

---

## 10. EQ7 — Equivalence metrics, thresholds and quarantine policy

### 10.1 Calibrate **before** new candidate data

Run A0/B1 reference trials across the required mode × frequency × scenario cells using new fixture revisions and clean process boundaries. The minimum pilot is **three repeats per cell**, but that is only a feasibility budget, not a statistically strong guarantee. Expand references if sample scatter or rare outliers prevent defensible thresholds; stop at the declared budget if unresolved and report `INCONCLUSIVE`.

Set prospective thresholds separately for:

- Initialization identity: exact source, fixture, physics rate, profile, resource and logical state; numerical initial-state bands grounded in engine/contact tolerances.
- Input chronology: accepted-state equality in Lane R for the claimed interval, with exact tick semantics at the **same frequency**.
- Event ordering: actual material contact, grip attachment, slipping/release, support and ground events; zero tolerance for an illegal contact/force assertion.
- Continuous response: COM/velocity and native contact distributions **only on accepted-input-matched windows**; use observed variance, physics resolution and gameplay-relevant margins.
- Outcomes: meaningful completion of the declared task, not merely evaluator process success.
- Across 120 vs 60 Hz: time-normalized events and outcome robustness; **no exact tick-match requirement across different steps**.

A numerical envelope must be signed off by the physics specialist **before** it is used to pass new candidate data. If 15 cm of unexplained divergence is observed, do not declare it acceptable by setting the threshold to 15 cm after the fact. An envelope derived from unstable behavior may itself justify quarantine.

### 10.2 Split certification outcomes

The decision report must explicitly classify each metric/scenario pair:

| Classification | Meaning |
|---|---|
| `QUALIFIED_BINARY_GATE` | Real contact/task success can be used as mandatory pass/fail under declared conditions |
| `QUALIFIED_CONTINUOUS_METRIC` | Numeric score is comparable under frozen conditions and validated envelope |
| `DIAGNOSTIC_ONLY` | Useful for troubleshooting, not optimization ranking |
| `QUARANTINED` | Invalid/unfair or insufficiently reproducible for the proposed search |
| `MISSING_COVERAGE` | Declared mode, frequency, hand configuration or required onset not established |

A scenario can have a qualified **binary** gate while its continuous path score remains `DIAGNOSTIC_ONLY`. This is likely relevant to Catch after v1.3.1, but v1.3.2 must still validate it.

### 10.3 Do not manufacture a favorable optimizer

- Never silently remove the sole test that reveals a loss of real acquisition, one-hand weakness or adverse movement direction.
- If a required gameplay capability cannot be measured reliably, the **search scope must be narrowed explicitly**, with a named capability not optimized, or `NO_GO` if narrowing would make the study misleading.
- Any revised evaluator receives a new immutable benchmark ID (`benchmark_eval_v132` proposed), schema, code/fixture hashes and metric formula version. Historical `benchmark_eval_v131` remains reproducible and **incomparable by default**.
- Do not inspect sealed/private holdout outcomes; schema tests that do not reveal private outcomes remain permitted when already supported by the established infrastructure.
- Report negative, failed-preparation and quarantined cells in the denominator. No cherry-picking passes from favorable modes.
- **No Auto-Tuning search in v1.3.2 itself.** `GO` authorizes planning a separate study, not silently starting one.

---

## 11. Exact validation matrix and evidence rules

### 11.1 Core matrix

| Group | Scenarios | Lane R | Lane A | Required conditions |
|---|---|---|---|---|
| Catch | Isolated and sequence, real destination retention | Yes | Yes | Headless/rendered × 60/120 Hz; trace/observer controls |
| Clean lateral | Left and right stabilized | Yes | Yes | Both modes/rates, support identity and signed progress |
| Counter-swing | Left/right new mirrored-clearance fixture | Yes | Yes | Both modes/rates; reversal before any ground event |
| Stop/settling | Two hands and one hand | Yes | Yes | Release/neutral and low-energy controls |
| Active brake | Two hands and one hand | Yes | Yes | Accepted opposite effort; 50% and 10% metrics typed |
| Reverse | Two hands and one hand | Yes | Yes | Genuine opposite-motion onset and support continuity |
| First Ascent public regression | Existing static course | As existing contract supports | As existing contract supports | No gameplay changes or hidden holdout use |
| Original physics regression suites | Pre-v1.3.2 selected coverage | N/A | N/A | 60 and 120 Hz safety and source parity |

**Minimum repeat count:** 3 independent process/world repeats per primary cell where an actual valid onset is achievable. Record insufficient coverage rather than claiming a complete matrix. For instrumentation OFF, a reduced but explicitly reported comparison matrix may be used to control cost; it cannot support strong equivalence conclusions without adequate repetitions.

### 11.2 Validation identities and comparators

Every record must have: revisioned scenario, tape/policy ID, lane, engine version, physics Hz, render/headless, startup/clock state, fixture hash, A0/B1 resource hash, camera/input settings, flags, feet load mode, hand configuration, sample phase, timeline validity, instrumentation flags, run ID, hash of raw outputs and original control-policy version.

The comparison report must provide for each pair:

1. Setup identity verdict.
2. Earliest requested-command divergence.
3. Earliest **accepted-command** divergence.
4. Earliest target/contact/support divergence.
5. Earliest physical-state divergence on a valid like-for-like phase, and its magnitude.
6. Whether differences precede or follow the first control/target divergence.
7. Continuous metrics with typed status and confidence limits described modestly given n.
8. Real task outcome, retention evidence, actual force authority and possible ground/foot contribution.
9. Artifact and run-hash pointers sufficient for a reviewer to reproduce the claim.

Never compare a PRE solver state against a POST controller state just because both share the same displayed tick.

### 11.3 Failure preservation

Any `BLOCKED_CLOCK`, `BLOCKED_INPUT`, `PRECONDITION_NOT_MET`, `INTERRUPTED`, `NOT_COMPARABLE`, engine warning, outlier or crashed process gets a unique stored receipt. A corrected rerun gets a new directory. Never delete failure receipts, rename fails to pass, ignore stale FPS callbacks or aggregate orphan results into the accepted run set.

---

## 12. Implementation map (audit first; proposed additions)

The agent must discover the **actual paths/functions in the checked-out repository** before implementation. The following are integration proposals based on the source/report; they are **not claims that the files already exist**.

**Reuse/audit existing:**

- `features/grip_up/scripts/climbing_input_router.gd`
- `features/grip_up/scripts/grip_targeting.gd`
- `features/grip_up/scripts/intent_locomotion_coordinator.gd`
- `features/grip_up/scripts/climbing_controller.gd`
- `features/grip_up/scripts/ground_locomotion.gd`
- `features/grip_up/scripts/foot_contact_solver.gd`
- `features/grip_up/scripts/locomotion_observer.gd`
- `features/grip_up/scripts/capture_trace.gd`
- `features/grip_up/scripts/transfer_diagnostics.gd`
- v1.3/v1.3.1 auto-tuning runner, catalog, trace comparator, native/MCP tooling and tests; discover exact filenames rather than guessing.

**Suggested test-only modules:**

| Module | Responsibility |
|---|---|
| `tools/auto_tuning/evaluator_qualification/replay_schema.py` | Canonical replay tape, typed fields, hashes and validation |
| `tools/auto_tuning/evaluator_qualification/replay_runner.py` | Isolated evaluation processes, R0/A lanes, repeat/mode matrix, result receipt validation |
| `tools/auto_tuning/evaluator_qualification/compare_lanes.py` | First-divergence analysis, same-Hz vs cross-Hz separation, truthful classification |
| `tools/auto_tuning/evaluator_qualification/qualification_metrics.py` | Typed stopping/reversal aggregation and eligibility diagnostics |
| `tools/auto_tuning/evaluator_qualification/qualification_report.py` | Per-scenario certification and gate report |
| `features/grip_up/tests/qualification_input_replay.gd` | Fixed tick accepted/requested snapshot and R0 injection via existing router |
| `features/grip_up/tests/qualification_fixture_prep.gd` | Bounded lawful dynamic one-hand entry and mirrored counter-swing fixtures |
| `features/grip_up/tests/qualification_probe_cost.gd` | Observer/trace switch analysis without altering controller authority |
| `docs/validation/evaluator_v132/` | Manifests, old/new benchmark migration, diagrams, raw evidence and decisions |

If existing modules already provide equivalent functionality, extend them with versioned, test-only hooks rather than duplicating stateful recorders. Production/export presets must exclude any research-only modules without breaking the game.

### Proposed commands (illustrative only; not currently verified)

```powershell
# Run from a fresh, audited checkout of the GRIP UP project.
# These entrypoints must be implemented/documented before use.
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/evaluator_qualification/replay_runner.py --lane R0 --scenario swing_catch --hz 120 --mode headless --repeats 3 --output builds/eval_v132/catch_r0_h120
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/evaluator_qualification/replay_runner.py --lane A --scenario swing_catch --hz 120 --mode rendered --repeats 3 --output builds/eval_v132/catch_a_r120
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/evaluator_qualification/compare_lanes.py --study builds/eval_v132 --output docs/validation/evaluator_v132/comparison
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/evaluator_qualification/qualification_report.py --study builds/eval_v132 --output docs/validation/evaluator_v132/decision.md
```

The implementation may use a different CLI if it is safer to extend the existing runner; document real commands. Never use the historical study's output directory for new data.

---

## 13. Milestones and pass/fail gates

| Gate | Task | Required result | On failure |
|---|---|---|---|
| **EQ0** | Freeze/audit identities and physics clock | Baseline restored, immutable hashes, startup and clock proven | `BLOCKED_BASELINE` |
| **EQ1** | R0 replay schema, recorder, tick semantics | Accepted-command audit; synthetic negative tests; no physics bypass | `BLOCKED_REPLAY` |
| **EQ2** | Catch R vs A at 60/120 Hz | Separate binary and continuous conclusions; earliest divergence attributable/classified | `BLOCKED_CATCH_EQUIVALENCE` or quarantine |
| **EQ3** | Real one-hand 60 Hz preparation | Genuine onset at declared bands or explicit unavailable coverage after bounded attempts | `MISSING_ONE_HAND_60` |
| **EQ4** | Mirrored lateral/counter-swing fixture | Symmetric preconditions, support-valid reversal tests, historical failed fixture preserved | `BLOCKED_LATERAL` |
| **EQ5** | Metric and detector qualification | Typed releases, active brakes, reversals, stop paths and interruptions verified independently | `BLOCKED_METRICS` |
| **EQ6** | Instrumentation cost and isolation | Repeated ON/OFF tests and valid stage-cost attribution | `BLOCKED_PROBE` or diagnostic only |
| **EQ7** | Cross-mode qualification, benchmark freezing and decision | Prospective score eligibility and numerical envelopes, holdouts sealed, independent signoff | `GO_FOR_NEW_SEARCH` or `EVALUATOR_NOT_READY` |

**Early-stop rule:** if a hard source/clock/input-integrity gate fails, stop score qualification and preserve evidence. Continue only tests that directly diagnose that gate. Do not consume the rest of a large matrix merely to increase the number of green checks.

### Search-readiness decision rules

`GO_FOR_NEW_SEARCH` requires **all** of the following:

1. Audited, immutable A0/B1 reference and clean setup/clock/phase continuity in both engine modes.
2. Valid R0 (and R1 if used) provenance and explicit accepted-command comparability rules; no unexplained critical mismatch classified as same-input physical divergence.
3. Catch has a qualified real-contact essential gate, with clear per-mode outcomes; any numeric catch score used for ranking is separately qualified.
4. Valid signed clean-lateral measurements and separately measured counter-swing/reversal under physically valid support, or an explicit justified capability-scope restriction.
5. Typed, independently recomputed stop/brake/reverse metrics with real valid controls and qualified missing-data handling; essential claimed hand/Hz conditions actually measured.
6. Repeatedly measured instrumentation overhead with no unresolved test-induced command change that invalidates the intended comparison.
7. Prospective, signed-off tolerances where needed; no post-hoc generous thresholds or optimizer-cherry-picked subsets.
8. Core 60/120 Hz regressions and physics constraints remain intact; default startup and export exclusions verified.
9. v1.3.2 benchmark/schema is newly frozen with historical cross-version scores explicitly non-comparable, private holdouts untouched.
10. Independent physics-specialist review plus explicit report of remaining limitations. Human gameplay quality remains **unproven** until real user testing.

If all are met except nonessential continuous metrics, `GO` may cover a **named narrow future study** using only certified metrics, with excluded objectives stated prominently. If missing measurements conceal an essential capability (such as one-hand movement intended for optimization), **NO_GO for that study**. A narrower GO must never be advertised as universal GRIP UP locomotion optimization readiness.

**No further v1.3.2 iteration by default:** If the predeclared qualification budget is exhausted and blockers remain, publish `NO_GO`, preserve the playable A0/B1 baseline and recommend either targeted human tests or proceeding with gameplay/M7. Do not start an endless chain of evaluator-reliability versions without a separate product decision.

---

## 14. Work allocation: Codex and independent physics specialist

### Codex / integration agent

- Verify actual repository identity, read existing v1.3/v1.3.1 code and archived report **before** designing interfaces.
- Own safe working branch, immutable benchmark versions, JSON/schema validation, runner, replay tape capture, result provenance, no-stale-tick guard, process isolation and unique archive paths.
- Keep R0 replay routed through existing gameplay input. Investigate a possible R1 accepted-command seam but do not invent a fake or bypass physical authority to claim success.
- Implement the two evaluation lanes, trace comparison, cost matrix, field-level first-divergence report and typed metric audit.
- Document any unavailable feature and report explicit blocker rather than silently approximating it.
- Run Godot/MCP rendered verification in addition to headless contracts, identify when input is scripted rather than human.
- Restore normal startup and protect the previous Windows executable; export exclusions and C/E parity verified.

### Independent physics/Jolt specialist

- Audit exact ordering of requested/accepted input, body creation and pre-step vs post-step states at 60/120 Hz.
- Verify actual native body state, force/torque budgets, contact state, material anchors, foot loads, grip release/retention and pending-hand zero-force condition.
- Review one-hand 60 Hz preparation for lawful physical entry; reject teleporting/velocity-setting shortcuts.
- Validate mirrored counter-swing geometry and ground interruption cause; require no unauthorized ground authority in climb-only metrics.
- Compare fixed-input replay up to the first accepted-command divergence; distinguish solver/numerical sensitivity from feedback input changes.
- Review prospective equivalence envelopes and quarantine decisions before a benchmark can be used for candidate scoring.
- Explicitly sign off on any claimed continuous-metric comparability, including cases where the correct answer is `NOT_QUALIFIED`.

These roles should independently review the same evidence, not simply repeat an automatically generated score.

---

## 15. Required final deliverables and summary schema

1. `baseline_audit.md` with Git/engine/resource hashes, old/new file manifest and restoration proof.
2. `replay_contract.md` describing R0, optional R1, accepted/requested/effective semantics and sample-phase alignment.
3. `catch_replay_report.md` with matched-input windows, adaptive action divergence, event timing, native contacts, binary vs continuous conclusions, and per-cell repetitions.
4. `one_hand_60hz_report.md` with physical preparation attempts, onset/reason distribution, actual foot/ground state and measurable coverage.
5. `lateral_mirror_report.md` preserving historical counter-left ground interruption while reporting the new fixture results.
6. `stopping_braking_report.md` with independent trace recomputation, complete typed outcomes and full support/censor context.
7. `probe_isolation_report.md` with ON/OFF per-stage overhead, repeated results and any accepted-input perturbations.
8. `cross_mode_qualification.md` with all four mode/Hz cells, first mismatches and defensible per-scenario quantitative envelopes.
9. `benchmark_migration.md` and a **new** revisioned metric catalog; untouched v1.3/v1.3.1 evidence, sealed holdouts and versioned scored-metric eligibility.
10. `decision.md`, one concise truthful outcome; `verification.json` with run identities/hashes; full raw and failed run receipts.
11. Independent specialist review and copy/backup/default-startup verification.

### Suggested `decision.md` template

```markdown
# GRIP UP v1.3.2 — Evaluator Qualification Decision

- Source baseline: [verified SHA / commit]
- Measured evaluator revision: [verified SHA / commit]
- A0/B1 gameplay source changed: NO / YES [block reason]
- R0 same-Hz accepted input equivalence: [per-cell verdict and matching window]
- R1 diagnostic seam: SUPPORTED / UNSUPPORTED / NOT_USED
- Adaptive catch: [real contact x/n per mode/rate, context, uncertainty]
- Catch binary eligibility: QUALIFIED / DIAGNOSTIC / QUARANTINED
- Catch continuous eligibility: QUALIFIED / DIAGNOSTIC / QUARANTINED
- Clean lateral: [left/right per mode/rate]
- Counter-swing: [left/right, interruption, ground causes]
- One-hand 60 Hz: [actual valid onsets / attempted; excluded if missing]
- Stop/brake/reverse: [qualified metric names, missing status, scope]
- Probe ON/OFF: [repeated costs, observed input change if any]
- 120 Hz headless/rendered: [accepted commands + state + outcome]
- 60 Hz headless/rendered: [accepted commands + state + outcome]
- Core physical regressions: PASS / FAIL / NOT_RUN
- v1.3.2 benchmark ID and score formula hash: [value]
- Private holdout outcomes accessed: NO / INCIDENT [details]
- New optimization or RL trials executed: 0
- Human gameplay feel: NOT_EVALUATED
- Search readiness: GO_FOR_NEW_SEARCH / EVALUATOR_NOT_READY / NO_GO
- Authorized scope if GO: [named metrics and scenarios only]
- Remaining blockers: [evidence and risk]
- Next recommendation: [bounded study, human playtest, or M7]
```

---

## 16. Final directive to the implementing agents

> Build **GRIP UP v1.3.2 — Evaluator Qualification**, not an AI optimization or controller modification. Audit the exact v1.3.1 baseline. Add a fixed-tick replay lane that verifies actual accepted inputs through the original gameplay pipeline and keep a separate adaptive-policy lane. Use them to characterize the Swing & Catch divergence honestly. Repair the *test* preparation for one-hand 60 Hz without writing body state; build a new mirrored lateral fixture while preserving historical interrupted trials; qualify stop/brake/reverse semantics and measure instrumentation overhead with repeated runs. Freeze and independently review prospective per-mode/Hz scoring thresholds, preserving binary grip safety and quarantining unstable numerical metrics. Re-run relevant safety regressions, protect Janga and the playable A0/B1 build, leave holdouts sealed, restore defaults and deliver a strict per-capability `GO_FOR_NEW_SEARCH` or `NO_GO` decision. **Do not run Random/TPE, RL, Jev, or M7 as part of this assignment.** If a reliable evaluator cannot be demonstrated within the declared budget, preserve the negative evidence and stop; do not invent a PASS.

**End of specification — GRIP UP Evaluator Qualification v1.3.2.**
