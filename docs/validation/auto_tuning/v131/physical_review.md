# Evaluator reliability v1.3.1 - physical review

## Scope and status

This feature changes diagnostic execution and measurement only. The production climbing controller, actuator, geometry, original seven-scenario catalogue, historical results, parameter defaults and private holdouts remain unchanged. No optimization or human rating is part of this work.

The new shared-tick driver is a deliberately versioned evaluator. Its outcome is not assumed equivalent to the historical driver: the historical driver resumed on SceneTree.physics_frame before node physics callbacks; the new driver emits input at priority -100 and observes after callbacks at priority +100. A successful new catch is not proof that the historical discrepancy has been repaired or explained.

Current status: the initial 23 pure contract checks passed. Parent development_catch_002 completed four headless 120 Hz runs without source drift: isolated catch with trace ON, isolated trace OFF, isolated existing-observer OFF, and the seven-cell sequence. Catch completed in each; the sequence retained the historical lateral GOAL_NOT_REACHED (6/7 goals). These are development outcomes, not yet a strict parity or full reliability gate. Physical matrix and rendered evidence are supplied separately by the parent runner. Readiness requires those receipts and typed metric qualification, not just an engine process returning completed.

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

