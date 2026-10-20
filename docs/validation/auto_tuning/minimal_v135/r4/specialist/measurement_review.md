# v1.3.5 independent measurement and statistical design review

Review stage: **PROSPECTIVE DESIGN APPROVED WITH IMPLEMENTATION GATES PENDING**. This is permission to implement and qualify the declared experiment, not GO_MINIMAL_BENCHMARK, a search result, a candidate recommendation or product approval. No engine has been launched by this reviewer. No simulation source, historic evidence, Git state or synchronized copy has been modified. No private holdout has been opened.

The complete 429-line v1.3.5 specification was read. The integration owner reports BASELINE_READY at clean commit `bc619a6`, tag `baseline/pre-v1.3.5-minimal-tuning`, branch `feature/v1.3.5-minimal-tuning`. The actual new source, dependencies and exact executable identities must still be registered and qualified. Historic v1.3.4 measurements must never fill a missing fresh result.

## 1. Scope and reusable evidence

Only Vertical and Right Traverse enter training. The four public historic v1.3.4 tapes were read without accessing private holdout data:

| Tape under `builds/eval_virtual_cursor/fixture_feasibility_v134_r1/tapes/` | SHA-256 | Frames | Frozen onset |
|---|---|---:|---:|
| `vertical_pull_clean_v134_r2_120.json` | `4b12d62cf7a536bd78c5aca992ac5d5df52ebc645166a452a9377f93bddd1016` | 545 | 425 |
| `vertical_pull_clean_v134_r2_60.json` | `2da5a7d8ce774cb84646454f8a263335a970e837980238f26ec831a0bfb7b8e2` | 296 | 236 |
| `lateral_clean_right_v134_r2_120.json` | `bd4202e6fc59ab2cff863f938bbb601853e96ac73e864c1a580c15bcf769eca1` | 545 | 425 |
| `lateral_clean_right_v134_r2_60.json` | `6ea4ebe66ce5e9cc07d3b42538b08cf6443b7669ca0fd1731772d5109beeeb0c` | 296 | 236 |

All declare genuine adaptive capture provenance, valid source onset and `diagnostic_only=false`; their later fixed replays are distinct observations. These are suitable **historical inputs for explicit import**, not fresh v1.3.5 passes. New catalog/tape wrappers must retain the original byte hashes, source/geometry identities, actual frames and declared window. Revalidation must run under the new measured source. A changed physical world or action sequence requires a new tape and identity.

Safe reuse is the v1.3.4 real-input preparation/replay path, body snapshots, conservative clearance, typed `metrics.summarize`, exact comparator, native projection/dispatch contracts, source archive and actual world retirement. Reuse the approved `optimization_override_loader.gd` / `optimization_trial_lab.gd` Resource-copy/install/restore route. Existing `qualification_driver.start` and `reliability_driver.start` deliberately reject nonbaseline overrides: add only a narrowly scoped opt-in candidate policy, retaining the baseline-only policy for old evaluators. Do not bypass the full whitelist or overwrite protected gameplay resources.

The old `optimize.py` / `scoring.py` orchestration assumes seven historic tasks, legacy four-axis aggregates and different proposal limits. Its study/storage/identity primitives are reusable; its unqualified task membership and scores are not the new minimal benchmark. No second physics or picking engine is required.

## 2. Hard qualification gates before proposals

1. Freeze source, engine, registry, catalog, all selected tape bytes, parameter canonicalization, score/quality contract, proposal order/seed and complete budget plan. Preserve clean baseline rollback and profile-2/LIVE startup.
2. Certify actual Python→JSON→Godot transport, finite exact numeric dimensions, canonical backing/logical viewport, clock and ownership **before** body creation. Keep typed scalar/Vector2/Vector3 provenance; missing comparable evidence is not a strict match. No epsilon or world-coordinate rounding is approved.
3. Record explicit A0/B1 as a complete four-value candidate, validate effective Resource values/protected fields before the first physical tick, and verify safe restoration after every episode. Reject malformed/partial/unknown/constraint-invalid maps before physical execution. Record effective resolution before spawn as required; a post-spawn report alone cannot establish that admission guard.
4. Run the full fresh baseline: two tasks × two frequencies × three H/R pairs = **24 single-episode processes**, with complete eligible task windows in every run. Recompute metrics and inspect actual supports/anchors/forces. Compare strict H/R and within-mode repeats. One failing required baseline cell means NO_GO_MINIMAL_BENCHMARK, no geometry repair and no narrower scoring selected afterward.
5. Complete the source-specific negatives and impaired-canary sensitivity gates. Infrastructure/safety failure stops globally; a legitimate candidate task failure remains a typed candidate rejection. Source changes invalidate the registered study.
6. Freeze numerical fresh-A0 references, actual repeat ranges and all thresholds **before the first optimizer proposal**. The formulas below are prospective, not fitted to candidate results. Missing applicable quality evidence cannot be silently treated as a pass.

