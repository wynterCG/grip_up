# v1.3 physics review - frozen evaluator candidate

## Scope and decision

This is offline experimental infrastructure only. Existing production controllers, tuning defaults, body mass, collision geometry, spring K/D, reach, grip strength and torque/force caps are unchanged. The normal application still starts in profile 2. Trials explicitly select profile 4 / A0 / B1. There is no automatic adoption, RL or claim of human enjoyment.

Final training tape is train_tape_r3, revision 3. Six of seven physical task goals pass at both frequencies; the remaining airborne lateral challenge is VALID but has negative signed progress. This is deliberately not repaired by changing the tape, geometry or actuator until it passes. The earlier r2 apparent lateral success was walking contamination and is historical failed benchmark evidence, not a climbing gain.

## Approved four parameters

| Actual ClimbingTuning field | Baseline | Bounds | Units |
|---|---:|---:|---|
| `traversal_speed_m_s` | 0.25 | 0.18..0.32 | m/s |
| `traversal_input_ramp_s` | 0.12 | 0.07..0.2 | s |
| `traversal_target_max_rate` | 0.24 | 0.16..0.3 | m/s |
| `traversal_target_max_acceleration` | 0.9 | 0.6..1.2 | m/s^2 |

They only parameterize existing intent/planner code. The other two proposed fields remain frozen: plan acceleration 1 m/s2 and prediction .18 s. Planner offset remains .055 m. A conservative first-search coupling requires target_rate^2/(2*target_acceleration)<=.055; the input ramp spans at least four 60 Hz ticks. This does not prove that all excluded combinations are intrinsically unstable.

Frozen mechanics: body 12 kg; acquisition R=.65708 m; spring 6000 N/m and 220 Ns/m; shared hand sum <=360 N; feet <=180 N total and <=120 N per foot; shared assistance <=20 Nm; combined ground/climb moment <=150 Nm. Post-budget runtime samples check these limits, finite body/force state, legal actual anchors, zero pending force, no unsupported air actuator and no hybrid/dynamic ownership conflict. Feet require SUPPORTING/SLIDING, unilateral compression and the existing friction cone. Protected mechanical fields and actual overrides are rechecked, not inferred from never-updated flags.

The direct_body_transform_mutation invariant has an explicit STATIC AUDIT / whitelist / source-identity enforcement scope. It is not a runtime interceptor for every transform assignment. Explicit fixture placement/initial velocity before the first simulation tick and the authorized hybrid kinematic phase remain separately named. Existing hand/support wrench approximations are unchanged; the auto-tuner does not make their effective mass model exact.

## Manifest, resource and lifecycle contract

- Full four-field overrides; unknown fields, partial sets, bool/string/nonfinite values, range/coupling/precision/hash errors rejected. Candidate identity is recomputed from sorted fixed-eight-decimal canonical values.
- Every listed source hash is independently read before/after. The Python parent additionally enforces the full dependency closure and Git/binary identity. Caller Git metadata alone is not presented as an independent Godot Git observation.
- Actual engine executable SHA and input_trace_id matching the selected catalog are enforced BEFORE creating the trial Lab. Unknown implementations/scenarios reject rather than score zero effort.
- TrialLab duplicates the tuning Resource, installs synchronously after configure but BEFORE any physics step, and restores the exact original Resource identity. These four fields are not consumed to construct geometry in configure. Normal startup profile 2 and physics Hz are restored.
- Each result row includes actual overrides/install records; initial COM/body pose/velocities, camera/FOV/viewport, bindings and observed configuration flags are saved. Native playback uses an explicitly requested isolated world; no startup behavior is added to gameplay.
- Source and result writes are local research output. No saved default tuning/resource is overwritten.

## Training policies and task semantics

All inputs use ordinary Godot actions and actual pointer/button events. No candidate-dependent planner, force, pose correction, extra reach or fake contact exists. Each scenario creates a fresh Lab/world; multiple scenes within the same process do not restart Jolt internals, so fixed scenario order/process context is part of provenance.

