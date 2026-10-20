# v1.3 scenario and experimental-validity review

2026-10-20. Independent design/fixture review, before optimization. Source baseline supplied by the main agent: `f865ebf3a95eac983329d43df1a90dd1b7952bbd`, recoverable under the pre-v1.3 tag. This review runs no optimizer, changes no controller/runner/geometry, and reports no held-out outcome.

**Recommendation:** reuse existing physical tasks, keep a small but heterogeneous training set, freeze input policies and the split before search, and distinguish numerical improvement from easier automation. Existing v1.2 components are real; their coverage has limits described below.

## Reuse that exists in source

| Existing asset | Valid reuse | Important limit |
|---|---|---|
| `features/locomotion_test_suite/resources/tasks.json` and `scripts/locomotion_test_harness.gd` | T01-T10 live task declarations, actual input/readiness gates, variant identity, recorder and human task UI. | A case name is not a physical fixture. Outside the explicit mastery mirror, labels such as `mirror`, `changed_normal` or `left_high` describe manually selected starting conditions; their geometry is not automatically transformed. Inspect actual anchors/normals before claiming that coverage. |
| `features/grip_up/scripts/intent_test_level.gd` | Step wall/real ledge, traverse wall/feet and hang supports; unchanged free-surface selection. | Original arena is broad and can admit unintended solutions. Score a frozen physical goal, not a label or selected cursor coordinate. |
| `test_locomotion_allocation.gd`, `test_intent_feet.gd`, `study_v12.py` | Known A1 asymmetric/diagonal pathology and B1/B2/B0 physical comparisons; reproducible regression families. | Legacy fixtures include controlled actuator setups and body-origin metrics. Do not rename those measurements COM or call manually initialized contacts natural mouse acquisition. Three identical repeats are repeatability, not pose diversity. |
| `features/locomotion_test_suite/scripts/mastery_course.gd` plus `resources/mastery_course_r1.json` | Real floor starts, broad M-A ascent/M-B traverse/M-C catch, explicit mirrored geometry, bounded attempt state and practice/scored labels. | Three separate checkpoint arenas, not one continuous world. M-A/B `transfers` is same-hand regrip count, not the full observer handoff count. |
| `tests/test_mastery_course.gd` | Genuine finite mouse/action feasibility through baseline A0/B1 at60/120Hz; contact and retained same-anchor catch are distinct. | This is a state-dependent reference driver, not an open-loop tape or a skill test. Its success varies with earlier world history. It uses W preload, angular-state pumping and velocity-based braking; those decisions must be versioned if reused. |
| `features/grip_up/scripts/first_ascent_level.gd` and `tests/first_ascent_exercise.gd` | An actual continuous wall/traverse/bar/deck sequence from ordinary floor to static assisted top-out, native sole support and30cm ordinary walking. | The helper waits for current reach windows, actual route progress and ownership state. It is closed-loop. The physical climb and the assisted crossing must be reported separately. Its bars touch; it does not prove a compulsory ballistic swing gap. |

M-C baseline feasibility evidence must not be overstated. Final v1.2 isolated proofs caught actual points outside pre-pumping anatomical reach and retained the same anchor for.60s, but real feet contributed approximately39-97N. Ground motor ungrounded is not arm-only support. An ALL-segments120Hz replay failed a catch after isolated success. Preserve this as robustness evidence; do not silently remove that outcome or lower retention thresholds.

## Small diverse training set

Seven short episodes can reuse four geometry families. Keep each episode's raw metrics and failures; multiple episodes on one wall are not seven distinct level layouts. The optimizer should initially see only the train manifest, candidate schema and train results.

