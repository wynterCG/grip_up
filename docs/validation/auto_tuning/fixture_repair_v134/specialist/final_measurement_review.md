# v1.3.4 final measurement review

Status: **FINAL MEASUREMENT REVIEW COMPLETE — FEASIBILITY_NO_GO**. The integration worker confirmed FINAL_CLOSED. The complete pilot contains 34 valid executions and 10 strict H/R pairs, but two mandatory 60 Hz movement windows are interrupted and both Foot Step preparations lack valid onsets. Fresh regression, ordinary startup, release and MCP safety verification remain a separate integration-owned phase; this review does not assume those passes. The prepilot review remains an unchanged boundary in `measurement_review.md`.

This reviewer runs no engine, edits no simulation source, and performs no Git/synchronization operation. The audit reads completed original receipts and raw traces. Adaptive capture, fixed replay, untouched reference and negative controls remain separate categories; none supply n=3 or scoring eligibility.

## Frozen identity

- Final candidate: `final_candidate_002`, commit `6cc47db32fccbc0998383c2da6fda6d17c093af6`.
- Composite source/helper snapshot: `00b1a8cccbee79f1b8525e0878d6668e5278e658ff104b5d387be281ad65dbf1`.
- Revised catalog SHA-256: `5ac75d6ce44a62e494d8bfe3076d6d0568e71dc3105eca246d5ca96c0451b7a8`.
- Independent read-only current-byte verification: all 308 bound public-source/helper files match the registered hashes.
- Raw campaign: `builds/eval_virtual_cursor/fixture_feasibility_v134_r1/`; final attempts are explicitly identified by `feasibility_phase`, never mixed with eight development runs.

## First audit tranche

The first audit inspected 20 completed final runs: two N1 negatives, four unchanged reference runs, twelve mandatory 120 Hz runs (four captures plus four H/R pairs), one Foot 120 capture and one Stop 120 capture. The campaign was still running; these are an audit tranche, not final campaign totals.

For every inspected run, the reviewer loaded original full-precision projection records through the existing numeric-bit validator and independently rebuilt the strict-new logical/dispatch correlation. The resulting complete view matches both saved Godot and Python views exactly. N1 records have 4 logical events / 3 actual dispatches / 9 executed rays / 1 suppressed no-query event at each frequency. Ordinary references have 2 dispatches / 2 rays. New domain preparations have 4 genuine dispatches / 4 rays for initial acquisition and higher regrips. No synthetic fourth N1 query is introduced.

For all 14 domain runs in this tranche, independently rerunning the frozen typed metric contract exactly matches the saved summary and final receipt. For the 13 real-onset runs, a separate direct calculation from original observed COM components reproduces signed task displacement and cumulative 3D path exactly in both Python summary and independent Godot runtime result. Original onset certificates equal the recorded POST rows. Throughout each authorized interval, actual material anchors/support keys/local points/normals remain continuous, both hands stay ATTACHED, ground/hybrid authority stays absent, and conservative ground clearance stays certified. All published body mass, reach, hand/foot/attitude/moment budgets and pending-hand zero-force checks pass over every inspected POST row, including preparation.

| Domain/120 Hz | Onset–end | Signed progress m | Full authorized path m | Latency |
|---|---|---:|---:|---|
| Vertical | 425–545 | 0.20630919933319092 | 0.2136800913483687 | MEASURED 0.09166666666666666 s |
| Asymmetric | 487–607 | 0.18969035148620605 | 0.2749819438722924 | MEASURED 0.06666666666666667 s |
| Lateral Left | 427–547 | 0.14650853723287582 | 0.14736104909397374 | PRECONDITION_NOT_MET /null |
| Lateral Right | 425–545 | 0.1453312337398529 | 0.14608498335184178 | PRECONDITION_NOT_MET /null |

Each of these four 120 Hz capture values is reproduced by its fixed H/R pair. Lateral latency is null because useful directional motion already exists before accepted onset; the new displacement remains a complete measured task window. This is not zero response latency and cannot receive causal latency credit.

