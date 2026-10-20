# GRIP UP — Auto-Tuning Benchmark Qualification
## v1.3.3 · Implementation and Validation Specification · English

**Audience:** Codex integration agent, Godot/Jolt physics specialist, testing/measurement specialist.  
**Project:** `wynterCG/grip_up` · Windows/Godot 4.7.2 with integrated Jolt · PC mouse/keyboard.  
**Status of this document:** requested implementation specification; **none of its new gates, fixtures, scores, or experiments are claimed to have passed.**  
**Immediate decision:** qualify a *bounded, versioned benchmark subset* before authorizing any new Optuna search. Preserve A0/B1 and the existing game feel.

---

## 0. Executive requirement

The v1.3.2b projection ablation identified a controlled condition under which the **two tested Swing & Catch replay tapes** agree strictly between headless and rendered runs: the **same actual backing window size**, the **same physics frequency**, and otherwise matching effective configuration. Twelve corresponding pairs passed. Changing the backing size reproduced the earlier microscopic difference in the ray direction and the potentially large downstream difference in the physical trajectory at 60 Hz.

**This is a limited finding, not general benchmark or optimizer qualification.** It does not certify other grips, the other raycast offsets, other scenes, one-hand release, stop/brake/reversal, different screens or hardware, random seeds, or real-player feel. The old unequal-window comparisons stay quarantined.

**Implement a bounded v1.3.3 campaign that:**

1. Makes a canonical test environment an enforced, *observed* precondition, not a command-line suggestion.
2. Extends repeatable headless/rendered comparisons to a small set of useful movement tasks, without changing A0/B1 physics.
3. Qualifies the definitions and preconditions of candidate-ranking metrics, rather than equating simulator completion with gameplay success.
4. Clearly separates fixed-input replay, adaptive scripted task evaluation, and human playtests.
5. Produces an explicit domain-by-domain eligibility matrix and one final **GO_LIMITED_BENCHMARK / PARTIAL_DIAGNOSTIC / NO_GO** decision.
6. **Does not execute a parameter search in this version.** A later, separately approved pilot may use only the newly eligible cells.

**Product principle:** an optimizer may suggest a parameter set; it must not declare a better game. The player retains grip selection, timing, and directional control.

## 1. Verified source findings and open questions

### 1.1 Findings from the supplied v1.3.2b report

| Evidence | Verified scope | What it does NOT establish |
|---|---|---|
| Matched 1024×576 backing: strict headless/rendered match | Two existing Swing & Catch tapes; 60/120 Hz; three pairs for each matching size/frequency | General deterministic replay across all game scenarios |
| Matched 1440×810 backing: strict match | Same two tapes under the larger matched size | Interchangeability of results from small and large backing sizes |
| Historical unmatched 1024×576 vs 1440×810: strict mismatch | First local ray divergence at tick 282 (120 Hz) and tick 28 (60 Hz) | A bug in Jolt or the player's mouse |
| Different backing sizes reproduced divergence within headless | Evidence for a combined backing-size/stretch numerical effect | The exact inaccessible internal floating-point operation |
| All 36 ablation runs completed real contact and retention | The tested catch events completed | Equality of full trajectories under unequal backing |
| Native ground support transiently contributes during catch | Some phases are not arm-only | A pure two-arm-only catch benchmark |
| Prior regressions: 1,146 passing checks | Preserved physics and live-input behaviors covered by those suites | Proof of human control quality, new benchmark validity, or all solver internals |

Key historical source identity: v1.3.2b measured source `da7ed73d3cb9832319eda9c78ae6393a01f34f76`, old captured tapes associated with `036a9dc`, physics 60/120 Hz. Read the corresponding manifests before proceeding. Do not fabricate or resolve ambiguous commit/tag identities from abbreviated hashes; use the full IDs actually present in the working repository.

### 1.2 Existing concerns to retain as genuine open items

- A0/B1 `Lateral Traverse` from the earlier tuning study moved in the opposite signed direction; a subsequent **clean lateral** fixture showed positive progress. These are different initial conditions and must remain separate benchmarks.
- The v1.3.1 stop/release detector became measurable for two-hand support. One-hand 60 Hz qualification, mirrored lateral/counter-swing coverage, and active braking remain incomplete.
- The earlier v1.3.1 R0 strict replay diverged on cursor/raycast. v1.3.2a isolated external mouse/focus interference in observed samples. v1.3.2b diagnosed the new projection/backing effect. Do not conflate their distinct run identities or pretend each earlier no-go has been retroactively passed.
- A1 showed measured regressions against A0 in asymmetrical and diagonal cases. B2 showed localized selection effects without a robust overall step improvement. Neither is an approved replacement.
- The v1.3.2b pairs predominantly selected ray-offset 0 on these tapes. Other ordered picking offsets are not yet certified.

## 2. Non-negotiable scope, invariants, and exclusions

### 2.1 In scope

- Benchmark launch configuration, environment verification, replay setup, fixture generation, read-only telemetry, scenario/task evaluation, typed metrics, comparator policy, test reports and rollback.
- **A0/B1** as the current reference for experimental profile 4 (physical feet B1 ON where the scenario specifies). The ordinary game startup still uses profile 2.
- Existing virtual-cursor replay in its currently supported context, extended only through explicit, tested infrastructure paths. Use the real input router, camera, raycasts, material anchors, controllers and Jolt physics.
- A small number of benchmark arenas or tape variants only where essential to isolate a defined capability.
- Optional instrumented rendered tests using Godot MCP Pro; automated input is **not** a human playtest.

