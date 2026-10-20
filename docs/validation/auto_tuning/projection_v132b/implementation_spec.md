# GRIP UP — Projection & Viewport Qualification v1.3.2b
## Targeted engineering specification for Codex and the Physics Specialist

**Status:** IMPLEMENTATION SPECIFICATION — not a report of completed work  
**Date:** 20 October 2026  
**Project:** `E:\Godot Games\grip_up` — Godot 4.7.2 / integrated Jolt  
**Suggested branch:** `feature/v1.3.2b-projection-qualification`  
**Predecessor:** Virtual Cursor Isolation v1.3.2a and its subsequent requalification campaign (`requal_20261020_r1`)  
**Scope:** Camera-to-viewport projection diagnostics, controlled display-size comparisons, and qualification of cross-mode picking/physics measurements. **Do not retune locomotion.**

---

## 0. Executive decision and boundaries

The v1.3.2a requalification established that virtual cursor/input isolation worked in the *three observed rendered interference comparisons*: user mouse movement, delivered button events, and a focus-loss episode did not alter the paired rendered replay. The JSON tape-admission defect was also resolved. Six headless replays (three at each physical tick rate) reproduced their own captures in all compared published fields.

Nevertheless, **strict headless ↔ rendered equivalence remains `NO_GO_INPUT_REPLAY`**. The first cross-mode mismatch moved from input/cursor to the camera-picking pipeline. This is not a demonstrated Jolt defect, nor evidence that external mouse interference caused the current mismatch.

Implement a **small, isolated diagnostic and qualification campaign** that determines *why* identical recorded viewport cursor/camera data can produce slightly different rays and materially different later physical trajectories. Test the effect of backing window size and effective viewport mapping before considering any correction or bounded comparison policy.

### Non-negotiable rules

1. Keep the A0/B1 playable locomotion, 12 kg body, ~0.65708 m anatomical reach, 360 N shared hands, 180 N total feet / 120 N per foot, 20 N·m assistance, 150 N·m combined moment, grip materials, Jolt settings, scene geometry, and hybrid mantle **unchanged**.
2. Keep the normal **LIVE** input and interpolated presentation camera untouched. The experimental `V0_PHYSICS_FOLLOW` replay camera remains explicitly identified: it is not equivalent by definition to normal player-view interpolation.
3. Preserve actual `Camera3D.project_ray_origin`, `project_ray_normal`, physics queries, hit selection, material anchors, and normal `request_hand` / contact validation. Never directly write `ATTACHED`, relocate a hand target, teleport the body, or synthesize a successful capture.
4. Do not overwrite v1.3, v1.3.1, v1.3.2, v1.3.2a, or `requal_20261020_r1` evidence. This campaign needs its own revision, hash manifest, immutable tapes, trial directories and failed receipts.
5. Do **not** run Optuna, Random/TPE/CMA tuning, RL, Jev scoring, private holdouts, M7, or a new locomotion A/B campaign.
6. No global floating-point/contact tolerance shall be introduced to make an existing failure disappear. A candidate tolerance is a conclusion requiring evidence, not an input to the experiment.
7. Separate **input fidelity**, **ray/picking identity**, **continuous physical agreement**, **functional gameplay agreement**, and **human game feel**. Passing one does not certify another.
8. At the first hard gate failure, stop the frozen matrix. Permit only a predeclared small number of directly related diagnostic runs; do not quietly fix and resume under the same experiment ID.

---

## 1. Baseline facts, not hypotheses

Source: the user's final v1.3.2a requalification report, not independent execution by this document's author.

| Observation | 120 Hz | 60 Hz |
|---|---:|---:|
| First cross-mode ray/material mismatch, tick | 282 | 28 |
| First ray-direction difference (norm) | `1.54318774e-7` | `2.9802322e-8` |
| First material-point separation | `0.810711 µm` | `1.474537 µm` |
| Rendered destination contact tick | 440 | 210 |
| Headless destination contact tick | 440 | 215 |
| First retained destination grip | 527 (both) | 259 (both) |

At 120 Hz, the accepted input, valid virtual cursor coordinate, ray origin, sampled camera pose, projection matrix, chosen offset and collider (`catch`, shape 0, face −Y) agreed at the first mismatch. The first known difference was **the value returned by `project_ray_normal()`**, followed by the physical material point. Later force, velocity and COM traces also diverged.

