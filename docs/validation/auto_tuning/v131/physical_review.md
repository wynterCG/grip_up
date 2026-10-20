# Evaluator reliability v1.3.1 - physical review

## Scope and status

This feature changes diagnostic execution and measurement only. The production climbing controller, actuator, geometry, original seven-scenario catalogue, historical results, parameter defaults and private holdouts remain unchanged. No optimization or human rating is part of this work.

The new shared-tick driver is a deliberately versioned evaluator. Its outcome is not assumed equivalent to the historical driver: the historical driver resumed on SceneTree.physics_frame before node physics callbacks; the new driver emits input at priority -100 and observes after callbacks at priority +100. A successful new catch is not proof that the historical discrepancy has been repaired or explained.

Final catch status: the qualified revision at commit `24b18d7` completed 32/32 actual contacts and same-anchor retentions across both modes/frequencies. ER2 passes only that narrow outcome requirement; ER5 remains NOT_READY for continuous scoring because the rendered 120 Hz policy branches and changes contact timing/progress. See the final catch review below and the parent locomotion/decision reports. Earlier development receipts (including four headless catch runs and the initial pure checks) remain preserved and do not substitute for this final matrix.

## Baseline identity, not overrides

baseline_lab.gd extends the original gameplay lab directly. It calls the normal load_test and verifies the four existing fields against the canonical baseline before the first step. It does not duplicate, install or edit a tuning Resource. The old loader is used only for validation and provenance; its binding list remains empty. A nonbaseline candidate is rejected before actuation.

The reference remains A0/B1, profile 4 in the declared cells. Original startup profile 2 is checked. Each actual initial snapshot records the observed profile, allocation, feet flag, B2 flag, intent flag and four values. Reset restores normal startup ownership and physics frequency; source hashes are verified before and after. No Resource restoration claim is inferred merely from matching numbers.

## Tick and observation contract

The same Node driver executes headless and rendered. Requested decisions queue real Input action events; only the pre-control probe emits them. The post-control probe records the coordinator's raw accepted Vector2, separately from filtered intent and separately from requested input. A stop or reversal timestamp is acknowledged from that actual raw command, not predicted as the next tick.

The names pre_control and post_control describe node callback order. They do not claim a new post-solver integration. Body COM, velocity and spin come from PhysicsDirectBodyState3D at each hook. COM is transform.origin + center_of_mass, with the latter used as the world-space COM offset. Newly admitted controller forces are telemetry from this callback and are not falsely treated as an already integrated velocity change.

Actual callback delta is recorded and checked against 1 / requested_hz. Time used for episode comparisons is the tick-based physics clock; wall time is only an explicit timeout and overhead measurement. Camera pose, pointer, FOV, viewport, interpolation fraction, bodies, shapes, material-local targets, collisions and support identities are retained.

### Clock/lifecycle revision after the preserved 60 Hz failure

The first rendered 60 Hz run in catch_001 correctly returned BLOCKED_TRACE / ACTUAL_DELTA_MISMATCH. Its first 15 recorded world ticks received delta = 1/120, then tick 16 received 1/60, despite the requested frequency being 60 from driver start. The project default is 120; runtime assignment immediately preceded first-world construction. This establishes an effective startup frequency transition. An already scheduled engine batch is a plausible explanation, not a proven internal engine diagnosis. The failed receipt is retained and cannot qualify as 60 Hz data.

The new harness revision waits on actual post-probe callbacks in an empty world after requesting the frequency. Two consecutive callbacks must carry the requested delta. Every startup delta, run tick, elapsed wall time and absence of a Lab is recorded. Five observed wall seconds or 120 callbacks without confirmation produce explicit BLOCKED_SETUP; the external process watchdog still covers an engine that stops producing callbacks entirely. No stale world is advanced or later relabelled. The existing exact in-scenario ACTUAL_DELTA_MISMATCH guard remains.

Every new world is now constructed after post_completed, including the first and subsequent sequence cells, after retiring the old world. The creation boundary is recorded per scenario. Earlier 120 Hz receipts showed an initial one-step state difference: alone first PRE had vY = -0.0816667 m/s and COM 0.680566 mm lower than sequence first PRE (vY = 0). Lifecycle normalization addresses that measured setup inconsistency without changing a body pose or velocity. It is a second evaluator revision and does not retrospectively prove the cause of historical native failures. The parent must rerun the physical matrix against the new source commit; prior success counts remain version-specific.

