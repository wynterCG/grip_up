# Benchmark qualification v1.3.3

**NO_GO_BENCHMARK — BQ1 canonical environment admission failed before gameplay.**

- [Full report](result_report.md) and [decision](decision.md).
- [Observed eligibility](eligibility_matrix.json), [planned run budget](run_plan.json), [first failure](first_divergences.json).
- [Metric contract](measurement_contract.md), [environment contract](environment_contract.md), [catalog](benchmark_catalog_v133.json), [dataset migration](dataset_migration.md).
- [Physics review](physics_specialist_review.md), [measurement review](specialist/BQ_measurement_review.md).
- [Verification](verification.json), [negative/control coverage](negative_controls.json), [evidence index](evidence_manifest.json).

The environment contract describes planned positive conditions; only one of12 positive preflights was attempted,11 and the wrong-size negative were NOT_RUN. No new catch/domain gameplay world was launched. Four pure diagnostics explain the launch-size failure without requalifying it. Normal startup,1146 old regression checks and release safety passed separately.

Executed commands: `python tools/benchmark_preflight.py` (rejects setup); `python tools/benchmark_diagnose.py` (four bounded diagnostics); `python tools/benchmark_safety.py export`; `python tools/benchmark_safety.py inspect-pack`; `python tools/benchmark_native.py start/inspect/runtime/restore` (each stage separately). These campaign paths are immutable; rerunning commands against used paths is intentionally rejected. Full commands and raw output are archived. No next campaign starts automatically.