MB2 produces only a local two-task certification. Even a perfectly deterministic baseline cannot approve the full historical benchmark, physical generalization or human feel.

## 3. Fixed-input candidate semantics

Use the **same actual fixed tape and frozen onset tick/window** for every candidate in a cell. Reobserve the candidate's own recorded POST row, prior quiet dwell, real accepted command, legal support and material anchors. Never copy A0's body pose, velocities or anchors into the candidate, shift its onset to a later success, add rescue inputs, or silently use an adaptive tape for ranking. Candidate-specific adaptive captures are separately labeled diagnostics with no fixed-input comparison credit.

Retain the approved progress onset: two genuine attached loaded hands, nonground/no hybrid/no native ground authority, conservative clearance, same anchors through raw prior dwell, absolute directed support-relative speed ≤0.1 m/s, full spin ≤0.2 rad/s for the existing elapsed 0.25 s, and actual positive accepted command at onset. Required horizon and support continuity remain unchanged. No force, reach, adhesion or preparation damping change is permitted.

Fixed screen intentions do **not** guarantee identical world rays across different candidates: their bodies and V0 cameras can evolve differently. Each candidate must select the correct real surface/face/envelope within reach and keep its actual anchors stable during measurement. Exact ray/local-point/physics equality applies to H/R and repeats of the **same** candidate; it is not a candidate-versus-A0 gate that would prohibit the intended physical differences.

Record attempted, execution validity, certified onset, complete window, task success and metric status independently. Missing onset and interruption keep official null values and truthful reasons. Preserve raw partial movement separately. No measured distance of zero is manufactured. A failed task cannot be rescued by strict replay fidelity.

Cleanup includes neutral/released input, removed provider/router ownership, restored Resource bindings/settings, absent old world/driver/probes and no retained physics objects. Incomplete traces, stale JSON, source mismatch and corrupt comparators are infrastructure failures, not poor candidate scores.

## 4. Objective and prospective practical gates

Keep four reported families separate: directed progress, movement fidelity, physical/control quality and reliability. Use a Pareto view of the two signed progress differences after eligibility/quality gates, with A0 explicitly included; do not reuse the old seven-task scalar or let a large progress value buy away a hard failure. The optimizer receives only training records. It receives neither private holdout files nor transfer outcomes used for retuning.

For each task/frequency and each descriptive quantity `x`, define `B(x)` from the fresh matched A0 cell and `R(x)=max(A0 repeats)-min(A0 repeats)`. Freeze both the extraction method and all realized numerical limits before proposals. H/R determinism should make these spreads zero, but **zero spread is not zero uncertainty about players, starts or the real game**. No t-test, confidence interval, significance or independent `n=3` claim follows from three identical replays.

Prospective engineering gates, subject to independent physics review before the score contract is frozen:

| Quantity | Practical rule |
|---|---|
| Progress gain on at least one primary task | ≥`max(0.010 m, 0.05×B(progress), 3×R(progress))` |
| Allowed progress loss on the other task | ≤`max(0.005 m, 0.03×abs(B(progress)), 3×R(progress))` |
| Directional efficiency loss | ≤`max(0.03 absolute, 3×R(efficiency))` |
| Extra backwards COM excursion | ≤`max(0.005 m, 3×R(backwards excursion))` |
| Measurable response-latency increase | ≤`max(0.030 s, 2/Hz s, 3×R(latency))` |
| Extra peak angular speed | ≤`max(0.10 rad/s, 0.10×B(peak angular speed), 3×R(...))` |
| Extra accumulated angular travel | ≤`max(0.05 rad, 0.10×B(angular travel), 3×R(...))` |
| Extra actuator-saturated sample fraction | ≤`max(0.10 absolute, 3×R(saturation fraction))` |
| Protected valid stop-path increase | ≤`max(0.010 m, 0.10×B(stop path), 3×R(...))` |
| Protected valid settling-time increase | ≤`max(0.10 s, 0.10×B(settling), 3×R(...))` |
| Necessary acquisition/retention/support/window failure | No new failure relative to eligible A0 |
| Physical invariants / force / reach / authority | All original hard limits; no enlarged allowance |