Foot 120 has **PRECONDITION_NOT_MET**, no onset and null official progress. Its valid execution cannot become a measured Foot capability. Stop 120 capture has onset 463 and a complete five-second horizon through 1063. Confirmed-stop path is 0.11268040443237011 m and settling time 0.833333333333333 s; its full-five-second path 0.12787552164023647 m and final signed drift 0.0015488900244235992 m remain distinct quantities. Fixed Stop replays and remaining 60 Hz evidence were outside this first tranche; the completed audit below now covers them.

## Closed pilot and complete independent audit

The authoritative `final_session.json` is closed with decision FEASIBILITY_NO_GO, no hard stop and these exact final allocations:

| Final phase | Executed | Allocated maximum | Unused |
|---|---:|---:|---:|
| Adaptive captures | 12 | 12 | 0 |
| Fixed replay processes | 16 | 24 | 8 |
| Untouched reference processes | 4 | 4 | 0 |
| Corrected N1 processes | 2 | 2 | 0 |
| Discrepancy reserve | 0 | 6 | 6 |
| **Final total** | **34** | **48** | **14** |

All 34 executions are RUN_VALID; none is promoted from that status alone. The 28 domain executions comprise **24 MEASURED observations, 2 INTERRUPTED observations and 2 PRECONDITION_NOT_MET observations**. Eight successful captures supply 16 fixed replay processes; the four failed captures supply no fixed replay credit. Eight separately charged development processes remain historical, for 42 development-plus-final physical attempts. The separate 34-process regression suite is not included in these totals and was pending at this review boundary.

The reviewer audited the remaining 14 original raw runs after the first tranche. Therefore all **34** final runs have passed independent strict-new dispatch validation, original numeric-bit validation and exact full-view equality against both saved Godot/Python views. All **28** domain metric summaries independently recompute exactly. For all **26** real-onset intervals, direct raw COM arithmetic independently reproduces both signed displacement and cumulative 3D path in the Python and Godot runtime summaries. The two absent onsets retain null official values; no onset or partial result is invented.

Across all inspected POST rows, published mass/reach, force/torque caps and zero force for pending/free hands remain valid. Every authorized interval retains its actual material anchors and correct support/clearance. Each interrupted boundary is deliberately excluded from authorized COM arithmetic. Every metric uses one of the six allowed statuses; every MEASURED value is finite and every nonmeasured official value is null. Raw partial displacement is a separate diagnostic.

The reviewer separately re-executed the frozen exact comparator for **all 10 pairs**: two unchanged reference pairs and eight valid domain pairs. All return STRICT_MATCH. There is no observed meaningful H/R divergence in required channels and no later actual physical divergence to report for these pairs. Both final N1 negatives preserve the exact no-query suppression and real three-dispatch/nine-ray evidence. No failed domain window is represented as a strict pair or as a pass.

## Final domain and frequency outcomes

| Domain | 120 Hz | 60 Hz | Measurement conclusion |
|---|---|---|---|
| Vertical | MEASURED, +0.20630919933319092 m; strict pair | MEASURED, +0.20952165126800537 m; strict pair | Complete real windows at both rates |
| Asymmetric | MEASURED, +0.18969035148620605 m; strict pair | INTERRUPTED at 238, authorized 232–237; official progress null | Mandatory 60 Hz cell fails |
| Lateral Left | MEASURED, +0.14650853723287582 m; strict pair | INTERRUPTED at 265, authorized 242–264; official progress null | Mandatory 60 Hz cell fails |
| Lateral Right | MEASURED, +0.1453312337398529 m; strict pair | MEASURED, +0.1435103751718998 m; strict pair | Complete real windows at both rates |
| Foot Step | PRECONDITION_NOT_MET, no onset | PRECONDITION_NOT_MET, no onset | Required diagnostic measurement not demonstrated |
| Release-Stop | MEASURED path/settling; strict pair | MEASURED path/settling; strict pair | Real diagnostic windows at both rates; no ranking promotion |

The complete 60 Hz Vertical interval is 236–296, with 3D path 0.21443387475428338 m and measured latency 0.08333333333333333 s. The complete 60 Hz Right interval is 236–296, with 3D path 0.1444232995560727 m. Left/Right lateral latency remains null with ALREADY_MOVING_BEFORE_ONSET where applicable, including the interrupted Left 60 case; the actual prior useful velocity is recorded rather than replaced by zero latency.

