# GRIP UP v1.3.5a — Deterministic Metric Reduction & One Bounded Auto-Tuning Study

**Implementation specification for Codex and the independent physics / measurement specialists**  
**Status:** Proposed; not an implementation, experimental result, or permission to promote parameters.  
**Platform:** Godot 4.7.2 / integrated Jolt, Windows development environment, Python offline tooling.  
**Primary goal:** Remove the identified cross-interpreter *metric-audit* incompatibility, recertify the minimal benchmark under one frozen source/environment, then perform at most one bounded, fail-closed auto-tuning campaign.  
**Out of scope:** New movement physics, RL, Jev, M7, wider benchmark repair, production runtime ML, automatically changing game defaults.

---

## 1. Evidence and baseline: do not reinterpret the historical R4 result

This specification is based on `GRIP UP v1.3.5 — relatório do benchmark mínimo` (`REPORT(9).md`), especially its R4 artifacts and measured source. The previous campaign's **final decision was `NO_GO_MINIMAL_BENCHMARK`** and its playable **A0/B1 reference is unchanged**. Preserve the previous study and its failed trials verbatim. Nothing in this spec retroactively approves the old optimizer results.

Facts already demonstrated in R4:

- Minimal training catalog `benchmark_minimal_v135_r1` includes **Vertical Pull** and **Lateral Right** only. The frozen fixtures are the v1.3.4 r2 versions.
- The new baseline produced **24/24 valid processes**, **12/12 headless/rendered strict-match pairs**, and **16/16 within-mode matches**, using three fixed replays per mode/frequency/task.
- At 120 Hz the baseline's signed progress was **0.2063091993 m** vertically and **0.1453312337 m** to the right. At 60 Hz it was **0.2095216513 m** and **0.1435103752 m** respectively. These are historical measured values, not substitute passes for a new campaign.
- The actual optimizer study ended after **two proposals / three physics launches**, with **no usable numerical candidate objectives**, no random/TPE expansion, no finalists, no holdout and no human A/B trial.
- One slower trial failed its required quiet onset. The subsequent faster trial's vertical physics produced a positive raw progress observation, but its result was **invalidated by an audit mismatch**; Right was not evaluated. Neither trial may be adopted or recast as successful.
- The decisive mismatch was **one ULP of binary64** in recomputing a 3D path from 120 identical per-segment values. The published Godot value and Python **3.11.15 `sum()`** were `0.2245515785359135` m; Python **3.13.13 `sum()`** gave `0.22455157853591354` m. A **plain left-to-right scalar reduction**, tested offline in the historical report, gave the Godot value in both Python versions. The reported difference was `2.7755575615628914e-17` m.
- The first divergent offline accumulation prefix ended at tick 439; this is an **arithmetic auditing event**, **not** a first physics or headless/rendered divergence.

**Important separation:** R4's MB2 baseline qualification was a legitimate, limited GO, while its end-to-end optimizer was NO_GO. The new campaign must establish *both* a qualified baseline and a compatible full audit path. The physical replay equivalence criterion and contact rules are not relaxed by this change.

### Reference identities to read, not hard-code blindly

Inspect and capture the repository's actual R4 identifiers before editing: historical baseline tag `baseline/pre-v1.3.5-minimal-tuning`; R4 measured commit abbreviated `7d56a6d`; snapshot `cbe93f29aa2f6e47e4aa3fd784bbc1055cfa36bacaa385f7e07baa2bc262d54d`; Godot version `4.7.2.stable.steam.ed1daf0bf`; Optuna `5.0.0`; historical Python 3.11.15 / 3.13.13 split. Reuse original artifact hashes only for historical identification. **Do not claim a new revision equals the old source.**

## 2. Non-negotiable gameplay protection

Preserve these mechanical facts and limits:

| Property | Frozen value / behavior |
|---|---|
| Gameplay body | One 12 kg `RigidBody3D`; original Jolt integration |
| Anatomical grip reach | Approximately 0.65708 m |
| Two-hand force budget | 360 N shared |
| Physical feet | 180 N combined / 120 N per foot |
| Posture/swing assistance | 20 N·m shared |
| Resultant moment cap | 150 N·m |
| Arm spring/damping | 6000 N/m; 220 N·s/m |
| A0 tuning | speed 0.25 m/s; input ramp 0.12 s; target rate 0.24 m/s; target acceleration 0.90 m/s² |