Backwards excursion is the maximum decrease from the running maximum of signed task COM progress in the authorized window. Angular travel is the time integral of observed full angular-speed norm, and peak speed is its maximum. They are **not** support-relative twist. Saturation is the fraction of authorized POST samples carrying the actual saturation flag. Specify sample inclusion/endpoint integration in the versioned projection and unit tests before measurement. A contact impulse is not automatically invalid jerk. Report velocity-derived acceleration/smoothness proxies with actual contact tags as diagnostics; do not add an uncalibrated jerk reward.

The existing unsupported twist frame must remain NOT_APPLICABLE/null. Do not invent a twist angle from screen rotation or relabel world angular travel as validated twist. Any unavailable quality family remains explicitly unavailable and limits the claim.

Latency uses the approved >0.02 m/s useful speed and 0.05 s dwell. ALREADY_MOVING_BEFORE_ONSET remains null, never zero or a response bonus. Compare latency numerically only when both matched records are MEASURED. If a fresh-A0 measurable latency becomes unavailable for a candidate, mark the comparison NOT_COMPARABLE; it supplies no latency-improvement credit and cannot silently establish the no-worsening gate. The disposition of that unresolved quality gate must be fixed before proposals (conservative default: no finalist promotion without sufficient comparable evidence). If A0 itself has unavailable Right latency, preserve that declared coverage limitation rather than inventing a universal requirement from null data.

An eligible candidate may have negative directed progress: retain the measured signed number and reject performance as appropriate. Onset/window failure is ranking-ineligible; use a separately labeled deterministic optimizer trial disposition, not a fabricated physical distance. Archive every failure and duplicate in chronological order.

## 5. Preselected canary and proposal schedule

Before candidate results, preselect the impaired non-optimized four-knob map:

```json
{"traversal_speed_m_s":0.18,"traversal_input_ramp_s":0.20,"traversal_target_max_rate":0.16,"traversal_target_max_acceleration":0.60}
```

It changes no physical force or contact rule. Its braking envelope is 0.0213333333333333 m, below 0.055 m; the ramp spans 12 steps at 60 Hz. Run V/R at 120 Hz twice each: four separately charged canary launches. A repeatable practical degradation in at least one **valid complete** task establishes continuous-performance sensitivity. A repeatable, safe, truthful acquisition/onset failure establishes only reliability discrimination, which must be labeled separately; do not call it a measured movement gradient or manufacture zero progress. If the canary demonstrates neither, the sensitivity gate fails. If it demonstrates only reliability discrimination, the initial local sensitivity stage must establish an informative eligible continuous surface before random/TPE continuation; otherwise stop. Do not choose a new canary after observing the score surface.

A1 is historical negative evidence. It is not a seed or one of the four-knob proposals. If omitted because no approved equivalent route exists, say so.

Prospective search is deliberately below the specification's maxima: **18 configurations = 8 local sensitivity + 6 random + at most 4 TPE**, one task per process. Each complete candidate needs two 120 Hz task launches: 36 launches, with four controlled-confirmation/retry slots inside the 40-launch ceiling. Both tasks are attempted for an admissible candidate unless a global safety/infrastructure stop forbids continuing. Precheck remaining launch/episode budget before starting the two-task unit. Reject constraint-invalid and duplicate proposals honestly without unbounded redraws; preserve proposal counts separately from physical evaluations.

Suggested frozen local pairs around A0 are speed 0.22/0.28, ramp 0.09/0.15, rate 0.21/0.27 and acceleration 0.75/1.05, changing one knob at a time. All pass the stated cross-constraints. These are proposals for the predeclared schedule, not measured improvements. Pin the proposal seed/order and actual Optuna/Python versions. Enter TPE only if eligible prior trials reveal a nonconstant, reproducible informative surface; no practical gains or systemic failure is a valid early stop. Do not consume its four slots merely because they exist.

## 6. Prospective process and episode accounting

There is no hidden multiplication of the specification's headline maxima. A one-task/process design cannot evaluate 32 full configurations in 40 launches, nor run fresh A0 plus three complete finalist matrices in 48 launches. The integration owner has therefore selected the smaller search above, **at most one finalist**, and a new, isolated two-episode runner **only for final validation**. This is a prospective choice before results.

