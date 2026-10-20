# GRIP UP — Physics Auto-Tuning Lab
## Experimental Optimization & Learning Specification — v1.3

**Document status:** Implementation-ready research specification; no optimizer, trained policy, improved game feel, or benchmark result is claimed to have been implemented by this document.  
**Language:** English. **Primary platform:** Windows PC. **Game engine:** existing GRIP UP Godot 4.7.2 + integrated Jolt configuration, as recorded in the project reports (verify working copy).  
**Primary method:** Offline black-box parameter optimization (Optuna / TPE, with optional CMA-ES).  
**Optional research extension:** Restricted reinforcement learning for low-level coordination, only after explicit go/no-go review.  
**Starting point:** Existing playable locomotion, before reactive challenge M7. This is an independent experiment; it must not alter the M7 deliverables or replace the approved controller automatically.

---

## 0. Executive decision

**Do not train an AI to climb the whole level.** First determine whether automatic tuning can find a small, robust, physically valid parameter set that gives a *meaningfully better player-controlled locomotion experience* than GRIP UP's present A0 baseline.

The optimizer proposes values. Godot runs existing physics. The evaluator measures results. The designer/playtesters decide whether the experience is better. Parameters are never silently promoted to defaults, and optimization must not increase force budgets or allow impossible motions.

The output of phase 1 is **a shortlist of validated tunings with trade-offs and evidence**, not a single magic score or an autonomous climbing agent.

### Research questions

- Can the present A0 movement architecture produce better responsiveness, precision, and transfer control through safe high-level tuning alone?
- Are improvements stable across different postures, camera angles, 60/120 Hz, and unseen routes?
- Does any tuning preserve the crucial feeling of gravity, inertia, single-hand swing and genuine difficulty?
- Which knobs materially affect perceived control, and which knobs should be frozen or removed?
- Is a state-dependent low-level coordinator warranted, or can fixed tuning already reach the useful ceiling?

### Existing evidence to respect

The provided **GRIP UP v1.1** report describes:

- Original movement allocation **A0** kept as the reference. An experimental **A1** allocation worsened asymmetric and diagonal movement in measured trials; **do not use A1 as the default or claim it is an improvement**.
- **B1** physical feet as the established comparison; **B2** foot ranking demonstrated a localized directional change but no proven general benefit. B2 remains optional.
- Feedback for driving/braking/neutral swing is implemented as experimental presentation/diagnostics; subjective benefit is not yet demonstrated.
- 5,094 technical checks passed in the v1.1 delivery, but passing safety tests does not establish better feel.
- The v1.2 **Locomotion Test Suite** is a specification from this conversation. **Inspect whether it has been implemented before assuming its arenas and metrics exist.**

Consult the actual source tree, archived traces and latest manifests before coding. All subsequent parameter values and paths in this specification are research proposals until verified.

---

## 1. Non-negotiable player controls and physics

**Preserve:**

- Third-person PC climbing with independent mouse aiming and **hold-to-grip** hands (LMB left, RMB right; releasing means release).
- Camera orbit and dolly, player-intended body movement using the current profile-4 control model.
- Real collision and gravity on the main dynamic `RigidBody3D`, and reaction forces on dynamic supports.
- Grip acquisition requiring contact; pending out-of-range targets provide **zero load** until actual contact.
- Physical leg contacts when separately enabled; unloaded visual IK is not physical support.
- Static hybrid top-out as an explicitly assisted, collision-checked transition; do not count its kinematic traversal as purely physical climbing.
- Baseline controller paths, old game builds and Janga's original grabber.

**Forbidden as optimization outputs:**

- Changes to mass, world gravity, anatomical arm/leg reach, collider sizes, physics layer/mask, friction limits, grip integrity to mask failed catches, or force/torque maxima.
- Hidden body teleports, direct transform/velocity changes, runtime animation root motion to cheat the physical climbing portion, or extra airborne force.
- Permitting out-of-range gripping, missed obstruction checks, longer attachment beyond physical limits, or making a dynamic platform static in scoring runs.
- Changing authored challenge geometry or victory conditions to improve score.
- Increasing the total hand effort budget (reported reference: **360 N**), optional feet budget (**180 N total, 120 N per foot**), shared assistance (**20 N·m**), combined climbing moment (**150 N·m**) or maximum anatomical contact reach (approximately **0.65708 m**).
- Replacing existing players' grip and path choices with an automatic planner.

