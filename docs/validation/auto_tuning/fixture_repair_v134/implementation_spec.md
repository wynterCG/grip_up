# GRIP UP — Benchmark Fixture Repair & Feasibility

**Specification:** v1.3.4 · Pre-M7 / Auto-Tuning Laboratory  
**Language:** English  
**For:** Codex integration agent; independent Jolt/physics reviewer; independent measurement and test-design reviewer  
**Source of requirements:** `GRIP UP — v1.3.3 R3 Preflight and Benchmark Qualification` (`result_report(2).md`), measured source `7a578995915d56ade2fa447f3adfdd6e19dc0218`  
**Required product decision:** keep playable A0/B1; repair the evaluation-only pick-record contract; make the required physical benchmark fixtures capable of valid measurement at both 60 and 120 Hz; demonstrate feasibility with a **small, separate campaign**.  
**Not authorized:** another 96-process primary benchmark campaign; Optuna/TPE/CMA-ES, RL, Jev, M7; parameter optimization; broader locomotion refactor; changing the player's real forces, collision rules, hand reach, physics timestep, hybrid mantle, or default control profile.

---

## 0. Executive mandate

R3 **certified its preflight** and ran 61/96 primary processes, but ended `NO_GO_BENCHMARK`. Swing & Catch reference replays gave **six strict headless/rendered pairs** (three at each frequency); the 34 separate regression processes passed **1,146 checks**. The remaining failures do not justify rewriting the movement controller:

1. Negative control **N1** was rejected *after* a full physical run because a validator counted a **logical no-query pick event** as though it required a real raycast sidecar record. The actual sidecar correctly contained three physical query calls, not four.
2. The compulsory **Vertical Pull, Asymmetric Pull, Left/Right Lateral** and diagnostic **Foot Step / Release-Stop** scenarios frequently failed to establish or retain the physical measurement preconditions. At 60 Hz, some ran into the SpawnPad during the analysis window; at 120 Hz, Vertical Pull was interrupted close to an edge, with a conservatively flagged FootBase clearance uncertainty. A valid replay can be faithfully reproduced while its *task* remains unmeasurable.
3. No movement domain was eligible for Auto-Tuning scoring in R3. Positive 120 Hz lateral results are valuable **diagnostic evidence only**, not permission to promote them or reuse them as qualified R3 scores.

**v1.3.4 is a repair-and-feasibility exercise, not a ranking exercise.** First correct and certify the instrumentation semantics; next demonstrate that the same real A0/B1 controller can enter valid starting conditions and complete measurement windows in evaluation-only fixtures. Only then **recommend**, without automatically launching, a separately authorized new benchmark qualification.

A good outcome is a short, truthful report. If one required fixture remains infeasible under the protected physical rules, report `FEASIBILITY_NO_GO` and stop. Do not move the acceptance criteria until a result passes.

---

## 1. Frozen evidence to preserve and reproduce

### 1.1 Identity and immutable R3 receipts

Keep the entire original R3 campaign, including its `PREFLIGHT_CERTIFIED`, primary `NO_GO_BENCHMARK`, source and helper hashes, tapes, raw traces, failed N1 receipt, typed metric CSV, slot matrix, independent reviews, and export/restoration evidence, untouched. New experimental files require new identities, directories, manifests and hashes. Do **not** resume the original 61-process campaign or fill its missing cells with v1.3.4 trials.

R3 measured-source commit: `7a578995915d56ade2fa447f3adfdd6e19dc0218`; composite certified snapshot: `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`. Inspect and verify these references against the actual checkout rather than assuming branch HEAD is identical. Godot/Jolt observed: `4.7.2.stable.steam.ed1daf0bf`. The original study used backing **1024×576**, logical viewport **1920×1080**, seed **101**, profile 4 A0/B1, and V0 replay input. Capture exact executable hashes at runtime.

Historical R3 evidence that v1.3.4 must quote without reinterpreting:

| Case | 120 Hz evidence | 60 Hz evidence | Honest interpretation |
|---|---|---|---|
| Swing & Catch reference | 3/3 strict H/R pairs, genuine destination catch | 3/3 strict H/R pairs, genuine destination catch | Reference comparison passes within the certified environment |
| Vertical Pull | onset tick 268; interrupted at 275 near SpawnPad edge; FootBase `OVERLAP_OR_ROTATION_BOUND`, ~0.766 mm margin | onset not certified | No usable progress/latency in R3 |
| Asymmetric Pull | `QUIET_ONSET_NOT_REACHED` | same | Compound prerequisite not satisfied; individual cause requires tracing |
| Lateral Left | +0.149168 m, complete one-second horizon, n=3 H/R | ground/support switches to `EQ132SpawnPad` at tick 200 | 120 Hz diagnostic-only; 60 Hz interrupted, not a controller failure |
| Lateral Right | +0.149263 m, complete one-second horizon, n=3 H/R | ground/support switches to `EQ132SpawnPad` at tick 200 | Same distinction |
| Foot-Supported Step | `QUIET_ONSET_NOT_REACHED`, despite observed B1 foot load | same prerequisite failure | A loaded foot alone does not validate the required non-ground start |
| Two-Hand Release-Stop | stop path 0.116284 m; settling 0.816667 s | onset 199, interrupted 200 by ground | 120 Hz diagnostic-only; 60 Hz stop cannot be scored |
| N1 negative | nine in-engine checks PASS; runner `RUN_INVALID/MISSING_REAL_PICK_RECORDS` | not qualified | Post-run semantic count bug; no demonstrated missing raycast |