## Catch evidence

A request's intended point, actual camera ray hit, accepted material collider/local point, persistent target, reach window, finite-path status, actual hand endpoint, attachment and actual admitted load are separate records. CONTACT_VALIDATED precedes ATTACHED in the observational event chain; neither is a prediction. RETAINED requires continuous ATTACHED state with the same anchor for 0.6 s. Regripping or slipping resets that interval.

Initial source contacts never substitute for the destination contact. A pending target is not an actual support and cannot earn support validity or force credit. A real contact can fail later under the unchanged arm range and force budgets; contact success and retention therefore remain distinct.

## Prospective preconditions

Revision 1 thresholds were written before new physical outcomes. Revision 2 corrects the two qualification defects measured in the development smoke, before the frozen qualification matrix; its exact prior catalogue is preserved in development/benchmark_eval_v131_r1.json:

- Clean lateral: signed support-relative lateral speed <= 0.10 m/s and angular speed <= 0.20 rad/s continuously for 0.25 s; maximum wait 5 s.
- Counter-swing: actual signed lateral velocity in [-0.50, -0.02] m/s, earned through existing input within 2 s.
- Stop/brake/reverse preparation, revision 2: signed speed in [0.15, 0.50] m/s, earned within 2 s. Revision 1 used [0.05, 0.50].
- Low-energy preparation, revision 2: full support-relative speed norm <= 0.10 m/s, plus angular norm <= 0.20 rad/s, continuously for 0.25 s within the same maximum wait. Clean lateral retains its lateral-component criterion.
- Settling metrics: speed <= 0.10 m/s and spin <= 0.20 rad/s continuously for 0.25 s.
- Reversal metrics: > 0.02 m/s in the newly accepted command direction continuously for 0.05 s.
- Observation windows: clean lateral 1 s, counter 2 s, stop/reverse controls 5 s.
- Existing real hand support and zero native ground authority are required throughout qualified control measurement. The one-hand cases require continuity of that original hand and anchor.

Failure to reach a precondition is PRECONDITION_NOT_MET, not a silently different initial condition. A valid observation is not a positive performance goal. Negative signed displacement, late reversal, no settling, interrupted support and unavailable measurements remain visible. Python typed analysis owns the distinction between finite values, not observed by deadline, interrupted and unknown.

### Development qualification defect and bounded correction

The parent lateral_stop001 smoke completed all 12 engine processes, but its two-hand stop began at total speed about 0.078 m/s, already inside the 0.10 m/s stopped band. The revision 1 minimum directed start of 0.05 did not logically distinguish a stop task from a low-energy control. Separately, the one-hand low-energy case entered at total speed about 0.145 m/s because only the lateral component was tested. Those development receipts remain historical and do not become qualified stops retroactively.

Revision 2 uses 0.15 m/s for directed motion preparation: the unchanged 0.10 stopped band plus a declared 0.05 task separation. The low-energy case uses full relative velocity norm. These are benchmark validity checks, not force, geometry, tape, observation-window or performance-goal changes. Inability to enter the stricter state is an admissible PRECONDITION_NOT_MET; no outcome improvement is assumed. Baseline Resource verification errors now return BLOCKED_SETUP before any acquisition or settling, rather than being misreported as an unsuccessful physical preparation.

Revision 3 preserves those bands and fixes their elapsed-time interpretation: 30 quiet samples at 120 Hz span 29 intervals (0.241667 s), and 15 at 60 Hz span 14 (0.233333 s). Confirmation now requires (current_tick - first_quiet_tick) / Hz >= 0.25, resetting the first tick after any violation. The full low-energy speed/spin condition is also checked at the actual accepted-command snapshot. A state that drifts outside it between preparation and acceptance remains PRECONDITION_NOT_MET. The exact revision 2 catalogue is preserved in development/benchmark_eval_v131_r2.json.

## Supports, budgets and work

Support validity uses actual attached/slipping hands and actually loaded SUPPORTING/SLIDING feet; PLANTING or a selected target is not load. B1 foot forces remain separately visible, so ungrounded does not imply arm-only.

Stationary actual supports share an exact common static-world reference. A single moving support exposes material identity and actual COM-point velocity, including angular motion. Multiple unrelated moving supports have no fabricated common velocity: optional relative measurements remain unknown.