No edits to the playable movement coordinator, arm/foot actuators, body forces, Jolt physics settings, grip acquisition, ground motor, hybrid top-out, character mass, collision geometry, camera LIVE behavior or default control profile. Keep the original Janga grabber and previous working builds intact.

Use only the already-approved session-local Resource override path for candidate tuning. No candidate writes a persistent `.tres`, `.tscn` or user settings file. The default executable and `PLAY` remain unchanged and do not ship optimization tooling.

**Safety invariant:** `RUN_VALID` is not `TASK_SUCCESS`, and neither is equivalent to `BETTER_FEEL`. A numerical tool failing its own cross-check does not prove that the physics regressed.

## 3. Deliverables

1. A single documented **binary64 metric-reduction contract**, identical for preflight, offline audit, candidate evaluation and final qualification.
2. A narrowly scoped reduction implementation in the Python auditing/tooling layer. Avoid changing the Godot formula unless an independent review proves the original Godot sequence itself needs a separate, explicitly authorized change.
3. A golden-fixture test containing the original raw segment bytes, their tick/ordering information, exact published Godot result, and a provenance manifest.
4. Tests across the pinned Python version and, where available, the historical other interpreter; same input bytes must produce the same **binary64 output bits**.
5. A new immutable campaign identity; frozen code, tools, interpreter, dependency lock, engine, tapes and protocol hashes; completely separate receipts and SQLite study.
6. A new, limited baseline qualification and gated optimizer run **only after** the audit contract is certified.
7. A fully auditable final decision: `METRIC_CONTRACT_NO_GO`, `BASELINE_NO_GO`, `OPTIMIZATION_NO_GO`, `CANDIDATE_FOR_HUMAN_AB`, or `NO_CANDIDATE_KEEP_A0` as appropriate. Do not label an unfinished study successful.

Names below are suggested artifacts, **not claims that the files already exist**. Codex must first inspect the current repository to locate the real implementations and their existing CLI/contracts. Prefer local additions to those modules over parallel, contradictory runners.

## 4. MR0 — Baseline freeze and repository audit

Before editing:

- Record branch, full SHA, clean/dirty status, engine SHA, Python path/version, installed Optuna version and SQLite settings.
- Verify the original R4 receipts, the failed auditor run and the source-level quality contract. Extract the *actual* 120 per-tick distances and their exact serialization, **never a rounded copy from the Markdown report**.
- Locate the Python `sum()` used to recompute `path3D` / stop path, and every other reduction in score-relevant audits. Identify whether any occurs in preflight, optimizer, Pareto, finalist/holdout or CSV report paths.
- Trace where Godot computes the published path: type of each segment, order of addition, accumulator type, when an observation is appended, whether interpolation is used, and whether segments are derived from COM source positions or published ready-made lengths.
- Verify clock, `POST` sampling, fixed replay tapes, candidate override whitelist and restoration logic remain unchanged.
- Create a recovery point (branch/tag) and byte-level protected-file manifest. Capture originals and the historical R4 archive as read-only inputs.

Do not infer the Godot arithmetic implementation solely from matching one displayed decimal string. The target is a **verified exact-bit contract** for the published observable, grounded in code and golden data.

**MR0 PASS:** precise metric definition, data provenance, original source identities, and all candidate mutation points recorded before a code change.

## 5. MR1 — Canonical binary64 reduction contract

### 5.1 Explicit intended arithmetic

For an ordered list of finite, already-defined binary64 segment magnitudes `d[0..n-1]`, the candidate contract is:

```python
def sum_binary64_ordered(segments):
    total = 0.0
    for value in segments:
        # No use of sum(), math.fsum(), numpy.sum(), sorted values,
        # compensated summation, quantization, or reordered parallel reduction.
        total = total + value
    return total
```