### 2.2 Out of scope

- Changing walking/climbing actuation, stiffness/damping, 12 kg body mass, collider anatomy, friction, Jolt settings, grip eligibility, source surface geometry, capture tolerances, or player controls to make tests pass.
- Replacing `project_ray_normal()` with bespoke or precomputed aiming in the actual qualification runs; injecting world-space contact positions; writing `ATTACHED`; teleporting/reorienting the player after world creation; manually zeroing velocity to stabilize a fixture.
- Changing the hybrid mantle's 1.15 s certified route or claiming dynamic-platform top-out.
- Running Random/TPE/CMA-ES/Optuna candidates, parameter sensitivity sweeps, RL training, Jev inference, or starting M7 in this campaign.
- Accessing private holdout outcomes before a valid shortlisted candidate exists in a future study.
- Building a new full training platform or introducing a generic user-input simulator for release builds.

### 2.3 Keep physics and control budgets unchanged

| Quantity | Current effective reference |
|---|---:|
| Body mass | 12 kg |
| Shoulder-to-contact anatomical reach | approximately 0.65708 m |
| Shared hand traction budget | 360 N |
| Physical feet total / per foot | 180 N / 120 N |
| Shared angular assistance | 20 N·m |
| Combined climbing moment | 150 N·m |
| Planner requested traversal speed | 0.25 m/s |
| Intent input ramp | 0.12 s |
| Maximum target-length rate | 0.24 m/s |
| Maximum target-length acceleration | 0.90 m/s² |

Read **effective runtime values** and the project tuning resource, not generic unused defaults. Keep the existing narrow float-report allowance on limit monitors, without silently expanding underlying limits. No new force may be introduced by instrumentation or fixtures. Pending grips must exert zero force. Reactive supports still receive proper force reactions when tested, although moving platforms are not part of this primary qualification.

## 3. Qualification policy: three things that must never be confused

| Layer | Question | Necessary evidence | Allowed conclusion |
|---|---|---|---|
| **Execution contract** | Did the requested environment, tape and inputs really execute? | Manifest, clock, actual backing, accepted input, complete trace | `RUN_VALID` or typed invalid/aborted reason |
| **Replay equivalence** | Does the *same configuration* produce matching observations in matching conditions? | Tick-aligned headless/rendered traces, both sides' first divergence | `STRICT_MATCH` for measured channels or `MISMATCH`; conditional bounded numeric policy only if separately proven |
| **Task/metric qualification** | Does the test distinguish useful movement and support a fair candidate comparison? | Task completion, preconditions, metric meaning, repeated baselines, negative controls | `ELIGIBLE_FOR_RANKING`, `DIAGNOSTIC_ONLY`, or `EXCLUDED` |

A scenario may complete successfully yet remain **ineligible** if the measurement is contaminated. Likewise, a deliberate negative-control failure can be a successful *test of the evaluator*, not a successful gameplay episode.

**Special rule for future candidate tuning:** fixed inputs and equal environment are required for fair *treatment*, not identical physics outcomes between **different parameter configurations**. If candidate parameters alter movement, actual grip contacts are allowed to change and must be measured honestly. Strict cross-mode replay comparison is between repetitions of the **same candidate** with the same effective environment; never require a candidate to have the same force/trajectory as the baseline to be considered an improvement.

## 4. BQ0 — Freeze the reference and audit actual interfaces

Before changing code:

1. Inspect Git status, active branch, v1.3.2b manifests, measured source SHA, engine binary, original virtual input provider, v1.3.1/1.3.2 comparators, auto-tuning resource override loader and existing v1.2 test-suite scenes.
2. Create a recoverable tag/commit and a **read-only baseline manifest** with hashes. Do not overwrite the historical v1.3, v1.3.1, v1.3.2a or v1.3.2b evidence.
3. Run one fresh ordinary profile-2 startup verification and existing reference suites at 60/120 Hz. Identify any pre-existing warning/failure separately.
4. Document real entrypoints in use. Scripts and commands in this spec are *proposed*, not assertions that those names already exist.
5. Record expected behavior and actual ownership when entering and leaving any scripted scene. Keep live-input code and release export exclusion unchanged unless an audited test-only change is necessary.

Proposed new working tree: `docs/validation/auto_tuning/benchmark_v133/` for the campaign and `tools/auto_tuning/benchmark_qualification/` for orchestrator/metrics. Use established paths if they already implement the same responsibility. Prevent a second competing metric or replay implementation.

**BQ0 gate:** the existing game starts with original defaults; the baseline is reproducible; historical directories remain immutable; the physics specialist approves the audit boundary. Otherwise stop.

## 5. BQ1 — Canonical execution environment

### 5.1 Canonical setup

Use the already tested **1024×576 actual backing window** for the primary qualification, **1920×1080 logical viewport** and the existing effective stretch/canvas policy. This is a **test setting**, not a request to change game-window defaults or resolution offered to players.

For each run, record and validate:

```yaml
engine_version_and_sha: measured binary; not merely "4.7"
physics_backend: integrated Jolt, verified
physics_ticks_per_second: exactly 60 or 120
scenario_id: immutable scenario revision
input_lane: V0 virtual replay | adaptive scripted
logical_viewport: [1920,1080]
actual_backing_window: [1024,576]
actual_stretch_final_transform: measured at preflight and at picks
screen_index: observed; do not assume CLI --screen was honored
window_mode_and_position: observed
render_mode_and_display_server: observed
DPI_and_OS_scale: measured if exposed
camera_owner_FOV_near_keep_aspect: actual values
camera_effective_transform_and_projection: captured at selection
actual_mouse_and_focus_events: monitored, not injected into replay
physics_clock_stability: measured before world creation
original_tuning_resource_identity: verified
input_tape_sha256_and_source: preserved
source_tree_engine_scenario_hashes: immutable manifest
```