Do not claim that `OVERLAP_OR_ROTATION_BOUND` necessarily represents a physical collision. Do not claim it is false. The runtime native contact manifold was unobservable in that run, because the report limit was zero. Classify native contact as `UNKNOWN` until directly supported.

### 1.2 Protected game configuration

- Gameplay body: **one 12 kg RigidBody3D** using existing Jolt dynamics.
- Effective shoulder-to-contact reach: approximately **0.65708 m**.
- Shared hand traction **360 N**; feet **180 N total**, **120 N per foot**; shared attitude assistance **20 Nm**; combined climbing moment **150 Nm**, retaining established float-reporting conventions.
- Experimental benchmark: **profile 4, A0/B1**, exact original resources, original acquisition and material-anchor rules. Canonical A0 values: traversal speed **0.25 m/s**, input ramp **0.12 s**, target rate **0.24 m/s**, target acceleration **0.9 m/s²**.
- Ordinary product startup remains **profile 2 / LIVE**, optional experimental switches disabled as in the original startup; PC mouse/keyboard bindings unchanged.
- No direct pose/velocity writes, fake hand contacts, hidden anchoring, forced support, broader force caps, physics timestep changes, changed Jolt slop, or kinematic substitutes for benchmark climbing.
- Leave Janga's original protected grabber, existing top-out controller, camera LIVE path and release export behavior untouched.

Evaluation-only geometry and scripted **real inputs** can change *with provenance*, because this document is about designing physically feasible test fixtures. Those changes cannot become production-world behavior implicitly.

---

## 2. Required ownership and workflow

**Codex/integration agent:** audit the actual repository and R3 evidence, implement schema/tests and evaluation-only fixtures, orchestrate limited runs, preserve source and manifests, produce reports.

**Independent physics/Jolt reviewer:** assess the proposed fixture geometry, collision sweeps, support transitions, foot loading, force budgets, and whether any proposed clearance/preparation change covertly makes movement unphysical. The reviewer must explicitly distinguish query uncertainty from native contact facts.

**Independent measurement reviewer:** define and independently check what constitutes a pick dispatch, valid onset, interruption, measurement status, fixed replay, pair eligibility and score prohibition. Review the R3 N1 trace before approving the new contract.

Stage boundaries are strict: review/fix one source candidate, run small contracts, demonstrate fixture feasibility, then freeze one version for the feasibility pilot. If a change is necessary after the final freeze, record a new candidate/source identity; never edit measured bytes in place or relabel old passes.

---

## 3. FR0 — Pick instrumentation: fix event versus query semantics

### 3.1 Root cause as observed in R3

N1 injected a derived, **diagnostic-only** tape changing the first four frames. At tick 1 the logical stream contained:

```json
{"hand":0,"reason":"INVALID_AIM_NO_NEW_TARGET"}
```

This event means **no physical raycast was dispatched**. The remaining physical-query sidecar contained exactly three dispatches:

- tick **3**: valid corner aim; one picker invocation with **seven ordered rays**, all MISS;
- tick **55**: source target query;
- tick **282**: destination target query.

The historical validation counted four logical `target.picks` entries and demanded four raycast sidecar entries. This is the defect to repair. It is not evidence that the tick-1 event should have dispatched an extra ray or that the sidecar should synthesize a fourth record.

### 3.2 Formal event taxonomy

The actual implementation may use existing field names. Document their mapping rather than breaking historical schemas without migration. New canonical concepts:

| Concept | Meaning | Requires physical-query record? |
|---|---|---|
| `TARGET_DECISION` | A decision to attempt, reject, retain or cancel targeting | **No**, by itself |
| `PICK_SUPPRESSED` | No real picker dispatch (invalid aim, unsupported state, no new target request) | **No** |
| `PICK_DISPATCH` | The real selection routine entered and issued an eligible set of world queries | **Yes**, one sidecar per real dispatch |
| `PICK_RESULT` | Outcome of a dispatch: hit, MISS, obstructed, ineligible, etc. | **Yes**, linked to its actual dispatch |
| `GRIP_REQUEST` | A normal request to the gameplay hand state machine after a valid target | **Not necessarily** a new query if already sourced from an existing dispatch |
| `ATTACHED/SLIPPING/RELEASED` | Gameplay contact lifecycle | **Never** manufactured by the evaluator |