Every candidate must pass physics invariants **before** it is ranked on performance or feel. A high reward never compensates for safety or authority violations.

---

## 2. Baselines, variants and boundaries

Preserve independent, reversible profiles:

| Label | Meaning | Purpose |
|---|---|---|
| **BASE-A0-B1** | Existing profile-4 intent coordinator, A0 allocation, physical feet B1 (explicitly enabled) | Main development reference for paired comparisons |
| **BASE-A0-NOFEET** | Same controller, physical feet disabled | Sensitivity / support-availability comparison |
| **A1-NEGATIVE** | Existing regressed A1 allocation | Negative control only, not initial training seed |
| **B2-OPTIONAL** | Existing B2 candidate selection | Separate targeted follow-up; not mixed into first optimization |
| **TUNE-...** | Frozen A0 architecture + proposed high-level parameter overrides | Auto-tuning candidates |
| **RL-RESEARCH** | Future low-level bounded coordinator policy, optional | Separate phase; never shipped by default |

Do not accidentally start the game in whichever experimental profile the harness last used. Restoring the original runtime startup profile is part of every run and failure recovery.

A tuning run should set **A0 and the intended B variant explicitly**. Do not optimize A1 and B2 simultaneously with basic movement parameters: that destroys causal attribution.

---

## 3. Parameter search space — deliberately small

### 3.1 Stage 1: high-level intent planner parameters

Search only a few parameters that are already semantically understood and directly affect player response. Inspect exact variable names and bounds in the current source; the table below uses **reported v0.7 reference values** and **proposed search intervals**, not certified playable limits.

| Candidate knob (map to actual field) | Reported reference | Proposed first-stage range | Why tune it |
|---|---:|---:|---|
| Virtual desired movement speed | 0.25 m/s | 0.18–0.32 m/s | Speed of intended body motion |
| Input response ramp | 0.12 s | 0.07–0.20 s | Responsiveness vs abruptness |
| Virtual desired acceleration cap | 1.0 m/s² | 0.65–1.35 m/s² | Acceleration of requested motion |
| Planning horizon | 0.18 s | 0.12–0.24 s | Reactive vs anticipatory target placement |
| Target rest-length slew | 0.24 m/s | 0.16–0.30 m/s | How fast actuator goals can change |
| Target rest-length acceleration | 0.9 m/s² | 0.60–1.20 m/s² | Smoothness of actuator command |

These are **design-proposed bounds**. Before searching, the physics specialist must check they do not violate any current controller assumptions, bounds, race conditions, or numerical constraints. Tighten any range that is unsafe or behaviorally implausible.

**First sweep only 3–4 knobs**, e.g. movement speed, input ramp, rest-length slew and acceleration. After sensitivity analysis, explore additional knobs only where a measured effect exists. Avoid a large search space with too few trials.

### 3.2 Stage 2: conditional parameters, strictly separated

Only after a successful Stage 1 and human review, consider:

- Small changes to the coordination bias when a foot is already physically loaded.
- Support-aware braking / damping *intent* rates, while preserving physical damping and moment limits.
- Controller settling/anti-windup thresholds and numerical dead-zones, where trace analysis reveals a genuine failure.
- Grip-targeting tolerance *for the cursor only*, but **never** changes to physical acquisition reach/contact authority, and only in a dedicated input study.

Do not tune Jolt solver settings, spring K/D, character mass, physical swing torque limits or grip overload capacity in Stage 1. Those are separate research topics with a separate safety gate. Do not optimize aesthetics/UI feedback against movement performance in the same study.

### 3.3 Parameter metadata contract

Each knob should declare:

`id, engine_path, type, units, baseline, min, max, transform, requires, invariants, version, provenance`.

Reject candidates with unknown IDs, missing required fields, nonfinite values, out-of-range values, coupled-constraint violations or changed schema versions. Overrides must be *session-local*, applied before simulation begins and never written into source files during a trial.

---

## 4. Architecture: Python optimizer + Godot evaluator