No body transform, velocity, force, reach or budget is added by this feature. Runtime checks reuse the frozen mechanical monitor and direct admitted-force snapshots. No-body-write assurance is source-scope enforcement and audit, not a pretend runtime detector with an always-false variable. Current hand 360 N, feet 180 N, assist 20 Nm and combined moment 150 Nm limits are unchanged. No energy conservation theorem is claimed for contact-rich Jolt integration or partial actuator work.

## Trace and instrumentation scope

The recorder writes bounded pre/post samples and events to unique run-local JSONL files, atomically finalized. Recorder OFF disables JSONL writing; it does not imply that the existing gameplay observer is off. A separate catch-only reference disables that observer and reads actual direct state itself.

The reported cost_usec covers the post probe's snapshot, event derivation and serialization only. It excludes pre-probe input and recording, existing observers, engine work and rendering; external whole-process timing is required for total overhead.

Rendered screenshots are bounded to 12 and captured at frame_post_draw. Their index names the latest preceding observed scenario/tick/time, alongside the actual render frame. They show interpolated rendering, not a claimed solver snapshot. PNG readback cost is separately recorded and may affect render cadence. Headless/rendered, trace OFF/ON and full observer OFF/ON comparisons must retain that distinction.

## Historical discrepancy: observed evidence, not a causal verdict

The immutable v1.3 baseline repeatedly caught in headless isolated and sequence runs with about +0.40555 m progress. The earlier native baseline failed NO_REAL_CATCH with about +0.19213 m. Their catch-start COM differed by about 5.88 mm, linear velocity by 0.04886 m/s and spin by 0.08920 rad/s, before the catch command. Actual source material anchors differed only by a few micrometres. Camera/FOV/viewport and public source hashes matched, while the prepared contact/load state differed.

The parent's exact historical reproduction subsequently observed native success and failure (two successes and one failure in the cited native isolated group), with successes around +0.40532 / +0.41591 m and the failure around +0.19216 m. These results establish limited rendered repeatability of that evaluator, not a specific Jolt defect.

Render-follow camera phase, before-callback coroutine continuation, initial B1 contact/load state and actual request timing are candidate mechanisms. They remain hypotheses until paired new traces locate and explain the first meaningful divergence. The historical coarse samples do not preserve enough endpoint/path evidence to assign a specific pending-release cause.

## Remaining limitations

The new driver inherits scenario business logic and read-only monitoring from the frozen old driver. New callback timing is explicit rather than proof of identical numerical histories. Ray-based arm/path checks remain the production approximation. Native collisions and finite contact forces may amplify small initial differences; successful scripted runs do not establish human feel or generalization. No private holdout has been opened by this reliability work. No new parameter search is authorized by a passing diagnostic suite alone.

## Final catch_002 physical review (source 24b18d7)

This section reviews existing receipts only: no additional engine execution or source edit was used. Canonical code commit is `24b18d760604fffe3455c5b4c9b8b72f37577b4d`. Parent checks passed 43 Godot pure contracts, 75 Python contracts and the original 24 executions / 884 gameplay checks. Those pure contracts do not replace the physical matrix.

Evidence: `builds/auto_tuning/reliability_v131/catch_002/attempts/`, with the parent's comparison tables and per-catch receipts in [reports/catch_002/comparison.md](reports/catch_002/comparison.md) and [reports/catch_002/summary.json](reports/catch_002/summary.json). All 32 outer evaluations completed and all 32 destination catches reported actual contact and same-anchor retention. They comprise three isolated and three sequence repetitions per mode/Hz, plus trace-OFF and existing-observer-OFF outcome controls. The sequence contains seven scenarios, so 32 evaluations include 104 scenario rows; this is not 104 catch repetitions.

### Outcomes, frequency and initial-state qualification

| Physics/mode | Catch outcomes | Signed COM progress range (m) | Maximum hand force (N) | Maximum foot force (N) | Maximum combined moment (Nm) |
|---|---:|---:|---:|---:|---:|
| 120 Hz headless | 8/8 | 0.53419018 exact in these runs | 253.157 | 54.400 | 68.329 |
| 120 Hz rendered scripted | 8/8 | 0.45063904 to 0.53446585 | 254.974 | 54.956 | 68.552 |
| 60 Hz headless | 8/8 | 0.63439047 exact in these runs | 242.304 | 39.289 | 76.767 |
| 60 Hz rendered scripted | 8/8 | 0.63435948 to 0.63467556 | 242.484 | 39.516 | 76.774 |

