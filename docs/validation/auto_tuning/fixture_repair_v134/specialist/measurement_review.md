# v1.3.4 independent measurement review

Review stage: **APPROVED FOR THE FINAL FEASIBILITY TEST; OUTCOME PENDING**. The scoped approvals below cover repaired instrumentation and the static r2 measurement design. They do not certify fixture feasibility or final pilot qualification. The reviewer read the complete v1.3.4 specification and inspected frozen R3 evidence plus new raw development evidence. This review used offline Python and source reads only: **zero reviewer engine processes**. R3 files were not changed.

The proposed narrow repair is justified: classify logical no-query decisions separately from actual picker dispatches, and redesign evaluation fixtures while retaining the actual A0/B1 controller and existing measurement formulas. No threshold relaxation, scoring, optimizer, new qualification campaign, or LIVE gameplay change is approved here.

## 1. Historical identity and N1 observation

R3 measured commit: `7a578995915d56ade2fa447f3adfdd6e19dc0218`. Composite certified source snapshot: `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`. Its public-source digest and composite source-plus-helper digest have distinct documented scopes; they must not be mistaken for a source mismatch.

The original negative remains **RUN_INVALID / MISSING_REAL_PICK_RECORDS** in:

`builds/eval_virtual_cursor/benchmark_v133_r3/primary/benchmark_v133_r3/attempts/swing_catch_train_120_headless_r1_e0310d17/`

Fresh read-only inspection confirms:

| Tick | Hand | Logical entry | Actual dispatch evidence |
|---:|---:|---|---|
| 1 | 0 | `INVALID_AIM_NO_NEW_TARGET`, no `audit` | No sidecar; no query should occur |
| 3 | 0 | Valid `(0,0)` aim with actual picker audit | One sidecar, seven ordered MISS rays, no winner |
| 55 | 0 | Source selection audit | One sidecar, first offset wins, source material point and underside normal |
| 282 | 1 | Destination selection audit | One sidecar, first offset wins, catch material point and underside normal |

There are four logical entries, three actual dispatches, and nine executed rays. All nine original in-engine negative checks are true. This explains the post-run count rejection, but does not retrospectively promote the frozen receipt. The old runner at `tools/auto_tuning/benchmark_qualification/campaign.py` compared sidecar count against every `target.picks` entry. The logical sentinel is generated before selection in `features/grip_up/scripts/grip_up_lab.gd`; it must not cause a fabricated query.

Re-read SHA-256 values:

| File | SHA-256 |
|---|---|
| `benchmark_audit.json` | `1c9e7f7c271336c96fe6046e78bec07fedf2ccf9a74bcd3b9f06c23bf0bf3baa` |
| `projection_picks.jsonl` | `ab02c42b2545baec6111a28935e58d47ee850c2c549132376ac84de4232a4b42` |
| `receipt.json` | `92cc68a1a2720125e86580b8acab1080bcda8049c2a0a5bfd79419ae8af06c1f` |

## 2. Pick contract acceptance criteria

The implementation helper owns the canonical versioned pick contract. Independent acceptance requires the following semantics, rather than a count-only exception for N1.

1. Keep logical decisions, suppressed requests, actual dispatches, actual results, and gameplay attachment separate. Dispatch means the real selector issued world queries. A result belongs to exactly one dispatch; an attachment remains the real controller's state transition.
2. Bind each dispatch to session/attempt, physical tick, hand, and unique per-tick dispatch ordinal. Specify whether the ordinal is global across hands or per hand, and test that exact rule. Preserve process IDs for raw forensics, but compare a documented session-normalized identity across H/R processes; blindly comparing different attempt prefixes would reject equivalent runs.
3. Compare identity sets **and ordered sequences**, then exact actual rays, winner, collider/shape, local material point/normal and winning offset. An equal count cannot conceal one missing and one orphan record. Seven executed rays are one dispatch; early first-winner termination legitimately executes fewer than seven.
4. A known invalid-aim suppression has zero dispatches and zero sidecars. A duplicate logical notification cannot manufacture an extra dispatch. Conflicting or ambiguous duplicates must be rejected or explicitly `UNKNOWN_LEGACY_EVENT`, never silently made equivalent.
5. Migration is a derived view over unchanged archived bytes. Recognize only explicit suppression schemas and complete actual audited selections. An unaudited unknown reason, incomplete audit, multiple possible sidecar matches, or ambiguity between two same-tick/same-hand calls is not proof of equivalence. The original N1 can produce an independently validated migration report while its historical receipt remains invalid.
6. Validate complete stream/clock/source/environment first. An aborted or truncated stream is invalid/incomplete; absence of future ticks cannot be reinterpreted as missing picker calls. An observed dispatch lacking its sidecar still fails.
7. Accept legacy numeric hand values `0`, `1`, `0.0`, `1.0` only when finite and exactly integral. Reject booleans, strings, null, fractions and non-finite values. Do not round or canonicalize cursor/ray/material coordinates as part of identity migration.
8. Probe-disabled runs must explicitly declare unavailable sidecar coverage. They may be controlled observer comparisons where authorized; they cannot claim a complete sidecar correlation gate merely because zero sidecars were recorded.