```text
Offline optimization CLI (Python)
    |
    +-- Candidate generator (Random -> Optuna TPE; optional CMA-ES)
    |
    +-- Trial manifest: params + code/scene/engine hashes + scenario list
    |
    +-- Isolated Godot headless execution of existing test scenarios
    |      |
    |      +-- Session-only tuning overrides
    |      +-- Fixed input replay or authored physical challenge fixtures
    |      +-- Per-step observables and per-trial summary JSON
    |      +-- Hard constraints / crash and timeout reporting
    |
    +-- Scorer: constraints first, multi-objective metrics second
    |
    +-- Persistent experiment storage / plots / Pareto archive
    |
    +-- Shortlist -> unseen validation -> real player comparison
```

### Tooling choices

- Python 3 with a pinned, project-local virtual environment.
- Optuna's `TPESampler` as the first adaptive search method. Use a seeded `RandomSampler` as the baseline and for initial coverage.
- Optional `CmaEsSampler` only for a fixed, all-continuous search space; its Python package may require a `cmaes` dependency. Verify the pinned Optuna API actually installed before calling it.
- SQLite study storage is sufficient for local experiments with one worker; use a supported persistent backend if scaling later.
- Godot 4.7.2 executable resolved from actual local tools configuration. Start from current project utilities (`tools/project.py`, regression runners) rather than inventing a new hard-coded path.
- Headless runs should use documented Godot flags such as `--headless --path ...`, and a supported scene/test entry. Forward custom trial config using an explicitly implemented argument convention; **do not assume a CLI argument already exists**.
- One worker by default. Multiple physics instances competing for the same CPU can change performance and undermine comparisons; concurrency is opt-in and must use separate temporary directories and unique outputs.

**Do not make runtime gameplay depend on Python, Optuna, external APIs, a GPU inference runtime, or an online service.**

---

## 5. Runner interfaces and data contracts

Suggested project additions (adjust names to the verified tree):

```text
tools/auto_tuning/
  optimize.py
  run_trial.py
  candidate_schema.py
  scoring.py
  aggregate.py
  shortlist.py
  replay_candidate.py
  report.py
  requirements.lock / pyproject.toml
  configs/
    first_sweep.yaml
    scenario_splits.yaml
  tests/
    test_schema.py
    test_scoring.py
    test_runner_contract.py
features/grip_up/scripts/
  optimization_trial_runner.gd     # headless entry point or lab-integrated runner
  optimization_override_loader.gd # validated, trial-local parameter injection
  optimization_telemetry.gd        # structured measurements
features/grip_up/tests/
  test_optimization_invariants.gd
  test_optimization_replay.gd
docs/validation/auto_tuning/
  README.md
  study_manifests/
  reports/
```

### Candidate input JSON, representative example

```json
{
  "schema_version": "1.0",
  "trial_id": "pilot-000042",
  "candidate_id": "sha256-of-canonical-parameter-values",
  "profile": "BASE-A0-B1",
  "parameter_overrides": {
    "intent_target_speed_mps": 0.25,
    "input_ramp_seconds": 0.12,
    "rest_length_slew_mps": 0.24,
    "rest_length_accel_mps2": 0.9
  },
  "scenarios": ["vertical_pull_train", "asymmetric_traverse_train"],
  "requested_physics_hz": 120,
  "input_trace_id": "train_asymmetric_01",
  "run_seed": 101,
  "repository_commit": "VERIFIED_AT_RUNTIME",
  "timeout_seconds": 90
}
```

`repository_commit` above is an illustrative placeholder and must be replaced by actual observed revision information, **not supplied as if verified**. Named parameter keys and scenarios are a proposed integration contract; map them to real script/resources before implementing.

### Output JSON, representative example

```json
{
  "schema_version": "1.0",
  "trial_id": "pilot-000042",
  "status": "completed",
  "environment": {
    "engine_version": "4.7.2",
    "physics_backend": "Jolt",
    "physics_hz": 120,
    "repository_commit": "ACTUAL_RECORDED_HASH",
    "scenario_hash": "ACTUAL_RECORDED_HASH"
  },
  "invariants": {
    "force_budget_violation": false,
    "unphysical_grip": false,
    "direct_body_transform_mutation": false,
    "solver_nonfinite": false
  },
  "metrics": {
    "useful_displacement_m": 0.2,
    "movement_latency_s": 0.14,
    "directional_efficiency": 0.75,
    "unwanted_twist_rms_rad": 0.06,
    "grip_retention_rate": 1.0,
    "completed": true
  },
  "artifacts": {
    "trace_path": "TRIAL_LOCAL_PATH",
    "log_path": "TRIAL_LOCAL_PATH"
  }
}
```

