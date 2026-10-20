# v1.3.3 measurement contract, revision 1

This is a prospective measurement definition, not a qualification result. The Python API is `tools/auto_tuning/benchmark_qualification/metrics.py:summarize(ticks, definition, onset_certificate)`. It never writes gameplay state or computes an optimizer score. Its synthetic tests are evaluator evidence, not climbing or human-feel evidence.

## Observations and onset

Inputs are published `PhysicsSnapshot` rows with the existing physics metadata. Select `post_control` rows only; the phase is after application callbacks and before the next integration, not a newly invented post-solver callback. PRE observations may coexist but cannot fill missing POST ticks. Validate 60/120 Hz, consecutive integer ticks, finite direct COM/linear/angular velocity, fixed delta and timestamp, actual support flags, hand identities, foot forces and native ground authority. An absent field is not a zero.

`definition` declares `id`, `kind` (`progress` or `release_stop`), `direction_world`, `observe_s`, `physical_feet` and `require_foot_load`. The unit axis is fixed at onset from the real wall/support frame. Mirrored tasks reverse their physical setup and axis together. This campaign uses stationary supports; published COM progress/path are in world coordinates. Moving-support qualification remains outside scope.

`onset_certificate` contains `onset_tick`, optional `end_tick`, `reason_code`, and `certificate`. Its certificate must be the complete recorded POST row at the onset tick, not an approximate reconstructed state. Both hands must actually be ATTACHED to retained nonzero anchors with aggregate load above 1 N; native ground walking, hybrid authority and ground motor force/torque are excluded. A required foot onset needs real compressive force above 1 N and valid foot support. Progress independently checks the full 0.25 s quiet interval ending on the preceding tick, plus the accepted onset tick: absolute support-relative directed speed <=0.10 m/s, full angular speed <=0.20 rad/s, continuous loaded legal dual-hand support, and any required actual foot load. This lateral clean band does not silently require full linear speed <=0.10 m/s. Release stopping independently requires actually accepted neutral intent and support-relative directed onset speed in [0.15,0.50] m/s. The driver also proves preparation, camera, anchor legality and environment; a single snapshot or trusted capture log cannot substitute for the raw prior dwell.

No onset returns `PRECONDITION_NOT_MET`, with null values. A later hand/anchor loss, native ground authority or hybrid interval interrupts the authorized window. When published, conservative `ground_clearance_status` must be `CLEAR_QUERIED_SEGMENT`, both at onset/quiet preparation and during the measured interval; an uncertain ground sweep is not evidence of safe absence. End means the last authorized POST row before the event; provenance retains the interrupting tick. Missing data or a truncated episode is `INVALID_MEASUREMENT`, not a failed climb or a completed timeout. Supplied `end_tick` must agree with this end; null allows independent determination.

## Typed metric families

Every value has exactly one of `MEASURED`, `CENSORED_TIMEOUT`, `INTERRUPTED`, `PRECONDITION_NOT_MET`, `INVALID_MEASUREMENT`, `NOT_APPLICABLE`, plus `reason_code`, `onset_tick`, `end_tick`, unit and event provenance. Every non-measured value stays null. Twelve specification table families produce thirteen IDs because catch completion and retention are separate quantities.