This is **candidate reference pseudocode**, not automatic proof of matching Godot. Ensure inputs are genuine Python `float` (binary64), validate finiteness and scalar type at the boundary (reject `bool`, strings, nullable gaps, and unexpected types), and preserve the original sequence. If existing behavior permits only finite non-negative path segments, enforce that existing invariant rather than silently taking `abs()` of invalid data.

For audit/serialization, record `struct.pack('>d', value).hex()` (or an equivalent complete 64-bit representation) and `value.hex()`; decimal rendering alone is not an exact-bit test.

**No tolerance substitution.** Do not replace exact cross-language validation with `isclose`, epsilon, decimal rounding, ULP allowance, float32 conversion or `math.fsum()`. Even a one-ULP mismatch is a valid failure of an **exact-recompute contract** until its semantics have been agreed.

### 5.2 Order and timing

- The reduction must use the same order the Godot metric defines: by simulation tick, then any declared within-tick order. A sorted-by-value list, concurrent order or event-aligned resampling is forbidden.
- Preserve the window endpoints exactly. R4 baseline windows have 121 POST observations at 120 Hz, or 61 at 60 Hz; 120 and 60 consecutive deltas respectively. Confirm this from real data; do not silently drop the initial/final sample.
- Do not mix physics frequencies, candidate versions, captured vs replayed inputs, raw vs corrected COM positions, or phases (PRE/POST).
- On interruption, missing observation, changing support, incorrect state, invalid segment, NaN/Inf, or broken tick continuity, the derived metric is **typed null with its original reason**, not a partial final score.
- Preserve signed progress, path length and directed efficiency as separate calculations. Do not overwrite path with final displacement or mistake a path length for signed progress.

### 5.3 Precision of inputs

Verify the byte-exact source format of each segment. If raw COM vectors are float32 and length calculations are performed in double, replay their **documented** conversion/magnitude sequence. If the receipt publishes already-computed double segment lengths, the canonical reducer must consume those values, not silently recompute using a different square-root implementation. Any discrepancy in individual segment bits is an **input-definition failure**, not an aggregation failure.

Do not introduce a separate homemade physics or projection algorithm. The patch concerns only the audit arithmetic of already published measurements.

## 6. MR2 — Golden vectors, adversarial tests and cross-interpreter checks

### 6.1 Historical R4 golden case

The full historical 120-segment fixture must reproduce:

```text
Godot:             0.2245515785359135 m
Python 3.11 sum(): 0.2245515785359135 m  (historical observation)
Python 3.13 sum(): 0.22455157853591354 m (historical failure)
Desired canonical sequential reduction: exact published Godot bits
Historical first differing offline prefix: tick 439
```

R4 reported 120 individual segment values identical between environments, with aggregate SHA-256 `2ef81c7306f293e5d7e22a7d9ad72c30997b9959920dca024e759ba20e8ca104`. Reconfirm that hash from the original evidence using the *original hash construction*, not a newly invented serialization. Preserve the published hex output `0x1.cbe1b2b09d8a6p-3` and the differing `0x1.cbe1b2b09d8a7p-3` as diagnostic references.

The implemented sequential reducer must reproduce the original Godot result bitwise under both historical interpreters if installed. At a minimum, the **one pinned campaign Python interpreter** must pass. Cross-version checks using a second interpreter are additional evidence; they must not permit silently switching interpreters mid-campaign.

### 6.2 Negative and metamorphic contract tests

Test with real JSON roundtrips, including nested manifests and metric payloads:

- Empty segment list, single element, many small elements and a large dynamic-range mix (for contract behavior, not as gameplay physics).
- Cancellation / ordering sensitivity where appropriate for the generic reducer; negative values must be forbidden on specifically non-negative path metrics.
- Segment list reordered with unchanged multiset: must **not** be called the same canonical sequence; preserve tick sequence/hash and detect identity mismatch.
- One altered binary64 bit, dropped or duplicated tick, missing/NaN/Inf value, wrong endpoint, mixed POST/PRE, partial measurement represented as zero, and incorrect units: all rejected.
- Python `int` vs integral JSON float where explicitly authorized by the existing schema; no numeric canonicalization for vectors, pixel cursor positions, contacts or forces.
- Simulated Python 3.11/3.13 legacy `sum()` mismatch retained as a **positive regression detector**: the new tool must explain/reproduce it instead of falsely claiming old `sum()` is consistent.
- Idempotent, side-effect-free recomputation from the same immutable raw receipt; result bits and provenance repeat exactly.