Required boundary tests use serialized JSON consumed by the actual validator, not only handcrafted internal dictionaries. Test invalid held aim, valid corner aim, seven MISS rays, genuine hit, two hands on one tick, repeated same-hand calls, suppression duplication, missing sidecar, orphan sidecar, duplicate identity, chronological reordering, ray reordering, hand/tick/ordinal mismatch, winner-offset/material mismatch, malformed numeric hands, ambiguous legacy event, and aborted/missing tick streams. Perturb each matched field independently while preserving overall counts. The real N1 fixture must assert exactly the three observed dispatches, with all exact ray data and no tick-1 dispatch. Offline success alone does not satisfy FR0: direct Godot boundary tests and a **new** physical 120 Hz N1 are required, then the final 60 Hz negative as planned.

## 3. Compound onset audit

Owners inspected: `features/evaluator_virtual_cursor/scripts/benchmark_driver.gd`, its inherited quiet/motion helpers, and `tools/auto_tuning/benchmark_qualification/metrics.py`. The following clauses must be separately visible on every POST row, including when an earlier source-order clause fails.

| Clause | Required evidence / existing contract |
|---|---|
| Trace and accepted clock | Consecutive real POST ticks, matching configured Hz and delta; actual backing 1024×576 and logical 1920×1080 |
| Valid support frame | Actual support valid, no hybrid owner; material support identity and actual support-point velocity |
| Nonground | `support.grounded == false` and `native_ground_authority == false`; ground force and torque individually negligible under the existing 0.0001 threshold |
| Conservative clearance | `CLEAR_QUERIED_SEGMENT`, with original body proxies, layer scope, start/end/sweep/rotation checks and actual shape/margin evidence |
| Dual real hands | Both `ATTACHED`, non-`NONE` support, nonzero actual anchors; total hand force strictly greater than 1 N |
| Anchor continuity | Same recorded runtime anchor within each run and same material support/local point across paired processes; no renewed attachment hidden inside the quiet dwell |
| Directed quiet speed | Absolute support-relative velocity projected onto the task axis ≤0.1 m/s |
| Full spin | Full angular-velocity norm ≤0.2 rad/s; this is not just task-axis spin |
| Foot prerequisite, when declared | Actual SUPPORTING/SLIDING foot on valid material support, compressive normal load strictly >1 N; a visible planted foot or arbitrary force norm is insufficient |
| Quiet elapsed dwell | At least 0.25 s elapsed in uninterrupted eligible rows, not merely N rows counted as N timesteps |
| Accepted progress onset | Positive accepted world command along declared axis >1e-6, plus the actual accepted POST recheck |
| Raw prior dwell | Existing progress verifier checks onset−1−round(0.25×Hz) through onset inclusive: prior dwell plus accepted onset, all legal and same anchors |
| Stop onset | After real quiet preparation and actual physical drive, accepted neutral command and directed support-relative speed in [0.15,0.5] m/s; full velocity norm is not a substitute |
| No hidden actuator | Pending grips have zero force; declared feet-off implies zero foot force; unchanged force/torque caps and real controller input |

The approved quiet speed is **directed scalar speed**, not full linear speed ≤0.1. Publish full speed as a diagnostic too; changing the predicate would create a new contract. Stop settling separately uses full linear speed ≤0.1, full spin ≤0.2 for sustained 0.25 s. Stop onset does not reuse the progress quiet-speed test after its deliberate acceleration.

