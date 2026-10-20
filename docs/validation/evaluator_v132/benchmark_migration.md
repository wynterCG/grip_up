# Benchmark migration

`benchmark_eval_v132` revision1 has separate R0 requested-input replay and A
adaptive-policy identities. It cannot be pooled with v13 or v131 scores.
Historical catalogs, formulas, catch/control receipts and all failures remain
unchanged; no old result is backfilled with a new success status.

New `metric_catalog_v132.json` versions full-norm settling and 3D stopping path
separately from **directed-speed** active-brake fractions. v131 used full speed
norm for those fractions: its parser and outputs remain explicit legacy
diagnostics, not silently relabelled v132 numbers. Independent Python reads raw
phase-tagged traces and checks the new GDScript runtime fields.

No aggregate reward is enabled. The score formula ID is
`DISABLED_NO_AGGREGATE_SCORE_v1`; its SHA256 and the actual metric implementation
hashes are recorded in verification. A future study requires a separately frozen
eligible scenario/metric contract and specialist-approved per-mode/Hz envelopes
before candidate results. An input identity epsilon is not such an envelope.

Release, opposite braking, reversal, passive settling, signed drift, full path
and onset-reference excursion retain distinct meanings. Unknown or interrupted
measurements remain null with typed statuses. Ground/support interruption cannot
erase an earlier valid milestone, nor authorize subsequent climbing credit.

Private holdouts remain sealed. No optimizer, sensitivity study, RL, Jev, M7 or
candidate promotion is authorized or executed by this migration.