Numbers in these examples are **illustrative**, not results from GRIP UP.

Every trial emits a machine-readable success/failure reason. Status taxonomy: `completed`, `failed_invariant`, `invalid_candidate`, `failed_runtime`, `timed_out`, `unsupported_scenario`, `cancelled`. A crash or timeout is **never** silently scored as an excellent configuration or dropped from the study without attribution.

Use atomic writes (temporary file + rename), unique trial directories and complete stdout/stderr logs. The parent runner must verify the output belongs to the intended code hash and trial ID.

---

## 6. Scenarios: teach the optimizer general control, not one route

### 6.1 Training set — small and diverse

| Scenario | Initial situation | Primary metrics |
|---|---|---|
| **Vertical Pull** | Two genuine grips on a static wall, reachable climb goal | response latency, useful height, settling |
| **Asymmetric Pull** | Different hand heights and shoulder offsets | useful directed motion, axial twist, effort |
| **Lateral Traverse** | Different hand placements, horizontal command | lateral progress, overshoot, corrections |
| **One-Hand Hang** | One loaded anchor; initial swing velocity variants | controllability, swing preservation |
| **Swing & Catch** | Real catch opportunity requiring timing | window, actual capture, grip retention |
| **Foot-Supported Step** | Hands and one real loaded foot vs feet disabled | force shares, progress, slip |
| **Ground/Grip Transition** | Begin walking, establish actual grip and unload feet | acceleration discontinuities, control gap |

Scenario fixtures must use the **actual implemented geometry and real initial physical contacts**. Do not call a manually attached hand a real catch in a test labeled natural input. Keep synthetic actuator fixtures distinct from genuine in-app capture tests.

### 6.2 Validation — unseen to the optimizer

Hold out at least:

- Different grip spacing, offset or wall angle, including asymmetric and near-limit anatomically feasible grips.
- An unseen left/right mirror of a training scenario.
- A new dynamic-support configuration: existing reactive beam is suitable as a **regression check**, not permission to implement M7.
- Different physical initial velocities and camera angles.
- Two-stage climb and multiple transfers.
- Long uninterrupted gameplay sequence: **The First Ascent**, including the hybrid top-out and grounded return.
- The original known A1 failure fixture as an explicit canary.

Keep the final held-out set private to the optimizer process and don't make per-trial decisions using it. Use it only for shortlisted finalists. If the tuning loop repeatedly inspects the held-out outcomes to adapt search bounds, create a **new** holdout split before final claims.

### 6.3 Input tapes and evaluation honesty

Record real input attempts (mouse button state, pointing ray/contact requests, WASD and camera actions) with timestamps. Use the same input replay for controlled A/B comparisons where possible, but acknowledge that diverging physics makes later clicks hit different geometry.

Therefore run **two complementary forms**:

1. **Open-loop replay:** identical control commands; good for low-level causal response and regressions, but poor as sole gameplay-score evidence.
2. **Closed-loop test driver:** reacts to current, observed physical state with a **fixed, declared, versioned policy**. It may choose reasonable commands but must not secretly adapt to the candidate tuning, teleport, grant extra reach or use a trained oracle to overcome failures.

Neither replaces human playtests. If a replay no longer targets the intended physical surface because the trajectory diverged, label the trial accordingly rather than counting the missed click as pure controller failure.

---

## 7. Metrics: define what 'better' means

Do **not** collapse all movement quality into a single score before understanding trade-offs.

### Required raw metrics