| Train episode | Existing geometry and start | Frozen task / key observations |
|---|---|---|
| TR-V vertical response | Step; two genuinely acquired comfortable wall contacts; B1 explicit. | Fixed W interval, neutral stop, optional opposite command as a separately identified phase. Signed COM rise, latency, stopping/settling, contact load and saturation. |
| TR-A asymmetric movement | Traverse wall; two observed contacts with a declared height/fore-aft offset. | Separate W and W+D episodes or phases with named direction frames; preserve negative progress and axial twist. Do not rank a sign reversal as efficient because path length is small. |
| TR-L lateral correction | Same unchanged wall; explicit offset contacts. | D, neutral and A under a frozen command schedule. Useful lateral progress, overshoot, reversal response and accidental grip loss. |
| TR-H one-hand control | Existing hang or existing controlled pendulum fixture. | Near-rest loaded hand, build and brake with fixed declared policies. Preserve useful amplitude; distinguish pendulum plane from axial twist. A synthetic initialized hang is an actuator fixture, not a natural catch. |
| TR-C real retained catch | Existing M-C or swing-reach geometry; ordinary acquisition where possible. | Destination beyond actual free-shoulder reach at the declared reference; actual contact then retained same anchor. Log incoming speed, obstruction, foot/ground support and failures. Target centre is not a substitute for the actual caught material point. |
| TR-F foot-supported step | Existing Step; matched B1 and NOFEET conditions. | Useful progress and actual loaded-foot contribution, hand demand and slips. This is support-availability sensitivity; B2 is not introduced into the first parameter search. |
| TR-T ground/grip boundary | Ordinary Step floor, no initial grip. | Walk/reach, finite contact and load transfer through existing controls. Track actual authority and acceleration discontinuities; pending selection is never hand support. |

For a limited pilot, TR-V/TR-A/TR-L/TR-H are a reasonable first4-cell infrastructure check. **A search restricted to them must say catch, feet/transition generalization is under-evaluated.** It cannot claim all section6 capabilities are covered. Add the remaining fixed episodes before a broad locomotion recommendation; do not add them adaptively because one candidate happens to win.

Start with3-5 baseline repeats per important condition at120Hz in isolated engine processes. Preserve variation and worst outcome. Include a small, predeclared set of feasible initial states rather than resampling until support acquisition succeeds. Use the same state/seed roster and driver policy for every candidate and its paired A0. Acquisition failure is an outcome; a declared inadmissible start is a fixture-validity failure, not a zero-cost trial to discard.

## Initial-state admissibility

There are two legitimate fixture types. Both need explicit labels.

- **Natural-input start:** ordinary real floor and body, finite held mouse/actions acquire contacts and physical motion establishes posture. Save the whole approach, then mark the measurement window. No body transform/velocity write after measurement begins. Divergent acquisition is retained and classified.
- **Controlled actuator start:** an existing test fixture initializes pose, velocity or material anchors before measurement. This can isolate low-level response, but it is not natural reach/catch evidence. Record all initialized values and inspect their actual first-tick state. Do not splice a synthetic attachment into a trial labelled natural-input capture.

Prefer comfortable source grips with positive anatomical margin for response training. Keep near-limit valid hands as a separate harder validation condition. A starting arm at its hard limit with a descending body is fragile by construction; an optimizer must not be rewarded for ignoring that limit. No standing penetration, inaccessible shoulder path, visually planted but unloaded foot, or already saturated/failed hand should be called a settled valid start.

Small alternate conditions should be established before measurement: left/right acquisition order, a reflected valid hand arrangement, slight support-relative yaw/lean, and small attainable residual motion from a fixed preparation gesture. If using explicit velocity initialization in an actuator fixture, label it and freeze it; do not set velocity again to align candidates after they diverge. The physics specialist owns numeric bounds after checking actual body/support geometry.

## Hold-out coverage and sealing

Hold out outcomes, not merely scenario names. The following are coverage obligations, not claims that fixtures have already been implemented or passed:

1. A different physically feasible grip spacing/height offset or wall-normal arrangement, including a near-limit valid hand. Reuse existing geometry where different surface points provide the condition; changing a label alone is insufficient.
2. An actual geometric left/right mirror not used in training, with anatomical hand identities and signed measurement direction reflected correctly.
3. A camera-angle condition and a camera-orbit-during-held-intent condition. Preserve the original locked support frame; never rotate a held material target with the camera.
4. Different initial linear/angular motion established before measurement, with actual COM/support-relative velocities recorded. Small residual physical motion and a later pendulum phase test different things; do not collapse them into a seed label.
5. An existing dynamic/hinged support in a different declared configuration, preserving real material motion and reciprocal reactions. This is a regression fixture, not M7. Moving-platform hybrid top-out remains ineligible.
6. A two-stage/multiple-transfer route with a fixed driver, and genuine human-controlled First Ascent. First Ascent is the continuous route; checkpointed mastery is complementary.
7. Original A1 asymmetric/diagonal pathology as a negative-control canary against paired A0. Because this defect is already known, it is **regression coverage**, not unseen generalization evidence.

