# Auto-tuning technical comparison

Study status: **stopped**. reproduced essential regression: lost baseline task completion: swing_catch_train

Candidate trials: 2; baseline repeats: 3. All archived evaluation statuses: `{'completed': 6}`.

No candidate is promoted. Human A/B sessions: **0**. The screen cannot establish preferred game feel or global optimality.

![Four objective Pareto projections](pareto.png)

## Pareto archive (training only)

| Candidate | Progress | Precision | Physical quality | Reliability | Practical screening gain |
|---|---:|---:|---:|---:|---|
| e8941a99a5f7 | -1.2963 | -1.3699 | -1.4435 | 0.0000 | False |
| d2b9bedb66c9 | -1.9039 | -1.1111 | -0.8151 | -10.0000 | False |

## Baseline distributions

The CSV retains every raw scenario metric and each failed task. Null means unavailable; it is not a zero or successful completion.

| Scenario | Completed / attempts | Useful progress mean ± sample SD (m) | Worst (m) |
|---|---:|---:|---:|
| asymmetric_pull_train | 3 / 3 | 0.179050445556641 ± 0.0 | 0.179050445556641 |
| foot_supported_step_train | 3 / 3 | 0.254619359970093 ± 0.0 | 0.254619359970093 |
| ground_grip_transition_train | 3 / 3 | 0.230443716049194 ± 0.0 | 0.230443716049194 |
| lateral_traverse_train | 0 / 3 | -0.0667930245399475 ± 0.0 | -0.0667930245399475 |
| one_hand_hang_train | 3 / 3 | -0.00566786527633667 ± 0.0 | -0.00566786527633667 |
| swing_catch_train | 3 / 3 | 0.405551582574844 ± 0.0 | 0.405551582574844 |
| vertical_pull_train | 3 / 3 | 0.198075294494629 ± 0.0 | 0.198075294494629 |

## Interpretation limits

Objectives are predeclared screening gains scaled by practical floors and measured baseline variability. They are not a validated utility function for fun. Axial twist is evaluated on directed tasks; useful swing has its own phase/work/retention measure. Runtime and safety failures receive no objective value.

A negative pilot means no supported gain under this particular screen and budget. It does not prove that A0 is globally optimal. Held-out evidence is evaluated separately only after a repeated-valid shortlist is frozen. The main project report records native playback, regression coverage and the human review gate.