- **Useful displacement:** `dot(COM_end - COM_start, desired_unit_direction)` over the declared interval.
- **Directional efficiency:** useful displacement divided by full COM path length (with epsilon and a defined handling for near-zero paths); retain the sign.
- **Movement onset latency:** time between stable command onset and sustained useful velocity over a clearly declared threshold.
- **Response and correction:** overshoot, stop distance, reversal latency, oscillation and unintended movement after changing inputs.
- **Twist:** anatomically undesirable axial twist RMS; do not penalize all roll/pendulum motion indiscriminately.
- **Swing skill:** phase-responsive pumping vs braking, controllable amplitude, reachable-window duration, energy/work estimates with stated limitations.
- **Grip outcomes:** selected / reached / attached / retained, overload, slips, accidental releases and error reason.
- **Foot contributions:** load carried by real contacts, number of real planted supports, force share and whether selected contact actually aids the requested movement.
- **Smoothness:** finite controller-target jerk and body acceleration transients, excluding separately tagged legitimate collision impulses.
- **Actual completion:** real goal conditions, support and recovery; the hybrid top-out's assisted movement must be flagged as such.
- **Authority:** maximum observed force, torque, solver nonfinite counts, contact violations and unauthorized action attempts.
- **Runtime:** physics tick cost, total evaluation time, crash status and excessive fallback/recovery use.

### Metrics that must not be optimized blindly

- Maximizing ascent speed only: encourages jitter and uncontrolled impulses.
- Minimizing angular motion: destroys swing and essential asymmetric positioning.
- Minimizing arm force at all costs: can reduce useful movement and increase falling.
- Maximizing successful contacts regardless of load: rewards unsafe catch clamping.
- Comparing only average values: conceals rare catastrophic failures or one badly regressed posture.

### Hard constraints vs soft objectives

**Hard gate:** invariants, physical authority, contact legality, no nonfinite state, successful evaluation/trace integrity, no unapproved force/reach changes.

**Soft ranking:** response, directed progress, recovery, grip retention, skill preservation and robustness. Define thresholds relative to **A0 paired runs**, with confidence/variability across repeated simulations. At least one metric must explicitly reward controllable swing rather than treating every rotation as negative.

**Fairness:** performance is measured only against physically feasible tasks. Mark unreachable challenges and controlled negative fixtures separately.

---

## 8. Objective design and multi-objective selection

### 8.1 Starting with the baseline

For each scenario/seed/frequency setting, run A0 multiple times and record its distribution of results before evaluating new candidates. Treat the nominal same-seed runs as *paired setup*, not guaranteed deterministic replication: Jolt and runtime differences may still produce variation.

Scale metric improvements relative to **reference variability and scenario meaning**, not arbitrary unit magnitudes. For example, 1 mm changes in a 0.27 m climb should not be celebrated as a large general win.

### 8.2 First research phase: Pareto shortlist

Prefer 3–4 interpretable objectives such as:

1. **Reachability/progress:** completed physically viable scenarios and directed progress, robust across postures.
2. **Precision:** low unwanted overshoot and strong stopping/reversal control.
3. **Physical quality:** no excessive twist/jitter, maintained useful swing.
4. **Reliability:** retained legitimate grips and absence of severe regressions across seeds.

Keep a **Pareto archive** of non-dominated candidates. If Optuna's chosen sampler/setup supports multi-objective studies, use the documented multi-objective API; alternatively start with a frozen, explicitly documented composite for pilot exploration and only rank the finalists by separate objectives.

**Do not use a black-box numeric winner as the shipment decision.** Human evaluation determines which trade-offs feel best.

### 8.3 Safeguards against overfitting

- Train across multiple postures rather than a single climb.
- Randomize *initial conditions within authored physically valid ranges*, not forces or anatomy.
- Preserve fixed negative/adversarial fixtures.
- Include 60/120 Hz shortlist evaluation, not necessarily both rates for every initial search trial.
- Evaluate finalists in an unobserved route and human-played First Ascent.
- Treat any significant loss in lateral/asymmetric movement as a stop sign, even if vertical ascent improves.
- Report distributions, worst case and non-completion rates, not just means.

### 8.4 Sensitivity analysis

After the first sweep, produce one-dimensional partial comparisons or local perturbation tests for each tuned variable. Identify redundant, high-risk or weakly influential knobs. Shrink the space before running larger optimization budgets.

---

## 9. Experiment plan and budgets

These are **suggested evaluation counts**, not estimated execution times.

### Phase A0 — Instrumentation and replay contracts

- Freeze current branch/build and benchmark scenes.
- Verify currently implemented v1.2 test suite; implement only missing minimum evaluation APIs.
- Record exact runtime parameter identities and defaults.
- Prove one deterministic *configuration transport* test: passing a new override changes only the intended knob and leaves source files unchanged.
- Prove A0 reference evaluation can be reproduced and logged.

### Phase A1 — Baseline and random exploration