A manually entered decimal from the report is useful as an assertion label, **not** an acceptable substitute for the original raw fixture.

### 6.3 Validate *all* score-critical reductions

Audit and test any other metric accumulators used for *hard acceptance or ranking*: signed COM projection, path3D, lateral excursion, braking path, work/force budget summaries, quality-gate window accumulation and Pareto comparisons. Different formulas need not all use the same reducer; they **must** have explicit, source-matched algorithms and exact data boundaries.

**MR2 PASS:** original R4 failure is independently reproduced, the new reducer matches the source-derived Godot metric bitwise, the same code is used by qualification and optimization, and adversarial tests correctly fail. If any foundational assumption is disproved, stop and report `METRIC_CONTRACT_NO_GO` rather than fitting a tolerance.

## 7. MR3 — One Python environment and immutable experiment provenance

R4 separated qualification under Python 3.11.15 from the optimizer under Python 3.13.13. End that implicit split.

- Prefer the already installed, lockable Python **3.13.13 / Optuna 5.0.0** environment for the complete *new* campaign if dependencies work there. Otherwise select a single supported locked environment **before** certification, explicitly record why, and requalify everything under it. Do not choose a different interpreter after seeing candidate outcomes.
- Preflight, quality-contract generation, metric recomputation, optimization, SQLite, reports, shortlist and finalist evaluation must launch under the same pinned `sys.executable` or an equivalent verified environment fingerprint.
- Store executable absolute path and SHA (if accessible), Python `sys.version`, key package versions/lock hash, locale, platform, architecture, float format and metric reducer source/hash in every run manifest.
- Refuse mixed-version receipts or a source/metric-definition mismatch at resume. A changed semantic reducer, even if intended as a bug fix, requires **a new study identity**.
- Candidate evaluation always runs Godot 4.7.2 with its pinned binary; use same canonical **1024×576 backing** and logical **1920×1080 viewport**, explicit clock confirmation at 60/120 Hz, and same tape/fixtures for each matched comparison.
- The sole optimizer worker reserves a unique directory before launch; timeout and crash must yield typed invalid outcomes. Do not partially credit unfinished runs.

Preflight contracts may use offline past receipts to test arithmetic. A **new physical baseline** must be generated after the finalized tooling/code freeze.

## 8. MR4 — Audit pipeline integration (no physics edit)

Implement the canonical reducer through one shared module imported by all audit paths. Suggested function names:

```text
metric_binary64.py
  validate_ordered_segments(...)
  sum_binary64_ordered(...)
  audit_path_against_godot(...)
  canonical_metric_contract_id(...)
```

Locate actual project modules first; the above is a proposed shape, not the repository's asserted layout.

The output record for a score-relevant path should include at least:

```json
{
  "metric": "path_3d_m",
  "status": "MEASURED",
  "unit": "m",
  "window": {"first_tick": 425, "last_tick": 545, "phase": "POST"},
  "segment_count": 120,
  "segment_stream_sha256": "<real hash from archived bytes>",
  "published_binary64_bits": "<16-hex-digit representation>",
  "recomputed_binary64_bits": "<16-hex-digit representation>",
  "reducer_contract": "ordered_binary64_sequential_v1",
  "audit_result": "EXACT_MATCH",
  "provenance": {"source_hash": "<actual>", "python_env_hash": "<actual>"}
}
```

Values in angle brackets are placeholders, not invented receipts. Keep existing schema compatibility or explicitly version it; downstream readers must reject unknown versions rather than assuming equivalence.

Do not turn `INTERRUPTED`, `PRECONDITION_NOT_MET`, `NOT_APPLICABLE` or a hard safety violation into a numeric objective. Keep raw and derived values, reasons and audit stage separately visible. Any new metric contract should receive independent physics and measurement review before study launch.

## 9. MR5 — New certification before any parameter search

The original R4 study is closed and immutable. Create a **new campaign identifier**, new SQLite database, unique source manifest, new raw directories, new receipts and comparison outputs. The word "resume" in this specification means **resume the research program**, **not** `resume` the failed R4 SQLite state or trial counter.