The old live `_quiet_benchmark` checks instantaneous eligibility and elapsed dwell, while the later raw verifier also checks fixed-anchor continuity. Therefore publish both instantaneous quiet eligibility and final certificate eligibility; `QUIET_CERTIFIED` in a preparation log alone cannot certify the final accepted onset. Publish all failed clauses, first all-true tick, every loss/reset, elapsed quiet duration, phase boundaries, and per-clause and cumulative funnel counts. For no onset, retain genuine reasons and raw telemetry, with official metrics null.

### Offline decomposition of frozen failed preparation windows

The following are independently recomputed from the final 5×Hz POST rows of the failed R3 adaptive preparations. These correspond to the exhausted five-second quiet loop. Counts are numbers of eligible rows, not elapsed durations; a streak of k rows covers (k−1)/Hz seconds. No new physical reproduction was performed.

| Domain/Hz | Tick window | Clearance eligible | Hand load >1 N | Axis speed eligible | Full spin eligible | Nonground / no native authority | All-clause longest streak |
|---|---|---:|---:|---:|---:|---:|---|
| Vertical/60 | 97–396 | 0/300 | 297/300 | 300/300 | 300/300 | 300/300 | 0 |
| Asymmetric/120 | 188–787 | 26/600 | 594/600 | 600/600 | 587/600 | 600/600 | 14 rows, 0.108333 s; first all-true tick 195 |
| Asymmetric/60 | 95–394 | 0/300 | 297/300 | 300/300 | 300/300 | 300/300 | 0 |
| Foot Step/120 | 191–790 | 600/600 | 600/600 | 600/600 | 516/600 | 0/600 | 0 |
| Foot Step/60 | 97–396 | 300/300 | 300/300 | 300/300 | 269/300 | 0/300 | 0 |

In all five windows, support validity, no hybrid, dual ATTACHED state and non-NONE hand support keys pass every row. In Foot Step, real compressive load >1 N passes **every** row while native ground authority is present on every row. This is an actual compound onset conflict in the recorded preparation; it is not a failure to display the foot. Asymmetric120 has transient full-spin and hand-load failures too, so removing the clearance obstruction cannot be assumed sufficient before a new run.

Sources: adaptive capture directories matching `{vertical_pull_clean_60, asymmetric_pull_clean_120, asymmetric_pull_clean_60, foot_supported_step_120, foot_supported_step_60}_headless_r0_*` under the preserved R3 primary `attempts/` tree. Each count evaluates native observed flags, both actual hand states/supports/loads, clearance, directed support-relative velocity and full spin independently, adding compressive foot load only for Foot Step. No first-failure short-circuit was used.

### Onset and interruption are different evidence

Vertical120 at tick275 has actual `FootBase` query hit `OVERLAP_OR_ROTATION_BOUND` against `EQ132SpawnPad`, margin `0.0007657434907741845` m. Grounded and native authority remain false there; the contact-report limit is zero. This supports **CLEARANCE_UNCERTAIN**, not a proven collision and not a proven false positive. Only ticks268–274 were authorized; the partial path is not a full Vertical result.

Lateral60 at tick200 differs: actual ground state names `EQ132SpawnPad` and grounded/native authority become true, even though clearance queries are clear and ground applied force/torque at that POST are zero. Thus motor-force zero does not imply an unsupported climbing phase. End the task window before tick200. The earlier completed latency event can remain MEASURED while progress is INTERRUPTED; the cell still fails feasibility.

Native contact manifold absence with `max_contacts_reported == 0` is **UNKNOWN**. A conservative clearance result, ground proximity/native support state and a solver contact manifold are separate observables. Never replace one by another in either implementation or report.

## 4. Metric, task and replay gates

Reuse the frozen R3 formulas; this review approves no formula revision. Independently recompute signed world COM progress and cumulative 3D path from raw authorized POST rows, compare with the independent Godot runtime summary, and then check typed metric windows. Keep each value's unit, window, scenario/fixture revision, tape/source identity, Hz/mode and reason in either the metric or an unambiguous joined envelope.

All six statuses remain explicit: MEASURED, NOT_APPLICABLE, PRECONDITION_NOT_MET, INTERRUPTED, CENSORED_TIMEOUT, INVALID_MEASUREMENT. MEASURED requires a finite value; nonmeasured official values remain null. RUN_VALID only means execution validity. A nonzero partial raw displacement cannot rescue an interrupted task, and null cannot become zero. Useful latency remains >0.02 m/s sustained 0.05 s; already-usefully-moving before onset yields null latency with `ALREADY_MOVING_BEFORE_ONSET`, never free zero-latency credit.