A dispatch with seven ray candidates must not be confused with **seven independent picker invocations**. Record dispatch count separately from ray count, and the winning ray offset (or no winner). No synthetic ray to satisfy a count. A valid aim can still yield a legitimate MISS.

### 3.3 Correlation and counting contract

For every *actual* dispatch, emit an unambiguous identifier derived from **attempt/session ID + physics tick + hand ID + per-tick dispatch ordinal**. Never use a process-global object ID as the only key for cross-process comparison. Preserve existing identifiers separately for forensic evidence.

Invariant per completed replay:

```text
count(PICK_DISPATCH where dispatched_world_queries = true)
    == count(sidecar dispatcher records)

for each dispatcher record:
    matching dispatch identity exists exactly once
    ordered rays and outcomes match the real selector's sidecar
    reported winning offset corresponds to the same actual hit

for each PICK_SUPPRESSED:
    no dispatcher record exists for that event identity
```

A `PICK_RESULT` must link to exactly one real dispatch. A `TARGET_DECISION` need not. The validator should compare set identity and chronological order, **not only array lengths**. Duplicates, missing dispatches, orphan sidecars, misordered offsets and fabricated hits remain fatal.

Keep old `target.picks` rows intact in R3 archives. For new artifacts, provide an explicit, versioned migration/derived view. If one legacy event cannot be mapped without ambiguity, mark its classification `UNKNOWN_LEGACY_EVENT` and do not count it as a pass.

### 3.4 Required negative and positive contracts

Implement **real JSON roundtrip** and actual driver/validator boundary tests for at least:

1. Invalid aim with held button and no new target: logical event exists, **zero** query calls.
2. Valid `(0,0)` aim: valid coordinates, normal real picking (do not treat as invalid).
3. Valid aim, all seven ray offsets MISS: **one** dispatch with seven real ray sub-results and no attached hand.
4. Valid hit with normal material point/face/offset: one linked dispatch and correct hand.
5. Two hands on one tick: distinct identities even with the same cursor position.
6. Multiple requests in a tick: unique ordered ordinals, never collapsed or double-counted.
7. Duplicate logical event without duplicate dispatch: no invented ray.
8. Missing physical sidecar for a real dispatch: reject with `MISSING_REAL_PICK_RECORDS`.
9. Orphan/duplicate sidecar, inconsistent hand/tick, mismatched winning offset: reject with typed reason.
10. Legacy JSON hand `0.0/1.0`: accept only exact integral numeric values; reject `0.5`, strings or null, without rounding cursor coordinates.
11. Aborted or incomplete stream: classify as incomplete/invalid; do not infer missing picks from absent ticks.
12. N1's original four logical events / three dispatches: passes **only if** linked identity and actual sidecar data agree, not because a missing count is ignored.

The original N1 run is a **historical failure**; never rewrite it. A new N1 result in the repaired source can pass, and must have a new run ID and full evidence.

### 3.5 Implementation constraints

Fix evaluation-specific sidecar publication, schemas, or the frozen runner's validation logic at the narrowest owner. Do not change `grip_targeting.gd`, normal picker ordering, seven-ray sampling, collision masks, contact validity, strength or acquisition to make the log look nicer. If the only viable fix would touch gameplay picker semantics, stop for explicit review and create a controlled equivalence test instead of silently patching the game.

**FR0 gate:** all schema and N1 contracts pass offline, in Godot, and on a genuine opt-in test replay at 120 Hz; the sidecar matches actual picker dispatches. The primary R3 record remains unchanged.

---

## 4. FR1 — Build a fixture feasibility debugger before moving geometry

R3 often reported compound prerequisite failure (`QUIET_ONSET_NOT_REACHED`) without isolating which clause was preventing entry. Before authoring revised fixtures, expose each clause on a common physics-tick timeline, using native values already observable. Proposed per-tick fields (map to actual names in code):

```text
run_id, domain_id, fixture_revision, source_hash, tape_hash
physics_hz, tick, phase, backing_size, viewport_size
body_COM, body_pose, velocity_linear, velocity_angular
requested_move, accepted_move, active_input_profile
left/right hand state, anchor material ID/local point, reach, load
left/right foot state, native support validity if observable, load
real_ground_support, support_collider_id, ground_motor_authority
native_contact_report_available, native_contact_evidence
quiet_window_elapsed, |v|, |omega|, directed_speed
clearance_status, query collider/shape/part, inflation/margin,
  reason (end overlap, sweep intersection, rotation bound, unknown)
onset_clause_results, onset_tick_or_null, first_failed_clause
measurement_window_status, interrupt_tick, interrupt_reason
```

