# GRIP UP v1.3.3 R2 — decision

- Baseline/source preservation: PASS;1146 fresh regression checks.
- BQ1 canonical backing/clock: PASS;12 positive processes plus1 correct wrong-size rejection.
- BQ2 primary catch reference: REJECTED_SETUP on first H120;0 qualified pairs,11 reference processes not run.
- Vertical/asymmetric/clean lateral L/R: MISSING_COVERAGE at60/120Hz.
- Foot-step/two-hand stop: NOT_RUN; diagnostic-only n1 plan excludes ranking. One-hand60Hz remains OPEN.
- Cause: JSON float-array compared with integer-array before startup; no primary body/tick existed.
- Correction: exact numeric scalar validation, with nonnumeric dimensions rejected;16-check contract passes.
- Supplementary: one fixed H/R120 pair strictly matches complete published precision channels and retains actual catch. It is diagnostic, n1, no60Hz coverage; legacy scalar/Vector2 representation difference remains explicitly recorded.
- Final verdict: **NO_GO_BENCHMARK** for the frozen R2 primary campaign.
- Private outcomes/search/RL/Jev/human playtests:0. No gameplay defaults promoted.
- Next action: keep source fix and evidence; no automatic R3 or optimizer. A separately authorized fresh campaign must redo primary admission/reference with the corrected source.