Treat exposed fields that are unavailable on a headless platform as typed `UNAVAILABLE` with declared limitations, never guessed equal zeros. A headless screen of `-1` does not itself invalidate a correct pairing. Screen-index differences that were confounded in the last study prevent **isolated causal claims**, but may be listed as observed differences when every picking/physics field still matches.

### 5.2 Preflight must reject rather than quietly repair

- Validate backing dimensions from the **running engine** before creating gameplay bodies; verify at each measured pick and on relevant resize callbacks.
- Validate clock before world initialization and consistent tick order. Detect stale 120 Hz startup callbacks during 60 Hz setup, duplicates, missing ticks, unexpected pauses and focus-induced suspension.
- Reject inconsistent viewport, camera owner, FOV, transform, or input-map. Preserve the original expected tape values.
- Never remap a tape's pixel `(0,0)` to viewport center, quantize coordinates, or recenter by default. A tape pixel is only valid when the tape declares it valid.
- Use an observed actual window. If the OS refuses the requested size, result = `ENVIRONMENT_NOT_COMPARABLE` / `BLOCKED_SETUP`; do **not** resize the opponent's result in post-processing.
- One Jolt world running per test process; clean synchronous teardown between episodes; one worker by default.

### 5.3 1440×810 is a control, not mixed training data

Run the larger backing only for a small **portability check** after the 1024×576 suite succeeds. A 1440×810 run must be paired with **1440×810**, never a 1024×576 counterpart. Keep scores partitioned by backing profile; do not pool or normalize away its physical effect. If the OS moves the window to another monitor, record this explicitly.

**BQ1 gate:** three preflight runs per physics frequency and mode with effective sizes and V0 state verified, plus one negative that deliberately requests a mismatched size and must be rejected *before physical qualification*. Do not count preflight-only checks as physics outcomes.

## 6. BQ2 — Preserve the qualified Swing & Catch reference

Before adding a new scenario, reconfirm the limited v1.3.2b result using the exact **existing captured V0 tapes** and same-source A0/B1. At each frequency, execute three fresh headless/rendered pairs at 1024×576, in unique processes or equivalent verified clean-world lifecycles.

Required equality checks by **physical tick**, without shifting one trace to the contact tick:

- Accepted/held/pressed/released input; virtual cursor validity/coordinates; replay sequence and camera request.
- Real camera ownership, effective pose/projection at picking; original ordered raycast offsets, winner, collider/shape, face, material anchor identity and location.
- Hand state transitions and actual destination contact/retention; source release; pending-grip applied force = zero.
- Published COM, rigid-body pose, linear/angular velocity, force/torque budgets, relevant foot/native-ground support, contact state and phase.
- No hybrid mantle authority or unannounced ground motor in a suspension-only measurement window.

Keep the known factual distinction: both 60 Hz and 120 Hz can succeed with different contact ticks; **do not assert their ticks must be equal across frequencies**. The qualification compares one frequency with itself across modes.

If the reference fails strict equality, freeze the first divergent input/camera/ray/material/physics field and stop expanding the benchmark. A successful final catch with divergent trajectories is not an equivalence pass.

**BQ2 gate:** fresh, fully documented 3/3 strict pairs for each frequency with no safety violations. The earlier 12-pair study remains historical evidence, not an extra 12 passes for this new campaign.

## 7. BQ3 — Qualify a small, useful set of movement tasks

Do not blindly transplant the previous seven optimization episodes. Audit their actual start states, contact states and expected skill before including them. The v1.3.1 split between clean lateral and counter-swing must be preserved.

### 7.1 Initial candidate catalog

| Domain / provisional ID | Minimum setup contract | Primary measurable capability | Expected initial policy |
|---|---|---|---|
| `vertical_pull_clean` | Two real hands, verified climbing support, consistent initial loading; label any foot/ground contribution | Signed upward COM displacement and latency | Candidate for ranking after qualification |
| `asymmetric_pull_clean` | Real asymmetric hand anchors, no scripted pose teleport, controlled initial spin | Directed progress with rotation treated as context | Candidate for ranking after qualification |
| `lateral_clean_left` | Opposite/low initial lateral momentum; real two-hand support; no native walking authority | Signed leftward displacement after accepted input | Candidate for ranking after qualification |
| `lateral_clean_right` | Mirror of left, same spatial difficulty and support eligibility | Signed rightward displacement; symmetry check | Candidate for ranking after qualification |
| `foot_supported_step` | B1 foot contact is actually planted and can carry load; hand references also real | Supported upward progress + valid force transfer | Candidate only if contact-state preconditions are met |
| `two_hand_release_stop` | Directed speed is inside declared onset band and stable support is real | 3D stop path + settling + drift | Candidate only after detector proves valid measurements |
| `two_hand_active_brake` | Directed speed is inside onset band, distinct active braking request | Active loss of directed velocity; horizon-limited | Diagnostic until enough active-braking windows exist |
| `counter_swing_left/right` | Signed opposite incoming velocity measured, room for pendulum, no ground authority during window | Reversal of *actual* supported swing | Diagnostic initially; not hidden behind clean lateral score |
| `one_hand_stop_60hz` | Must have a real one-hand setup satisfying the onset without writing COM pose/velocity | One-hand stopping under stated support | **Open, not part of a limited go** until truly qualified |
| `ground_to_grip` | Ground contact measured, reaching & loading separated, no fake early grip | Authority transition and acquisition | Secondary diagnostic / possible later extension |
| `first_ascent_public` | Legitimate full route, physically separate hybrid interval | Integration/safety and task completion | **Validation only**; no hiding assisted vertical travel in climb score |