| Ledger | Maximum processes | Episode mapping |
|---|---:|---|
| Preflight | 8 | Declare each physical replay, transport rejection and any novel-tape authoring before launch; report zero-body pure processes separately as well |
| Primary MB2 A0 | 24 | Exactly 24 single-task episodes, 12 fresh H/R pairs |
| Negatives/canary | 8 | N1 both Hz: 2; impaired V/R 120 Hz twice: 4; two preregistered ground/interruption controls; schema mutations may be pure, never fake physics |
| Proposal stage | 40 | 36 planned single-task episodes for 18 candidates + up to 4 controlled episodes; still ≤160 episode cap |
| Final primary | 24 of the 48 finalist slots | Fresh A0 plus one finalist, two tasks × two Hz × three H/R pairs = 48 episodes, packed at most 2 independent episodes/process |
| Final protected/new starts | Remaining 24 finalist slots | Explicit preregistered cases and A0 controls; no transfer to training |
| Existing regression suites | 34 separate | Fresh established physical/LIVE safety coverage, not training samples |

There is **no A0 reference-reuse deviation in this selected plan**: the finalist primary matrix reruns fresh A0, rather than counting MB2 observations a second time. This resolves the earlier single-process budget conflict without weakening §9.1. Both the process and episode counts, including setup failures/timeouts/retries and any zero-body admissions, must remain explicit. Maxima are not quotas. Stop before a partially budgeted trial.

One prospective protected allocation inside 24 slots is Swing & Catch A0/finalist × two Hz × H/R: 8; novel V/R at 120 Hz A0/finalist: 4; authorized Stop A0/finalist × two Hz: 4; functional Asym/Left at 120 Hz A0/finalist: 4; First Ascent A0/finalist × two Hz: 4. Novel tapes must be genuinely distinct, authored/frozen before candidate assessment and separately charged when captured. This allocation is a design proposal until registered. Unavailable validated components must be labeled missing coverage, not silently replaced. Existing one-hand/foot/hybrid safety coverage and any remaining limitations must be mapped explicitly to the fresh validated suites or declared unavailable. No private holdout was inspected to create this proposal.

### Mandatory batch-runner evidence

The two-episode final runner is **not yet certified**. Its design is acceptable only with these predeclared gates:

- Each episode owns an independent Driver instance, full manifest, candidate hash, actual tape, trace, result and unique directory. No shared adaptive acquisition state, input frames, Onset certificate or Resource override survives into the next episode.
- Finish and record input/Resource/settings restoration, remove/free driver, provider, probes, world and physics objects, and prove old world/RIDs absent before starting the next environment/clock admission. Await actual retirement; queueing deletion alone is not proof.
- Independently requalify backing, logical viewport, clock, camera/input ownership and source/candidate before each new body. The second episode cannot inherit an assumed ready environment.
- Prove same-source A0 batch episodes are exactly comparable with qualified single-process A0 at the same task/Hz, and strict H/R plus within-mode comparisons remain intact. Keep original transport scalar/native-bit evidence. A prior episode cannot change the next task's result.
- Kill/timeout/crash preserves both attempted episode receipts, truthful completion/absence and launch accounting. Do not certify an unexecuted second episode or reuse stale output. No source change or rescue retry after freeze.
- Any batch cleanup/comparability failure stops finalist validation; no candidate promotion and no silent fallback that exceeds the registered process budget.

Implementation and actual batch evidence require further independent review. A design approval cannot establish those facts before tests.

## 7. Statistical and product interpretation

The baseline and repeated finalist cells measure deterministic local replay stability on four task/rate tapes. They do not represent independent players, start states or stochastic samples. Different seeds are not posture diversity unless a genuine physical stochastic effect is demonstrated. Report paired effects, all per-cell values, practical thresholds and worst cases; no confidence inflation from identical repeats.

Train only at 120 Hz, then validate fresh A0/finalist at both frequencies and modes. Never pool 60/120 trajectories into a single independent sample or require cross-Hz bitwise equality. Protected/new-start evidence is sealed from optimizer feedback; no retuning after seeing it. Asym/Left at 60 Hz historic invalidity and Foot Step absent onsets cannot become zero penalties or automatic passes. A new unsafe candidate behavior remains disqualifying.

Possible honest outcomes include NO_GO_MINIMAL_BENCHMARK, a narrowly certified benchmark with NO_ELIGIBLE_CANDIDATE, failed finalist validation, or HUMAN_REVIEW_PENDING. No automated two-task success establishes global improvement or fun. Human A/B, qualified transfer coverage and explicit product approval remain separate; profile 2/LIVE defaults stay unchanged.

**Review decision:** the prospective measurement design, reduced search and fresh-A0 batch budget mapping are acceptable for implementation/qualification. MB1/MB2, impaired-canary sensitivity, realized quality thresholds, source registration and especially batch integrity remain **PENDING actual evidence**. No optimizer proposal is authorized by this review alone.