The validation roster/thresholds/hashes are frozen outside the optimizer's train configuration. The optimizer process must have no per-trial access to validation results or score callbacks. It should receive only a sealed shortlist artifact after search: candidate IDs, canonical parameter hashes, training summary, policy/source hashes, rank rule and freeze time. The validation runner verifies that artifact before opening its scenarios.

Do not run all held-out candidates, print their outcomes to the sampler, then use those observations to narrow ranges or request another search. Once opened, that set is spent as a final unseen test for adaptive decisions. A revised search needs a newly declared hold-out condition set before further final claims. Baseline/candidate validation failures stay in the archive. An invalid validation fixture may be excluded transparently, but replacing it after seeing a candidate's result does not preserve an untouched hold-out claim.

No held-out outcome has been read or produced for this review. Public source geometry and historical v1.2 limitations were inspected; those are existing evidence, not new validation results.

## Mirrors, camera and velocity checks

- Reflect positions **and** physical hand identity, contact normals where relevant, geometry bounds and signed goal direction. Asymmetric rigs/solver contact order can produce real differences; do not require bitwise mirrored trajectories or hide one side's failure.
- Distinguish a passive camera orientation change from rotating the entire world/fixture. Equivalent world-frame covariance is a metric check; camera orbit preserving a latched command frame is an input/controller check. They are not interchangeable.
- An open-loop screen-space cursor tape is not camera-invariant. A ray/material-target driver that projects a world point through the current camera is performing a different policy. Record which one ran.
- Compare actual relative velocity at the measurement boundary, not the requested initialization alone. Support carry on moving material must be separated from self-directed progress.
- Repeat at60Hz after freezing the shortlist. Tick counts and exact catch times may differ; changes of success sign, contact legality or severe failure frequency are meaningful and must not be averaged away.

## Open-loop versus closed-loop contract

An open-loop tape contains immutable timestamped key/button states and cursor/ray requests. Replay exactly the same commands under A0 and tuning. Save the actual collider/material point selected at every request. If diverging motion makes a later screen click hit another object, label target divergence; it is neither proof of a pure locomotion failure nor permission to retarget silently. Recorded human input can still require viewport/camera compatibility checks.

A closed-loop driver may observe actual body velocity, contact state, a predeclared reach window and task geometry, then use fixed rules. The policy is itself part of the fixture: hash its implementation, thresholds, timeouts, target roster and hand-order rules; freeze it before evaluating candidates. It must not read candidate IDs/values to choose different commands, retry only losing candidates, alter contacts/geometry, or add direct body motion. Its policy trace should state which observation caused each action.

Existing mastery C and First Ascent drivers belong in this second category. The optimizer may find a tuning that suits their thresholds rather than humans. Therefore use both fixed open-loop response tasks and fixed closed-loop feasibility tasks, preserve per-task trade-offs, and keep human hands/routes unrestricted. Do not optimize a policy per candidate or call an automated completion player mastery.

## Review gates for the eventual runner contract

Before ranking any candidate, confirm all of the following:

- Scenario/geometry revision, actual source/engine identity, driver type/hash and measurement-frame reference are recorded with the trial ID before execution.
- Unknown scenarios/conditions fail explicitly; no automatic substitute fixture or fallback winner.
- Actual starting contacts and admitted support loads are saved; synthetic initialization is labelled. Native ground false is not used as an arm-only test.
- Source identity and force/reach/collider invariants are checked independently of performance. Crashes, timeouts, nonfinite states and stale outputs cannot become low-cost wins.
- Signed progress remains signed; no-motion efficiency is undefined, not perfect. Pending/reaching, first contact and retained support are separate states.
- Physical climb and assisted hybrid movement have separate phase scopes. Top-out success requires native support and ordinary30cm walk, not clip completion.
- Every train cell has raw results, failures and a matched baseline distribution. A large vertical gain cannot erase a lateral sign regression, lost swing or a catastrophic worst case through one hidden weighted score.
- Held-out results cannot enter per-trial objectives. A frozen shortlist and validation authorization are auditable before opening them.