At 60 Hz the first ray/material mismatch was on `source` at tick 28. The current report does **not** establish that the discrepancy is caused by resolution, Jolt, display focus, driver scheduling, floating-point precision, or a Godot bug.

Effective display settings observed:

| Mode | Backing window | Logical viewport | Reported scale |
|---|---|---|---|
| Headless | 1024 × 576 | 1920 × 1080 | ~0.533333 |
| Rendered | 1440 × 810 | 1920 × 1080 | 0.75 |

Both are 16:9, but identical logical viewport, camera pose and `Projection` matrix do not prove identical **internal camera-rectangle size or screen-point conversion**.

The requalification's rendered-human vs rendered-quiet pairs were exact for the published input, cursor, camera, ray, material and physics fields in the tested cases. **Preserve that separate finding**: this v1.3.2b campaign is not a repeat of user interference investigation unless a relevant change affects input isolation.

---

## 2. Technical hypothesis and engine-specific investigation

Prioritize the **camera projection path**. For Godot 4.7, source for `Camera3D.project_ray_normal()` calls `project_local_ray_normal(screen_point)`, rotates the resulting vector by `get_camera_transform().basis`, then normalizes. The local ray implementation uses internal viewport camera-coordinate and camera-rectangle calculations, including `Viewport::get_camera_coords(...)` and `Viewport::get_camera_rect_size()`. These are **engine-internal helpers**, not a promise that GDScript can call them.

This suggests a testable explanation: the `screen_point` may be interpreted through mode-dependent effective camera/viewport mapping even if the camera transform and projection matrix exposed in the test logs match.

Potential causes to distinguish, rather than assume:

- **H1 — Effective viewport/window conversion:** actual camera coordinates or camera rectangle differ because the backing window sizes/content scales differ.
- **H2 — Numerical precision/order:** identical effective geometry and inputs still yield differences from computation precision, normalization or representation; identify the *first* divergent operation if possible.
- **H3 — Sampling/order:** apparently identical recorded camera data may have been sampled at a different point in the callback order than the API used for picking.
- **H4 — Picking implementation discrepancy:** the ray matches after faithful mapping but a query shape/collider or material-local transformation differs.
- **H5 — Other/environmental influence:** only consider once H1–H4 have evidence, rather than defaulting to Jolt or focus.

The experiment must distinguish **the API's returned local ray**, **the world ray**, **actual ray-query hit**, and **the material-space anchor**; these are separate boundaries.

### Official versioned references

