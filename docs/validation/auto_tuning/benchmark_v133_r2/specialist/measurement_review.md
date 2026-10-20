# v133 r2 measurement review

Recommendation: **NO_GO_BENCHMARK** for the stopped primary campaign. Fresh environment preflights passed, but the first reference driver rejected its manifest before initialization or a gameplay world. A separately sourced diagnostic pair subsequently matched; it does not replace the failed primary admission or provide the required reference/new-domain replication.

Review is based on raw JSON, source reads and read-only Python recomputation. No engine, Git, source edit, synchronization, optimizer or holdout outcome was invoked by this reviewer. The reviewer authored the original Python metric module, so this discloses self-review of that implementation; the environment/trace investigation here is independent readback of the lead's receipts. The separate physics review provides independent semantic review.

## Frozen primary evidence

Primary source is `3ee5fabb6e2709d94dcc0e0663ba990bed8e75e3`. `preflight_session.json` records 13 successful admission assertions: 12 positive processes, three per headless/rendered and 60/120 Hz cell, plus one deliberate wrong-size rejection. Positive backing was 1024x576; logical viewport 1920x1080; no gameplay bodies. Rendered 60 Hz logs retain two initial 1/120 callbacks followed by two correct 1/60 callbacks before any world. Those are observed startup samples, not discarded gameplay ticks.

The first reference attempt `swing_catch_train_120_headless_r1_658b4656` has receipt `RUN_INVALID`, engine `BLOCKED_SETUP`, reason `ENVIRONMENT_NOT_COMPARABLE:CANONICAL_BACKING`, and exit 1. Its manifest requests `[1024,576]`; backing initialization and world-creation dictionaries are empty; `benchmark_audit.json` has `frames=[]`, `ticks=[]`. This is a driver admission failure, not a failed catch, raycast or Jolt trajectory.

Frozen source compares the parsed JSON `projection_config.window_size` Array directly to integer literal `[1024,576]` before invoking `Backing.initialize`. Diagnostic JSON roundtrip records numeric type 3 and the old Array equality as false. The failing manifest and original source remain preserved. A preflight without this manifest field did not exercise that exact validation branch; its 13 passes therefore cannot substitute for the failed end-to-end reference admission.

Primary coverage: one attempted invalid reference process, no valid primary process, zero primary gameplay worlds or completed pairs. Eleven further reference processes and all 72 new-domain processes remain not run: 83 unattempted primary cells. No primary onset, metric, new-domain ranking cell or fresh 60 Hz reference result exists.

## Bounded diagnostic sequence

All four issue-specific slots were consumed, including two pure tests. `primary_campaign_stays_stopped=true` is preserved.

| Slot | Source / observation | Interpretation |
| --- | --- | --- |
| D1 pure JSON contract | `dd7f77dc7b7c55011b22432174c93a4c4e9ca3cd`; 16 checks, one failure; string-vs-float operand error for `["1024",576]` | Failed diagnostic implementation retained, no gameplay world. |
| D2 pure JSON contract | Final diagnostic source; 16 checks, zero failures; old parsed Array comparison still false | Numeric-type and scalar admission guards exercised; no gameplay world. |
| D3 headless 120 Hz | `swing_catch_train_120_headless_r1_02ec69c9`, `RUN_VALID` | One real diagnostic catch under corrected admission. |
| D4 rendered 120 Hz | `swing_catch_train_120_rendered_scripted_r1_244b0d01`, `RUN_VALID` | One corresponding diagnostic catch, not a primary repetition. |

The final diagnostic source is `7a726febcb5257cac2cef23312c3b01d5cddb39b`, distinct from primary freeze. Comparing frozen source maps finds changes only to the test-only benchmark driver and the added backing test. Both real diagnostic manifests use this same final source map, 120 Hz, the same historical tape SHA256 `d09f2569cbbafb4db2d3571b806dc804622fe4efda3c6ba9d8790a51bdb2991b`, and 1024x576 backing. These are two diagnostic gameplay worlds, not zero worlds overall and not new primary passes. No 60 Hz gameplay diagnostic ran after the pure negative consumed an additional slot.

Each diagnostic has 536 POST rows and two actual pick records. Both report actual contact at tick 440, source free at 455, retained destination anchor at 527; normal is underside -Y and the real beyond-static reach/loading policy remains recorded. B1/native-ground contribution remains disclosed; this is not an arm-only catch.

## Exact cross-mode result and legacy representation mismatch

Read-only recomputation of `compare_required` reproduces `diagnostic_pair_120.json`: `STRICT_MATCH`; all required layer first-divergence entries are null; point-of-call comparison is `STRICT_MATCH`. Reported body/contact/force/planner channels and both actual ray/pick sidecars match under the comparator's declared process-ID mapping and metadata exclusions. This is exact measured-channel agreement for one diagnostic 120 Hz pair, not global solver determinism or benchmark qualification.

The nested `legacy_layers` result must remain visible as `CURSOR_OR_CAMERA_MISMATCH`, first tick 55. Its compared operands are different representations, rather than unequal H/R physical cursor observations:

| Operand at tick 55, cursor Y | Exact parsed value | Little-endian float64 bits |
| --- | --- | --- |
| Frozen raw tape / requested / effective frame scalar | 480.534973144531 | `fcffff3f8f087e40` |
| Actual Vector2 cursor, precise benchmark audit and point-of-call sidecar, both modes | 480.53497314453125 | `000000408f087e40` |
| Old `virtual_audit.json` cursor serialization, both modes | 480.534973144531 | `fcffff3f8f087e40` |

Independent Python checks show `float32(raw tape scalar)` equals the actual Vector2 component exactly, and formatting that component with 15 significant digits reproduces the old JSON value exactly. The difference is 2.2737367544323206e-13 in the promoted JSON scalars. Native Vector2 representation and legacy JSON encoding explain this sample without modifying the tape or adding a tolerance. The sidecar explicitly records raw tape and actual API vector separately. The legacy helper compares the raw frame scalar with the precise API vector within a run; its status therefore must not be described as an H/R cursor divergence.

The reviewer additionally compared all 536 precise `canonical_input.effective_aim_px` values directly between H/R and found exact equality, and the complete requested frame arrays are equal. This checks the cursor channel independently of the nested helper's operand construction. No epsilon, millimetre/pixel envelope, rounding repair, changed physical tolerance or replacement world ray was introduced. The original mismatch remains a recorded serialization/typed-coordinate interpretation limitation.

## Eligibility and report boundaries

No new domain is eligible. Vertical/asymmetric/left/right still lack all real onsets and replication; foot and release-stop retain planned diagnostic-only coverage; one-hand 60 Hz remains OPEN. The diagnostic pair is not 3/3 at either frequency and cannot satisfy BQ2. No fresh task-ranking metric or observer ON/OFF result was measured. Original gameplay regressions and prior headless-init evidence remain separate preservation/admission evidence, not additional v133 r2 passes.

Final reporting should retain both primary and diagnostic source IDs, every failed diagnostic, explicit zero primary worlds versus two diagnostic worlds, zero completed primary pairs versus one diagnostic pair, and the nested legacy mismatch alongside exact actual cross-mode results. No optimizer, global A0 superiority or human-feel conclusion follows. Final archive/export/restoration checks belong to the integration lead and were not independently repeated here. A further primary campaign requires explicit authorization and a new frozen identity; this review does not authorize an automatic r3.