This catalog is **proposed**. A scenario name does not mean the fixture already exists or that its outcome is certified. Record which prior scene is reused, which small authoring changes are required, and whether it has previously failed its own task. A physically impossible or baseline-failing case may be kept as a **diagnostic/negative control**, but must not be passed into optimization with a fabricated target.

### 7.2 Order of promotion

**Primary limited subset:** first qualify `vertical_pull_clean`, `asymmetric_pull_clean`, `lateral_clean_left`, `lateral_clean_right` and `foot_supported_step`. Add `two_hand_release_stop` as a metric-qualification task, not a substitute for directional climbing. Preserve the already qualified catch as a high-value *separate* safety/task anchor.

**Deferred until justified:** one-hand 60 Hz, counter-swing left contact with ground, geometry-quality grip variation, moving-platform climbing, all ray offsets, different cameras/hardware and full First Ascent as a fitness target.

### 7.3 Fixture construction rules

- Produce the desired initial state through **ordinary input and real contacts** only. Do not freeze a player into an ideal pose or set a velocity directly.
- Every measurement uses an **onset certificate** containing body pose, actual speed/spin, real hand/foot/native-ground support, camera, anchors, load and accepted command.
- If a requested onset is not reached in a bounded preparation window: `PRECONDITION_NOT_MET`; capture the last preparation state and reason. Never count it as zero-distance movement or success.
- Separate climbing from walking: ground authority after onset is `INTERRUPTED` unless the case expressly studies grounded transitions. Feet supporting load are not the same as ground-native walking authority.
- Clean lateral initial lateral speed must remain within its documented clean band (existing reference ≤0.10 m/s and spin ≤0.20 rad/s for ≥0.25 s, subject to audit). Counter-swing must start with **opposite** measured speed; it is a different labeled task.
- Counter-left historically touched the ground. Fix by an authored **symmetric arena with clearance**, not by preventing contact or removing real colliders. Ground contact is recorded, not hidden.
- For mirror tests, invert world/camera/contact setup consistently. Do not compare incomparable initial reach or loading and call that directional bias.
- A hand-only claim requires feet OFF, no native ground authority, and real single/dual hand support; otherwise name the B1-supported condition accurately.

### 7.4 Tapes, drivers and comparability

For fixed-input V0 tasks, capture new immutable tapes at **each requested frequency**, with the actual canonical backing and source hashes. Hold them fixed for a candidate evaluation. Record the exact cursor and camera effects, not just semantic WASD. Replaying a 120 Hz tick tape at 60 Hz is not automatic evidence of identical controls.

Where a task needs feedback to reach its state (e.g., Swing & Catch), keep the **adaptive scripted policy** in a distinct lane and compare completion rates/statistics, not strict input identity. Adaptive outputs are themselves evidence and must be recorded. Do not relabel a feedback-generated trajectory as fixed-input replay.

For any future candidate, the virtual-cursor tape may lead to a **different legitimate ray hit** because the player's body moved differently. Do not treat that as an automatic bug *against the baseline*; instead check its eligibility, task outcome, and within-candidate replay reliability. Likewise, do not secretly retarget to a better surface to save a failure.

**BQ3 gate:** within the limited subset, each proposed task must have a validated onset, correct support semantics, signed real movement, verified replay sampling and an honest pass/failure definition. A difficult task is not promoted solely because its evaluator returns a finite number.

## 8. BQ4 — Qualify measurements, not just test completions

### 8.1 Mandatory raw time-series outputs

By fixed physics tick, preserve **requested**, **accepted**, and **applied** input separately; COM and velocities; body angular velocity; grip and foot states/forces; target and current rest lengths; actual contact material IDs and world positions; ground authority; camera and backing metadata; evaluator phase; valid onset and interruption events; clamp/saturation/slip reasons. Use the existing v1.3.1 observer where possible; add only missing read-only fields.

### 8.2 Candidate ranking metrics (defined before a tuning study)

| Metric | Definition | Validity / trap to avoid |
|---|---|---|
| `signed_progress_m` | `(COM_end − COM_onset) · unit_requested_direction` over fixed authorized window | Negative means opposite motion; no ground walking counted as hanging traverse |
| `latency_to_useful_motion_s` | First sustained positive velocity/displacement after the accepted input tick | Not OS/mouse display latency; publish exact threshold/dwell |
| `directional_efficiency` | Signed progress divided by 3D path length, only if path exceeds a declared small numerical floor | A required early rotation is not inherently bad; do not optimize this alone |
| `overshoot_after_release_m` | Travel past the onset-of-release reference/target *after* release or stop request | Do not penalize commanded travel during the active movement phase |
| `stop_path_3d_m` | Integrated COM path from actual release onset until confirmed settling | Small final drift is not small path; never turn missing into zero |
| `settling_time_s` | Time from actual onset to start of sustained full-speed/spin stable interval | Requires sustained criteria; publish confirmation interval (historically 0.25 s) |
| `brake_fraction_reached` | Loss of directed velocity **during active braking window** | Later passive settling cannot count as active braking success |
| `reversal_time_s` | Time from accepted reverse command to sustained opposite signed velocity | Must preserve earlier valid reversal if later ground contact interrupts progress |
| `catch_success` / `retention_s` | Real destination ATTACHED/load and subsequent retained anchor, not selected/pending only | Binary completion cannot certify equivalent full trajectory |
| `foot_load_contribution` | Actual compressive support/impulse relative to hands over measured window | Visual planted pose is not a physical foot load |
| `twist_rms_rad` | Well-defined angular deviation within authorized phase | Rotation and momentum may be essential; diagnostic or Pareto dimension, not blanket penalty |
| `hard_physical_violations` | Contacts, load caps, no-force pending, collision, ownership, unexpected body writes, non-finite states | Hard reject, **never trade for progress** |

