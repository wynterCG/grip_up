# GRIP UP — Benchmark Preflight Certification & R3 Qualification

**Version:** v1.3.3 R3  
**Document type:** Implementation and validation specification (English)  
**Target:** Codex integration agent + independent physics/Jolt and measurement reviewers  
**Decision to implement:** Harden preflight certification, then run a **new** R3 benchmark qualification only if certified.  
**Not authorized:** parameter search, Optuna, CMA-ES, Jev, RL, M7, changes to the playable locomotion, or promotion of tuning defaults.

## 0. Executive instruction

The previous v1.3.3 R2 campaign correctly stopped **before gameplay simulation** when its first primary Swing & Catch reference failed `CANONICAL_BACKING`. The serialized `projection_config` contained numeric dimensions such as `[1024, 576]`; the Godot JSON parser presented them as real-valued numbers, while a newly added check compared the array against an integer array. The resulting failure was a **transport/schema error**, not evidence that the physical climb or camera projection had diverged.

R2 subsequently corrected the dimensional check and demonstrated one **supplementary** 120 Hz headless/rendered Swing & Catch pair with 536 POST samples each and strict correspondence across the published INPUT/PICK/CONTACT/PHYSICS/TASK channels. This did **not** qualify the primary R2 campaign, did **not** cover 60 Hz, and did **not** qualify the other movement domains.

**R3 has two independent gates:**

1. **PRE-R3 CERTIFICATION:** exercise the *entire real configuration transport and admission path*, including the actual JSON-backed projection structure and a small real replay pair at both physics frequencies. It runs **before** committing the R3 measurement source and **outside** the 96-process qualification budget, with a separately bounded budget.
2. **R3 PRIMARY QUALIFICATION:** freeze the certified source, repeat the original v1.3.3 BQ0–BQ7 plan using the unchanged catalog, controls, safety standards, and 96-process budget. The 34 existing regression processes remain separate, as explicitly decided by the designer.

If preflight fails, do not start the primary campaign. If a hard primary gate fails, stop R3 and report it. Fixes after a failed primary require a **new source identity and separately authorized campaign**; supplementary diagnostics may explain the failure but never count as primary cells.

**Success is not “the process ended,” “the catch completed,” or “the JSON was parsed.”** Success requires certified environment, valid onset, correct real contacts, matched fixed-input replay, honest metrics, correct domain coverage, and an explicit restricted eligibility decision.

---

## 1. Evidence and baseline that must be preserved

### 1.1 R2 facts (do not rewrite)