- 3–5 repeats for key baseline scenarios/conditions to estimate variation.
- First 12–20 candidate samples from a seeded random search, varying 3–4 knobs.
- Use one primary physics frequency (currently 120 Hz) during initial search and record backend/version.
- Reject failed constraints before computing performance rankings.
- Stop early if the logger is ambiguous or physics authority differs from the original controller.

### Phase A2 — Adaptive search

- Suggested additional 40–80 candidate evaluations using TPE.
- Re-test the strongest 5–10 candidates with repeat runs.
- Add 60 Hz comparisons, mirrored geometry and difficult postures for finalists.
- If evidence warrants, add a second search with tightened bounds; otherwise stop.

### Phase A3 — Generalization and human review

- Freeze candidate parameters before opening held-out results.
- Evaluate selected candidates against A0 on the same new scenarios and the First Ascent.
- Choose at most 2–3 finalists for human A/B sessions; randomize order and conceal the version label where possible.
- Record personal comfort and control ratings separately from automated movement scores.
- Do not promote a variant without a repeatable perceived benefit.

### Stopping conditions

Stop search if: hard safety invariant violation, substantial reproducible regression on essential lateral/asymmetric/swing fixtures, results dominated by noise, inability to reproduce traces, or no useful Pareto improvement across subsequent batches.

A negative result is a valuable answer: it may mean the current A0 controller is already well tuned within these parameter ranges.

---

## 10. Human playtest protocol

The main unresolved question is **whether a tuned movement feels better**.

### Design

- Minimum: designer does controlled repeated A/B self-tests, then 3–5 additional players if available.
- Include a short familiarization pass; alternate the order of variants between participants.
- Use identical gamepad/mouse settings, same graphics/frame pacing, geometry, profile, physics Hz and feet configuration.
- Test **Vertical Pull, Asymmetric Traverse, Swing & Catch, First Ascent**.
- Keep hands and route choices fully player controlled.

### What to record

- Task completion and time, attempts, falls, missed grabs, unnecessary releases and camera corrections.
- Subjective 1–5: input responsiveness, precision, swing control, perceived physical weight, fairness, fatigue, skill expression, willingness to play again.
- A forced-choice preference between A0 and each candidate, plus a short reason.
- Whether a beginner improves on repeats without all improvements being automated away.
- Events that *feel* wrong despite passing technical invariants.

Avoid broad marketing claims based on 3–5 testers. This is a small design gate, not a statistically conclusive study.

### Final acceptance

**KEEP** if a candidate remains physically valid, generalizes, and is clearly preferred in repeated playtests without sacrificing difficulty/skill. **REVISE** for mixed trade-offs with an identifiable fix. **REJECT** if it is unstable, overfits, feels automatic, or reduces expressiveness.

The designer's preference and the telemetry decision may differ; document both honestly.

---

## 11. Robustness and exploit tests

Required cases:

1. Zero attached hands + suspended WASD: no invented climbing propulsion.
2. Pending out-of-range target: no force/reaction before real contact.
3. One hand at extension limit: overconstraint/saturation cannot accumulate hidden energy.
4. Two hands on one dynamic support: no doubled net capability and correct reactions.
5. Release mid-swing and reattach: no old anchor force, no stale targets.
6. Camera orbit during held intent: no unintended direction jump or torque injection.
7. Asymmetric hands with a diagonal input: no movement sign reversal induced by candidate.
8. Physical feet OFF versus ON: no virtual foot forces when off; force only after valid contact when on.
9. Slip/overload: optimizer cannot train a candidate that ignores grip integrity.
10. Hybrid top-out: assistance is accurately labeled, controller authority mutually exclusive, valid return to walking.
11. Unsupported moving ledge: hybrid remains rejected as designed; no accidental promotion.
12. Parameter edge/bad values: reject NaN/inf, missing keys, out-of-bounds and cross-coupling violations.
13. Timeouts, crashes and stale trial results: correctly fail without false pass.
14. Multiple physics frequencies: no severe rate-dependent success inversion hidden by summary metrics.
15. New unused camera angle or mirrored route: no hidden dependence on fixture orientation.
16. A1 regression fixture: final candidates must be compared with A0, and the known sign/pathology documented.

All hard-constraint failures must be retained as unsuccessful evidence, not discarded from the experiment archive.