For each domain produce a **prerequisite funnel** with actual tick counts/time spent in each prerequisite, time of first all-true state, and its earliest loss. Report every failed clause, not only the first in source-order. A foot physically carrying force but not satisfying nonground onset must remain visible as *foot loaded; overall onset false*.

### Ground and collision truthfulness

- Ground contact is not interchangeable with a proximity ray. Distinguish native support, solver authority, reported contact, and geometric query.
- If the contact-reporting API provides no manifold, publish `UNKNOWN` instead of "no contact". Do not change the solver to make reporting easier.
- Conservative bounds are permitted to reject ambiguous clearance. Record shape and margin and inspect them; never switch the bound off globally because it rejects a fixture.
- The `SpawnPad` may legitimately cause a collision or native support switch. If a fixture is meant to represent hanging without floor help, the pad must not enter the measurement phase's support region.
- Do not credit any progress after a phase becomes grounded if the task requires airborne hanging.

**FR1 gate:** R3 failures can be explained in traces by specific unsatisfied onset/clearance/support clauses; no causal claim relies solely on a synthetic check.

---

## 5. FR2 — Revise fixtures, not player physics

### 5.1 Allowed changes

All modifications belong to a **new, clearly identified evaluation fixture/catalog revision**, loaded only under the opt-in test entrypoint:

- Position, clearance envelope or extent of a *benchmark-only* SpawnPad/approach surface.
- Initial approach geometry, anchor-bearing surfaces and stationary walls for benchmark cases; preserve true line of sight, real reach and actual surface identity.
- Duration/sequence of **real controller inputs** used to prepare a stable start, when the attempt is physically feasible.
- Scenario placement, measurement corridors and target direction *if* the original target is impossible or unfair, with explicit before/after evidence and no scoring continuity claim.
- A new fixture-local static buffer/clearance volume to prevent accidental ground assistance during a requested unsupported hanging phase, provided the same movement is still achievable through the real actuators.

A changed physical world means a **new scenario identity** and **newly captured tapes**. Never reuse old R3 tapes as if they represented the new geometry. Do not alter camera targeting semantics, hand acquisition radius, force limits, weight or friction to manufacture a passing result.

### 5.2 Non-negotiable validity criteria

Every measurement case must meet these before its onset is certified:

1. Real hands acquired through ordinary raycasts/request/reach/contact. Pending targets exert zero force.
2. Correct genuine support type for the task; same material anchors as recorded. Foot support must be real if required; genuine nonground status if the task requires hanging.
3. Quiet-start/counter-swing prerequisites use unchanged approved velocity, angular and support windows **unless a separate measurement-review decision documents a physically justified new benchmark contract**. Do not silently relax thresholds after failure.
4. Clearance is certified conservatively over the planned analysis region; no pad/ceiling contact changes task authority mid-window.
5. Body movement during the analyzed phase comes from A0/B1 actuators and real contacts, not seeded body velocity or manual transform.
6. Successful measurement does not imply target gameplay success. Preserve progress, latency, efficiency, load, stop and task outcome as separate fields.

A benchmark can be made easier to *measure* without making the movement artificially stronger. If an evaluation arena must be redesigned so extensively that its intended capability is no longer tested, **exclude and redesign the task**, do not report a pass for the original domain.

### 5.3 Domain-specific engineering requirements

#### A. Vertical Pull

- Reproduce onset 268 / interruption 275 in the preserved R3 fixture, read FootBase and SpawnPad shape transforms and conservative swept/rotation bound around the ~0.766 mm clearance uncertainty.
- Determine whether the interruption is due to real pad contact, potential overlap, pose/rotation inflation, or an unresolvable uncertainty. The report alone does not distinguish these.
- For a revised fixture, move the **test-only pad** outside the required climbing sweep or adjust the entry approach using actual controls while preserving support availability for acquiring the first hand grip.
- Confirm at least one **nonzero, signed, task-valid** body displacement during a full approved window; do not count a motionless but valid onset as demonstrated Vertical Pull performance.
- Preserve native support reporting uncertainty. Never set collision layers OFF to avoid the pad.

#### B. Asymmetric Pull

- Break down `QUIET_ONSET_NOT_REACHED` into independent angular velocity, linear speed, hand-anchor validity/load, foot load, ground state, clearance, and quiet duration.
- Build an asymmetric arrangement that can be **acquired and stabilized using real LMB/RMB and WASD** at both frequencies.
- Keep the asymmetry materially meaningful; symmetrical handles relabeled "asymmetric" are not acceptable.
- Do not add automatic stabilization torque, use rigid hand locks, or reset the body's velocity at onset.

#### C. Lateral Traverse Left / Right