Vertical/asymmetric and Step tasks intentionally begin on the floor: they measure pull/foot support transitions, not arm-only hanging. Ground-grip transition begins with no hands, walks D .10 s, clicks L, holds W while waiting at most 1 s for the R shoulder to reach the fixed wall at Y2.1/Z0 with R-.02 margin, then clicks R ONCE at its current shoulder X. The wait is a declared candidate-independent state policy and is included in measured latency.

Airborne lateral first holds W1.5 s, then neutral preparation, and must have real loaded two-hand support with grounded=false at onset. Measured D .35 / neutral .10 / A .25 / neutral .50 is unchanged from r2. ANY ground contact or actual native motor force/moment invalidates the measured task; rank progress is null with NATIVE_GROUND_CONTAMINATED while raw signed movement remains archived. An anatomically valid negative result remains GOAL_NOT_REACHED, not invalid preparation.

One-hand goal is supported swing, not positive net translation: same source anchor throughout, no native grounded sample, pendulum band >=.1 rad and observed positive DRIVE / negative COUNTER work. B1 feet remain active and contribute substantial load: this is NOT an arm-only pendulum. Only nongrounded samples with actual attached support qualify angle/work.

Catch reuses unchanged Mastery C geometry. It requests one persistent zero-load target before the real reach window, then uses the declared angular phase A/D policy. The EVENTUAL actual material anchor must be outside the pre-swing free shoulder R+.02, source is released, and the SAME destination anchor must remain ATTACHED for .6 s. Contact and retention are separate; setup source contacts do not masquerade as destination reliability. PENDING force is only diagnosed while actually REACHING, never from a legitimate already-attached load.

## Final pre-search smoke evidence

| Task | Baseline signed COM 120 / 60 Hz (m) | Known speed .26 override 120 / 60 (m) | Goal |
|---|---:|---:|---|
| vertical_pull_train | 0.19808 / 0.18777 | 0.20262 / 0.19219 | PASS |
| asymmetric_pull_train | 0.17905 / 0.17030 | 0.18143 / 0.17453 | PASS |
| lateral_traverse_train | -0.06679 / -0.06476 | -0.07246 / -0.06085 | GOAL_NOT_REACHED |
| one_hand_hang_train | -0.00567 / 0.10068 | -0.00580 / 0.13140 | PASS |
| swing_catch_train | 0.40555 / 0.67646 | 0.40206 / 0.69751 | PASS |
| foot_supported_step_train | 0.25462 / 0.25061 | 0.25582 / 0.25191 | PASS |
| ground_grip_transition_train | 0.23044 / 0.19288 | 0.23214 / 0.19544 | PASS |

All hard invariant flags false in these six baseline/known-override/safety runs. All source-after and restoration/pre-step guards pass. The known override is a transport/paired-evaluation check, NOT a selected tuning. It produces mixed effects, including worse lateral progress at 120 Hz. No stochastic search outcome has been seen here.

Airborne lateral baseline retains both original anchors and has zero native ground force/moment in the measured window at both frequencies. Its signed progress is -.066793 / -.064759 m. The W preparation leaves a natural leftward pendular phase; the short D phase does not overcome it before the explicit counter-command. Do not relabel negative motion as successful right traversal.

One-hand baseline: pendulum band .11541 / .11855 rad, phase-match proxy .58174 / .66254. DRIVE positive +2.48539 / +2.32029 J; COUNTER negative -.001196 / -.092623 J, but also COUNTER positive +1.78748 / +1.15213 J. Thus the proxy does NOT establish strong or universal braking. Actual loaded-foot fractions .70 / 1.00, native grounded false. Catch foot peak 45.67 /39.52 N, same destination retained .6 s after source release in both.

Stop distance remains null when the first stop is interrupted or never continuously slow for .25 s. Raw reasons are retained. Latency uses accepted coordinator input, not hardware latency. Twist is axial support-relative; pendular roll is not indiscriminately penalized. Target jerk is an acceleration derivative only across unchanged real anchors. Body acceleration includes gravity/contacts; collision-clean jerk is unknown. Partial contact work excludes ground and torque work; separately reported ground motor body work uses actual central force/velocity and torque/angular velocity. No total-energy conservation claim is inferred.