### 9.1 Preflight sequence

1. Run static protected-source audit and restore verification.
2. Run JSON/manifest/source/parameter-whitelist negative contracts under the exact pinned optimizer interpreter.
3. Verify the 120-segment historical arithmetic case bitwise and the new complete metric contract.
4. Test headless and rendered backing/viewport/clock before constructing gameplay bodies; verify actual window sizes, not CLI intent.
5. Reproduce one guarded Swing & Catch replay as a **protected reference**, preserving contact/retention semantics and keeping it outside training objectives.
6. Run a complete candidate-shaped **end-to-end dry-run** using A0 as a candidate override: Godot outputs, Python metric recomputation, score ingestion, SQLite row, report generation and cleanup. Ensure no external optimization is started by the dry-run.
7. Restore and compare original Resource/default profile and protected files. Obtain independent measurement/physics sign-off.

No mixed interpreter, no instrumented reward from captures, no mouse/cursor or source identity mismatches.

### 9.2 Baseline qualification

Rebuild the minimal benchmark with exactly the two approved training domains, **Vertical Pull** and **Lateral Right**, for each frequency and headless/rendered mode. Preserve the existing v1.3.4 r2 fixture and tape identity unless a separate, approved revision is deliberately declared; do not repair test geometry during this experiment.

Use the prior R4 design: **three replays per mode/frequency/task = 24 primary baseline processes**. Require valid onset, complete prescribed measurement window, correct contact and ground/hybrid exclusions, genuine movement and support, and H/R strict match **within each frequency**. Do not require bitwise identity between different Hz.

Calculate the same reference performance fields: baseline signed progress, efficiency/quality, adverse excursion, task outcome, path, and typed unavailable latencies. For Right, `ALREADY_MOVING_BEFORE_ONSET` stays a valid *reasoned null*, not an instant-response bonus.

Run negative/canary protections separately, including N1 logical-suppression vs physical-dispatch contract and historical `Asym 60` / `Left 60` interrupted tasks. These may remain explicit canaries, never be re-labelled training successes. If the new math tooling changes published Godot metrics or replay physics, stop. The metric patch alone is not authority to amend game thresholds.

**MR5 PASS / `CERTIFIED_FOR_LIMITED_SEARCH`** requires complete baseline coverage, strict pair comparisons, correct input/contact/physics invariants, verified metric audits under the same interpreter, repeatability, independent sign-offs, and explicit partition isolation. Otherwise `BASELINE_NO_GO`; no optimizer trials.

## 10. MR6 — One bounded parameter-optimization pilot

### 10.1 Fixed parameter space

Only these four fields are permitted, with the exact existing whitelist, bounds and coupling rule:

| Field | A0 | Bound |
|---|---:|---|
| `traversal_speed_m_s` | 0.25 | [0.18, 0.32] |
| `traversal_input_ramp_s` | 0.12 | [0.07, 0.20] |
| `traversal_target_max_rate` | 0.24 | [0.16, 0.30] |
| `traversal_target_max_acceleration` | 0.90 | [0.60, 1.20] |

`rate^2 / (2 * acceleration) <= 0.055 m` and the four-physics-tick ramp rule at 60 Hz remain mandatory. Invalid candidates are rejected prior to creating gameplay. Do not widen the search space after seeing an outcome.

### 10.2 Small, explicit budget

**At most 18 proposed configurations and at most 40 new Godot candidate-evaluation processes**, whichever limit is reached first. A proposal can consume multiple processes because it must exercise different tasks/frequencies. Reserve processes **before** launching; rejected/invalid/timeout processes still count toward the applicable process ledger once launched.

Suggested staged allocation (subject to an independently approved frozen plan, but not an increased cap):

- **Initial local sensitivity:** up to eight individual parameter proposals with only the two 120 Hz training tasks (up to 16 processes), with one-factor-at-a-time comparisons and mandatory preconditions.
- **Exploration:** up to six bounded random proposals, staged 120 Hz screens with remaining slots; proceed only if resources allow.
- **Conditional TPE:** up to four proposals, **only if** a sufficient valid sample exists and the remaining budget can complete task/frequency validation; it is not an obligation to consume all slots.
- **Cross-frequency check:** reserve capacity within the same 40-process cap to exercise both 60 and 120 Hz for promising proposals. **No candidate can be shortlisted merely because it passed a 120 Hz screen.**