- Preserve the valid R3 120 Hz references (+0.149168 m left / +0.149263 m right) for comparison **only as historical measurements**.
- Reproduce the R3 60 Hz SpawnPad native-support change at tick 200. Identify why the pad enters the path of the hanging character.
- Provide sufficient physical clearance to remain unsupported for the **entire intended one-second analysis horizon**, without ground motor influence.
- Keep truly mirrored lateral anchor geometry and a consistent definition of signed direction, hand support, and target corridor.
- A 60 Hz run may have a different trajectory and signed progress than 120 Hz; require valid domain behavior and H/R comparability *within* each frequency, not bitwise equality across frequencies.

#### D. Foot-Supported Step

- The scenario must start with legitimate active B1 foot compression/friction and a valid hand support configuration while meeting its declared nonground constraint, if that is the intended domain.
- Audit whether the compound quiet onset can physically coexist with a useful compressed foot support. A physical foot can load while ground remains true, so foot load by itself is insufficient.
- If the fixture is accidentally measuring push-off from the floor rather than foot contribution against climbing geometry, redesign **the lab fixture** and name the changed support context.
- Maintain force/reaction balance and record foot work/load, hand load and directed movement; a visible planted foot does not constitute physical contribution.
- This task is **diagnostic-only / n=1** under the prior R3 allocation. v1.3.4 may prove feasibility but cannot promote its statistical score.

#### E. Two-Hand Release-Stop

- Reproduce the 120 Hz result: stop-path **0.116284 m**, settling **0.816667 s**, onset 386; distinguish path until confirmed stop from complete five-second path **0.168328 m** and final signed drift **0.003122 m**.
- In the 60 Hz fixture, prevent the accidental native SpawnPad support switch at tick 200 while retaining physical freedom to slow down and settle.
- Keep the stop definition: 3D cumulative path to a confirmed sustained low-energy interval; active brake window, release drift and reversal are separate metrics.
- Never replace a null/interrupted 60 Hz stop with zero distance or the last observed distance.
- This remains diagnostic-only / n=1; a measured stop is evidence of the metric, not general controller optimization eligibility.

#### F. Reference Swing & Catch

- Keep one untouched reference domain for checking the repaired instrumentation and the environment: 1024×576 actual backing, 1920×1080 logical viewport, 60/120 Hz, same fixed tape across H/R pairs per frequency.
- New changes must not modify actual source/destination face, required grip range, actor budget, or the reference physics. A reference mismatch stops fixture experiments until explained.

---

## 6. FR3 — Prepare physically, then capture and replay

**Never inject an idealized state just to satisfy an onset.** Every source tape must derive from a physical preparation run with actual held-hand input, cursor/target requests, body gravity, contact resolution, and correct support. Audit the true sequence:

```text
RESET WORLD -> CONFIRM CLOCK/BACKING -> SPAWN NORMAL BODY
-> APPLY REAL PREPARATION INPUTS -> ACQUIRE TRUE ANCHORS
-> VERIFY SUPPORT/CLEARANCE/QUIET PREREQUISITES OVER FULL DURATION
-> RECORD ONSET WITH REAL CURRENT STATE -> APPLY TEST ACTION
-> MEASURE FIXED HORIZON -> VERIFY RELEASE/TEARDOWN
```

Run distinct preparations at 60 and 120 Hz if required by real physical state. Do not force identical onset ticks or input patterns across rates. Freeze a new tape from each accepted preparation. Fixed replay uses that tape identically for headless/rendered *at the same Hz*. An adaptive capture may generate the source tape but does **not** count as a fixed replay pass or an independent player success.

Record if the precondition is impossible within the declared preparation timeout, and why. A fixture is not "fixed" if all that changed is the diagnostic label; at least one complete real measurement must be produced at each required frequency.

### Validating stability without gaming it

A quiet onset cannot be produced by ignoring angular velocity or by over-damping the character only during test preparation. If no natural quiet-start condition exists with the current task geometry, change the fixture design (for example safer wall/pad separation, viable contact sequence) and then validate whether it still tests the intended skill. If this cannot be achieved, mark the domain *not feasible for this benchmark design*.

---

## 7. FR4 — Small, bounded physical feasibility pilot

This phase intentionally does **not** re-run the 96-slot v1.3.3 matrix. It is a diagnostic qualification of feasibility, with fresh source and tape identities. The following proposed limits are maximum budgets, not quotas to spend regardless of failure:

| Work | Maximum launches | Purpose |
|---|---:|---|
| Offline/contract tests | Not physical; record actual count | Pick semantics, JSON, metric/status, fixture catalog contracts |
| Iterative development physics | **8** separately labeled runs | Diagnose and adjust fixtures *before* freeze; never score |
| Final feasibility: six domain preparations × 2 Hz | **12** | Real physical capture with proof of prerequisites |
| Final feasibility: H/R fixed replays × six domains × 2 Hz | **24** | One strict pair per domain/frequency |
| Unchanged Swing & Catch H/R reference × 2 Hz | **4** | Regression of replay environment and instrumentation |
| Corrected N1 negative with real tape | **2** | One at each frequency; sidecar correlation and forbidden-contact check |
| Explicit discrepancy-only reserve | **6** | No silent repetition or hidden retuning |
| **Final pilot ceiling** | **48 physical processes** | Does **not** include development or historic regressions |
| Original regression suites | **34 processes separately**, if run | Existing physical/input LIVE safety, ~1,146 checks historically |