## Public safety and private final validation infrastructure

Public safety registry has four cases and passes 4/4 at 120 and 60 Hz: unsupported airborne intent, exact persistent pending/cancel, actual feet-OFF zero leg load, and two real higher handoffs with continuous old support/caps. The pending case uses profile 3 intentionally: profile 4 now resolves an anatomically reachable contact on the same wall, so treating that legitimate new contact as pending would be a benchmark bug. The airborne case has explicit pre-simulation placement and short warmup to keep gravity from landing during its observation window.

Private registry has nine versioned cases: actual changed grip spacing; actual camera/initial velocity; near-R contact; physically mirrored Mastery A/B including hand/index remap; two-stage Step; existing reactive beam; exact known A1 asymmetric-diagonal capsule canary paired A0/A1; continuous First Ascent. Its bytes are excluded from training dependency manifests and opened only on holdout dispatch after the parent shortlist freeze guard. Only catalog schema and parser checks were run before shortlist: NO HELDOUT OUTCOMES OR BENEFITS ARE CLAIMED.

The A1 canary copies test_capture_matrix.setup + test_locomotion_allocation.prepare(asymmetric): left offset(-.10,.42,-.35), right(.10,.20,-.35), input(.7,1), unchanged 12 kg capsule/support geometry. It is a negative control, not a training reward or a full humanoid route. Dynamic beam is a reaction/material tracking regression, not new M7 behavior or an isolated momentum conservation proof (hinge/gravity are external).

First Ascent uses the unchanged existing input/reach-window exercise through an injectable TrialLab. Controller metrics close on first assisted ownership and never bridge cached hybrid observer poses. Full mixed-route rank progress/work are null. Wrapper phase paths read ACTUAL direct-state COM every physics frame; dynamic and kinematic phases stay separate. Completion still requires the existing route, safe hybrid native ground, hands free, .30 m real walk and no assisted ownership.

## Tests, failures and what remains unproven

Loader unit: 30/30 in two invocations at fixed-fps120/60 (pure logic, not extra physical-frequency coverage). Trial contract: 13/13 validates versioned split catalogs and rejects mismatched trace, engine hash and unknown scenario without constructing Lab or changing Hz. Parent response metrics unit: 17/17 (root-owned). Full seven-cell r3 baselines/known override plus four-cell safety were run at both physics rates. There is no claim that all seven baseline task goals pass: 6/7 do.

Development receipts preserve r1/r2 failures, wrong-JSON-Hz setup error and benchmark contamination. Initial r1 lateral D1 s lost all grips; r2 +.448 m apparent traversal was grounded walking. The first ground click policy attempted a real .683 m shoulder distance after walking yaw, beyond R. A first safety pending attempt accidentally allowed profile4 same-surface clamping, and a long air warmup landed naturally. These were corrected as benchmark validity issues BEFORE search; no force/geometry/goal tuning repaired genuine negative r3 lateral performance.

Final source changed after the paired smoke only to restore the exact ORIGINAL heldout A1 canary offsets/input discovered by source audit; this private path was not executed by the public smoke. Parse/catalog checks follow that correction. Parent must refresh full source/Git manifests after committing infrastructure, then run baseline repetitions/holdout/native gates. Old candidate/result maps remain immutable evidence of the exact versions they ran.

The headless CA certificate-store warning is an engine environment warning, not SCRIPT ERROR or a task failure. Hardware timing, human ratings, enjoyment, final candidate generalization and long-run numerical asymptotics remain unproven. Defaults remain untouched.

## Frozen source hashes