- [Godot 4.7 Camera3D](https://docs.godotengine.org/en/4.7/classes/class_camera3d.html): `project_local_ray_normal`, `project_ray_normal`, `project_ray_origin`, camera transform/projection.
- [Godot 4.7 Viewport](https://docs.godotengine.org/en/4.7/classes/class_viewport.html): viewport size, visible rectangle, stretch/final transforms and camera ownership.
- [Godot 4.7 Window](https://docs.godotengine.org/en/4.7/classes/class_window.html): window size, content scale size/mode/aspect/factor/stretch.
- [Godot 4.7 `camera_3d.cpp`](https://github.com/godotengine/godot/blob/4.7/scene/3d/camera_3d.cpp): source-level calculation path. The installed `4.7.2.stable.steam.ed1daf0bf` binary and corresponding exact source revision remain the authoritative local environment. If the public 4.7 branch differs from the pinned build, record the difference; do not pretend a GitHub branch is binary identity.

---

## 3. Scope and deliverables

### Included

- Read-only diagnostics at the exact instant of real replay picking.
- A paired matrix that holds physical inputs and logical cursor constant while varying **only** the backing window/viewport configuration in named experiments.
- High-precision serialization of rays, relevant effective transforms, and contact provenance.
- Offline comparison reporting the earliest divergence at each layer.
- An independently checked conclusion as to whether window/viewport normalization explains the observed differences.
- A limited **proposal** for a tested replay-only correction or qualification envelope, if and only if supported by measurements.

### Excluded

- Rewriting Godot's projection or renderer, unless a narrow, separately approved instrumented engine build is absolutely needed to observe internal values. Such a build cannot silently replace the official engine in qualification.
- Directly injecting a world-space ray, replacing the real 7-ray targeting queries, forcing a collider/face/anchor, changing cursor target offsets or clamping a hit.
- Changing gameplay resolution/stretch defaults in production, altering the LIVE camera, moving geometry, adjusting physics, changing button semantics or modifying the optimizer's objectives.
- Broadening experiments to one-hand 60 Hz, lateral mirrors, stop metrics or other v1.3.2 unfinished domains. They remain outstanding and must be represented in the final scope table.

### Proposed artifacts, paths adaptable to audited tree

Use existing module names and conventions discovered from source; do not introduce parallel implementations when an approved hook already exists.

```text
docs/validation/auto_tuning/projection_v132b/
  README.md
  baseline_identity.json
  test_plan.json
  observations/
  ray_pipeline_diff.json
  window_ablation_report.md
  native_review.md
  independent_review.md
  decision.md
  verification.json
  evidence_manifest.json

tools/auto_tuning/  # extend the existing diagnostic and replay runners only
```

Every output has a source revision, engine identity, tape ID, mode, physical frequency, actual viewport/window configuration, outcome and source hash. Never infer these values from filenames alone.

---

## 4. Preserve baseline and qualify the measurement itself — PV0

Before any new runtime test:

1. Freeze the known-good v1.3.2a requalification commit and all original tapes/JSON/PNG/ZIP outputs by cryptographic hash.
2. Branch from the corrected replay/parser implementation; keep LIVE input and gameplay file hashes unchanged except for narrowly approved read-only tracing hooks.
3. Audit actual CLI flags, engine version/hash, renderer, root Window, content scaling settings, viewport hierarchy, camera ownership and `V0_PHYSICS_FOLLOW` phase.
4. Make a *fresh* baseline run without a candidate parameter override and verify profile 4/A0/B1 in replay while normal startup remains profile 2.
5. Assert world/body/resource creation occurs after the physical clock is valid, with no stale bodies or leaked recorder state.
6. Run existing v1.3.2a safety and original GRIP UP regression suites at the original 60/120 Hz coverage. Retain results separately from qualification.
7. Use a read-only sampling hook with minimal per-tick overhead, and measure its effect with an observer-off control. Tracing overhead itself is not automatically a physics discrepancy.

**Gate PV0:** baseline/rollback hashes verified; same replay tape and accepted inputs; no gameplay rewrite, added force or overridden anchor. Otherwise stop.

---

## 5. Projection diagnostic contract — PV1

Observe *on the same physics-tick boundary and at the same call site used for selecting the requested grip*. Do not substitute a later rendering-frame preview for the actual picking call. If any field is unavailable in Godot's public GDScript API, label it `UNAVAILABLE_PUBLIC_API`; do not synthesize an equivalent field and claim it was observed.

### Mandatory per-pick record

**Identity & sequencing**

- `trial_id`, `git_commit`, `engine_full_version`, `renderer`, `run_mode`, `scenario_id`, `tape_sha256`, `tick`, `physics_delta`, `input_stage`, `pick_call_index`, chosen cursor sample offset.
- Requested frame vs accepted/effective frame identity, button hand ID, `focus_active`, pause, internal replay provider state and active-camera node instance identity stable across the current process.

**Window, viewport & coordinate spaces**

- Root `Window.size`, current window mode and actual screen, content scale `size/mode/aspect/factor/stretch` if exposed by installed build.
- Actual owning `Viewport` instance, `get_visible_rect`, `get_size`, `get_final_transform`, `get_stretch_transform`, camera and viewport's active-camera ownership.
- If available, `get_camera_rect_size` and `get_camera_coords` via **explicitly documented engine instrumentation only**, as these may be internal C++ methods. Never call unsupported pseudo-APIs in production scripts.
- Raw tape cursor, its declared coordinate space, the precise `Vector2` supplied to camera projection, and the conversion applied before that call. Preserve all subpixel components; do not round or recenter.
- Monitor DPI / OS display scaling as *environment metadata* when available, not as a fabricated per-ray value.

**Camera projection**

- Camera node identity; `get_camera_transform()` and `global_transform` separately; projection type, FOV, near/far, keep-aspect, h/v offset and frustum offset.
- `get_camera_projection()` matrix values and any available camera-target/obstruction inputs from V0.
- `project_local_ray_normal(screen_point)`, `project_ray_normal(screen_point)`, `project_ray_origin(screen_point)` called with **the exact same argument** immediately adjacent to the production pick (read-only samples). Record field ordering and avoid any second camera movement between queries.
- Camera-rect/projection intermediates if and only if an audited debug engine is necessary and separately authorized.

**Picking and material contact**

- All seven actual ordered rays (origin, direction, distance, mask/exclusions, query sequence), first eligible hit and chosen sample index; do not run a second query and assume it equals the original result.
- Stable collider identity and instance mapping, shape index, hit position, world normal, surface/material ID, local/material anchor and native grip state transitions.
- Requested hand, target classification (selected/pending/reaching/contact/attached), retained support identity and first subsequent force/velocity/COM divergence.

**Numerical detail**

- JSON numeric serialization with sufficient precision for the runtime values, avoiding manual rounding or decimal truncation. Record whether the engine build uses standard or double-precision vectors. For human readability report angle between unit ray vectors, vector norm, and material-point distance in meters and micrometers; never use a rounded display value in the comparator.
- Reject NaN, infinity, missing required records and incoherent sample phases as `INVALID_TRACE`, not zero error.

### Diagnostic schema (illustrative; not a new gameplay API)

```json
{
  "trial_id": "pv132b_h120_r1",
  "tick": 282,
  "physical_hz": 120,
  "mode": "headless",
  "tape_hash": "<actual sha256>",
  "phase": "PRE_PICK",
  "cursor": {"space": "viewport_logical", "valid": true, "x": 0.0, "y": 0.0},
  "window": {"actual_size": [1024, 576], "content_scale": "<observed settings>"},
  "viewport": {"visible_rect": "<observed>", "size": "<observed>", "final_transform": "<observed>"},
  "camera": {"transform": "<observed>", "projection": "<observed>"},
  "ray": {"origin": "<observed>", "local_normal": "<observed>", "world_normal": "<observed>"},
  "pick": {"collider_id": "<stable mapping>", "shape_id": 0, "face": "-Y", "material_anchor_local": "<observed>"}
}
```

This is a **schema example**, not observed values for the full row. Implement typed JSON or a deterministic binary trace if it better preserves numeric fidelity; keep a text export for independent review.

**Gate PV1:** trusted point-of-call records with unambiguous phase/coordinate space, validated by synthetic parser/serializer tests and at least one matched same-mode pair. Missing fields are identified; no fabricated projection values.

---

## 6. Controlled window/viewport ablation — PV2

Use the *new* v1.3.2a replay tape captured at the same physical frequency. Do not reuse diagnostic-only or historical R0 tapes as qualification. Record every effective setting from the running engine; requesting 1024×576 does not prove Godot applied it.

### Primary pairs

| Pair | Headless window | Rendered window | Logical viewport | Purpose |
|---|---|---|---|---|
| P1: historic mismatch | 1024×576 | 1440×810 | 1920×1080 | Reproduce current result |
| P2: match small | 1024×576 | 1024×576 | 1920×1080 | Eliminate reported backing-size discrepancy |
| P3: match large | 1440×810 | 1440×810 | 1920×1080 | Independently test equality with a large backing size |
| P4: within-mode size | two separate headless sizes; two separate rendered sizes | — | 1920×1080 | Distinguish size sensitivity from render-mode sensitivity |

Execute P1–P3 at **120 Hz and 60 Hz**. Start with one fresh pair per setting; repeat a promising or contradictory result at least three times per mode/frequency before claiming reproducibility. Use the same fixed tape for a frequency and record whether the two frequencies have different legitimately captured tapes. **Never claim 120 Hz and 60 Hz must have identical tick numbers or trajectories.**

### Controls and confounders

- Keep scene, active camera, FOV, root Window scaling policy, game project settings, selected ray offset order, input tape, viewport logical resolution, seed, engine executable and callback order fixed while changing one backing-size dimension. If the engine cannot independently control a variable, label the pair `NOT_ISOLATED`.
- Keep aspect ratio constant for P1–P3. Any later aspect-ratio perturbation is supplementary, not used to justify current 16:9 failures.
- Verify real `Window.size` and viewport transforms *after* window initialization, immediately before constructing the world and at each relevant picking event.
- A headless renderer may have a virtual/hidden window with different semantics. Log the actual state; do not manufacture visual equivalence.
- Prevent the human user from affecting replay using the existing virtual input provider. The previous input-isolation evidence remains valid for tested conditions; do not spend the new budget on broad mouse/focus campaigns.
- Distinguish render frame cadence and physics tick cadence. A transient pause, wrong tick delta or viewport change invalidates the pair rather than becoming a physical mismatch.

### Pair evaluation

At each pair, compare in this order and stop the *comparison* at the first meaningful mismatch while preserving later raw traces:

1. Tape identity and accepted logical actions.
2. Logical cursor coordinates, validity and ordered offset candidate.
3. Active camera identity/owner, sampled transform, projection properties/matrix.
4. Root/window/viewport effective mappings and camera-local ray.
5. World ray, ordered physics query, collider/shape/face, material anchor.
6. Actual grip acquisition/release, force, velocity, COM and successful retention.

**PV2 output:** a table showing which single variable changed and whether it changes ray, anchor, physical state or task outcome. No generalized conclusion from just one successful pair.

---

## 7. Locate the first internal numerical difference — PV3

Use the Godot 4.7 code path as an investigation guide, **not** as a mandate to fork the engine. The public source suggests the stages:

```text
screen_point (viewport coordinates)
  → viewport camera-coordinate mapping
  → camera rectangle dimensions
  → projection half-extents / local ray construction
  → local normalization
  → camera transform basis
  → world normalization
  → actual physics ray/query
  → eligible hit / local material anchor
```

Compare available public API signals first:

- Same input to `project_local_ray_normal` but different output: focus on viewport mapping/dimensions and projection calculations; the camera's world rotation is not yet the first cause.
- Same local ray but different `project_ray_normal`: check camera transform basis, evaluation order and normalization.
- Same world ray but different hit: investigate query state, physics synchronization, shape geometry and query order without prematurely blaming the solver.
- Same hit but different material-local anchor: audit body/material transforms and the contact conversion phase.
- Same anchors/inputs but diverging forces or body dynamics: only then investigate genuine Jolt/physics differences.

If public methods cannot disambiguate internal mapping, the **Physics Specialist** may inspect the exact Godot build source and propose a *separate, non-shipping instrumented engine* that logs intermediate camera-coordinate and camera-rect values. Use it only with explicit branch/build identity, preserve the original engine comparison, and do not call its results an ordinary stock-engine run.

Never modify the release engine, change sampling phase to hide a mismatch, or use a handmade projection formula as the new production picking path during diagnostic qualification.

---

## 8. Strict identity versus functional and numerical qualification — PV4

Three distinct and non-interchangeable verdicts are required:

### A. `STRICT_MATCH`

Within a matched case, same effective replay events, camera/mapping inputs and serialized ray/pick pipeline values at the compared precision and phase. A strict mismatch remains a strict mismatch even if the deviation is sub-micrometer.

### B. `FUNCTIONAL_MATCH_WITH_NUMERIC_DRIFT`

Allowed **only after** root-cause classification and a predefined independent validation set show that small numerical differences do not change relevant behavior. Must verify:

- Same actual target collider, shape, support-local material point within a justified *local geometric* envelope, face and ordered ray winner (or explicitly document why equivalence of winners is safe).
- Same real grip acquire/release/retention outcome and no `NO_REAL_CATCH`, false contact or hidden ground assistance.
- No material violation of forces, torque, reach, collision, native support, ownership, pending-with-zero-force or recovery rules.
- Whole-trajectory metrics compared over matched **time intervals** and physically meaningful outcomes, not just final contact bit. Include distributions across runs, worst cases, first divergence, force/transient amplification and outcome sensitivity near reach/contact boundaries.
- A criterion for minimal *practical* difference selected before scoring candidates, independently reviewed, with a distinct status for outcomes matching but continuous data not qualified.

Do not declare this state merely because `0.81 µm` or `1.47 µm` appears small. The same campaign reported a 5-tick catch difference at 60 Hz, so sensitivity must be measured.

### C. `NOT_COMPARABLE` / `NO_GO`

If backing-window conversions are different and uncharacterized; if mapping/camera data cannot be observed reliably; if feedback causes different accepted inputs; if the world/raycast changes eligible support, or if continuous outcomes exceed justified limits, return a specific reason and keep the mismatch.

**Important distinction:** even if replay becomes functionally acceptable, the full Auto-Tuning optimizer may remain `NO_GO` because one-hand 60 Hz, lateral, stop/braking and reserved holdouts have not been requalified. Do not infer optimizer readiness from a single Swing & Catch fix.

### How to establish tolerances (if needed)

1. Gather same-mode repeat distributions, cross-mode matched-size distributions and cross-mode historical-size distributions, with both physical frequencies.
2. Separate natural numerical noise, changed window mapping, true different targets and trajectory amplification.
3. Select candidate *local* threshold(s) based on observed separation from incorrect contacts and geometry scale, plus predeclared performance requirements. Reject any threshold that admits a different shape/face/support, pending-only capture or loss of retention.
4. Freeze threshold proposal **before** running independent confirmation cases; do not tune it on the same failures that it must classify.
5. Report pass/fail counts, worst-case deviations, confidence limitations, sensitivity to contact boundary and any cases omitted.
6. If a defensible envelope cannot be found with the available evidence, leave continuous metrics **QUARANTINED**. This is a valid project outcome.

Do not establish blanket `ray_epsilon`, `anchor_epsilon` or `15 cm COM` settings by declaration.

---

## 9. Optional minimal normalization fix — strictly gated

**Do not implement a fix just because backing sizes differ.** At the end of PV3, choose one of:

- **Case 1 — Measurement-only correction:** the discrepancy comes from incorrect logging or coordinate labeling; fix diagnostics, not gameplay, and rerun qualification under a fresh campaign ID.
- **Case 2 — Replay-only coordinate mapping defect:** demonstrate that the virtual cursor's declared viewport coordinate is incorrectly converted before reaching the real Godot camera API. Correct *that one conversion* in the evaluation provider without changing production LIVE input or raycast behavior. Show before/after and full invariants. Use no direct world-ray injection.
- **Case 3 — Legitimate engine numerical difference:** keep the real API unchanged; qualify robust function-level comparisons or quarantine continuous scores.
- **Case 4 — Unknown cause:** produce `NO_GO_PROJECTION_UNRESOLVED`; stop rather than rewriting picking.

Any behavior-changing patch must be separately identified, reviewed, tested against the preserved baseline, and replayed in a **new** frozen qualification set. Do not modify the recorded historical campaign's source and claim the original runs now pass.

---

## 10. Physical safety and regression tests — PV5

All replays must pass the existing physical invariants (including the effect of the small ray difference, which might accumulate):

- 12 kg same RigidBody3D and original collision proxies.
- At most 360 N combined hand force, 180 N feet total / 120 N per foot, 20 N·m assistance and 150 N·m combined moment, with documented floating-point reporting tolerances (not increased force budgets).
- No force from FREE/REACHING/pending hands; actual material contact before load; no false ATTACHED.
- Consistent shape/collider eligibility, seven ray order, correct actual face and anchor.
- Arm reach never silently increases; early out-of-reach target is not a contact.
- No direct body-state writes, teleport, unapproved kinematic authority or root motion during climbing.
- No regression in live cursor selection, camera orbit/scroll, release/focus behavior, paused/reset state, ground support or hybrid top-out.
- The normal game's profile 2, flags OFF, LIVE provider and original build settings restored after testing.

Preserve a native rendered review via Godot MCP Pro when useful, but classify it accurately as scripted and supplementary, not a human playtest. A release-export smoke is not a full executable playthrough. Separate old regression counts from checks freshly executed by this campaign.

**PV5 failure:** any physical invariant failure forces `NO_GO_SAFETY` regardless of numeric ray equivalence.

---

## 11. Runtime budget and stop rules — PV6

Use an explicit, reviewable finite budget; the following is a suggested upper bound, not a count of tests already executed:

| Work package | Maximum | Requirement |
|---|---:|---|
| Static source/API audit | 1 | Full provenance and installed build check |
| Projection trace contract / parser checks | 1 suite | Do not create worlds unless needed |
| Preliminary P1–P3 pairs | 12 matched run-pairs total | Two frequencies, initially one pair/condition; budget includes directly justified repeats |
| Confirmation repeats | 12 run-pairs | Only for candidate cause/equivalence after preliminary evidence |
| Focused diagnostic runs after hard gate | 4 single runs | Directly linked to first failure only |
| Optional stock-vs-instrumented engine analysis | Separate authorization | No silent substitution |
| Existing gameplay regressions | As established in baseline suite | Independent of pair limits |

Freeze exact `test_plan.json` with the counts, sources, seeds, sizes and order **before** executing the final matrix. The suggested table must be reconciled so the executed maximum is unambiguous. No more runs automatically follow a `NO_GO`.

The freeze must specify a primary hard stop for: invalid tape, unexpected accepted-input mismatch, camera ownership/clock mismatch, missing instrumentation, material face/support switch, unsafe contact, or changed gameplay hashes. A small numerical deviation **is recorded as a strict mismatch** but can continue through a **pre-authorized diagnostic branch** to locate its cause. Do not let one expected microscopic difference prematurely prevent all meaningful diagnostics, and do not silently reinterpret it as a qualification pass.

Do not use arbitrary hidden retries, editor restarts, geometry changes, input rewrites or permissive fallback targets to obtain a green report. Preserve all negative receipts.

---

## 12. Proposed implementation architecture

Keep the existing virtual cursor provider and test driver authoritative. Add small read-only diagnostics/ablation controls rather than creating a new game-side controller.

**Suggested responsibilities:**

| Module | Change |
|---|---|
| Existing replay runner | Named window/backing-size run configuration; actual-state verification; immutable result directories |
| Existing replay provider | No behavior change unless PV3 proves a conversion bug |
| Existing picking audit | Point-of-call `project_local_ray_normal`, viewport mapping metadata, original hit provenance |
| Existing Python comparator | Multi-layer differences, strict vs functional statuses, first divergence and phase validation |
| Offline report generator | Window-size ablation table; per-frequency distributions; retained failed runs |
| Physics Specialist | Inspect authority, collision truth, numeric amplification and any proposed equivalence bounds |

The actual paths must be audited in the tree, using existing helpers from the v1.3.2a campaign. Implement typed records with isolated unit tests for missing values, non-finite values, signed zeros, precision serialization and version mismatch. Choose stable semantic collider IDs with a separately checked process-local mapping; don't mistake auto-generated node instance IDs for cross-process identity.

### Example report format

```json
{
  "campaign": "projection_v132b_r1",
  "decision": "NO_GO_PROJECTION_UNRESOLVED",
  "source_revision": "<actual commit>",
  "engine_revision": "<installed build>",
  "pairs": [
    {
      "pair_id": "P2_120_r1",
      "requested_headless_size": [1024, 576],
      "requested_rendered_size": [1024, 576],
      "effective_config_verified": false,
      "input_match": null,
      "local_ray_match": null,
      "world_ray_match": null,
      "material_identity_match": null,
      "contact_outcome_match": null,
      "continuous_metrics_status": "NOT_MEASURED"
    }
  ],
  "optimizer_permission": "DENIED",
  "unqualified_domains": ["one_hand_60", "lateral", "stop_braking", "private_holdouts"]
}
```

This is **illustrative output**, not a claimed result. Use real exact version, measured dimensions, counts and statuses in final receipts.

---

## 13. Milestones / specialist responsibilities

### PV0 — Baseline and source freeze
**Codex:** branch, hashes, project/settings/engine audit, test manifest and original baseline regressions.  
**Physics Specialist:** sign off protected files, budgets and distinction between virtual camera and LIVE.

**Exit:** protected current game and new campaign identity verified.

### PV1 — Observability at the pick site
**Codex:** typed, phase-specific ray/viewport/window audit, serializer and comparator changes; measure probe overhead.  
**Physics Specialist:** check actual source of rays and native contact identification, no duplicate query or invented field.

**Exit:** complete first-divergence provenance from cursor to material anchor.

### PV2 — Controlled ablation
**Codex:** run P1/P2/P3 at 60 and 120 Hz with verified effective window sizes, plus within-mode controls when budget permits.  
**Physics Specialist:** validate one-variable-at-a-time interpretation and any confounders.

**Exit:** evidence whether backing size is causal, correlated, irrelevant or unresolved.

### PV3 — Locate divergence / decide patch need
**Codex:** compare local ray/world ray/hit, reconstruct source-level order without replacing engine code; propose only minimal diagnostic fix if justified.  
**Physics Specialist:** independent numeric/contact-path review.

**Exit:** named, evidence-backed hypothesis or `UNRESOLVED`.

### PV4 — Qualify a limited comparison policy
**Codex:** produce strict equality table and separate functional/continuous comparisons, with unqualified cases explicit.  
**Physics Specialist:** reject unsupported tolerances and ensure geometry/contact boundary tests distinguish wrong supports.

**Exit:** `STRICT_MATCH`, `FUNCTIONAL_MATCH_WITH_NUMERIC_DRIFT`, or `NO_GO` with scope limitations.

### PV5 — Safety, normal-game regression and rollback
**Codex:** run preserved regressions, restore LIVE/profile2/defaults, export/smoke if necessary; verify release pack excludes experimental code.  
**Physics Specialist:** sign off invariant and evidence coverage.

**Exit:** playable A0/B1 unchanged regardless of qualification outcome.

### PV6 — Final bounded decision
**Codex:** generate reports, manifests, remaining-work list, exact coverage and failures; stop.  
**Physics Specialist:** independent recommendation `GO_LIMITED`, `NO_GO`, or `PARTIAL_DIAGNOSTIC_ONLY`.

**Exit:** one final product decision; do not launch tuning automatically.

---

## 14. Acceptance gates and future decision

### `GO_LIMITED_PROJECTION` (not full auto-tuning approval)

All must be true:

- Identical accepted replay input/cursor verified; effective viewport/camera mapping known and consistently replayed.
- The first ray difference is resolved or causally explained with a valid, independently checked comparison policy.
- Both 60 and 120 Hz have replicated, mode-paired evidence; no hidden missing cells presented as passes.
- Same legitimate collider/face/material selection, grip acquisition and retention, with no physical invariant failures.
- Any accepted continuous comparison has a predeclared, evidence-backed domain and threshold; out-of-domain situations remain quarantined.
- Normal LIVE controls, A0/B1 defaults, rollback and release packaging remain unchanged.

### `PARTIAL_DIAGNOSTIC_ONLY`

The camera/picking issue is localized and safe but lacks enough matched repetitions or functional-continuous comparability for scoring. Retain artifacts, declare exactly what is known and stop.

### `NO_GO_PROJECTION_UNRESOLVED`

Effective mapping or numerical divergence cannot be causally isolated, ray/query comparison remains invalid, or required input/mode identity is unavailable.

### `NO_GO_SAFETY`

Any physical limit, contact provenance, rollback, ownership or LIVE behavior regresses.

### Global optimizer status

**`OPTUNA / RANDOM / TPE / CMA / RL / JEV: OFF` throughout this project.** Even a successful PV6 closes only the narrow projection qualification issue. Future authorizations must separately address other quarantined benchmark domains, hidden validation, optimizer gates and human feel.

---

## 15. Final report requirements

The report must state without ambiguity:

1. Actual versus requested backing window, viewport and camera settings for every run.
2. The first divergent stage, tick and measured magnitude at each frequency.
3. Whether matching backing sizes removed, reduced or failed to affect the divergence; alternative hypotheses tested.
4. Whether local rays, world rays, actual ordered ray hits, material anchors, contact events and continuous physics agreed — each separately.
5. Replication and variability by mode/frequency, not just a single success screenshot.
6. Raw failed attempts and stopped/unrun cases, with preserved original identities.
7. Whether any fix occurred; exact source diff and fresh campaign identity if so.
8. What the Physics Specialist independently verified versus inferred.
9. Original GRIP UP LIVE runtime/defaults and all preserved regression results.
10. A bounded `GO_LIMITED_PROJECTION` / `PARTIAL_DIAGNOSTIC_ONLY` / `NO_GO_*` decision and remaining quarantined domains.

A **credible negative conclusion is a successful engineering outcome** if the root cause or limit is accurately exposed and no unsafe gameplay changes are made.

---

## 16. Instructions to the implementing agents

**Codex:** Treat this document as the implementation brief. Audit the existing v1.3.2a source, requalification evidence and installed Godot version before editing. Start with preservation and point-of-call diagnostics. Run the controlled backing-size comparisons under a frozen budget. Do not ask for a new broad controller spec. Do not relax comparison assertions merely to obtain PASS. Produce the exact measured data, evidence archive and explicit final gate.

**Physics Specialist:** Independently verify the causal chain between screen-space input and native contact. Approve neither equivalence bounds nor projection corrections without a demonstrated contact-safe rationale. Never treat a microscopic first deviation as automatically harmless, or a later COM divergence as proof of bad physics when upstream input/ray differences already exist. Preserve the user's preferred playable A0/B1 baseline.

**Design principle:** The purpose of this campaign is not numerical perfection. It is to learn whether two actual runs are comparable **well enough to make a trustworthy decision about gameplay tuning** — without falsifying how the character selects and loads physical grips.