| ID | Definition and qualification boundary |
| --- | --- |
| `signed_progress_m` | Unit requested axis dot (end COM minus onset COM), over the complete fixed authorized horizon. Negative is opposite movement. Interrupted observations remain null in the typed metric. |
| `latency_to_useful_motion_s` | Time from accepted onset to the beginning of a sustained interval with signed linear velocity strictly greater than 0.02 m/s for at least 0.05 s. If the preceding POST tick already has signed useful velocity >0.02 m/s, return `PRECONDITION_NOT_MET`, null, `ALREADY_MOVING_BEFORE_ONSET`; preserve observed useful-event ticks and raw progress, without awarding zero response latency. Equality at 0.02 does not meet the useful-velocity criterion. Defined for progress tasks; never hardware latency or proof of causality. |
| `directional_efficiency` | Signed progress divided by the integrated 3D COM path over the same complete horizon. Path must exceed 1e-6 m; otherwise precondition not met, not zero efficiency. |
| `overshoot_after_release_m` | Maximum nonnegative signed excursion after the actual neutral onset until confirmed settling, using onset as the spatial reference. Active commanded travel before release is excluded. |
| `stop_path_3d_m` | Integrated 3D COM path from neutral onset THROUGH the confirming tick of the first continuously settled interval. This is neither final drift nor the path merely to the first quiet tick. |
| `settling_time_s` | Time from neutral onset to the start of the first interval satisfying full relative speed <= 0.10 m/s and full relative angular speed <= 0.20 rad/s continuously for at least 0.25 s. Later interruptions preserve an already confirmed metric. |
| `brake_fraction_reached` | Not applicable to these progress/release tasks. Active braking requires a separate prospective active-command window and directed-speed definition. |
| `reversal_time_s` | Not applicable to these tasks. Do not manufacture a reversal from final displacement. |
| `catch_success`, `retention_s` | Not applicable to these tasks. The existing catch driver remains the authority for real contact/retention, independently of trajectory equivalence. |
| `foot_load_contribution` | Integrated actual compressive foot load divided by that impulse plus integrated positive world-up hand traction, using uniform POST intervals. Requires B1 and nonzero observed denominator; its exact directional/load scope is reported and must not be called whole-system energy or native-ground impulse. |
| `twist_rms_rad` | Uniform-tick RMS of a supplied support-relative twist only when every sample declares its frame valid. Otherwise not applicable; no body Euler angle is silently substituted. Diagnostic, not a blanket rotation penalty. |
| `hard_physical_violations` | Observed pending/free hand force and published hand/foot/torque-cap violations, with tick/reason identities. This is a limited independent readback; the existing driver's invariants remain hard gates for geometry, contacts, source ownership and unauthorized writes. |

Stop calculations reuse `metric_contracts.analyze` without changing its historical formulas. Its stop path includes the confirmation interval. The historical v132 `stop_path_m`, which ends at the start of settling, retains its separate identity and must not be aliased to the new metric. Legacy full-speed braking remains separate from any directed active-braking formula. Existing narrow limit-monitor allowances are retained: 360.001 N shared hands, 180.001 N total feet, 120.001 N per foot, 20.001 Nm assistance and 150.001 Nm combined climbing moment. These are reporting allowances, not widened actuator limits.

The top-level `signed_progress_m` and `path3d_onset_to_end` are independent observed-window diagnostics for recomputing the driver summary, including partial windows. They are not typed ranking values and must not replace a null interrupted metric. Python recomputation operates on published coordinates with Python floating arithmetic; arithmetic-only summary rounding must be distinguished from the strict trace comparison, which permits no blanket physical tolerance.

## Eligibility and separation

`task_succeeded` is separate from trace validity and metric availability. Progress requires a completed legal positive signed window; release stopping requires confirmed settling. This evaluator always returns `ranking_eligible=false`: only the campaign's environment, onset, negatives, required-channel replay and replication gates can promote a named domain.

`required_cells_complete` is a synthetic null-safe canary, not an optimizer objective. A required missing or non-measured cell produces no worst value. A weak asymmetric A1 cell remains in the denominator; removing it must reject the comparison. No aggregate score, practical improvement floor, weights or global A0/A1 superiority claim is authorized here.

Fixed virtual tapes must be compared against the same tape at equal physical ticks, within frequency and backing stratum. Adaptive preparation/policies retain their own lane and accepted output traces; their feedback commands cannot be relabelled as immutable fixed input. Identical seeds establish local repeats only. No scripted data is a human playtest, and no private holdout outcomes are read.

## Contract verification

Run `python -m unittest discover -s tools/auto_tuning/benchmark_qualification/tests -p test_metrics.py -v`. Synthetic tests cover all six statuses, both frequencies, onset identity, interruption boundaries, preserved earlier settling, 3D stop path through confirmation, full speed/spin, useful-velocity dwell, mirrored/negative progress, zero path, loaded feet, force caps, missing/bad ticks and a null-safe worst-cell A0/A1 canary. Existing typed stop tests remain reusable for braking/reversal behavior outside this task subset. Contract tests do not launch a physics world.
