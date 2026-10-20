# v1.3.3 R2 qualification repeat

**NO_GO_BENCHMARK primary campaign.** Canonical BQ1 passed; the first reference replay was falsely rejected by a JSON-array type comparison before any world existed. The correction is verified by a16-check contract and one supplementary H/R120 physical pair. These diagnostics do not fill missing primary coverage.

[Report](result_report.md) · [Decision](decision.md) · [Matrix](eligibility_matrix.json) · [Verification](verification.json) · [First failure and raw comparison](first_divergences.json) · [Physics review](specialist/final_physics_review.md) · [Measurement review](specialist/measurement_review.md) · [Evidence](evidence_manifest.json).

Run plan and immutable commands: `python tools/benchmark_repeat.py prepare`, `freeze`, `preflight`, `reference` (separate stages); `domains` was NOT_RUN. `python tools/benchmark_repeat_diagnostics.py` preserved its failed D1, then `--finish` used the three remaining slots. Used paths intentionally reject repetition. No automatic next campaign or optimizer.