Stop path ends at the **confirmation** of sustained low-energy settling, while settling time reports the start of that interval relative to release. Preserve separate full-five-second path, final signed drift, brake fraction, release drift and reversal definitions. Historical120 evidence is stop path0.1162836473271256 m, settle0.8166666666666664 s, onset386, quiet-start484, confirmation514; full-five-second path0.16832756064248672 m and final signed drift0.003121892921626568 m are distinct diagnostics. Interrupted60 stop remains null. Foot compression/load contribution is a scoped physical diagnostic, not proof of whole-body energy efficiency; retain force and real movement alongside it.

Each new mandatory domain/Hz needs a genuine accepted onset and a complete task-valid horizon. Vertical additionally needs nonzero signed task-valid displacement. A revised asymmetric fixture must retain material geometric asymmetry, and the left/right corridors must remain genuinely mirrored with consistent signed axes. Foot and Stop must produce real measured diagnostic windows without statistical/ranking promotion.

Each accepted adaptive preparation produces a new immutable tape for its actual fixture and Hz. Capture is not a fixed replay, an independent repetition, or an H/R pass. Replays must independently recertify onset from their own raw state. Compare the same fixed tape, source, seed, backing and fixture at the same Hz through exact input, typed cursor conversion, camera, actual dispatch/rays/material anchors, contact events, force budgets, body motion and task outcome. Compare chronological earliest meaningful difference and the first actual physical divergence separately. Keep documented representation diagnostics separate from physical differences. No cross-Hz bitwise match is required, and two matching task failures are not successful feasibility.

## 5. Required staged evidence before sign-off

| Gate | Required proof | Current reviewer decision |
|---|---|---|
| A: pick repair | Serialized contracts and actual Godot boundary tests; new physical120 N1 exact correlation and forbidden-contact checks | PENDING IMPLEMENTATION / EXECUTION |
| B: reference | Untouched Swing & Catch strict H/R at each Hz, canonical backing/clock; original source/destination face and real budgets | PENDING |
| C: feasibility | All eight mandatory domain/Hz cells, plus real Foot/Stop diagnostics, physically prepared full windows and full clause funnel | PENDING |
| D: fidelity | One exact same-tape H/R pair per viable domain/Hz, with independently recomputed metrics | PENDING |
| E: safety / archive | New source freeze, complete manifests/tapes, original R3 preserved, fresh34-process regressions, ordinary LIVE/profile2 and release isolation | PENDING |

Ledger maxima remain **8 development**, **48 final feasibility**, and **34 separate regressions**. Final planned allocations are12 captures +24 fixed replays +4 references +2 N1 +6 reserve. Development captures cannot silently supply fixed-replay credit. Register any discrepancy slot before consuming it; stop a domain after invalid preparation rather than spending its pair slots. A source edit after freeze requires a new candidate and source identity. The engine worker and integration owner maintain these ledgers; this review has launched none.

A final READY recommendation requires all mandatory cells at both Hz, actual diagnostic windows, repaired negatives, unchanged strict references, preserved invariants and independent evidence. Any missing/invalid mandatory cell, unexplained pair mismatch or safety guard failure requires **FEASIBILITY_NO_GO**. Neither decision qualifies ranking or ML. A later repeated R4/96 qualification needs separate authorization.

## 6. Review still required

The proposed boundary and diagnosis are acceptable in principle. Final approval is withheld until the pick helper, evaluation-only fixture changes and prerequisite telemetry have been inspected against these clauses, then the registered physical evidence and independent metric recomputation are available. This document intentionally makes no claim that a repaired fixture is already feasible.

### Narrow endpoint representation decision before physical execution

The integration worker reports a pure Godot JSON parse of the original measured endpoint component `-53.594322204589844` as `-53.59432220458984`: parsed binary64 bits `ffffffbf12cc4ac0` versus the promoted native component's `000000c012cc4ac0`. Reconstructing the named native `Vector3` endpoint recovers the exact original value. An independent Python reconstruction already matches all nine original N1 query endpoints; a deliberately changed endpoint was accepted by the first equality-only mapping implementation, and the helper has added an endpoint consistency check.