Assist peaks are 20.0000019 Nm, consistent with float32 representation of the unchanged 20 Nm cap and below the existing monitor tolerance; there is no new higher budget. The reported invariant dictionaries contain no force, pending-force, contact/anatomy, authority, nonfinite or protected-parameter failure. All 32 receipts preserve original Resources, restore startup profile/frequency and match source hashes after the run. No-body-write assurance remains source audit and the isolated baseline factory, not a numerical invariant inferred from a hardcoded false field.

All runs observed the same authored spawn and the same first PRE state within each Hz/mode/context: COM `(-0.55000001, 1.16931939, 0.40000001)`, vY `-0.08166667` at 120 Hz; COM `(-0.55000001, 1.16727769, 0.40000001)`, vY `-0.16333334` at 60 Hz. These are observations after one actual integration at their respective frequency, not identical elapsed-time states across Hz. Comparing 60 and 120 as bitwise trajectories would be invalid.

Startup confirmation used two correct empty-world callbacks for headless and rendered 120 Hz, and 17 callbacks for rendered 60 Hz: the first 15 stale 120 Hz callbacks were recorded with no world, followed by two actual 60 Hz callbacks. Every recorded scenario callback then carried the requested delta. Creation receipts use the post-control boundary; old subtrees were absent and old PhysicsBodies had zero remaining space registrations before new construction. This addresses the two measured harness defects without suppressing any mixed-frequency world sample.

At 120 Hz the three headless isolated and three headless sequence traces are exact across all 1068 corresponding physical rows, requested/accepted command channels, material targets and discrete contact events after excluding process runtime IDs and only generated `@CollisionShape3D@...` names. Shape dimensions, local transforms, disabled flags and contacts were not excluded. This is measured equality of those runs, not a general guarantee of Jolt determinism.

### Real catch chain and pending authority

The actual destination material anchor was initially at least 0.80718 m from the free shoulder at 60 Hz and 0.81526 m at 120 Hz, exceeding the unchanged 0.65708 m anatomical reach plus the declared 0.02 m outside-reach task margin. The accepted material contact, not merely the selected nominal point, supplies that test.

| Context | Selection tick | First actual reach-window tick | Contact / ATTACHED tick | First load > 1 N | Same-anchor RETAINED tick |
|---|---:|---:|---:|---:|---:|
| 60 Hz, all 12 traced repetitions | 142 | 212 | 213 | 214 | 249 |
| 120 Hz, all six headless traced repetitions | 282 | 436 | 438 | 440 | 510 |
| 120 Hz rendered, normal branch | 282 | 436 | 438 | 440 | 510 |
| 120 Hz rendered, shifted branch | 282 | 438 | 440 | 442 | 512 |
| 120 Hz rendered, delayed branch | 282 | 476 | 478 | 480 | 550 |

The 24 trace-enabled runs contain 19,244 catch pre/post rows and 6,836 REACHING hand samples. Actual arm-force magnitude in every such pending sample is exactly zero. Contact, attachment and first admitted load remain distinct. RETAINED occurs 36 ticks after contact at 60 Hz and 72 ticks after contact at 120 Hz: 0.6 s with the same anchor. Source release is a separate real input event; source attachment is not stitched into destination retention.

### First divergences and the rendered 120 Hz outliers

Outcome reproducibility does not make the progress metric reproducible enough for precision-sensitive ranking. The largest same-Hz observed rendered/headless progress difference is about 0.08355 m; the 120 Hz rendered range is about 0.08383 m. It must not be hidden inside a fabricated millimetre tolerance or described as the game becoming faster/slower.

Representative pair: `catch_headless_120_isolated_r1_trace_e07871f3` versus `catch_rendered_scripted_120_isolated_r1_trace_6d9d6acc`:

- Actual initial body state matches. At the first source request (tick 55), the material-local Z differs by 1.4305 micrometres. The actual render-follow camera and pixel ray differ, even though the intended world point is the same. A body-spin difference above the comparator's reporting epsilon 1e-6 first appears at tick 92 PRE (spin-Y difference 1.4305e-6 rad/s). That reporting epsilon is not a certification tolerance.
- The first consequential command difference occurs at tick 419 PRE, then is actually accepted at tick 419 POST. The headless policy requests W+A; the rendered outlier requests W+D. This is not copied/requested input masquerading as acceptance.
- At the preceding POST tick 418, the declared supported angular-phase speed is -0.0405834 rad/s headless versus -0.00306284 rendered, on opposite sides of the unchanged -0.04 rad/s feedback threshold. Thus the same closed-loop policy produces different real input after physical state divergence. It is not an identical open-loop tape.
- The actual reach window/contact move from ticks 436/438 to 476/478, a contact delay of 40 ticks (0.3333 s). Source release moves 453 to 493; retention moves 510 to 550. Progress changes from 0.53419018 to 0.45063904 m. The rendered sequence r3 exhibits the same delayed branch and 0.45076832 m progress.
- Rendered isolated r2 and sequence r1/r2 have no command-channel divergence from the headless reference and contact at tick 438. Rendered isolated r3 diverges earlier at tick 290, contacts at 440 and ends at 0.53175265 m.

This demonstrates a state-dependent, discrete-policy amplification, beyond merely noting an early micron-scale target difference. It does not prove which initial ray/contact detail uniquely caused the historical native misses, nor whether changing the policy would be preferable. No policy, force, geometry or threshold was retuned after observing these outcomes.

At 60 Hz representative headless/rendered r1 traces keep identical requested and accepted commands and discrete catch-event ticks. A source material-local Z difference of 1.9073 micrometres appears at tick 28; first body-spin difference above 1e-6 appears at tick 48 PRE. The much narrower observed progress envelope is still a measured baseline envelope, not a promised universal tolerance.

### Instrumentation controls and physical scope

Trace OFF and existing-observer OFF preserved the actual catch outcome in both modes and both frequencies. Headless end progress also matches the trace-enabled runs exactly at each Hz. Rendered controls remain inside or close to the corresponding observed rendered trajectories. Recorder-OFF and observer-OFF runs do not provide a complete corresponding trace, so those outcomes do not establish per-tick numeric zero effect. Pure source checks, read-only APIs and outcome controls support isolation, without pretending to prove exact rendered equivalence.

Some legacy fields are unavailable with the existing observer OFF: its ground-time/ground-authority flags and body-acceleration peak may remain zero. These must not be interpreted as measured absence of ground or acceleration. The new direct-state reliability snapshot/trace, where available, has separate scope.

The fixture is B1-assisted and intermittently contacts the native ground. Among measured POST samples in the traced runs, actual loaded feet and native ground/motor authority occur in every mode/Hz group. For example, headless 120 Hz isolated r1 has native ground/motor intervals at ticks 385-398 and 513-517; destination contact is 438, source FREE is 453 and attachment retention is confirmed at 510. The later source-release verification window can therefore include ground. `destination_alone=true` means the original hand was released; it does not prove arm-only suspension. The catch is genuine, but cannot be promoted as a no-ground, no-foot pure pendulum benchmark or whole-system energy test.

### Physics recommendation for ER2 / ER5

**ER2 new-revision catch outcome requirement: PASS, narrowly scoped.** All 32 attempted destination contacts and same-anchor retentions succeeded at both Hz/modes, with valid real contact chains, initially unreachable actual anchors, zero pending effort and unchanged budgets/defaults. The corrected phase/clock/world-lifecycle contract is auditable. Historical unique causation remains unresolved and is explicitly not claimed; old failures and source versions remain valid historical evidence.

**ER5 numeric cross-mode certification / precision-sensitive catch scoring: NOT READY.** Binary catch outcome parity is supported, but the rendered 120 Hz closed-loop bifurcation creates materially different progress/contact times. No universal numeric acceptance threshold or automatic search GO follows from 32 successes. A future explicitly frozen benchmark could distinguish binary task reliability from unstable continuous catch metrics; that is a benchmark/scoring decision, not a physics fix authorized by these results. Full ER5 also depends on the separate lateral/stop and runtime evidence. Overall search readiness remains NO_GO pending the complete gate review; no new optimization, holdout, human rating or gameplay change is implied.

## Final control-matrix review: ER3 / ER4

Read-only evidence is in `builds/auto_tuning/reliability_v131/lateral_stop_001/attempts/` and [reports/control_analysis_001/controls.md](reports/control_analysis_001/controls.md), with individual typed statuses in [control_summary.json](reports/control_analysis_001/control_summary.json). The 12 outer evaluations contain 144 cases: **84 valid observations, 36 interrupted and 24 precondition failures**. No failed precondition or interrupted full window has been counted as successful completion merely because its process exited normally.