When needed, distinguish commanded direction in the wall-support frame from world-space camera input. Use **real** support frames, not selected-but-not-attached targets. Record task-specific coordinate bases so left and right mirror have the same sign convention.

### 8.3 Typed metric values and eligibility

Each metric result must have exactly one status:

- `MEASURED`: observation and full validity conditions satisfied.
- `CENSORED_TIMEOUT`: episode ended before the measurement could be completed, while the task remained eligible.
- `INTERRUPTED`: valid start but a defined event changed its meaning (ground contact, unexpected grip loss, recovery state).
- `PRECONDITION_NOT_MET`: no valid onset; no result can be scored.
- `INVALID_MEASUREMENT`: invalid trace/tick/clock/data contract.
- `NOT_APPLICABLE`: the metric is not defined for that task.

Keep raw `null` for non-measured values, along with `reason_code`, `onset_tick`, `end_tick`, and event provenance. **A `null` stop distance must never become zero.** Do not collapse interrupts and preconditions into an opaque failure count. A binary task failure can remain a legitimate outcome even when a secondary continuous measure is absent, but optimizer eligibility must be judged explicitly.

### 8.4 Ranking contract is not a single easy-to-game scalar

Preserve the multi-objective split from v1.3: progress, precision/response, physical quality and reliability. Physical legality and evaluator validity are **hard gates**. Avoid summing incompatible scores into one positive number that allows contact cheating to compensate for speed.

Before any future search, calibrate practical improvement floors, caps and worst-case penalties against **independent baseline repetitions on the frozen benchmark**, not against observed candidate outcomes. Declare uncertainty/dispersion and per-domain weights before candidates are tested. The v1.3 proposal of a worst-cell metric can be retained only once those cells have sound onsets; missing cells cannot be dropped silently to inflate a candidate's worst case.

**BQ4 gate:** unit/property tests for every metric status and phase boundary; trace recomputation matches runtime summary; physical specialist signs off the semantic interpretations. A metric with incomplete preparation or unstable cross-mode behavior remains `DIAGNOSTIC_ONLY`.

## 9. BQ5 — Fairness, repeatability and cross-mode qualification

### 9.1 Primary matrix

For the proposed **five primary new domains** (`vertical`, `asymmetric`, `lateral left`, `lateral right`, `foot-supported step`) plus `two_hand_release_stop`, plan:

- **Three independent repetitions per cell** (fresh process/verified reset).
- **Two physics frequencies: 120 Hz and 60 Hz**, evaluated and qualified separately.
- **Two execution modes: headless and scripted rendered.**
- Same effective **1024×576** backing within each pair, with confirmed canonical viewport/camera contract.

Thus the full proposed new-domain matrix is **6 domains × 2 frequencies × 2 modes × 3 = 72 processes**, plus **12** fresh Swing & Catch reference processes (three pairs per frequency). This is an **upper budget**, contingent on previous gates. A domain failing a meaningful precondition does not require launching the rest of its matrix after the failure is adjudicated. Do not create extra runs just to attain a target pass count.

A small separate negative/control allotment of **up to 8** processes is allowed for deliberate wrong backing, corrupt tape, canceled grip, skipped tick, illegal target or loss of support. Allow **at most 4 issue-specific diagnostics** after any primary hard stop; label all supplementary, never fill missing primary cells. **Absolute campaign ceiling: 96 physics processes** (72 + 12 + 8 + 4) unless a new approved campaign is explicitly started. Tests which do not launch a physics world are counted separately.

### 9.2 Phase the matrix to avoid wasting effort

1. `BQ5a`: Replay catch control; short preflight for each new task at 120 Hz.
2. `BQ5b`: Finish 120 Hz cross-mode replications for domains that are actually valid.
3. `BQ5c`: Do the 60 Hz matching domain matrix; do not silently interpret failure as a rendering bug.
4. `BQ5d`: Run two stop-domain validations and controls, then generate locked eligibility matrix.
5. `BQ5e` (optional): small matched 1440×810 portability smoke on one or two **already qualified** tasks, not part of optimization score.

Do not use the same seed repeated three times as evidence of cross-seed robustness. Repetitions with identical seed measure local repeatability. Where randomization is relevant, preregister a **small separate seed/perturbation validation set** and mark it `GENERALIZATION_NOT_TESTED` if this campaign cannot afford it. Do not change the baseline's difficulty to favor a candidate.

### 9.3 First divergence and classification

At the first unequal tick, compare layers in order:

1. `ENVIRONMENT`: engine/hash, clock, actual backing/stretches, camera owner, viewport, scenario source, sequence.
2. `INPUT`: original request, emitted event, accepted action, effective intent, cursor validity and coordinate.
3. `PICK`: camera project ray, ordered ray offsets, collider/face, material anchor ID/location.
4. `CONTACT`: actual reach/attach/slip/loading, native ground/foot support and support-local velocity.
5. `PHYSICS`: COM/pose/v/omega, actuation forces and torques, collision/authority flags.
6. `TASK`: measured completion and metrics.

A later physics difference cannot be attributed to the solver if an earlier input/picking difference exists. Report `STRICT_MATCH` only for every **published and required** channel in that scenario. No approved blanket 1 mm, 1 pixel, 15 cm or arbitrary Jolt tolerance exists. If exact matching fails, keep `MISMATCH` or `DIAGNOSTIC_ONLY` and propose a **separate prospective statistical-equivalence design**; do not invent an envelope by measuring the very outlier being rescued.

### 9.4 Candidate-comparability policy for later work

It is legitimate for tuning parameters to change the trajectory, contact/release timing or task outcome. Later, compare candidate and A0 **using equal input policies, task definitions and environment strata**, not bitwise states. Re-run an individual candidate in both modes under matching backing to check its reproducibility. If only a headless result is available, it is exploratory and not a product promotion. All claims must specify mode, Hz, backing, seed and whether a run was fixed-input or adaptive.

## 10. BQ6 — Benchmark catalog and protected data partitions

### 10.1 Qualification set versus future optimization set

Define and freeze separate partitions:

- **Qualification/control:** same-backing Swing & Catch reference; technical negatives; baseline A0/B1 regression/calibration.
- **Public future-training set:** only domains that pass v1.3.3's metric/replay gates, plus documented source and fixture revision.
- **Public validation:** new mirror/reach/entry variations not used to select parameters; available only after a candidate is proposed in a later campaign.
- **Private holdouts:** remain sealed; this version may validate manifests/schemas only, not load outcome values.
- **Human playtests:** separate participant input, no use of scripted repeats as human data.

Do not repurpose any prior failed benchmark (`train_tape_r2`, old negative lateral, mismatched-window 60 Hz catch) as a positive optimization score. Keep migration tables explaining exact differences from v1.3 `train_tape_r3`, v1.3.1 `benchmark_eval_v131` and v1.3.2 `benchmark_eval_v132`.

### 10.2 Catalog contract (representative schema)

```json
{
  "benchmark_id": "benchmark_eval_v133",
  "revision": 1,
  "canonical_environment_id": "godot47_jolt_1024x576_v0",
  "physics_hz": 120,
  "input_lane": "fixed_virtual_replay",
  "scenario_id": "lateral_clean_left",
  "scenario_revision": "to_be_frozen_on_implementation",
  "tape_sha256": "provided_by_actual_capture",
  "objective_direction_frame": "attached_support_tangent",
  "required_initial_support": "two_attached_hands_no_native_ground_walk",
  "required_onset": "signed_speed_spin_stability_certificate",
  "completion_rule": "positive_signed_progress_under_authorized_support",
  "metric_ids": ["signed_progress_m", "latency_to_useful_motion_s"],
  "optimization_eligibility": "PENDING_QUALIFICATION"
}
```

This is a **schema example**, not a claim that the named tape or version already exists. Final manifest fields must use the project's actual complete source hashes, physics settings, world revision, window transform, policy revision and source paths. Reject incomplete or mixed-version candidates at ingestion.

## 11. BQ7 — Bound decision: not a new optimizer run

### 11.1 Status per domain

Each domain must have one of:

- `ELIGIBLE_FOR_RANKING`: stable environment; task start and finish well defined; measurable signal; legal physics; required same-backing within-Hz repeatability; no unresolved first-divergence blocker; negative controls behave correctly.
- `DIAGNOSTIC_ONLY`: valid scene/physics evidence but incomplete repeatability, insufficient measurement meaning, absent onset, baseline inability to achieve objective, or an unqualified condition.
- `EXCLUDED_SAFETY`: physical limit violation, input bypass, unauthorized state change, invalid grip/contact, corrupted trace, or other hard safety breach.
- `MISSING_COVERAGE`: planned test not completed for a stated reason. Must not be promoted via historical green suites.

### 11.2 Final top-level verdict

**`GO_LIMITED_BENCHMARK`** — May be issued **only** if BQ0–BQ2 pass and a coherent, preregistered useful subset of **at least vertical, asymmetric, left and right clean lateral** is `ELIGIBLE_FOR_RANKING` at **both** 60 and 120 Hz, the safety/gating metrics are valid, and BQ1 environment proof is complete. `foot_supported_step` and `two_hand_release_stop` must either qualify or be explicitly excluded with consequences clearly stated. This authorizes a **separate small optimization-pilot specification/decision**, not automatic Optuna execution and not default promotion.

**`GO_NARROW_DIAGNOSTIC`** — One or more domains qualify, but the above useful multi-movement subset does not. May support sensitivity analysis or targeted engineering investigations **only with a separate authorization**; **no** generic optimizer score, global A0 superiority claim or default change.

**`NO_GO_BENCHMARK`** — Required baseline replay fails, input/environment is not comparable, metric semantics are unsafe, or hard physics invariants fail. Freeze the first-difference evidence and stop. Do not restart another whole reliability-version chain automatically.

**`PARTIAL_MISSING_COVERAGE`** — Valid completed tests exist but the campaign ended before the specified required matrix. Report the missing cells, not a binary PASS.