The proposed **query_to-only** representation rule is acceptable under these conditions:

- Require the original sidecar `numeric_bits` component witness. Decode its binary64 value, require a finite exact promoted float32 component, and compare it exactly against the native endpoint reconstructed by the same Vector3 multiplication and addition. This is equality in the actual API's declared numeric type, not a distance tolerance.
- Separately confirm that the parsed scalar array converts to that same Vector3. Preserve both the parsed scalar/bit provenance and the measured component witness, explicitly identifying any JSON parser representation difference. Do not label differing scalar binary64 values a strict scalar match.
- Missing, invalid or forged witnesses must be typed invalid/incomparable. A one-float32-ULP change of the measured endpoint must still fail. Tests must cover these negatives and the known parser-only example.
- Python validation of the original full-precision JSON and its numeric witnesses remains exact. Same-Hz H/R comparisons of actual endpoint witnesses remain exact. No general rounding, epsilon, aim conversion, material-coordinate canonicalization or changed physical query is authorized.

This is conditional approval of a narrow representation contract, not approval of the current uninspected final implementation or any feasibility result.

### FR0 implementation and real development N1 review

**Decision: APPROVED for the repaired dispatch contract on candidate source `b682987f4fa2fecbd0490f3f71235266e8122378e056e176f42e46afb465eac6`, including its new development120 N1.** This closes the conditional implementation issues above for this source. It does not approve revised fixture geometry, the final pilot, or scoring.

The reviewer inspected the finished Python/Godot validators, opt-in projection-probe metadata, driver publication, runner strict-new validation and canonical pick contract. The accepted query endpoint rule is now implemented exactly as specified: mandatory measured binary witnesses, exact native endpoint bytes, a named Godot Vector3 transport check, and strict Python raw-scalar-to-witness binding. New artifacts require dispatch identity and ordinal; historical migration remains explicit. Nested vectors are finite numeric values of the correct dimension. No gameplay picker behavior was edited.

The reviewer independently reran the Python file-backed contract test: **49 shared JSON subcases PASS** (one unittest method, not49 separate unittest methods). The preserved integration-owned `pure/pick_contract_004` log records49 cases /128 checks /0 failures /0 physical bodies and prints both exact endpoint representations. The reviewer did not rerun Godot. Earlier failing pure attempts remain historical evidence.

New real development attempt:

`builds/eval_virtual_cursor/fixture_feasibility_v134_r1/attempts/swing_catch_train_120_headless_r1_02af2558/`

Independent offline verification loaded its original full-precision sidecars with the existing projection loader, reran `validate_stream` with `strict_new=True`, actual536 frames and complete outcome, and compared the complete output against both saved Godot and Python derived views. All three views match exactly. Actual dispatches are tick3/hand0/ordinal0/seven rays, tick55/hand0/ordinal0/one ray, and tick282/hand1/ordinal0/one ray. Tick1 is suppressed without a query. Totals are **4 logical /3 dispatch /9 rays /1 suppression**. All nine internal negative checks are true, execution is RUN_VALID, and cleanup disables the provider, removes input/camera ownership and releases both hands. Observed catch is physical at440 and retained527, with zero fabricated early attachment implied by this mapping.

Seven additional offline mutations of these actual new sidecars were independently rejected:

| Mutation | Typed rejection |
|---|---|
| Remove actual last dispatch sidecar | `MISSING_REAL_PICK_RECORDS` |
| Remove fresh dispatch identity | `MISSING_DISPATCH_IDENTITY` |
| Append orphan/duplicate sidecar | `ORPHAN_OR_DUPLICATE_PICK_SIDECAR` |
| Change actual endpoint alone | `PICK_ENDPOINT_RAW_BITS_MISMATCH` |
| Remove endpoint bit witness | `PICK_ENDPOINT_BITS_MISSING` |
| Change actual hand | `PICK_DISPATCH_IDENTITY_MISMATCH` |
| Change winning ray offset | `PICK_RAY_MISMATCH:offset_px` |