The six domains here are **Vertical**, **Asymmetric**, **Lateral Left**, **Lateral Right**, **Foot-Supported Step**, and **Two-Hand Release-Stop**. If the actual runner uses a different separation of capture and replay, map and justify the counts *before* launching, without exceeding the ceiling. For example, a capture performed inside a reference replay counts as a physical launch, not free preprocessing.

Run **small stage gates** rather than launching all 48 at once:

- **Gate A:** N1 schema, contract and one physically executed negative pass; maintain true no-query semantics.
- **Gate B:** unchanged Swing & Catch reference still reproduces at each Hz, with strict H/R equality in its already-certified same-backing environment.
- **Gate C:** for each domain/Hz, a genuine physical preparation reaches a valid onset and the requested capability can be measured for a complete window (or an honest terminal outcome).
- **Gate D:** each viable source tape yields one H/R pair with matching input, picking, contact and published physical channels. Measure any mismatch, don't massage it with tolerances.
- **Gate E:** negative/control cleanup, regression, source identity and independent reviews.

Fail fast on a **hard safety or instrumentation invariant**. On a fixture feasibility failure, stop that domain, save the trace, and consider only a separately identified revision within the development budget; do not consume all paired-replay slots on invalid starts. A partial success does not upgrade other missing cells.

No `n=3` statistical qualification is claimed by a single feasible pair. After a successful feasibility pilot, a new R4 qualification with a properly budgeted repeated matrix requires **explicit separate authorization**.

---

## 8. FR5 — Required metrics and typing

Use the existing versioned movement-metric formulas from R3 unless a specific contract bug is documented and independently approved. Every reported number needs `value`, `unit`, `status`, `window`, `scenario_id`, `fixture_revision`, `tape_hash`, `source_hash`, `hz`, `mode`, and `reason` where relevant.

Supported measurement states remain explicit: `MEASURED`, `NOT_APPLICABLE`, `PRECONDITION_NOT_MET`, `INTERRUPTED`, `CENSORED_TIMEOUT`, and `INVALID_MEASUREMENT`. Runner statuses (`RUN_VALID`, `RUN_INVALID`, `BLOCKED_SETUP`) are distinct from those metric states. `RUN_VALID` can contain an unsuccessful task or non-measurable metric.

Mandatory measurements:

- Actual accepted command timeline, cursor and camera/pick context.
- Verified valid-onset tick or a typed failure and all failed prerequisites.
- Valid measurement horizon; support changes, clearance issues and capture/release events with ticks.
- Signed COM progression in task direction and 3D COM path, without counting earlier ground walking as suspended climb.
- Directional response latency measured from **accepted input**, and a distinct flag if already moving in the requested direction before onset.
- Lateral efficiency only for uninterrupted task windows; retain raw movement for interrupted cases but do not score it.
- Active physical foot compression, actual foot/hand load and native ground authority distinction.
- Stop path, directed drift, settling start/confirmation, brake fractions and interrupted conditions, each according to the approved measurement windows.
- Contact and retention as different states; zero hand force before actual physical attachment.
- H/R comparison at same frequency/backing/fixture/tape; no cross-Hz exactness requirement.

For an interrupted case, do not use final partial progress as if the whole objective had finished. For a `PRECONDITION_NOT_MET`, progress may be present as **raw telemetry**, not official result. Never turn null into zero.

### Suggested feasibility result schema (illustrative; map to the actual existing schema)

```json
{
  "campaign": "fixture_feasibility_v134_r1",
  "domain": "lateral_clean_left",
  "fixture_revision": "explicit-revision-hash",
  "physics_hz": 60,
  "mode": "headless",
  "capture_or_replay": "fixed_replay",
  "status": "RUN_VALID",
  "onset": {"status": "PRECONDITION_NOT_MET", "tick": null},
  "measurement_window": {"status": "NOT_APPLICABLE", "end_tick": null},
  "metric": {"status": "NOT_APPLICABLE", "value": null, "unit": "m"},
  "strict_pair": "PENDING_PAIRED_RUN",
  "score_eligible": false
}
```

The above is a **schema sketch showing an invalid onset**, not an example pass. Never output a fabricated onset tick or `null` under `MEASURED` in real receipts. The actual schema validator must reject that contradiction. Use existing contract fields where available to avoid needless format forks.

---

## 9. FR6 — Evidence, comparisons and failure classification

For each fixture candidate and physical run, archive:

- Original source commit, dirty-tree policy, exactly measured source/helpers hash, engine binary/hash, Jolt and project settings relevant to step rate and collision.
- Evaluation-only fixture files, shape transforms/dimensions, scene revision and actual support/collider identity; before/after geometry diff.
- Full valid tape bytes and hash, policy provenance, input route, actual backing/canvas/camera state; no implicit re-use of old tapes.
- Manifest, CLI arguments, environment snapshot, timestamped PRE/POST traces, real query-sidecar events, onsets and late interrupts, stdout/stderr, machine-readable result and meaningful screenshot when needed.
- The most recent *true* real-picking event and material anchor, including 7-ray sub-results if actually called; no event fabrication.
- Typed reason for any failed admission, runtime abort, invalid onset, ground contact, clearance uncertainty or hard safety gate.
- Full H/R comparison at fixed tape/Hz: first difference by INPUT, CAMERA, PICK, CONTACT, PHYSICS, TASK; matching failure outcomes are still failures, not completed measurements.
- Reviewer sign-offs and exact re-execution commands for the checkout being tested.

Recommended tree (adapt after repository audit; these are **new proposed destinations**, not claims of existing files):

```text
docs/validation/auto_tuning/fixture_repair_v134/
  baseline_audit.md
  pick_event_contract.md
  fixture_feasibility_plan.md
  fixture_geometry_diff.md
  domain_feasibility.csv
  metric_contract_audit.md
  negative_controls.json
  replay_pair_results.json
  specialist/physics_review.md
  specialist/measurement_review.md
  decision.md
  verification.json
  evidence_manifest.json
builds/eval_virtual_cursor/fixture_feasibility_v134_r1/
  development/
  final/reference/
  final/capture/
  final/replay/
  final/negative/
  final/diagnostics/
```

Old R3 `first_divergence.json`, `r3_metrics.csv`, `r3_primary_test_matrix.json`, and preflight certificate remain immutable and navigable.

### Failure classification

- `PICK_CONTRACT_FAILURE`: a real dispatch/sidecar mismatch, not an invalid-aim no-query event.
- `FIXTURE_PRECONDITION_FAILURE`: valid program execution but no genuine onset.
- `CLEARANCE_UNCERTAIN`: a conservative bound rejects a pose without certified native-contact truth.
- `GROUND_AUTHORITY_CHANGED_TASK`: unexpected support transition during required hanging measurement.
- `REPLAY_FIDELITY_FAILURE`: H/R inputs/picking/contacts/physics differ under paired conditions.
- `ENVIRONMENT_NOT_COMPARABLE`: clock, backing, project, scene, mode, source or seed invalid.
- `HARD_PHYSICS_INVARIANT_FAILURE`: force/contact/pose or owner-authority contract violated.
- `FEASIBILITY_NOT_DEMONSTRATED`: allocated attempts ended with no complete real measured case.

If a constraint is unobservable, report `UNKNOWN`; never invent agreement. A classifier or future Jev helper may suggest hypotheses, but only actual validated evidence decides the gate.

---

## 10. FR7 — Regression and playable-game protection

Before any sign-off, run the existing suites that historically accounted for **34 processes / 1,146 checks** (24 physical/intention/hybrid/feet and 10 LIVE input) at their established 60/120 Hz settings. These are **separate** from the final feasibility ceiling and must be reported with exact fresh counts, not assumed passed from R3. Stop if any previously passing production contract regresses; classify environment/config failures separately from physics failures.

Also verify in the actual ordinary project:

- startup profile 2, LIVE input, virtual replay disabled, original four A0 tuning values and input bindings;
- actual mass, reach, actuators and caps unchanged;
- First Ascent, ordinary walking, hold-to-grip, feet and hybrid top-out still follow the preserved code paths;
- file parity between working copies, original Godot project configuration restored after temporary plugin/editor changes, original Janga grabber unchanged;
- evaluator/test-only scripts and fixture scenes excluded from release export; Windows export/startup smoke tested without claiming it is a full playthrough;
- the project/editor shows no **new** diagnostics; preserve pre-existing warnings and record their provenance.

A correct benchmark fixture does not become a new level of the shipping game. An observed improvement in input/cursor/replay controls also does not authorize changing the LIVE gameplay path.

---

## 11. Formal gates and product decision