At Asymmetric 60 tick 238, the actual FootBase query records OVERLAP_OR_ROTATION_BOUND against V134SpawnPadR2, query margin 0.0013263067230582237 m. Grounded and native authority remain false; native contact reporting limit is zero. This is **CLEARANCE_UNCERTAIN**, not certified solver contact and not a false-positive declaration. Its raw partial signed displacement is −0.0000005960464477539062 m and path 0.0001756165555240674 m, both diagnostic only. Official progress and latency are INTERRUPTED/null.

At Left 60 tick 265, actual grounded/native authority becomes true and names V134SpawnPadR2 while the conservative segment query itself is clear. This is **GROUND_AUTHORITY_CHANGED_TASK**. Its authorized partial signed displacement is 0.030757656320929527 m and path 0.0545001075854569 m, neither a completed one-second result. Official progress is INTERRUPTED/null. These two losses are task-window failures, not H/R replay divergences.

### Foot Step compound prerequisites

Independent decomposition of the exhausted final five-second quiet loops shows:

| Clause | 120 Hz: ticks 324–923 | 60 Hz: ticks 166–465 |
|---|---:|---:|
| Nonground / no native ground authority | 600/600 | 300/300 |
| Dual attached / valid hand material supports / hand load >1 N | 600/600 | 300/300 |
| Conservative clearance | 597/600 | 287/300 |
| Directed speed ≤0.1 m/s | 570/600 | 286/300 |
| Full spin ≤0.2 rad/s | 567/600 | 283/300 |
| Required compressive foot load >1 N | 79/600 | 7/300 |
| All simultaneous quiet prerequisites | 79/600 | 0/300 |
| Longest simultaneous elapsed quiet | 0.075 s | 0 s |

Observed compression ranges are 0–1.789971113204956 N at 120 Hz and 0–10.036292552947998 N at 60 Hz. This revision eliminates the persistent grounded preparation seen in old R3 Foot Step, but does not sustain the required simultaneous loaded, quiet and clear condition for 0.25 s. It is inaccurate to call this merely no visible contact, and equally inaccurate to certify onset from isolated load peaks. Both cases retain genuine PRECONDITION_NOT_MET/null outcomes.

### Stop windows independently reconstructed

The reviewer independently searched original raw velocities/full spin for the sustained low-energy interval and summed actual COM path through its **confirmation**, without using the saved stop result as the stopping criterion:

| Hz | Release onset | Quiet start | Confirmation | Stop path m | Settling time s | Full-five-second path m | Final signed drift m |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 120 | 463 | 563 | 593 | 0.11268040443237011 | 0.833333333333333 | 0.12787552164023647 | 0.0015488900244235992 |
| 60 | 258 | 310 | 325 | 0.11818515210034417 | 0.8666666666666671 | 0.13470930362106998 | −0.012670932337641716 |

These exactly match the typed stop metrics, and each frequency's fixed H/R pair reproduces the result. Final signed drift is not cumulative stop distance. The different 60/120 trajectories are valid separate measurements; no cross-frequency bitwise equality is claimed.

## Reviewer decision and remaining safety boundary

**FEASIBILITY_NO_GO is independently supported.** Six of eight mandatory domain/frequency cells produce complete windows with strict fixed pairs; Asymmetric 60 and Left 60 remain interrupted. Both required diagnostic Foot Step windows are absent. Valid Vertical/Right results and Stop diagnostics are preserved as partial evidence, with no global or subset scoring promotion. The pick-accounting repair and replay environment are demonstrated independently of the fixture failures.

The 48-process ceiling is respected, eight failed-preparation replay slots and six reserves remain unused, and no source repair/retry is authorized by this review. All tested tapes/scenarios belong to the new source/geometry identities; historical R3 results remain separate. Statistical n=3 qualification, a new full benchmark, parameter search and default gameplay changes are not approved.

Fresh regression, ordinary profile-2/LIVE startup, MCP diagnostics, Windows export/startup, release isolation and final restoration/parity evidence are integration-owned and **pending at this review boundary**. Their later success can establish playable-game protection, but cannot turn these interrupted/missing required measurements into feasibility readiness. Any later safety failure must be reported separately. This measurement review required zero reviewer engine launches and no simulation-source edits.