---

## 12. Reproducibility, observability and performance

- Record exact Git revision, Godot build, Jolt/engine configuration, input profile, B variant, random seed, test-scene file hash, parameters and scenario versions.
- Save trial manifest *before* execution; store immutable result afterward.
- Use explicit physics Hz and fixed-physics-step measurements, not a claim that identical seeds guarantee identical floating-point outcomes.
- Serialize metrics in SI units with an explicit schema, NaN policy and sample window.
- Validate frame/tick timestamps and filter out startup/loading frames.
- Separate physically simulated phases from the assisted kinematic top-out window in all physics work/force analyses.
- Save compressed traces only when needed (candidate finalists, failures or intermittent behaviors), not for every step of every trial.
- Keep an audit log of excluded scenarios and the cause of exclusion.
- Limit subprocess memory/CPU use; prefer sequential headless sessions first.
- Store optimization studies, candidate files and telemetry *outside production runtime state*, and ensure packaging excludes research dependencies.

### Report outputs

Produce a **comparison report** with:

- Baseline parameter table and permitted search space.
- Number of trials requested, completed, invalid, crashed, timed out and hard-rejected.
- Pareto plot/table, not just highest scalar score.
- Per-scenario A0 vs candidate means, spread, worst case and supported effect.
- 60/120 Hz result table for shortlisted candidates.
- Sensitivity plots/notes and suspected metric exploits.
- Human playtest preference and observed differences.
- `KEEP / REVISE / REJECT` recommendation for each finalist.
- Complete reproduction instructions and hashes.

---

## 13. Implementation milestones and no-go gates

| ID | Deliverable | Gate before continuation |
|---|---|---|
| **AT0** | Audit and freeze A0 source, fixtures, defaults and test runner | Source truth and baseline reproduce |
| **AT1** | Validated parameter schema + read-only, session-local overrides | Unknown/unsafe values rejected; no saved project modification |
| **AT2** | Structured headless evaluator and scoring contracts | Same trial ID and scene produce complete, auditable results |
| **AT3** | Baseline repetition and randomized search | Physics invariants pass; metrics have interpretable variation |
| **AT4** | Optuna TPE pilot + Pareto shortlist | No misleading single-score winner; constraints honored |
| **AT5** | Hold-out and 60/120 Hz validation | No major unseen-regression or fixture exploit |
| **AT6** | Human A/B validation | Perceived benefit established or candid negative conclusion |
| **AT7** | Candidate integration (only if approved) | New config selectable, no change to default without explicit approval |
| **RL0** | Optional standalone RL feasibility decision | Requires separate authorization and new design specification |

**AT6 cannot be marked PASS by automated runs.** Do not make RL0 a dependency of completing the offline tuning study. M7 remains independent and must not be auto-started because the optimizer finishes.

---

## 14. Agent responsibilities

### Main Codex agent

- Audit repository, identify actual tuning resources, create benchmark harness and isolate data files.
- Own Python integration, experiment manifests, storage, score calculation, reports and feature flags.
- Ensure baseline and old builds stay recoverable; avoid edits to original Janga.
- Run the exact project's Godot CLI and smoke/evaluation tools with captured logs.
- Perform regression and native playback of finalists, not just headless metrics.
- Preserve all negative experiments and clearly separate AI suggestion from gameplay adoption.

### Physics specialist

- Approve/limit the safe parameter schema before any search.
- Check intended and actual force/torque pathways; verify tuning does not secretly add motor authority or contact access.
- Design physical edge fixtures, safety assertions and metrics for real support versus unsupported movement.
- Diagnose why a candidate wins: numerical stiffness, better response, exploit, reduced swing, scene overfit, or genuinely robust behavior.
- Inspect differences at 60/120 Hz and on moving supports.
- Reject optimization metrics that reward impossible movement or hidden energy.

### Optional animation/UX reviewer

- Confirm better numbers correspond to visible control gains, not stiff, robotic animation or misleading presentation.
- Evaluate camera workload, grip readability and smoothness from actual gameplay footage.

At each gate write: changed files, new parameters, trial count, pass/fail detail, observed trade-offs and next-step recommendation.

---

## 15. Optional phase 2 — reinforcement learning (not part of first delivery)