The actual frozen scheduler must calculate that all required processes fit the cap *before* making a proposal. No `RUN_VALID` label substitutes for complete candidate evaluation. Stop early when one hard invariant fails, the metric auditor disagrees, a protected ability regresses, the budget is exhausted, or quality gates become impossible to meet. Do not spend more launches to obtain a win after a hard-stop event.

### 10.3 Candidate evaluation and scoring

- **Two actual training tasks:** signed vertical progress and signed rightward progress, using separate objectives. The candidate must complete both full windows and have valid metrics, not just attractive raw partial motion.
- **Safety and control quality:** the frozen R4 quality contract was efficiency no worse than 0.05, adverse backward/lateral excursions no worse than 5 mm, and measured response latency no worse than the greater of two ticks or 15% of A0. Recheck the exact contract in the repository and archive it before running; do not reinterpret an unavailable Right latency as zero. Additional hard safety gates remain independent of reward.
- **Robustness:** no lost essential capture, no forbidden ground authority, no simulated contact from a pending hand, no additional force, no early top-out assistance during training, no changed reach, no unsupported body writes.
- **Multiple objectives/Pareto:** include A0 as a reference point. Do not depict a candidate-only Pareto set as superiority to baseline. Use worst-case outcomes and report both task/frequency cells; do not hide a negative cell in an average.
- **Error semantics:** a candidate whose precondition is not met is **invalid for scoring**, not an inferior numerical progress; record the failure as a separate reliability concern. A timeout is censored/invalid, not a task score.
- **No direct feel claim:** increased vertical signed progress alone is not evidence of a better game. Changes in twist, braking, controllability and grip robustness require separate testing.

**Do not replay old R4 candidates as automatically approved study entries.** Their parameter vectors may remain historical diagnostic context, but the frozen new study needs fresh runs and a distinct trial ID. R4's `0.28` raw vertical progress has no approved optimizer value.

## 11. MR7 — Protecting unseen skills and the finalist gate

Only candidates surviving the complete new two-task qualification can be promoted to a **shortlist for review**, not to game defaults. At most **three finalists** proceed, subject to a separately reserved, finite finalist ledger (recommend **up to 24 physical processes**, with exact scenario/frequency counts frozen before launch; do not silently consume optimization budget or historical quota).

Use withheld tests and protected skills that were **not** training rewards:

- Real Swing & Catch acquisition and retention at both frequencies.
- One-hand hang/release and braking, where the previous benchmark can certify the measurement; unavailable one-hand 60 Hz coverage remains `MISSING_COVERAGE`, never a forced pass.
- Asymmetric / Left 60 failures as honest regression canaries (a previously interrupted fixture cannot be declared solved without a separately approved valid test).
- Foot-supported loading and ground-to-grip transitions with real contacts; unavailable quality scores remain typed and visible.
- The First Ascent and hybrid top-out safety/return to ordinary walking, in their original scope; assisted top-out motion must not be credited as dynamic climbing progress.
- Alternate starting posture/camera or a genuinely independent tape where existing evidence supports it. Historical R4 included one extra independent Vertical tape at 120 Hz but **no corresponding Right tape**; do not claim independent Right generalization from that record.

No access to private holdout outcomes for tuning, threshold selection or retries. Open a reserved holdout only after shortlist freeze, if one exists and its access conditions are met. Treat a missing required qualification as failure to make a general recommendation, not as an opportunity to waive the requirement.

**Finalist gate:** no regression in hard-safety invariants or crucial retained abilities; improvement must be meaningful, reproducible and not just a higher score on one known tape.

## 12. MR8 — Human A/B and promotion decision

Automated tests cannot decide whether the character feels better. If a finalist survives, conduct actual A/B comparisons with the original A0/B1 using normal mouse and keyboard, profile 4 and the same physical limits. Alternate play order and allow familiarization; do not label scripted input as a human session.