- Primary R2 source: `3ee5fabb6e2709d94dcc0e0663ba990bed8e75e3`.
- Final **diagnostic-only** fix source: `7a726febcb5257cac2cef23312c3b01d5cddb39b`.
- R2 environment preflights: **13/13**, including the negative 1440×810 rejection.
- First R2 primary H120 reference: `BLOCKED_SETUP / CANONICAL_BACKING`, no gameplay body, no physics tick and no usable catch metrics.
- R2 final D2 numeric admission checks: **16/16**.
- R2 D3/D4 supplementary H120/R120: original tape, **536 POST ticks**, actual contact at tick **440**, source FREE at **455**, destination retained at **527**, and full published-channel `STRICT_MATCH`.
- Historical legacy comparator reports a discrepancy between a raw JSON scalar and the native float32 `Vector2` representation of the **same** cursor coordinate. Treat this as a *representation comparison problem*, not a demonstrated cross-mode difference. Preserve raw values/bits and the legacy diagnostic.
- Original A0/B1 gameplay and the 34 regression processes/**1,146 checks** were preserved. Those checks do not qualify the new domains.
- R2's planned primary domain cases (vertical, asymmetric, left/right lateral, foot step, stop) and 60 Hz baseline replay remain **not run**. Do not fill them with the R2 supplementary results.

R2 is immutable. Use a new R3 root directory and independent hashes/receipts, including failed developmental attempts.

### 1.2 Protected playable configuration

- Godot **4.7.2 stable Steam**, Jolt integration used by the historical studies; identify the actual engine binary/hash at R3 startup rather than assuming it matches.
- Rigid-body mass **12 kg**; anatomical reach approximately **0.65708 m**.
- Total hand traction **360 N**, total feet **180 N**, individual foot **120 N**; shared attitude assistance **20 Nm**, combined climbing moment **150 Nm** under the existing reporting conventions.
- Experimental benchmark: **profile 4, A0/B1** and only the explicitly enabled original flags. The ordinary game continues to start on **profile 2 / LIVE**.
- A0's four canonical values: **0.25 m/s**, **0.12 s**, **0.24 m/s**, and **0.9 m/s²** (use the actual project-field mapping in the existing tuning registry).
- Existing movement physics, actuator and support budgets, world geometry, hold-to-grip, hand pending semantics, camera LIVE path, hybrid top-out, Janga grabber, and exported production defaults are immutable for R3.
- R3 changes may touch **evaluation-specific driver, schema validation, runner, comparison and tests only**, using guarded opt-in debug paths. Any required production change is a stop-and-request-review event, not permission to rewrite locomotion.

---

## 2. Campaign identity, code ownership and budgets

### 2.1 Identity and sequencing

Create a new work branch/checkpoint based on the currently corrected R2 diagnostic source, after reviewing the diff and confirming it is the intended candidate. Do not infer that R2's diagnostic change already qualifies R3.

Use distinct records and paths such as:

```text
builds/auto_tuning/benchmark_v133_r3/
  candidate_preflight/
    source_candidate_001/
      transport/
      environment/
      replay/
      results.json
  certified_source.json
  primary/
    references/
    domains/
    negative_controls/
    diagnostics/
    test_matrix.json
  regression/
  verification.json
  final_decision.md
```

The existing project structure may dictate different directory names. Resolve the actual paths by repository inspection, document them in the manifest and keep all historical results untouched. **Never overwrite** R1/R2, the original v1.3.2b window ablation, the historic v1.3.1 traces, or the protected backup executable.

Before each trial, record Git identity, dirty-tree policy, exact file bytes/hashes, engine path/hash, executable flags, tape bytes/hash, scenario revision, phase, seed, frequency, effective viewport, native window state, mode, and source of each input. A missing or inconsistent identity invalidates comparison. Old manifests are references, never substitutes for a fresh run.

### 2.2 Budget accounting — three separate ledgers

| Ledger | Allowed budget | Purpose and counting |
|---|---:|---|
| **Preflight certification** | **Up to 12 physical-replay processes** | At most three *distinct source candidates*, maximum 4 processes (H120, R120, H60, R60) per candidate. No primary qualification credit. Pure/schema checks are counted separately. Stop on a candidate's failing cell; do not run its remaining physical preflights merely to consume slots. |
| **R3 primary qualification** | **96 processes maximum** | **72 new-domain + 12 Swing & Catch reference + 8 negative/control + 4 issue-specific diagnostic slots**, as in v1.3.3. All primary attempts that launch/attempt physical admission are accounted for; rejected setup attempts are never silently free. Pure checks must be counted in another table. |
| **Historical regression processes** | **34, separate from 96** | The previously required suites at 60/120 Hz. Retesting after an infrastructure change must be explicit and recorded; do not count a repeat as 34 new suites. Failures are blocking. |

Keep **at most two additional pure diagnostics** per source candidate for repairing a preflight-only error, declared before execution. If more debugging is needed, return `PREFLIGHT_NOT_CERTIFIED` and ask for a new authorized bounded effort. The 4 primary diagnostics are reserved for failures *after* certification; do not transfer preflight slots into the primary budget or vice versa.

The 96-process ceiling and 34 independent regression processes are the user's established requirements; the 12-process preflight allowance in this document is a **new proposed bound**. Record it as its own ledger, not as previously executed work.

### 2.3 Freeze boundary

1. Preserve a recoverable **playable baseline** before edits.
2. Make evaluation-only changes and perform pure contract tests.
3. Perform preflight H/R at both frequencies on a single source candidate.
4. On a successful complete preflight, freeze the **identical source bytes** as the **R3 measured source** and record its hash. Certification must precede the primary campaign.
5. If any source/engine/tape/catalog/binding/config changes after that freeze, invalidate the unstarted or in-progress primary source and **stop**. Do not silently splice results across revisions.

A dry-run preflight is an eligibility check, **not** an optimization trial and **not** a replacement for the required primary baseline replays.

---

## 3. PC0 — Canonical JSON/typed admission certification

**Specific bug to prevent:** `Vector2i`-like/int array compared directly with a JSON-parsed float array, although each scalar is exactly an integer-valued number.

### 3.1 One canonical numeric contract

Implement or reuse a single named typed-boundary utility for window/backing dimensions, viewport dimensions and other integer-required projection configuration fields. It must:

1. Verify object/key presence and exact array length or exact schema shape.
2. Verify each element is numeric and not boolean, string, null, object or array.
3. Verify finite numeric values; reject NaN/infinity (including synthetic non-JSON test data).
4. Verify each integer-required coordinate is *exactly integral* (`1024.0` valid; `1024.5` invalid); prohibit rounding or clamping to pass.
5. Verify bounds and exact expected positive integer dimensions **after** type validation. No swapped axes or default on missing keys.
6. Preserve raw serialized values, their parsed type and the resulting canonical integer representation in the evidence.
7. Apply exactly the **same function** at preflight and at primary replay admission; no separate loose shortcut.
8. Reject invalid data before any creation of a gameplay world.

For example, the following are test expectations, not a mandated concrete GDScript API:

```text
[1024, 576]             -> accepted as 1024 x 576
[1024.0, 576.0]         -> accepted as 1024 x 576
JSON roundtrip of each  -> accepted
[1024, 576.0]           -> accepted
[1024.125, 576]         -> rejected: non-integral
[576, 1024]             -> rejected: wrong backing
["1024", 576]           -> rejected: string
[true, 576]             -> rejected: boolean
[1024, null]            -> rejected: null
[1024]                  -> rejected: wrong shape
[1024, 576, 1]          -> rejected: wrong shape
```

Do not generalize integral canonicalization to camera ray directions, COM, velocities, forces, material points, or other real-valued physics samples.

### 3.2 End-to-end real transport path

The *positive* certification must traverse the actual pipeline:

```text
Python benchmark runner
  -> final typed manifest and candidate/projection configuration
  -> actual JSON serialization to bytes
  -> actual filesystem/process invocation
  -> Godot JSON parser
  -> original replay/driver admission (with corrected typed boundary)
  -> canonical environment assertions
  -> pre-world clock/backing initialization
  -> actual V0 replay
```

**No synthetic shortcut:** a Python-only mock or a `Dictionary` created directly in GDScript does not certify the JSON roundtrip. Use the actual R3 projection structure, including fields that were missing from R2's earlier positive contracts.

Required outputs: `serialized_projection_config.json`, `godot_parsed_projection_config.json` (sanitized structured representation), `schema_results.json`, `admission_receipt.json`, and schema/source hashes.

### 3.3 Representation-aware comparison, not tolerance inflation

Keep the historical raw scalar coordinate and actual native float32 `Vector2` value distinct. If two fields are **specified by the API contract to represent the same float32 coordinate**, compare each only after converting through the *same native float32 representation*, and expose both originals and canonical binary/decimal values.

- This is **not** permission to round pixel coordinates, rays, normals, material points or physics fields to make them appear equal.
- `STRICT_MATCH` requires full equality of corresponding typed measured fields across H/R at equal backing and frequency, subject only to documented value representation semantics.
- Incomparable semantics must be labeled `TYPE_REPRESENTATION_MISMATCH` or `INVALID_SCHEMA`, **not** `STRICT_MATCH`.
- Retain the legacy comparator output alongside the new typed comparator, with an explicit reason if the two disagree.
- Never modify contact geometry or replay pixels to rescue a mismatch.

**PC0 gate:** all real roundtrip positive and negative contracts pass, and the exact final manifest accepted by preflight would be accepted by primary replay without a separate schema path.

---

## 4. PC1 — Window, viewport and clock certification

### 4.1 Canonical physical/environment profile

- Primary backing/root-window dimensions: **1024 x 576** effective pixels.
- Logical viewport: **1920 x 1080**.
- Preserve viewport/canvas transforms and scale identity information from the existing qualification pipeline.
- Keep the genuine v1.3.2a/V0 camera and seven ordered targeting rays, original material hit queries, and original selection filters. No artificial picker or scripted hand contact.
- Require matching **actual measured** window/backing dimensions in H/R; the requested CLI flags alone never count as evidence.
- At 60 Hz and 120 Hz, confirm two consecutive correct clock callbacks **before** world creation. Record any initial 120 Hz callbacks observed while preparing a 60 Hz session; they are not valid gameplay ticks.

### 4.2 Headless dummy-window setup

In headless only, where the CLI begins with a 64 x 64 dummy root, explicitly set the permitted root window size to 1024 x 576 **before clock validation and gameplay-body creation**; immediately read back the actual size and final viewport/transform. In rendered mode, inspect actual window/backing and fail if it does not match. **Do not silently overwrite a rendered window to conceal an unsupported or wrong environment.**

The path must be idempotent and opt-in to the evaluator, have no effect in ordinary LIVE startup, and must be included in the exact source hash/certification.

A deliberately wrong 1440 x 810 environment must be rejected by the environment gate, before physics world creation, with an honest `BACKING_SIZE` or equivalent typed failure. Never treat it as a legitimate 1024 x 576 test and never rescale the tape's ray coordinates to make it pass.

### 4.3 Environment and input identity

For every preflight and primary run capture:

- Effective headless/display-server or rendered mode, screen index, real window mode/size and requested values.
- Logical viewport and effective stretch/final transform, camera owner/mode, FOV, projection data, camera/target sampling phase, input lane, focus and pause state.
- A0/B1/profile/bindings, current seed and tape revision, accurate tick `delta`, callback order and scene world-creation boundary.
- Disabled/active observer and recorder flags.

Fail on wrong backing, duplicate/missing game input frame, wrong tick cadence, wrong identity, a paused run or unexpected LIVE authority over a virtual frame. Window position/monitor differences are recorded as context; do not assert general equivalence across monitors from one matched-window result.

**PC1 gate:** all H/R 60/120 environments qualify for their intended 1024 x 576 profile, with a successful intentional wrong-backing rejection that creates zero gameplay bodies.

---

## 5. PC2 — Minimum real replay certification before R3 freeze

Run **one** Swing & Catch replay in each cell using the original canonical tape for that *frequency* (new campaign hashes; do not substitute a diagnostic-only tape):

| Cell | Mode | Frequency | Qualification requirement |
|---|---|---:|---|
| PC2-H120 | headless | 120 Hz | Real contact, source released, destination retained; complete published trace |
| PC2-R120 | rendered scripted | 120 Hz | As H120 and strict same-tape H/R comparison |
| PC2-H60 | headless | 60 Hz | Real contact and retention, separate frequency-specific tape |
| PC2-R60 | rendered scripted | 60 Hz | As H60 and strict same-tape H/R comparison |

Observe all original physical semantics: actual free-surface raycast, reach/pending behavior, no traction before real contact, material-anchor identity, real source hand release, destination hand retention and ground/B1 contribution honestly labeled.

Compare *same-tape, same-frequency, same-backing* series **by physics tick**, not by alignment at contact time. Required layers:

1. **INPUT:** requested/accepted/effective logical commands, cursor validity/pixels, ordered edges, focus/pause state.
2. **PICK:** camera owner/pose, projection, ray origin/normal, winning offset and query, hit shape/face/material point.
3. **CONTACT:** left/right hand ID/state, anchors, foot/native support and contact/retention events.
4. **PHYSICS:** body COM/pose/v/omega, arm/foot strengths and force/torque budgets, solver authority and ground motor ownership.
5. **TASK:** phase/onset, real catch success, source release and retention duration.

**No tolerance-based repair** of ray or material deltas. Typed input-representation canonicalization may eliminate false self-comparisons only where the schema genuinely requires an exact float32 roundtrip. A successful catch with mismatched trajectory or effective inputs fails strict qualification.

Source R2's supplementary 120 Hz results are **historical context**, not PC2 passes. If a preflight cell fails, archive its first divergence and stop; any repaired candidate starts again with new identity and the permitted remaining preflight budget.

**PC2 gate:** both H/R pairs pass `STRICT_MATCH` for the measured published chain at their respective frequency and equal backing, without invariant violations; the final serialized manifest, compiler source, tape hashes and engine identity are frozen.

---

## 6. Source certification receipt and pre-primary checkpoint

After PC0/PC1/PC2 pass, create `certified_source.json` that includes:

```json
{
  "campaign": "benchmark_v133_r3",
  "preflight_status": "CERTIFIED",
  "source_hash": "<observed hash>",
  "engine_hash": "<observed hash>",
  "actual_backing": [1024, 576],
  "logical_viewport": [1920, 1080],
  "supported_frequencies": [60, 120],
  "supported_lanes": ["V0_HEADLESS", "V0_RENDERED_SCRIPTED"],
  "real_json_roundtrip": true,
  "strict_catch_pairs": {"60": "STRICT_MATCH", "120": "STRICT_MATCH"},
  "preflight_physics_processes": 4,
  "primary_processes_consumed": 0,
  "optimization_permitted": false
}
```

Placeholders are examples of the expected document structure, **not** evidence that a certification has passed. If any field cannot be verified, leave it absent/status-invalid and set `PREFLIGHT_NOT_CERTIFIED`.

Perform an independent physics-review and measurement-contract sign-off at this boundary. Check complete diff against A0/B1 baseline and confirm ordinary LIVE control is unaffected. All subsequent primary runs must verify against the frozen certificate; do not mutate its source to “fix” a primary failure.

---

## 7. R3 PRIMARY — repeat the existing v1.3.3 BQ0–BQ7 without changing scope

Use `GRIP_UP_Auto_Tuning_Benchmark_Qualification_Spec_v1_3_3_EN.md` as the **governing BQ0–BQ7 qualification catalog and methodology**. The additions in R3 are prerequisites and an execution protocol, not a redesign of the benchmark or its thresholds.

### 7.1 Exact ordering

1. **BQ0:** baseline/source audit; playable profile2 ordinary startup and A0/B1 experimental profile4 identity; run the existing 34 regression processes *in their separate ledger*.
2. **BQ1:** 3 environment validations per mode/frequency and the deliberate mismatch negative as in the v1.3.3 requirement. Pure pre-world checks do not fill task cells. Verify the certified primary source/manifest.
3. **BQ2:** fresh primary Swing & Catch references: **3 matched pairs at 120 Hz and 3 matched pairs at 60 Hz** (12 distinct processes), independent of PC2 and R2 diagnostic results. Every primary result must pass the same real-transport and full-trace guards.
4. **BQ3:** qualify task preparation, correctly typed support and onset certificates for six named domains. Do not fabricate starting body velocity/pose or write hand `ATTACHED`.
5. **BQ4:** verify time-series metrics and typed status semantics from raw traces before ranking any domain.
6. **BQ5:** six domains at H/R × 60/120 Hz × n=3, **72 processes maximum**, phased so valid 120 Hz cases run before their 60 Hz counterparts and hard precondition failures stop unnecessary expansion.
7. **BQ6:** freeze dataset/eligible cells, distinct training/reference/holdout partitions; do not open private holdout outcomes.
8. **BQ7:** evidence-backed independent GO/NO-GO judgment. This decision **does not run Optuna**.

### 7.2 Required domain catalog

| Domain | Primary task meaning | Validity condition |
|---|---|---|
| `vertical_pull_clean` | Positive signed upward movement via real hands | Genuine hand support and no ground-walking contamination after onset |
| `asymmetric_pull_clean` | Useful vertical movement with asymmetric attachments | Both/required hands genuinely attached; posture and angular motion disclosed |
| `lateral_clean_left` | Signed left motion from stabilized hanging start | Real attachments; no ground authority; correct stabilization certificate |
| `lateral_clean_right` | Signed right motion from stabilized hanging start | Mirror semantics; separate state/heading sign; no ground authority |
| `foot_supported_step` | Useful contribution of **physical B1 foot** | Real load-bearing planted foot; separate hand and foot forces |
| `two_hand_release_stop` | Path and settling after release in genuine supported state | Directed onset speed in range, real support, no false zero for missing stop |

The existing additional catalog entries (`two_hand_active_brake`, `one_hand_stop_60hz`, `first_ascent_public`) remain **diagnostic, open, or validation-only** according to the original v1.3.3 specification. Do not quietly substitute these for required scored domains.

The primary qualification requires, at minimum, vertical, asymmetric, **left and right clean lateral** usable and comparable at both frequencies. An impossible/baseline-failing fixture can remain `DIAGNOSTIC_ONLY`; it cannot be called `ELIGIBLE_FOR_RANKING` to meet a numeric quota.

### 7.3 Correct metric semantics

- **Signed progression:** `ΔCOM dot desired_unit_direction`, correctly signed and measured only during the authorized task interval.
- **Directional efficiency:** useful directed movement versus actual path, including the correct sign; not a reward for ground walking during hanging challenges.
- **Latency:** time from an *accepted* eligible command to confirmed useful response; report `ALREADY_MOVING_BEFORE_ONSET` instead of fabricated zero latency.
- **Stop path:** integrate **3D** COM motion from a real release onset until qualifying stable support; failure to settle is a typed non-measurement, not 0 m.
- **Settling:** report the start of the sustained stable interval after observing the full confirmation window; don't confuse active braking with later passive settling.
- **Active brake/reversal:** measure directed speed changes during their actual authorized phase, preserving interruptions due to ground or other support changes.
- **Support quality:** hand-attached versus reaching versus selected/pending, native ground contact, B1 foot load and valid material points all remain distinct.

Use existing v1.3.1/v1.3.2 metric status enums (`MEASURED`, `CENSORED_TIMEOUT`, `INTERRUPTED`, `PRECONDITION_NOT_MET`, `INVALID_MEASUREMENT`, `NOT_APPLICABLE`). Preserve raw `null` plus cause and provenance. Do not score missing, interrupted or unknown observations as if they were numerical wins.

### 7.4 Negative and safety tests

Within the **8 primary negative/control** processes, cover the prioritized invalid conditions from the governing spec: wrong backing, invalid/corrupt tape, duplicate/missing input tick, pending/canceled grip traction, wrong/changed support or invalid contact, and unsafe authority transfer. Assign them a fixed list and budget before starting the primary matrix. If a pure contract check can cover a case without physical execution, record it under the pure ledger and reserve physics controls for cases that actually need a world.

All normal force/torque budgets and reach limits remain mandatory, including zero force for FREE/REACHING, no hidden top-out motors in dynamic climbing and correct reactions on dynamic support where covered. Existing Jolt monitors and their published float representation limits are unchanged.

### 7.5 Primary hard-stop behavior

On the first **hard** invalid reference/environment, broken schema, first unmatched published-channel input/camera/ray/material/physics event, corrupted measurement, or physics safety violation:

- Freeze a failed primary receipt with the exact run identity, timing, raw input and earliest typed failure.
- Preserve the primary slot as attempted/invalid (do not erase or reclaim it).
- Mark downstream cells `NOT_RUN_EARLY_STOP`.
- Use at most **4 separate, explicitly budgeted issue-specific diagnostics**; they cannot become reference or domain passes.
- Keep a separate branch/source identity for any subsequent correction, and ask for a fresh campaign approval before another primary matrix.

Do **not** use result-based tuning, new tolerance margins, geometric offsets, rerouted raycasts, extra force, pre-attached hands, world teleports or fabricated trace values to turn failed tests green.

---

## 8. Repeatability, relevance and ranking policy

Within a frequency and matched backing, report H/R and within-mode n=3 repeatability separately. Between 60 and 120 Hz, compare task reliability and aggregate robustness, but do **not** demand tick-identical trajectories across unequal integration steps.

A domain can be `ELIGIBLE_FOR_RANKING` only if it has real valid onsets, meaningful objective, no critical support contamination, sound metrics, required repetitions and demonstrated same-backing cross-mode comparability. If not, label `DIAGNOSTIC_ONLY`, `EXCLUDED`, `MISSING_COVERAGE` or `QUARANTINED` with reasons.

Do not use preflight or R2 diagnostic examples as baseline samples in the R3 score. Do not use adaptive feedback policy output as fixed replay identity. Adaptive Swing & Catch, if retained as a reliability task, is distinct from V0 strict fixed replay and must be assessed statistically by its actual accepted decisions.

Do not calibrate tolerances against a failing candidate to make it acceptable. No optimizer may use the new benchmark until BQ7 signs off the per-domain status and the game designer separately authorizes a tuning pilot.

---

## 9. Tooling, performance and source integrity

### 9.1 Runner responsibilities

- Use the project's existing Python/Godot runner and exact CLI contract after inspecting the checkout; do not invent flags or assume old CLI examples still work.
- Give every attempt a fresh directory and atomic completion receipt; retain stdout, stderr, exceptions, exit code and run identity.
- Validate the *actual serialized file* that will be read by Godot, not just the Python in-memory object.
- Save a full typed receipt for any pre-world failure; never claim it was a physical test.
- Track requested and observed sizes and all clock callbacks, including transients prior to world creation.
- Prevent parallel Jolt worlds/runs during these comparisons; one physical evaluator process at a time.
- Keep transient editor/MCP setup separate from production defaults; restore `project.godot` exactly and verify afterward.

### 9.2 Comparator responsibilities

- Compare matching ticks in ascending order and report the **earliest meaningful unequal layer**, plus the first later actual physical divergence.
- Preserve both raw and typed-canonical forms for cursor fields. Detect same-source internal scalar/Vector2 representational differences rather than mislabeling them H/R divergence.
- Do not consider a changed collider/face, material anchor, accepted command, or input sequence “functionally equivalent” by numeric tolerance.
- Explain whether missing input fields, camera/backing mismatch, physics state mismatch, or environment suspension invalidates a comparison.
- Keep the old comparator's noncanonical result available for audit rather than rewriting history.

### 9.3 Instrumentation cost

Measure the benchmark with observer/trace toggles under the established environment, if budget permits and the earlier hard gates have passed. Record per-tick sampling/probe time and wall-clock/real tick gaps, with n and hardware. Do not claim ON/OFF equivalence from one sample or infer Jolt determinism from the absence of input events. Export builds must continue to exclude evaluator tooling.

---

## 10. Mandatory verification and QA

### Preflight contract matrix (before primary source freeze)

| Contract | Positive case | Required negative case |
|---|---|---|
| JSON dimensions | Actual `projection_config` Python→JSON→Godot with int/float/mixed numeric fields | Fractional, string/null/bool, swapped axes, malformed array |
| Exact source/tape | Hash and schema agree for final candidate and original tape | Mutated source or tape rejected |
| Backing | Real headless `root.size` and rendered 1024×576 | 1440×810 rejected before world creation |
| Viewport and clock | 1920×1080; 2 correct 60/120 Hz callbacks before bodies | Wrong viewport, missing clock confirmation |
| Virtual input | Exactly one valid frame/tick and held/edge distinction | Duplicate, missing, or out-of-order frame |
| Cursor typing | Same native float32 coordinate inside appropriate typed fields | Invalid value or genuinely different physical pixel rejected |
| Catch replay | H/R 120 and H/R 60, each same-tape strict comparison | Material mismatch is not hidden by catch completion |
| Playable startup | profile2/LIVE/provider OFF without source mutation | Wrong opt-in mode cannot activate in ordinary/release |

### Primary regression and runtime matrix

After certification, repeat the original 34-process preservation suites and the complete phase-gated primary 96-process plan, conditional on passing prior gates. Document all attempted, valid, invalid, blocked, not applicable and not run counts **separately for each ledger**.

### Review sign-offs

- **Codex/integration:** actual schema, runner, environment, source freeze, packaging and audit chain.
- **Physics/Jolt specialist:** real grip/force/contact and rollback invariants; onset integrity; first physical divergence; no cheating.
- **Measurement reviewer:** typed numeric comparison, metric states, paired H/R design, missing data, published-channel equality.
- **Designer:** human-playability preference is separate and **not** implied by a benchmark `GO`.

Independent reviewers must preserve dissent or open uncertainties; a combined green checkmark is not sufficient.

---

## 11. Acceptance outcomes

### `PREFLIGHT_CERTIFIED`

All PC0–PC2 gates pass on the same source/engine/tape manifest, including **H/R at 60 and 120 Hz**, correct serialized backing and full real replay. This **only authorizes starting the R3 primary qualification**.

### `PREFLIGHT_NOT_CERTIFIED`

Any preflight transport, environment, clock, input/camera, physical replay or source identity gate fails. Stop before the R3 primary matrix. Report scope and first cause, and do not reuse a prior diagnostic as a certified pass.

### `GO_LIMITED_BENCHMARK`

Primary BQ0–BQ7 pass according to the governing v1.3.3 rules: both catch reference frequencies qualify; vertical, asymmetric and **both clean lateral** scenarios qualify with the specified n=3 H/R comparisons at 60 and 120 Hz; safety and metric contracts are valid; foot-step and stop are either honestly qualified or specifically excluded with consequences. A limited go is bound to named scenes, backing, frequency, engine and source identity. It authorizes proposing a separately approved **small auto-tuning pilot**, not launching it here.

### `NO_GO_BENCHMARK`

The primary matrix hard-stops or fails its required domains, equivalence, semantics or safety gates. Preserve the valid evidence and do not resume the primary campaign after a source fix without new authorization.

### `PARTIAL_DIAGNOSTIC_ONLY`

Only a partial matrix exists, or the tasks remain useful for investigation but not scoring; the overall optimizer authorization remains **NO_GO**. Do not use this as an alternative label to conceal a required BQ7 failure.

**At completion, output both independent statuses:** `preflight_status` and `primary_qualification_status`. A passed preflight can coexist with a primary `NO_GO`.

---

## 12. Required deliverables

Provide:

1. `preflight_contract_report.md`, with actual JSON Godot roundtrip values and all negative cases.
2. `preflight_hz_mode_matrix.json`, four real H/R cells including hashes, camera/picking and physical contact results.
3. `certified_source.json` or `PREFLIGHT_NOT_CERTIFIED` with an exact blocking receipt.
4. `r3_primary_test_matrix.json` with attempted/not-run entries for **all** planned cells, not an inflated success count.
5. `r3_metrics.csv`, with explicit statuses, typed nulls and metric provenance.
6. `first_divergence.json`, `replay_comparison.json` and raw/bounded traces when relevant.
7. `negative_controls.json`, `regression_index.json` and the **three separate budget ledgers**.
8. `verification.json`: engine and sources, protected source hashes, LIVE profile2 startup, replay disabled by default, release export/tool exclusion, original project restoration.
9. `decision.md`: per-domain eligibility; primary GO/NO-GO; remaining risks; whether a separate ML experiment could even be proposed.
10. An archive manifest with hashes and retained failed attempts; immutable R1/R2/historical links.

Recommended final report opening:

```text
# GRIP UP — v1.3.3 R3 Preflight and Benchmark Qualification

Preflight: CERTIFIED / NOT_CERTIFIED
Primary benchmark: GO_LIMITED_BENCHMARK / NO_GO_BENCHMARK / NOT_RUN
Playable A0/B1: PRESERVED / REGRESSION
Preflight replay processes: attempted N / limit 12
Primary qualification processes: attempted N / limit 96
Regression processes: completed N / required 34 (separate)
Primary reference pairs: 120 Hz N/3; 60 Hz N/3
Qualified scoring domains: [explicit IDs]
Optimization executed: NO
Human feel approved: NO, unless independently tested
Blocking event and exact source: ...
```

---

## 13. Final implementation order and stop rule

1. Audit old source and manifests. Preserve baseline gameplay.
2. Build/fix **one** shared typed JSON admission path and its real file roundtrip tests.
3. Validate backing/window/viewport/clock in real Godot without bodies.
4. Run four bounded real preflight Swing & Catch replays and strict same-frequency H/R comparisons.
5. Freeze source identity and obtain reviewer approval **only after** all four pass.
6. Run the separate 34-process regression suite and ordinary LIVE/release checks.
7. Execute the original v1.3.3 primary campaign in strict gated order, without adjusting code or scores to force completion.
8. Return a bounded, evidence-based conclusion and stop. No automatic Optuna, ML, RL, Jev or M7 progression.

**Core instruction to Codex:** prevent *known infrastructure and schema faults* from consuming the primary qualification budget, while never weakening the real physical and replay requirements. A clean preflight merely earns the right to try the benchmark. It is not itself a benchmark result.

### Project-local basis

- `result_report(1).md` — v1.3.3 R2: initial preflight proof; first primary `CANONICAL_BACKING` admission failure; corrected D2; supplementary D3/D4 120 Hz strict match; unchanged source/physics and original regression evidence.
- `GRIP_UP_Auto_Tuning_Benchmark_Qualification_Spec_v1_3_3_EN.md` — governing BQ0–BQ7 scenarios, measurement contracts, 96-process cap, negative/control policy and GO/NO-GO requirements.
- `window_ablation_report.md` — v1.3.2b matched-backing strict equivalence in the two previously tested Swing & Catch tapes (not blanket Jolt determinism).
- v1.3.2a virtual cursor and v1.3.2 evaluator reports — source of the typed-input/camera/projection distinctions and unresolved domain-coverage limits.

**Do not claim any milestone here is implemented or passed until R3 produces its own receipts.**