| File | SHA256 |
|---|---|
| `features/auto_tuning_lab/scripts/first_ascent_trial_exercise.gd` | `6b23505074358a51d32f2d9edf2c29378e04e77419b947b0a59597e9409eb8a4` |
| `features/auto_tuning_lab/scripts/native_review.gd` | `957b4e7ef46f9575f201508a3656f5575bb20480733331220133daa48b488576` |
| `features/auto_tuning_lab/scripts/optimization_canary_fixture.gd` | `2306644b8bf5d93a223d0f8694a29a31c62375281b6aea3a4322fa400019c7e7` |
| `features/auto_tuning_lab/scripts/optimization_override_loader.gd` | `06f35943e1c83a25fa9f65c5452bb4f1eaf11c42f218021758c1628a3d57fc2c` |
| `features/auto_tuning_lab/scripts/optimization_trial_driver.gd` | `19d2f0b93cbf3501dfd05c02d0d46da958cde3307c62b015db254a978f6b2713` |
| `features/auto_tuning_lab/scripts/optimization_trial_lab.gd` | `df67368c3c75d36d4d7242219ec9b690f121a6e259bbaf1a1f6742b558b51316` |
| `features/auto_tuning_lab/scripts/optimization_trial_runner.gd` | `05444b1fdd99f386eb95285143f759e03b25519e55cb720c9293794e14b3e55f` |
| `features/auto_tuning_lab/scripts/response_metrics.gd` | `a4b92a0be9143559fbbc97277196c4376a38b010afef31ce928358d3595f3d8f` |
| `features/auto_tuning_lab/resources/parameter_space.json` | `aec7e3be5e22fa9185cedc1e0e9bd1bfbf8d101205da69d732294e072a959e2b` |
| `features/auto_tuning_lab/resources/safety_scenarios.json` | `da94bb4fc6c853738db83d79c8d7b773b42f0ebe417b1a0b8e146bf2a195615e` |
| `features/auto_tuning_lab/resources/train_scenarios.json` | `67c9af636ba97c55846e86d8992e46ed04d2bcdb2153ec9b23dfe1161f25c553` |
| `features/auto_tuning_lab/tests/test_override_loader.gd` | `88471762b4c7dc79e09f9ce27b7b1a8ba1ea217326d08e5bb49ffc9f997a1c4f` |
| `features/auto_tuning_lab/tests/test_response_metrics.gd` | `96cced85e5ed7e5e2bf8a74a50ff2dc38f45f2dcc709a6b8d67c268544b95e91` |
| `features/auto_tuning_lab/tests/test_trial_contract.gd` | `4685a03ae1f647a4255f765145a70c02514a4cecd3c3beb741179855c3c6080b` |

Private definition SHA is kept in the private validation provenance after shortlist; the optimizer does not receive its contents. Public smoke receipts are under baseline_smoke/, earlier attempts under development/. No production source was edited by this specialist.

## Narrow FirstAscent timeout contract fix

The exercise-owned tick loop now calls a shared deadline predicate which latches driver.cancelled on wall expiry. The existing final run_trial classification consequently returns timed_out rather than completed plus an aborted failed_task. Unexpired deadlines and invariant-triggered aborts retain their distinct behavior. No gameplay, route, fixture or tuning changed.

Focused test_trial_timeout.gd: 11/11 at 120 and 60 configured Hz. It exercises the REAL FirstAscent wrapper pre-tick callback and REAL trial status/cleanup path with an expired test wall clock; zero route physics frames advance, no Lab/body or withheld performance outcome is constructed. It checks explicit ABORTED scenario evidence, no Resource binding residue, Hz restoration and unchanged listed source provenance. This is a cancellation contract test, not a successful FirstAscent holdout run.

Final changed source hashes:
- optimization_trial_driver.gd: `19d2f0b93cbf3501dfd05c02d0d46da958cde3307c62b015db254a978f6b2713`
- test_trial_timeout.gd: `46f97c147119682dc3d8bf19a37aef5062e3c1a0e91525f98daf1032591629e8`

Root independently fixed Python transport so a validated nonzero-exit timed_out result is preserved; the specialist did not edit Python. Full observed manifests must be refreshed after this code change.