All manifest expected source-file hashes match the read checkout. All194 R3-inventoried `features/grip_up/` and `runtime/` gameplay files match their original source hashes. The new feasibility receipt SHA-256 is `cb7488e235cd402a9c7b16f3e6e3ebe213436efc80650d3c1316b4b36d505354`. The original R3 N1 remains invalid and unchanged. This development replay is charged to development, never a free final-pilot result. Final fresh60/120 negatives, unchanged reference fidelity, prerequisite instrumentation, revised fixtures and safety gates still require their own evidence.

### Prepilot r2 design/code decision

**APPROVED_FOR_FINAL_FEASIBILITY_TEST**, conditional on freezing/registering the reviewed bytes and the independent physics review. This authorizes only the already specified bounded pilot. It is not a claim that the unmeasured r2 fixtures work. The development ledger is independently observed at8/8 and final0/48; development must not be resumed. The two saved development H/R reference comparisons are STRICT_MATCH; their success cannot replace final-source references.

The r2 catalog gives all six changed domains new `_v134_r2` identities, separate fixture revisions and new captured tapes. The static pad front changes .32→.39 m; Foot Step uses a distinct broad lip with top.65/front.10 m. The preparation acquires ordinary entry grips, issues W1.5 s, releases/reacquires each hand15 cm higher through normal targeting and hand-state transitions, and then applies inherited quiet, accepted-onset and measurement logic. Asymmetry remains a real12 cm height difference; left/right acquisition and signed axes remain mirrored. No measured r1 result is described as an r2 pass. Static clearance estimates require future physical validation.

The runner enforces phase ceilings12 captures/24 replays/4 references/2 negatives/6 reserve and total48 final, separately from8 development and34 regressions. It requires a registered final source, rejects source/helper/engine changes, stops hard execution/instrumentation mismatches, and skips replay slots for an invalid preparation. It reuses actual metrics and the exact existing comparator; scoring remains prohibited.

Two issues found in this independent review were corrected before freeze:

1. Initially only capture eligibility and pair strictness were checked. The reviewed `measurement_valid` predicate now checks capture **and each fixed replay**, rejecting identically reproduced failed task windows. A missing/interrupted window cannot be rescued by STRICT_MATCH. The gate does not demand measured latency when an otherwise valid task legitimately has a typed latency precondition.
2. The quiet-only diagnostic originally omitted accepted onset, same-anchor history, actual force/torque and task phase. The reviewed diagnosis now exposes these separately, joins the real certificate/observation and interruption, and treats missing support-point velocity as unavailable/false. It still does not synthesize an onset. Stop accepted speed remains separate from quiet speed.

Fresh offline checks using original R3 raw Vertical120, Lateral Left60 and Stop120 rows show all accepted-onset clauses true at268/179/386 and preserve interruptions275/200 where present. An actual valid development Vertical row passes eligibility; changing its observation to INTERRUPTED fails; making only latency PRECONDITION_NOT_MET/null preserves task eligibility. These are read-only contract checks, not new physics runs.

| Reviewed prepilot bytes | SHA-256 |
|---|---|
| `features/evaluator_virtual_cursor/scripts/feasibility_fixture.gd` | `d056474b2e41834a9e997a7b7adc01093769034b8b5d0e68780ef0dcff2b9c7a` |
| `features/evaluator_virtual_cursor/scripts/feasibility_driver.gd` | `90743d75f44d19e95f42efefd525a33435f375c082321f7e4201ddf6913d158d` |
| `features/evaluator_virtual_cursor/resources/fixture_feasibility_v134.json` | `5ac75d6ce44a62e494d8bfe3076d6d0568e71dc3105eca246d5ca96c0451b7a8` |
| `tools/fixture_feasibility.py` | `504b4034f645c4886bc0970c41ec639d7e773913ca1641e59c2e6d53e6aa63fe` |
| `tools/fixture_prerequisites.py` | `2d97f7221922480e57dea9566fe15865261317d382995da8646d1c28cbfd0267` |
| `tools/auto_tuning/benchmark_qualification/campaign.py` | `2e875bc62d79973290c7c8f1c38fe88294d277594125cdb6989627b3bc49d1ec` |

Final source registration must bind these bytes and all their dependencies. Any later source change requires a new candidate review; these hashes cannot certify different bytes. All final cell outcomes, same-Hz H/R pairs, diagnostic Foot/Stop windows, negatives, regressions and release/LIVE gates remain PENDING. The only acceptable outcome without every required gate is FEASIBILITY_NO_GO; no new full qualification or optimizer follows automatically.
