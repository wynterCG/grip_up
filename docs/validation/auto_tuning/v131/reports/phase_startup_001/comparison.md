# Reliability diagnostics — measured receipts

Evaluations: 37. Execution statuses: `{'completed': 36, 'BLOCKED_TRACE': 1}`. Scenario rows: 127.

A completed evaluator is distinct from a successful catch or a valid fixture entry. No automated summary certifies search readiness.

| Scenario | Mode / Hz | Context | Trace / observer | Completed / observations | Signed progress mean ± sample SD (m) | Worst (m) |
|---|---|---|---|---:|---:|---:|
| asymmetric_pull_train | headless / 60 | sequence | True / True | 3 / 3 | 0.170296 ± 0.000000 | 0.170296 |
| asymmetric_pull_train | headless / 120 | sequence | True / True | 3 / 3 | 0.179050 ± 0.000000 | 0.179050 |
| asymmetric_pull_train | headless / 120 | sequence / historical | True / True | 3 / 3 | 0.179050 ± 0.000000 | 0.179050 |
| asymmetric_pull_train | rendered_scripted / 120 | sequence | True / True | 3 / 3 | 0.178829 ± 0.000044 | 0.178785 |
| asymmetric_pull_train | rendered_scripted / 120 | sequence / historical | True / True | 3 / 3 | 0.178757 ± 0.000074 | 0.178679 |
| foot_supported_step_train | headless / 60 | sequence | True / True | 3 / 3 | 0.250610 ± 0.000000 | 0.250610 |
| foot_supported_step_train | headless / 120 | sequence | True / True | 3 / 3 | 0.254619 ± 0.000000 | 0.254619 |
| foot_supported_step_train | headless / 120 | sequence / historical | True / True | 3 / 3 | 0.254619 ± 0.000000 | 0.254619 |
| foot_supported_step_train | rendered_scripted / 120 | sequence | True / True | 3 / 3 | 0.254717 ± 0.000092 | 0.254653 |
| foot_supported_step_train | rendered_scripted / 120 | sequence / historical | True / True | 3 / 3 | 0.254654 ± 0.000062 | 0.254612 |
| ground_grip_transition_train | headless / 60 | sequence | True / True | 3 / 3 | 0.240422 ± 0.000000 | 0.240422 |
| ground_grip_transition_train | headless / 120 | sequence | True / True | 3 / 3 | 0.208331 ± 0.000000 | 0.208331 |
| ground_grip_transition_train | headless / 120 | sequence / historical | True / True | 3 / 3 | 0.230444 ± 0.000000 | 0.230444 |
| ground_grip_transition_train | rendered_scripted / 120 | sequence | True / True | 3 / 3 | 0.208276 ± 0.000484 | 0.207721 |
| ground_grip_transition_train | rendered_scripted / 120 | sequence / historical | True / True | 3 / 3 | 0.231341 ± 0.001896 | 0.230047 |
| lateral_traverse_train | headless / 60 | sequence | True / True | 0 / 3 | -0.064759 ± 0.000000 | -0.064759 |
| lateral_traverse_train | headless / 120 | sequence | True / True | 0 / 3 | -0.066793 ± 0.000000 | -0.066793 |
| lateral_traverse_train | headless / 120 | sequence / historical | True / True | 0 / 3 | -0.066793 ± 0.000000 | -0.066793 |
| lateral_traverse_train | rendered_scripted / 120 | sequence | True / True | 0 / 3 | -0.066146 ± 0.000565 | -0.066780 |
| lateral_traverse_train | rendered_scripted / 120 | sequence / historical | True / True | 0 / 3 | -0.066608 ± 0.000895 | -0.067478 |
| one_hand_hang_train | headless / 60 | sequence | True / True | 3 / 3 | 0.100685 ± 0.000000 | 0.100685 |
| one_hand_hang_train | headless / 120 | sequence | True / True | 3 / 3 | -0.005668 ± 0.000000 | -0.005668 |
| one_hand_hang_train | headless / 120 | sequence / historical | True / True | 3 / 3 | -0.005668 ± 0.000000 | -0.005668 |
| one_hand_hang_train | rendered_scripted / 120 | sequence | True / True | 3 / 3 | 0.005978 ± 0.020090 | -0.005657 |
| one_hand_hang_train | rendered_scripted / 120 | sequence / historical | True / True | 3 / 3 | -0.005703 ± 0.000238 | -0.005978 |
| swing_catch_train | headless / 60 | isolated | False / False | 1 / 1 | 0.569523 ± null | 0.569523 |
| swing_catch_train | headless / 60 | isolated | False / True | 1 / 1 | 0.569523 ± null | 0.569523 |
| swing_catch_train | headless / 60 | isolated | True / True | 3 / 3 | 0.569523 ± 0.000000 | 0.569523 |
| swing_catch_train | headless / 60 | sequence | True / True | 3 / 3 | 0.634584 ± 0.000000 | 0.634584 |
| swing_catch_train | headless / 120 | isolated | False / False | 1 / 1 | 0.534190 ± null | 0.534190 |
| swing_catch_train | headless / 120 | isolated | False / True | 1 / 1 | 0.534190 ± null | 0.534190 |
| swing_catch_train | headless / 120 | isolated | True / True | 3 / 3 | 0.534190 ± 0.000000 | 0.534190 |
| swing_catch_train | headless / 120 | isolated / historical | True / True | 3 / 3 | 0.405552 ± 0.000000 | 0.405552 |
| swing_catch_train | headless / 120 | sequence | True / True | 3 / 3 | 0.535107 ± 0.000000 | 0.535107 |
| swing_catch_train | headless / 120 | sequence / historical | True / True | 3 / 3 | 0.405552 ± 0.000000 | 0.405552 |
| swing_catch_train | rendered_scripted / 60 | isolated | True / True | 0 / 1 | 0.000000 ± null | 0.000000 |
| swing_catch_train | rendered_scripted / 120 | isolated | False / False | 1 / 1 | 0.534034 ± null | 0.534034 |
| swing_catch_train | rendered_scripted / 120 | isolated | False / True | 1 / 1 | 0.534410 ± null | 0.534410 |
| swing_catch_train | rendered_scripted / 120 | isolated | True / True | 3 / 3 | 0.534081 ± 0.000381 | 0.533658 |
| swing_catch_train | rendered_scripted / 120 | isolated / historical | True / True | 2 / 3 | 0.337799 ± 0.126235 | 0.192164 |
| swing_catch_train | rendered_scripted / 120 | sequence | True / True | 3 / 3 | 0.534345 ± 0.000127 | 0.534200 |
| swing_catch_train | rendered_scripted / 120 | sequence / historical | True / True | 0 / 3 | 0.192168 ± 0.000024 | 0.192147 |
| vertical_pull_train | headless / 60 | sequence | True / True | 3 / 3 | 0.188316 ± 0.000000 | 0.188316 |
| vertical_pull_train | headless / 120 | sequence | True / True | 3 / 3 | 0.197991 ± 0.000000 | 0.197991 |
| vertical_pull_train | headless / 120 | sequence / historical | True / True | 3 / 3 | 0.198075 ± 0.000000 | 0.198075 |
| vertical_pull_train | rendered_scripted / 120 | sequence | True / True | 3 / 3 | 0.198026 ± 0.000403 | 0.197562 |
| vertical_pull_train | rendered_scripted / 120 | sequence / historical | True / True | 3 / 3 | 0.198165 ± 0.000083 | 0.198095 |

## Metric outcomes

`{}`

Null typed values are accompanied by status/reason. Raw partial paths and fixed-horizon displacements remain in each typed_metrics.json. Physical thresholds and a future scoring rubric are separate.

Same-Hz catch comparisons use the same declared phases and stable material identity. Differences are localized at serialization-scale sensitivity, not judged against a fabricated universal millimetre tolerance. Different-Hz trajectories are summarized separately.

Consult the signed specialist review and final decision for setup validity, observer effects, blocked fixtures and remaining causal uncertainty.