This document is a validity checklist and design handoff. Final implementation compliance must be assessed against the actual runner/schema/configs once supplied. No contract is certified merely because a proposed API has these names.

## Initial contract source review

The following source was inspected while implementation was still in progress: `resources/parameter_space.json`, `resources/train_scenarios.json`, `scripts/optimization_override_loader.gd` under `features/auto_tuning_lab/`, and Python `candidate_schema.py`, `run_trial.py`, `common.py`, `scoring.py` under `tools/auto_tuning/`. No runner execution or held-out file/result was opened for this review.

Positive findings: the parameter resource names four A0 planner knobs with units, bounds and frozen physical properties; Python/Godot loaders whitelist session-local values; the coupled target stopping-distance limit is explicit. The train manifest now names all seven capability families. The scorer preserves signed progress, hard/runtime status and separate worst-cell axes, and requires a measured useful-swing quantity rather than accepting an all-rotation penalty. These are source-level observations, not completed physics certification.

Open issues sent directly to the implementation owners before search:

- `one_hand_hang_train` initially specified ordinary bar acquisition then D without an explicit unloaded-ground preparation. Native ground/readiness and actual hand/foot load must be inspected; otherwise label it mixed ground/hand movement rather than a proven hanging pendulum.
- `lateral_traverse_train` declares1.0s task duration but command changes at1.25/1.50s. The executor must run those phases inside the declared observation/settling window before claiming reversal control.
- `swing_catch_train` must validate the eventual actual material point against the declared shoulder reference, not only its selected centre. Retention must belong to the same real hand/anchor; slips/reanchors cannot be stitched into a retained catch.
- The candidate transport accepts a holdout split, but sealing requires the separate validation entry to verify a frozen shortlist before opening hold-out definitions/results. The training-only path/hash filter alone is not the whole gate.
- Per-scenario invariant dictionaries were initially allowed to be empty by the Python result validator. The global minimum gates do not establish additional per-row safety coverage; require or disclose whichever assertions the physics runner actually emits.
- Python/Godot trial-ID and timeout validation initially differed (`.` allowed by Python, not by the Godot ID regex; timeout below1s accepted by Python but refused by Godot). Align transport or explicitly test those invalid-candidate classifications before presenting cross-language identity as complete.

Subsequent source re-review confirmed resolution of the ID/timeout mismatch, mandatory per-row hard booleans, and the Python shortlist gate. The gate now verifies canonical freeze SHA/timestamp, candidate parameter membership, repository/engine identity and every frozen public training source hash before opening validation sources. The one-hand manifest now requests ordinary W preparation and an ungrounded start. These transport/declaration fixes do not by themselves establish physically valid starting postures.

The first complete Godot driver source was then inspected, still before any optimization outcome. Additional findings were sent directly to physics/ML owners:

- `_fixed_tape` includes duration plus settling, so the lateral1.25s counter-command is inside its1.50s window; the final key release is explicit. That initial scheduling concern is resolved at source level.
- `_fresh` disabled persistent distant targeting, while `_catch` immediately sent its single request outside reach before moving. The ordinary request path rejects an out-of-range request unless a separate predictive window applies; holding the rejected button does not resubmit it. The driver must choose and freeze either actual-reach-window then finite click, or the existing explicit persistent-target mode. An impossible driver request must not be attributed to candidate locomotion.
- The first `_catch` implementation used constant W+D, not the richer phase/braking feedback suggested by some policy metadata. Source/config/policy hash must describe the actual commands rather than an intended algorithm.
- The ground/grip-transition cell acquired both hands before starting its measurement. That does not measure WALK/REACH/ATTACH boundary continuity, even if the earlier setup logs mention the contacts. Start the transition observation before actual acquisition, or narrow the cell's claimed scope.
- Initial one-hand readiness was checked before an additional wait. Recheck the actual state at the measurement boundary and qualify swing work per observed support state; an earlier ungrounded sample cannot certify a later grounded interval as hanging.
- Generic positive-displacement completion is inappropriate for a legitimate retained catch or a build/counter maneuver ending near its origin. Keep signed progress raw, but define catch completion from actual target retention and define swing completion from its declared control task rather than imposing incidental straight-line progress.
- Whole-episode `capture.contacts/retained` included setup source grips. A failed destination catch could therefore still show100% whole-episode retention. Report destination selected/contact/retained separately from setup source retention. Leaving both hands attached is a two-support retention test, not proof the new hand alone carried incoming load.
- A unitless signed-work phase-match proxy should retain separate DRIVE/COUNTER windows and actual motion. Zero counter-work must not silently establish braking control. This quantity remains a technical work proxy, not human swing skill.

