# Independent measurement review: R4 search stop

Decision: **NO_GO_MINIMAL_BENCHMARK for this optimizer study.** The actual pilot stopped correctly on an independent metric recomputation failure. No candidate is eligible for promotion. The earlier MB2 approval remains a historical approval of the observed qualification corpus and permission to attempt the bounded search; it is not a successful search outcome.

This addendum records offline review only. I launched no engine, changed no source, formula, tolerance, candidate, tape or initial signoff, and performed no replacement physics run. It supplements, rather than rewrites, `measurement_qualification_review.md` and `measurement_signoff.json`.

## Frozen scope and observed execution

The source snapshot is `cbe93f29aa2f6e47e4aa3fd784bbc1055cfa36bacaa385f7e07baa2bc262d54d`, commit `7d56a6db9f467df92cd002aee8494e98ae6399ee`. The quality contract SHA256 is `279f739e74674e11b695fb8e15592e883c680ebb9c8869c055b0629aeb5fb496`; the optimizer reference SHA256 is `052641575181462406011e9c7083d5df03072f9cbeadc29964c9d1205efeaf0c`.

Two sensitivity proposals were made. Four task/process slots were reserved, but only three optimizer engine processes actually launched:

| Proposal | Changed traversal speed | Actual tasks | Disposition |
|---|---:|---|---|
| `mbq_000_sensitivity` | 0.22 m/s | Vertical and Right, both `RUN_VALID` with `PRECONDITION_NOT_MET` | `REJECT_CANDIDATE`, objective values null |
| `mbq_001_sensitivity` | 0.28 m/s | Vertical only; Right never launched | `STOP_STUDY`, objective values null |

Other three parameters remained at the registered values: input ramp 0.12 s, target rate 0.24, target acceleration 0.9. The lower-speed proposal failed the frozen onset precondition. Its valid execution does not imply task success, and rejection without a manufactured score was appropriate.

For the upper-speed Vertical attempt `vertical_pull_clean_v134_r2_120_headless_r3_ff1cc7a7`, Godot exited normally and recorded the complete authorized interval, ticks 425–545 at 120 Hz. The adapter nevertheless classified the attempt `RUN_INVALID` with reason `INDEPENDENT_METRIC_RECOMPUTE:path3d_onset_to_end`. A `MEASURED` internal observation saved before this check does not override the invalid receipt or create an admissible objective.

`optimizer/pilot_report.json` records `global_stop=true`, `NO_GO_MINIMAL_BENCHMARK` and an empty shortlist. No random/TPE proposal, confirmation, finalist, protected candidate comparison, human acceptance or default promotion followed. Before search, the cumulative evaluation count was 40 processes: one earlier failed preflight, seven R4 preflights, 24 baseline and eight negative controls. With the three actual optimizer launches, it is 43. The fourth reservation is not an executed process. Ordinary safety regression processes remain a separate ledger.

## Independent arithmetic reconstruction

I inspected and reran the existing offline `diagnostics/arithmetic_probe.py` under both exact interpreters, then independently computed a packed segment digest from the captured COM rows. The input is the same existing `benchmark_audit.json`; no physical replay was involved. There are 121 COM points and 120 segments.

| Quantity | Value |
|---|---|
| Godot published 3D path | `0.2245515785359135`, `0x1.cbe1b2b09d8a6p-3` |
| Explicit ordered left fold, Python 3.11.15 and 3.13.13 | Exactly the Godot value |
| Builtin outer `sum`, Python 3.11.15 | Exactly the Godot value |
| Builtin outer `sum`, Python 3.13.13 | `0.22455157853591354`, `0x1.cbe1b2b09d8a7p-3` |
| Final difference | `+2.7755575615628914e-17` m, one binary64 ULP |
| Signed progress, both implementations | `0.21730303764343262` m |

Both versions produced identical per-segment square-root results. The SHA256 of all 120 segment values packed as little-endian binary64 is `2ef81c7306f293e5d7e22a7d9ad72c30997b9959920dca024e759ba20e8ca104` under both interpreters. Thus the observed discrepancy is isolated to the outer floating-point reduction for this captured trace, rather than a segment length or signed-progress difference.

The earliest unequal **offline accumulation prefix** ends at tick 439: ordered fold `0.0038754118399282078` (`0x1.fbf53e38d7fc5p-9`), Python 3.13 builtin sum `0.0038754118399282073` (`0x1.fbf53e38d7fc4p-9`). This is not an observed Godot prefix or a first physical divergence: Godot publishes only the final path summary. The actual published-channel discrepancy is the final summary for tick 545. There is no candidate H/R pair from which to infer cross-mode physical agreement or disagreement.

The source uses an explicit sequential `distance += sqrt(...)` in Godot and an outer builtin `sum(...)` in Python. Python documents that float summation changed in 3.12 to a more accurate algorithm on most builds. That documented change is consistent with the directly reproduced version-dependent reduction here. [Python 3.12 builtin `sum` documentation](https://docs.python.org/3.12/library/functions.html#sum).

## Qualification coverage and decision boundary

The baseline audit declares Python 3.13.13 as the intended optimizer environment. My earlier independent qualification recomputations used Python 3.11.15. The frozen Godot manifests and composite source identity do not themselves bind the outer Python executable/version and floating-point reduction semantics. I therefore distinguish the declared environment, the independently observed diagnostic interpreters, and the actual frozen raw qualification corpus; I do not infer undocumented qualification command provenance from the manifests.

The earlier 24 baseline runs, 28 strict baseline comparisons and eight negative controls remain historical evidence. Their successful corpus checks did not establish that builtin reduction would remain bit-identical to Godot on every future candidate trajectory under both interpreters. The search exposed that coverage limit. It does not retroactively invalidate the raw baseline measurements, and the original permission-to-search signoff is preserved byte for byte, SHA256 `ac30546aba1ee86793e1a602a90ed18ead5466d243381825054c9327be8c8762`.

The strict independent check correctly failed closed even though the discrepancy is numerically tiny. No epsilon, alternate summation, score rescue or post-outcome rerun is applied. The upper-speed raw progress is diagnostic evidence only; it cannot be promoted to a qualifying result. The failure is measurement arithmetic/comparability integrity, not evidence of a physical instability or a changed raw COM trajectory. The generic infrastructure-or-safety stop category does not establish a safety fault.

Any future repair requires a separately authorized, versioned measurement contract with explicit reduction order and interpreter identity, new frozen source and fresh qualification before further proposals. This review grants no continuation. The retained A0 gameplay defaults remain the only approved defaults; no search improvement, transfer, independent-start generalization or player-feel improvement is demonstrated.

## Evidence integrity

All paths below are relative to `builds/eval_virtual_cursor/minimal_v135_r4/`.

| Evidence | SHA256 |
|---|---|
| `attempts/vertical_pull_clean_v134_r2_120_headless_r3_ff1cc7a7/benchmark_audit.json` | `3f9248d21cb57862c029e7b20da3e104fc644067a8bb51f012beaaca5cdd7e7b` |
| Same attempt, `benchmark_runtime.json` | `77776d2b1dddf19d934386805a15e1a979f1e40f5e6910bd8ee9840cece9afc6` |
| `optimizer/pilot_report.json` | `067a76d85afb3141e140f3809c7d1798aef3e43ab604a51c117238c82b2a5af5` |

The offline reconstruction is also recorded in `diagnostics/arithmetic_probe.py`, `diagnostics/py311.json` and `diagnostics/py313.json`. The two segment digest checks in this review were executed independently against the same raw file with Python 3.11.15 and the pinned optimizer environment's Python 3.13.13. They do not count as additional engine episodes or a repaired qualification.