| Milestone | Required proof | Gate |
|---|---|---|
| **FR0 — Baseline** | R3 evidence and source hashes preserved; protected game flags and code identified | PASS/FAIL |
| **FR1 — Pick accounting** | N1 logical 4 / physical 3 accepted with exact dispatch correlation; malformed sidecars still rejected | PASS/FAIL |
| **FR2 — Prerequisite instrumentation** | Per-clause onset/clearance/ground reasons measured, not guessed | PASS/FAIL |
| **FR3 — Fixture feasibility** | One physically obtained valid onset and uninterrupted measurement at **both** 60/120 Hz in each mandatory domain | PASS/PARTIAL/FAIL |
| **FR4 — Replay pairing** | Matched H/R same tape per domain/Hz for actual inputs, raycasts, anchors and published physics | PASS/PARTIAL/FAIL |
| **FR5 — Metric integrity** | No false measured values; typed null/interruption, provenance and units correct | PASS/FAIL |
| **FR6 — Safety/release** | Protected game unchanged; fresh regression evidence and rollback verified | PASS/FAIL |
| **FR7 — Decision** | Explicit recommendation on readiness for a **new** qualification, not an Optuna GO | `FEASIBILITY_READY_FOR_REQUALIFICATION` or `FEASIBILITY_NO_GO` |

Mandatory domains for the feasibility decision: **Vertical Pull, Asymmetric Pull, Lateral Left, Lateral Right** at **both 60 and 120 Hz**. Foot-Supported Step and Two-Hand Release-Stop also require real measured pilot windows, but retain their **diagnostic-only** status and cannot supply a statistically qualified ranking by themselves. Swing & Catch must remain an unchanged reference.

`FEASIBILITY_READY_FOR_REQUALIFICATION` requires all mandatory gates, correct N1, preserved strict reference pairs, and independently verified evidence. It means **eligible to design and request a new full benchmark qualification**, not eligible for scoring or parameter search yet. A new R4 campaign, with n=3 repeated cells and new opt-in approval, remains mandatory for optimization eligibility.

`FEASIBILITY_NO_GO` is correct if any mandatory real fixture cannot provide a valid window, any safety/identity guard fails, or the actual H/R paired replay diverges without a separately accepted narrow qualification. Preserve all partial successful cells but do not combine them into a global score.

Human game-feel tests and designer preference are not replaced by this qualification. Even a later optimized A0 candidate must be accepted by a player before changing defaults.

---

## 12. Explicit instructions to Codex

1. Read the actual v1.3.3 R3 receipts, especially N1's raw `target.picks` and physical sidecar, per-clause onset traces, geometry near the SpawnPad, and reviewer findings. **Verify** the real code owners and resource paths; do not implement guessed filenames as if already present.
2. Freeze a new candidate source and preserve R3 unchanged. Inventory all gameplay files that must remain identical.
3. Implement the evaluation-only logical-event/real-query schema and identity correlation. Add roundtrip JSON, direct Godot and runner tests. Re-run **a new** N1 negative while verifying actual query count. Do not delete or rewrite original N1.
4. Instrument onset prerequisites and clearance/support diagnosis without modifying movement physics.
5. Iteratively author evaluation-only, physically feasible fixtures. Prioritize the 60 Hz SpawnPad interruptions and the asymmetric quiet onset; retain genuine surface selection and same gameplay limitations.
6. For each candidate, document old/new geometry, actual physical preparations, input timelines, changed scenario/tape IDs and independent physics approval before acceptance.
7. Freeze one source and execute the **bounded** pilot. Stop on true hard invariant failure. Do not recycle invalid results, change acceptance criteria retrospectively or spend the full budget unnecessarily.
8. Run fresh preserved regressions, verify default LIVE startup, release isolation, and document the precise counts and any failures.
9. Produce `decision.md`: each domain/Hz outcome, measurement status, strict H/R status, reason when invalid, and explicit `FEASIBILITY_READY_FOR_REQUALIFICATION` versus `FEASIBILITY_NO_GO`.
10. **Do not run Optuna, RL, Jev, M7 or a new 96-process qualification**. Ask for a separately authorized next phase if feasibility is demonstrated.

---

## 13. Definition of done

The v1.3.4 deliverable is complete when it truthfully provides:

- An evaluation-only, tested correction for N1 query-event accounting; no fabricated rays and no weakening of missing-sidecar detection.
- A per-domain physical diagnosis of why the R3 fixture failed and what changed in the new test-only geometry/preparation.
- Captured, auditable real-input preparations and **at least one complete, task-valid measurement per mandatory domain at 60 and 120 Hz**, or an explicit no-go explaining why this was not feasible.
- Same-frequency H/R comparison of each completed feasibility tape, reporting exact inputs, actual material rays/anchors, and observed physics with no arbitrary tolerance.
- Separate diagnostic-only status for Foot-Supported Step and Release-Stop, and unchanged Swing & Catch reference.
- Explicit per-trial counts, exact source/tape/scene hashes, named empty/missing cells and archived negative runs.
- Original playable A0/B1 protected, verified 34-process regression and debug/release isolation.
- Final **feasibility** decision, **not** a declaration that the benchmark, Optuna, or ML is ready.

**Design rule:** Improve the *test's ability to observe real climbing*, not the character's ability to beat the test. If measuring a maneuver requires cheating its physics, reject the fixture rather than corrupting GRIP UP's locomotion.