Suggested controlled tasks: Vertical, Lateral Right, Swing & Catch and The First Ascent. Record attempts, task completion, unintended slips, number of corrections, stopping/reversal control, subjective responsiveness, comfort, physical credibility, skill expression and overall preference. If there are only one or two testers, disclose that limited sample. Existing designer feedback that A0 is fun is relevant context, **not** a substitute for new blinded/alternated comparisons.

Possible outcomes:

| Decision | Meaning |
|---|---|
| `METRIC_CONTRACT_NO_GO` | Reducer/input arithmetic contract not certified; no benchmark/search |
| `BASELINE_NO_GO` | New baseline or negative controls failed; no search |
| `OPTIMIZATION_NO_GO` | Pipeline discrepancy, hard safety regression or study failure |
| `NO_CANDIDATE_KEEP_A0` | Study completed within budget but no meaningful, robust candidate |
| `CANDIDATE_FOR_HUMAN_AB` | Technical finalist only; **not** default promotion |
| `HUMAN_REJECT_KEEP_A0` | Technical candidate declined in human comparison |
| `HUMAN_APPROVED_PROPOSAL` | Candidate recommended for *separate explicit* integration decision |

**Never promote automatically.** Keep A0/B1 as the normal reference even after a `CANDIDATE_FOR_HUMAN_AB` result. If no verified candidate emerges within the budget, terminate this optimization line and proceed to gameplay/M7 unless the developer separately requests a new research problem.

## 13. Process and budget ledger

Create separate accounts, recorded before execution:

| Ledger | Proposed maximum / scope | Counts toward optimization 40? |
|---|---|---|
| Offline contract, JSON, golden fixture | Pure tool tests, no gameplay worlds | No |
| Physical preflight | Cap specified in frozen plan; recommend max 8 | No; separate ledger |
| Baseline fixed replay qualification | 24 processes | No; separate ledger |
| Negative/canary validation | Up to 8 processes, exact list frozen | No; separate ledger |
| One bounded auto-tuning pilot | **18 proposals / 40 candidate processes max** | Yes |
| Finalist / unseen-skill validation | Up to 24 processes, only after shortlist | No; separate ledger |
| Existing safety regressions | **34 processes**, previously 1,146 checks | No; mandatory independent ledger |
| Human sessions | Real persons only; counts and outcomes separate | No |

These are **proposed new-campaign budgets**, not reports of runs already performed. Fix the final per-stage maxima before any scored candidates. Development failures and diagnostic reruns need their own bounded accounting; never silently refill the candidate budget. If one required validation cannot be performed under the remaining budget, report an incomplete gate rather than inventing more capacity.

## 14. Reproduction, archiving and independent review

For each run capture:

- New campaign/study ID, parent R4 reference ID, branch/commit, clean source manifest, public-helper hash, raw tape ID/hash and catalog revision.
- Godot binary and Jolt/version fingerprint; actual headless/rendered mode, backing size, logical viewport, clock, seed and startup confirmation.
- Exact Python interpreter/version, dependency lock, Optuna/SQLite versions and reducer contract version/hash.
- Approved candidate parameter vector and canonical candidate SHA; specific Resource copy, protected flags and restore certificate.
- Input/cursor/camera/picking audit, real contact and retention, feet/ground authority, published physical fields, typed metric status, raw segments and final binary64 bit representation.
- stdout/stderr, timeout/errors, invalid reasons, sidecars, trace window, comparator decision, task decision, quality decision and ledger consumption.
- Complete failed attempts, including invalid setup, invalid numerical contract and unsuccessful tasks. Never replace the original logs with a report-generated success.

Use new directories outside the closed historical R4 study. Archive receipts and source bytes with SHA256; audit extraction/readback. Avoid falsely asserting that identical values in the published trace mean the entire internal Jolt state is bitwise identical. Keep PRE/POST phase labels truthful; POST is post-control before next physics integration in the existing instrumentation.

Independent physics review checks contacts, forces, body authority and physical safety; independent measurement review checks metric semantics, binary representation, order of operations, data splits, scoring and budget integrity. Both sign-offs are required for any search GO and for any finalist. If specialists disagree, record a NO_GO and the specific disagreement.