Use RL **only if** the fixed-parameter study reveals a stable ceiling and a clear need for state-dependent coordination, such as switching how force is shared across different support geometries.

### 15.1 Allowed scope

A learned policy may output **small, bounded adjustments to low-level actuator goals** (e.g. rest-length offset within certified rates, or support allocation shares within existing budgets). It must not choose the next handhold, attach/detach hands, select routes, overwrite body motion, change physics caps or skip collisions.

### 15.2 Observations

Supported inputs only: body/support-relative position and velocities, actual hand/foot contact states, anchor-relative geometry, measured load, real joint/servo targets, current player's intended direction and available mechanical limits. No future perfect state unavailable in runtime.

### 15.3 Training and rewards

- Use a versioned observation/action API with explicit normalization and input bounds.
- Reward physically feasible movement along *the player's current intention*, precise braking, sustainable support and retention, not maximum ascent alone.
- Penalize unauthorized action attempts, saturation-induced jitter, unwanted catastrophic loss and mismatch with requested direction; **do not penalize all pendulum energy**.
- Train on heterogeneous support configurations and random feasible starts, holding out unseen geometry.
- Compare against A0 and best fixed-tuning variants on the **same tests**.
- Enforce all hard constraints outside the policy through a deterministic safety/controller layer.

### 15.4 Model deployment

Keep inference entirely local and deterministic for a given observation/model where practical. Specify export format and runtime before training; Godot/Jolt should continue to own physics. If reliable local inference is not practical, do not force Python into shipping runtime.

### 15.5 RL no-go criteria

Reject the RL path if it makes character motion automatic, reduces manual skill, is brittle in new geometry, requires unsustainable inference overhead, cannot be debugged, behaves poorly at alternative physics Hz, or violates the established movement/force contracts.

---

## 16. Final acceptance and product decision

The Physics Auto-Tuning Lab is successful if it delivers **valid experiment infrastructure and an honest comparison**, whether or not it finds better numbers.

Minimum acceptance:

- [ ] Existing GRIP UP play mode and A0 behavior preserved.
- [ ] Candidate values are isolated, typed, bounded, reversible and hashed.
- [ ] A standard Python command produces reproducible trial manifests and results from Godot.
- [ ] The evaluator distinguishes unsupported motion, contact, gripping, retention and genuine gameplay completion.
- [ ] Known v1.1 A1 regressions remain visible as negative controls.
- [ ] Study outcomes preserve worst-case results and variability.
- [ ] Finalists generalize to withheld scenarios, not just training arena layouts.
- [ ] Shortlisted candidates are checked at 60 and 120 Hz.
- [ ] At least one human A/B evaluation is recorded before any promotion, preferably including outside testers.
- [ ] No hidden extra force/reach and no shipping dependency on the optimizer.
- [ ] A clear KEEP/REVISE/REJECT and source-backed report exists.

**Final product principle:** the optimizer is a research assistant for the physics designer. The player must still choose holds, manage timing, develop skill and feel the consequences of weight and inertia. *The mathematically fastest climb is not necessarily the most enjoyable climb.*

---

## Appendix A — Suggested CLI shape (proposed, not already installed)

```bash
# Names below are target CLI contracts for implementation, not existing commands.
python tools/auto_tuning/run_trial.py --candidate configs/baseline.json --scenario vertical_pull_train --hz 120
python tools/auto_tuning/optimize.py --config tools/auto_tuning/configs/first_sweep.yaml --trials 60
python tools/auto_tuning/shortlist.py --study auto_tuning/studies/pilot.db --top 8
python tools/auto_tuning/report.py --study auto_tuning/studies/pilot.db --output docs/validation/auto_tuning/reports/pilot.md
```

Make the config, runner, and output paths Windows-safe and isolated per trial. Actual executable resolution should reuse current project tool configuration rather than hard-code `E:` as a universal path.

## Appendix B — External implementation references

- Optuna samplers / TPE / CMA-ES: https://optuna.readthedocs.io/en/stable/reference/samplers/index.html
- Optuna efficient optimization algorithms: https://optuna.readthedocs.io/en/stable/tutorial/10_key_features/003_efficient_optimization_algorithms.html
- Godot command-line/headless usage: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html

The installed dependency versions and runtime arguments must be verified in the working project. Documentation describes available APIs, not proof that this repository already implements the corresponding harness.