Possible extra note: `GO_LIMITED_BENCHMARK` is strictly scoped to **named scenes, fixed canonical backing and frequencies, specified player profile, input lane, measured channels and this machine/engine identity**. It is not equivalent to an end-to-end ML study certification or gameplay improvement.

### 11.3 Future optimization only after a separate decision

If `GO_LIMITED_BENCHMARK` is achieved, a future v1.3.4 pilot could start with the known **four high-level A0 tuning fields** already defined in v1.3, begin with a transparent sensitivity/random phase and advance to Optuna only through a new budget/gate. Preserve A0/B1 as a frozen playable reference, do not mix changing B2/A1 into the same search, and require repeat tests and real player A/B before making any default change.

If only `GO_NARROW_DIAGNOSTIC` occurs, **do not train or rank on Swing & Catch alone**. A single mastered scenario encourages overfitting and says too little about the control feel of a full climbing game.

## 12. Safety, negative tests and no-cheating checks

Mandatory controls or contract tests:

1. Wrong backing/window size is rejected before gameplay-world scoring; no tolerance-based repair.
2. Tape JSON roundtrip preserves hand ID 0/1, ordered button edges, `(0,0)` validity and wheel ±1; fractions rejected.
3. Duplicate/missing/late tick, invalid camera owner, viewport resize, changed physics Hz, mismatched source hash and stale controller are rejected with typed reasons.
4. Real physical mouse motion, clicks and focus callbacks do not change the virtual cursor or replay accepted input when the engine keeps executing; actual suspension is classified, not silently filled.
5. A future fixed replay cannot write hand `ATTACHED`, body transform, velocity or substitute a raycast target. Real contact and retention are required.
6. REACHING/pending/free hand force is zero; hand/foot budgets and opposite forces on dynamic supports hold within existing published monitor conventions.
7. Invalid foot/ground/native support cannot be substituted with a proximity ray to count a completed move.
8. A0/A1 canary: preserve A1's known regressions and ensure a negative or worse candidate cannot receive a favorable aggregate by missing its weakest scenario. This can be a **metric/unit test** and must not enable A1 by default.
9. Counters/plots separate episode executed, task succeeded, metric measured, domain eligible, replay equivalent and human approved. Never substitute one for another.
10. Confirm all test-only providers, observers, scripts and large research assets are excluded from release export; normal game profile2/live input startup untouched.

For negative controls, use explicit fixtures/configurations that exercise invalid paths. Do not insert artificial physical failure into a positive baseline run and then use that same baseline as evidence of natural failure.

## 13. Performance and trace integrity

- High-frequency observers must be read-only, bounded and optionally disabled. Record performance by component: total game tick, pre-pick sidecar/projection, post reader, serialization, render cadence and trace output separately.
- The v1.3.2b probe ON/OFF check is prior limited evidence. Do not infer negligible total overhead from a `probe_usec` that excludes final writing and other loggers.
- Store **complete structured per-tick traces** only where necessary for qualification; permit bounded windows plus clear hash-referenced raw archives for wider comparisons.
- Validate file atomicity, hashes, process exit, JSON schema, line/tick counts, clock consistency and source parity. A parser exception or process timeout is not a failed climb.
- Use independent recomputation for signed path, stop path, onsets, braking and first divergence. A Python report generator must not silently reinterpret Godot metric statuses.
- Historical results remain read-only. Archive *every* unsuccessful attempt and mark it with its original code hash and reason; no stale JSON may satisfy a fresh test.

## 14. Milestone sequence and acceptance gates

| Milestone | Required output | Proceed only if |
|---|---|---|
| **BQ0** — freeze/audit | Baseline tag, source/engine hashes, inventory of existing evaluators | Current game untouched, historical evidence recoverable |
| **BQ1** — canonical backing | Runtime preflight + negative controls; per-process environment record | Backing/clock/input/world state verified, no silent repair |
| **BQ2** — catch control | Fresh 3 pairs/Hz at 1024×576; tick-aligned chain | Exact published-channel equality and real retention |
| **BQ3** — domain catalog | Audited new fixture/tape definitions, real onset certificates | No fake support or baseline-failing score cells |
| **BQ4** — metrics | Typed status, metric unit tests and trace recomputation | Expert agrees metrics mean what they claim |
| **BQ5** — matrix | Up to 72 new-domain processes, proper 60/120/mode partitions | Complete qualified cells or explicit stop + reason |
| **BQ6** — freeze dataset | Versioned benchmark, public/validation/holdout separation | No private outcomes opened; no contaminated legacy scores |
| **BQ7** — decision | Eligibility per cell/domain, GO/NO-GO, manifests/archives | Formal expert review; no unapproved search |

Milestones may need preparatory coding before measuring earlier gates; however **no later gate may be reported as satisfied or published as score data until its prerequisites pass**.

## 15. Responsibilities and implementation workflow

### Codex (integration lead)

- Inspect existing implementation and derive the smallest compatible extension of current providers, driver, metrics and archives.
- Keep source modifications isolated; store proposed/new wrappers in research folders and maintain a clean startup/release export.
- Implement immutable run manifest and actual-environment preflight, scenarios, Python comparator, reports and readable exception classifications.
- Build a run matrix with deterministic ordering and an explicit run budget. Stop at first hard mismatch; do not opportunistically expand the campaign.
- Compile, execute prescribed contract suites, invoke Godot/MCP when useful, and publish exact commands **after validating they exist**.
- Verify mirror and source hash parity, return ordinary main to initial settings, and provide a fresh audit of source vs executable identity.