## 15. Exact acceptance tests for Codex

A1. Historical R4 raw-segment fixture is read from authentic bytes; old Python 3.13 `sum()` discrepancy is reproduced, while new sequential reduction matches the source-derived Godot binary64 bits.  
A2. Reducer behavior matches across the two historical Python versions where both can be run; the actual new campaign uses **one pinned interpreter** end to end.  
A3. Dropped/duplicated/reordered sample, NaN, wrong phase, wrong units, incomplete measurement, mixed schema and altered original source are rejected, never scored.  
A4. Complete Python→JSON→Godot negative contracts pass using the **real manifests**, not simplified copies.  
A5. New physical preflight runs with proper backing, camera and clock at 60/120 Hz; same-input reference replay results are valid and original contact rules preserved.  
A6. Full new baseline is 24/24 process-valid and has strict H/R matching within each frequency and every training task; reference progress/quality values are recorded anew.  
A7. N1, other selected negatives, canary tasks, reset and Resource restoration are exercised honestly under the frozen plan; evidence is preserved separately.  
A8. The optimizer uses the same audited reduction library and environment and never gives objective values to typed-invalid tasks.  
A9. All searches observe the declared process/proposal caps, early-stop on invalid input/physics/metric contract, and leave the failed R4 study immutable.  
A10. Swing & Catch, contact pending/slipping rules, ground authority, actor masses/forces and hybrid top-out regression suites remain unchanged and pass in their declared coverage.  
A11. A clean normal game launch remains profile 2/LIVE with original A0 tuning; experiment provider OFF; release pack excludes Python/Optuna/testing assets.  
A12. Final outcome names actual trials and receipts, reports zero candidates if none qualify, and never presents an invalid raw gain or a positive scripted task as human validation.

## 16. Work division and stop conditions

**Codex / integration owner:** inspect actual repository, freeze sources, implement the smallest shared metric-audit change, unify interpreter launch, wire manifests/CLI and tests, execute guarded campaigns, archive results and produce final report. Do not redesign movement in response to candidate scores.

**Physics specialist:** confirm no gameplay modifications, appropriate acquisition/retention and force budgets, real unsupported contact handling, original fixture identity and dynamic vs hybrid phase separation. Escalate any safety anomaly before scoring.

**Measurement specialist:** reproduce the exact one-ULP root cause from historical raw bytes, verify Godot accumulator semantics, certify sequential reduction as source-equivalent, review missing data and partial windows, quality thresholds, Pareto construction, holdout isolation and arithmetic identity across tools.

**Human designer:** only after an independently approved technical shortlist, compare A0/B1 and finalists by actually playing. Retain the original if improvement is unclear.

Stop at the **first** of: failed contract or sign-off; newly invalid baseline; violated physics/gameplay boundary; first unauditable metric; exhausted budget; no eligible finalists after the bounded study. No automatic v1.3.5b or further tuning loop is authorized. A clean **`NO_CANDIDATE_KEEP_A0` is a successful research conclusion** even though no parameter improves.

---

## 17. Required final report outline

1. Executive decision and explicit scope (`metric contract`, `baseline`, `optimizer`, `human`).
2. Frozen source, engine, Python/Optuna and reducer identities.
3. Historical R4 one-ULP reproduction, new exact-bit evidence and adversarial contracts.
4. Clean new baseline by domain/frequency/mode, with typed statuses and pair comparisons.
5. Negative/canary and physical safety reviews.
6. Actual optimizer proposals, trial states, process count, Pareto including A0, and early stops.
7. Finalist/unseen tests **only if legitimately reached**, with missing evidence called out.
8. Human trial evidence **only if actually performed**.
9. Unmodified LIVE/default/export proof, rollback and protected-file hashes.
10. Final `GO / NO_GO / KEEP_A0 / CANDIDATE_FOR_HUMAN_AB` decision grounded in receipts, followed by the game-design next step.

**Product principle:** GRIP UP's climbing feel is already enjoyable. This is the final bounded attempt to see whether data-driven parameter selection can produce a **measurable, reproducible and human-perceptible** improvement without making the character stronger or more automatic. If it cannot, keep A0/B1 and move forward with gameplay.