**Entry and support audit.** All accepted stop/brake/reverse starts that qualified have directed support-relative velocity within the declared [0.15, 0.50] m/s interval. All qualifying LOW_ENERGY starts have full relative velocity norm <= 0.10 m/s and spin <= 0.20 rad/s. No raw accepted onset outside these bounds was found across the 144 results. Native ground/motor authority is absent at qualified entry; actual required hands are ATTACHED. The 24 precondition failures are all four one-hand control families at 60 Hz in both modes and all three repetitions: preparation ends grounded, with one attached hand but without the required ungrounded supported state. Zero velocity while resting on the floor does not qualify as a low-energy hanging control.

**ER3 clean response: valid, directional and B1-assisted.** All 24 left/right clean cases qualify and retain their declared support during the one-second observation. End progress measured along the commanded fixed axis is positive: left 0.102643-0.109911 m and right 0.215533-0.225828 m across modes/Hz. The initial lateral speed is within the registered quiet band, not identically zero: roughly 0.001-0.007 m/s at 120 Hz and 0.034-0.038 m/s at 60 Hz. Feet are material contributors. In representative r1 traces, mean foot-force magnitude during clean left/right is about 52 / 74 N, with no native ground authority. The directional asymmetry is measured, not explained away as numerical noise or attributed uniquely to feet. These are opposite command controls in the same authored support context; no new mirrored world geometry or arm-only comparison was added.

**ER3 counter-swing: qualified starts, incomplete left windows.** Every counter case enters with velocity genuinely opposite the coming command (about -0.024 to -0.041 m/s along the declared axis). All 12 right-counter windows remain valid; all 12 left-counter windows are interrupted by real native ground/motor contact. Representative first interruption is 1.68-1.70 s after accepted onset at 60 Hz and 1.90-1.91 s at 120 Hz; both original hand anchors are still ATTACHED at that event. Sustained reversal can be measured before later interruption, but that does not make the whole two-second suspended window valid. Left/right feasibility is therefore not interchangeable, and no grounded continuation is credited as climbing progress.

**ER4 typed measurement pipeline: demonstrated with limits.** Two-hand release and bounded counter-brake have valid measured stopping/settling at both Hz and modes. Representative report ranges are release distance 0.11543-0.11662 m, brake distance 0.18816-0.19134 m, and release settling 0.85-1.075 s. The latter difference across Hz is retained rather than rounded into equality. Negative final displacement after release/brake is compatible with earlier positive stopping distance: the body can drift forward, then swing back. Continuous reverse deliberately changes the movement direction; its negative progress on the old forward axis is not an automatic failure of reversal.

Low-energy two-hand controls yield MEASURED settling in all 12 runs, and one-hand 120 Hz low-energy controls in all six runs. Reported settling time zero means the stable interval starts at accepted onset and is subsequently confirmed for the full 0.25 s; it does not mean an instantaneous detector or a body freeze. One-hand 60 Hz controls remain PRECONDITION_NOT_MET. Counter-brake/reverse one-hand 120 Hz and two-hand reverse windows later interrupt on native ground, so missing whole-window outcomes are censored/interrupted, not zero-valued scores. An early measured reversal may coexist with that later interruption. Neutral release, active counter-brake and sustained reverse remain distinct task/metric families.

**Physical invariants and decision.** All 144 result monitors report no protected-parameter, force-budget, pending-force, nonfinite, anatomy or ownership violation. Independent readback of the four representative r1 full traces found maxima of about 254.99 N hands, 90.50 N feet, 20.0000023 Nm assist and 70.96 Nm combined moment, inside the unchanged caps with float32-level assist roundoff. These are representative trace maxima, not an invented global maximum over all 12 runs. The actual support and native-ground interruptions explain the validity labels without requiring a new locomotion or force change.

**Final physical recommendation: NO_GO for a new parameter search.** ER4 has a real, typed stopping/low-energy pipeline; ER3 establishes clean directional measurement and honest opposing-motion entries, but lacks complete left-counter windows and all one-hand 60 Hz controls under the frozen conditions. ER5 still has the rendered 120 Hz catch progress/contact-time bifurcation documented above. A reliable partial diagnostic benchmark has been delivered; full candidate-ranking readiness has not. This conclusion calls for no automatic gameplay repair, no weakened preconditions, no new force/geometry changes and no claim about human enjoyment. Preserve A0/B1 and the stopped study while the integration report states the measured limits.