The implementing agents own resolution and runtime test receipts. The following final source review supersedes the earlier open source findings; it does not manufacture their execution results or an AT5 PASS.

## Final revision2 source review

**Source-contract acceptance: no remaining design/fixture blocker to the AT2 smoke and repeated-baseline gate.** This is qualified source review, not a claim that the seven tasks passed, that their measurements are sufficiently repeatable for search, that a tuning improved gameplay, or that held-out/human evaluation occurred.

Reviewed snapshot SHA256:

| File | SHA256 |
|---|---|
| `features/auto_tuning_lab/scripts/optimization_trial_driver.gd` | `6be346185e81785b75efea2483d3c2be604d0d0f7848ec175589261ba3e1e440` |
| `features/auto_tuning_lab/resources/train_scenarios.json` | `6e7657a9003aaa02bff194ae169971410afa9ffa1b168e6853f16cc01eeb0ace` |
| `features/auto_tuning_lab/scripts/response_metrics.gd` | `a4b92a0be9143559fbbc97277196c4376a38b010afef31ce928358d3595f3d8f` |
| `features/auto_tuning_lab/scripts/native_review.gd` | `957b4e7ef46f9575f201508a3656f5575bb20480733331220133daa48b488576` |

Resolved source semantics:

- Transition measurement begins before the actual walk and pointer acquisitions. The second-hand reach wait is an explicit declared state policy; it does not synthesize an attachment. Its policy/config must stay frozen during comparisons.
- One-hand readiness is checked at the measurement boundary after preparation. Initial observed configuration now records actual input/controller profiles, allocation, physical/B2 feet, targeting mode and hybrid ownership alongside poses, velocities, contacts, camera and bindings.
- Catch uses the existing explicit persistent-target feature, with pending zero-load safeguards. It checks both the selected request and eventual actual material point against the free shoulder recorded before pumping. Source release is explicit, and destination retention verifies the same anchor for.60s after source release. Catch completion no longer depends on incidental positive COM translation.
- Destination contact/retention has separate fields, and catch reliability uses destination retention rather than counting retained setup source grips as a successful catch. Aggregate setup counts remain visible as such.
- One-hand work and angle samples are qualified per frame by actual ungrounded attached support. A native-ground-contact latch disqualifies hanging completion; an end-only check no longer permits a land/relaunch shortcut. The goal requires unchanged real source anchor, a pendulum band of at least.10rad, positive DRIVE work and negative COUNTER work. The unitless proxy requires observed work in both phases and remains explicitly labelled a work/retention proxy, not human skill. Actual foot contribution still needs separate interpretation under B1.
- The pre-contact force check only rejects force while the target hand is REACHING. A legally ATTACHED hand is no longer falsely classified as an illegal pending support solely because it carries load.
- Lateral commands and the final release lie within the observation schedule. Response analysis uses accepted commands, the first stop/reversal rather than the best result, null for interrupted/unobserved outcomes and target-jerk derivatives only across the same anchor. It has no simulation authority.
- Native review uses a separate explicit scene, labels playback scripted, records monitor0 and bounds screenshots. It does not supply human ratings or overlay an already-running play world. The native entry itself does not implement the Python shortlist gate; before shortlist freeze use training requests only, and perform held-out native replay through the later frozen review procedure.

After this review, freeze source, geometry, goal definitions and input policies before the three baseline repeats and random search. A failed readiness condition or weak/noisy measurement is evidence to stop or restrict claims, not permission to repair losing candidates by moving supports, increasing authority or modifying the reference policy after search. Any source change after these hashes needs its own identity and an appropriate follow-up review.

**No optimizer was executed by this reviewer, and no held-out definition/outcome or study result was opened.** Actual120/60Hz smoke, baseline variance, invariants and native replay remain the main/physics agents' gates. AT6 remains genuine human evidence only, using the separate prepared protocol.
