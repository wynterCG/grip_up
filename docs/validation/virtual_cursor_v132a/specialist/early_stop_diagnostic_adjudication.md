# Independent adjudication of the first frozen replay failure

Date: 2026-10-20. Read-only review; no engine execution or source edits by the specialist.

## Observed failure and permitted conclusions

The frozen source captures under `builds/eval_virtual_cursor/frozen_capture_r1` have actual real loaded captures and same-anchor retention:

| Hz | Contact tick | Source FREE | Retained tick | Request distance / reach | Selected destination normal |
|---|---:|---:|---:|---|---|
| 120 | 440 | 455 | 527 | 0.814921677 / 0.65708 m | `[0,-1,0]` |
| 60 | 215 | 223 | 259 | 0.807716429 / 0.65708 m | `[0,-1,0]` |

These are **source captures**, not repetitions proving playback. They retain B1/ground contributions and do not establish an arm-only task.

The first qualification attempt, `qualification_r1/attempts/V0-H_120_r1_c56d2f29`, has engine status `BLOCKED_SETUP`, reason `INPUT_BUTTON_EDGE`, and **zero scenario rows**. No world/physical replay result exists for that attempt. It is a real qualification failure of serialized frame validation, not a Jolt divergence, selected-face failure or actual capture miss.

The identified source cause is numeric representation at the JSON boundary: a legitimate hand index serialized and parsed as `0.0` was rejected by membership in the integer array `[0,1]`. The subsequent validation checks numeric type, finiteness and exact integrality before converting the hand index; fractional hand IDs remain invalid. This preserves the intended discrete action semantics and does not authorize a target, increase reach, change body state or alter the force solver.

The frozen qualification remains **NO_GO_INPUT_REPLAY**. A source correction and passing parser units do not turn that failed attempt into a pass or justify silently restarting the 24-run matrix.

## Derived diagnostic tape provenance

The proposed diagnostic derivation is acceptable **only as separately identified diagnostic evidence**, with all of the following:

1. Original frozen tape bytes, file hash, capture manifest hash and capture-source hash map remain unchanged and recoverable.
2. The derived artifact has its own file hash, explicit `diagnostic_only:true`, parent tape identity and reason for derivation. Frame/reference contents are preserved except any prospectively declared negative manipulation, which must be identified as such.
3. Original `capture_source_hashes` and new replay-runtime source hashes are separate fields. Never replace the historical capture identity with the new runtime identity while implying they were identical.
4. A per-file approved source delta, including old/new hashes, identifies the JSON-validation/guard change. It is not a generic wildcard permitting any later source update.
5. Python and Godot reject the derived tape for ordinary capture/qualification or without the explicit negative/diagnostic case. No automatic fallback permits ordinary qualification to use it.
6. The result states source compatibility is an audited **diagnostic hypothesis**, not measured physical equivalence. Even an exact observed replay cannot approve a new qualification baseline or continuous envelope.
7. No new source capture is fabricated, no old capture result is retagged and no outcome is promoted. Additional diagnostics retain their own failures.

This permits a direct engine check of the repaired JSON edge path against preserved source frames, without claiming a new frozen qualification run.

## The four-run allowance is not permission for unrelated downstream tests

Spec section8.1 and the prospective protocol require that, after a hard input/picking gate failure, only diagnostics directly related to that gate continue. The maximum of four is a ceiling, not a requirement to spend four runs or an exemption for all previously named negatives.

Here, **N1 JSON round-trip / integral edge validation / ordered press-release dispatch** directly diagnoses the gate. A bounded variant checking numeric wheel representation would likewise be directly related to the repaired serialized numeric contract.

N2 silhouette/camera selection, N3 hardware noninterference and N4 in-flight abort are important required capabilities, but they are downstream of the failed pre-world JSON gate and do not independently diagnose why that frame was rejected. Their pre-existing names do not by themselves make them directly relevant. The independent recommendation is therefore to run only the direct N1 diagnostic (or explicitly related numeric-contract variants) and leave N2–N4 **NOT_RUN_EARLY_STOP / INCOMPLETE_COVERAGE** under this qualification.

No broad physical safety regression rerun or supplementary operational restoration should be counted as completing these missing qualification cells. The final decision remains NO_GO_INPUT_REPLAY, with the narrower conclusion that the parser repair was diagnosed if the permitted direct diagnostic succeeds. Input isolation, real user mouse/window disturbance, rendered picking equivalence and background scheduling remain unqualified until separately authorized and measured.