### Physics/Jolt specialist

- Review fixture anatomy, actual grip/foot/ground contacts, the effect of 60 vs 120 Hz, reaction forces and Jolt state-reading phases.
- Reject setup cheats and optimizer shortcuts through body transforms, target substitution, hidden support or numeric tolerance widening.
- Validate support-frame geometry, mirrored setups and signed progress; decide whether an early rotation is valid movement or a test artifact.
- Audit the stop/reversal metric definitions, contact-manifold limitations and any long-term implications of v1.3.2b's finite precision.
- Provide independent recommendations per domain with explicit `PASS`, `PARTIAL`, `REJECT`, `MISSING_COVERAGE` and supporting evidence.

### Testing/measurement reviewer (may be the same agent in a separate review)

- Validate JSON roundtrip/tape identity, onset/censoring logic and comparisons at equal ticks.
- Recompute metric values from raw traces, check plots against CSV/JSON, flag cross-mode/Hz pooling and disallowed holdout access.
- Inspect the effect of instrumentation without attributing numerical differences to it without a controlled causal test.

### Human designer

- Does **not** need to participate in this technical qualification. Later, trial A/B finalists and rate clarity, responsiveness, precision, ability to stop, swing mastery and desire to replay.
- Human feel remains the final product gate. No scripted playthrough may be called a human UX pass.

## 16. Mandatory deliverables

Place the new outputs under a dedicated, new campaign path, for example:

```text
docs/validation/auto_tuning/benchmark_v133/
  README.md
  baseline_manifest.json
  benchmark_catalog_v133.json
  environment_contract.md
  run_plan.json
  runs/
    <unique_run_id>/manifest.json
    <unique_run_id>/result.json
    <unique_run_id>/trace.json.gz
    <unique_run_id>/stdout.txt
    <unique_run_id>/stderr.txt
  first_divergences.json
  measurement_contract.md
  eligibility_matrix.json
  scenario_metrics.csv
  replay_comparison.csv
  negative_controls.json
  physics_specialist_review.md
  human_protocol_reference.md
  result_report.md
  decision.md
  verification.json
  evidence_manifest.json
```

Report must list **attempted/valid/invalid/aborted/early-stop** counts, not just total “checks passed”. Every table must identify Hz, backing, headless/rendered, run source, tape/policy revision, seed, actual onset, successful task criteria and metric status. Non-run cells remain visibly non-run. A passing old regression is source preservation, not evidence of new benchmark validity.

Minimum decision-file template:

```markdown
# GRIP UP v1.3.3 — Benchmark Qualification Decision

- Baseline preserved: PASS / FAIL
- Canonical backing and clock verified: PASS / FAIL
- Swing & Catch reference replay: STRICT_MATCH / MISMATCH / NOT_RUN
- Vertical / asymmetric / lateral L / lateral R: status individually
- Foot-supported step: ELIGIBLE / DIAGNOSTIC_ONLY / EXCLUDED / NOT_RUN
- Two-hand stopping metrics: ELIGIBLE / DIAGNOSTIC_ONLY / EXCLUDED / NOT_RUN
- Cross-mode coverage: count per cell and first divergence, if any
- 60 Hz qualification: status independently
- One-hand 60 Hz: OPEN / qualified with separate evidence
- Hard physics invariant failures: count and identities
- Private holdout outcomes consulted: should be 0
- Optuna/RL/Jev runs: should be 0
- Human playtest sessions: should be 0 (unless separately authorized)
- Final verdict: GO_LIMITED_BENCHMARK / GO_NARROW_DIAGNOSTIC /
  PARTIAL_MISSING_COVERAGE / NO_GO_BENCHMARK
- Scope of any go and explicit remaining exclusions:
- Next permitted action:
```

## 17. Final instruction to the agents

> Qualify the measurement system, not a preferred result. Treat the v1.3.2b same-window Swing & Catch correspondence as a **limited starting point**. Enforce and prove 1024×576 actual backing in both modes, preserve A0/B1 and every physical invariant, build only enough new fixtures and metrics to establish a useful multi-movement benchmark, and stop with accurate `MISSING_COVERAGE` or `NO_GO` where appropriate. Do not launch parameter tuning or open private holdouts in this stage. The final purpose is a trustworthy later comparison between candidate and baseline in a *fun, player-controlled* physical climbing game.

---

### References carried forward (project-local sources)

- `window_ablation_report.md` (v1.3.2b) — canonical source for matched-backup projection evidence and its limits.
- `report(8).md` / v1.3.2a requalification — JSON roundtrip, external mouse/focus interference, old size-mismatched replay.
- `report(7).md` / v1.3.2 qualification — layered input/picking differences, metric coverage gaps.
- `report(6).md` / v1.3.1 reliability — typed stop metrics and one-hand coverage limitations.
- `report(4).md` / v1.3 Auto-Tuning Lab — parameter space, pilot regressions and historical seven-task baseline.
- `GRIP_UP_Physics_Auto_Tuning_Lab_Spec_v1_3_EN.md` — future optimizer goals and legal search space.
- `GRIP_UP_Locomotion_Test_Suite_Spec_v1_2_EN.md` — prior movement mastery/test design.
- `GRIP_UP_Projection_Viewport_Qualification_Spec_v1_3_2b_EN.md` — projection instrumentation and controlled ablation design.

**Where the project uses different actual paths than these source labels, cite the audited repository paths in the final manifest. Do not invent repository files or test evidence.**
