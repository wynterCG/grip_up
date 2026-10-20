# R3 primary measurement review

**Preflight: CERTIFIED. Primary benchmark: NO_GO_BENCHMARK.** Fresh primary reference replay is repeatable, and some task-specific measurements are useful. The required multi-movement subset does not qualify at both frequencies, and the first physical negative control subsequently hits a frozen observer-accounting hard gate. Its successful engine episode and individual negative assertions must not be promoted to a passed control.

Review consists of read-only raw-data inspection, Python recomputation and new review artifacts only. No engine, source edit, Git operation, E mirror operation or synchronization was invoked. The reviewer authored the measurement/comparison modules and discloses that limitation; independent numeric readback and re-execution against raw records do not constitute a second independent simulator. The physics specialist's separate interpretation remains required. Precertification reviews/signoffs are preserved unchanged.

## Source scopes and ledgers

Measured Git checkpoint: `7a578995915d56ade2fa447f3adfdd6e19dc0218`. Certificate snapshot is `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`, the canonical digest of the 295 public-source hashes plus five execution-helper hashes. Individual manifests' `source_snapshot_sha256` is `7d5b3942f6ab2e51173fdcdc985e2098717b1f4dce00abf3623a579570cb9d28`, the digest of public sources only. These deliberately different scopes must not be reported as a hash mismatch. Actual registered C-source/helper bytes still match the certificate at this review.

Precertification used three candidates and four physical replay processes of its separate limit 12. Two candidates failed pure PC0 checks with zero physical replays; their failures remain preserved. Candidate 003 passed PC0/PC1 and both real PC2 pairs. Those four replays fill no primary cell.

Primary results comprise 12 valid reference processes, 48 valid domain executions and one invalid physical negative: **61 attempted, 60 execution-valid, one invalid, zero aborted**, with no primary diagnostic processes. Ordinary 34-process/1,146-check regressions and pure admission checks remain separate. Of the 72 planned domain attempts, 24 were skipped because required preparation never produced an onset; they are missing task coverage, not failed processes or zero-valued scores. The first negative's hard failure stops the five later registered controls; unused allotments are not reallocated.

## Primary reference and repeatability

Fresh BQ1 records 12 positive pure validations and a deliberate wrong-backing rejection. Fresh BQ2 records three H/R pairs at 120 Hz and three at 60 Hz, all strict across the required published chain, independent of precertification. No cross-Hz trajectory identity is asserted.

The reviewer additionally recomputed n=3 within-mode comparisons using the frozen comparator. The new `primary_within_mode_measurement.json` contains 28 strict comparisons: eight reference comparisons and 20 domain comparisons. Fourteen groups have repeats 1,2,3; repeats 2 and 3 are compared with repeat 1. Captures and probe-OFF runs are excluded. Stop has only repeat 1 per mode/Hz and remains explicitly without n=3. The JSON links both raw audit paths and hashes, retains legacy/typed interpretation, and reports no first unequal field. Repeatable interrupted behavior is not a successful task.

Across domains there are 17 strict H/R pairs: nine primary-domain pairs plus one stop pair at 120 Hz, and six lateral pairs plus one stop pair at 60 Hz. This includes repeatable interruptions and does not by itself certify metric eligibility. There are 12 adaptive captures, 34 fixed domain replays and two stop probe-OFF controls among the 48 domain executions; captures never become fixed-repeat evidence.

## Independent metric readback

All **48** domain metric files were recomputed from raw `benchmark_audit.json`, precise `benchmark_runtime.json` onset certificates and the frozen definitions using the unchanged Python metric implementation. Every result matches its saved typed summary. For all **43** real-onset windows, a separate direct calculation of world-COM signed displacement and integrated 3D path also matches both the saved diagnostic values and the Godot runtime summary exactly. Five runs have no onset, so no fictitious window is calculated.

Observation classifications across these executions are 18 MEASURED, 25 INTERRUPTED and five PRECONDITION_NOT_MET. All 48 are RUN_VALID execution contracts; only 18 report task success. Metric-specific states remain distinct from this observation summary. No missing or interrupted value becomes zero.

| Task | 120 Hz | 60 Hz | Consequence |
| --- | --- | --- | --- |
| Vertical clean | Real onset 268; authorized end 274; conservative ground-clearance interruption at 275. Signed progress and response latency null/INTERRUPTED; partial raw progress 0 and path 2.070337969104702e-7 m retained diagnostically. | No certified quiet onset; PRECONDITION_NOT_MET. | Required vertical movement is not qualified. Uncertain clearance is not a proven native walking/contact event. |
| Asymmetric clean | Quiet onset not reached. | Quiet onset not reached. | PRECONDITION_NOT_MET/null; no fixed replay or positive score fabricated. |
| Clean lateral left | Full legal one-second window; signed progress 0.14916837494820356 m; latency 0.14166666666666666 s; three fixed pairs. | Onset 179, authorized end 199, actual native-ground authority changes task at 200. Progress INTERRUPTED/null. | Useful 120 Hz measurements; no both-Hz eligible domain. |
| Clean lateral right | Full legal one-second window; signed progress 0.1492631696164608 m; same latency; three fixed pairs. | Same onset/interruption boundaries as left; progress INTERRUPTED/null. | Same scope; mirror values are measured independently, not assumed identical. |
| Foot-supported step | Required quiet/loaded onset not reached. | Required quiet/loaded onset not reached. | PRECONDITION_NOT_MET/null; B1 being enabled or a visually planted foot is insufficient. |
| Two-hand release-stop | Real onset 386; first quiet interval starts 484 and confirms at 514. Stop path 0.1162836473271256 m; settling time 0.8166666666666664 s. | Real onset 199; native-ground interruption at 200. Stop/path/settle INTERRUPTED/null. | 120 Hz metric diagnostic only: one pair and probe-OFF control cannot replace n=3. No 60 Hz stopping result. |

Separate threshold/dwell recomputation finds lateral useful-motion criterion/confirmation ticks 365/371 at 120 Hz and 188/191 at 60 Hz. The latter valid response occurs before interruption: its latency **0.15 s remains MEASURED**, while subsequent task progress is INTERRUPTED/null. Preserving that earlier measurement does not make the 60 Hz task successful.

Independent stop integration through confirming tick 514 yields exactly 0.1162836473271256 m; timestamp subtraction from onset to quiet start yields exactly 0.8166666666666664 s. The five-second stop window's raw path is instead 0.16832756064248672 m, and its final signed drift is 0.003121892921626568 m. These are different quantities; neither substitutes for stop path. A small final drift does not mean a small or zero traveled path. Both available stop probe-OFF controls match published channels, without establishing general observer-overhead equivalence.

## Frozen negative-control failure

Failed control: `primary/benchmark_v133_r3/attempts/swing_catch_train_120_headless_r1_e0310d17`, derived negative tape SHA256 `bcee5b74cd6e591917366eeac3b2ce6159b12b3e8dc2164f4ae0521d34fce86a`. Its original positive tape remains unchanged. The engine completes 536 POST rows, exits zero, records nine of nine negative assertions true, retains actual catch, and reports no dropped trace rows. Nevertheless the Python control receipt is correctly preserved as **RUN_INVALID / MISSING_REAL_PICK_RECORDS** under the frozen campaign rule.

Earliest explanatory evidence is the tick 1 entry `{"hand":0,"reason":"INVALID_AIM_NO_NEW_TARGET"}` in `target.picks`. It is an input rejection/sentinel with **no actual raycast audit**, not a camera query. The complete episode has four entries in that heterogeneous array:

| Tick | Entry semantics | Actual query sidecar |
| --- | --- | --- |
| 1 | Invalid-aim sentinel; no new target; FREE hands, zero force | None, consistently with no query |
| 3 | Explicit valid top-left; seven executed MISS rays | Present: seven rays |
| 55 | Source selection | Present: one SELECTED ray |
| 282 | Catch selection | Present: one SELECTED ray |

The frozen postprocessor counts all four `target.picks` entries, while only three are real query invocations. The sidecar has exactly those three invocations and nine executed rays. Independent validation/join of every actual ray confirms exact screen point, offset, origin, direction and reason, and exact selected collider/shape/material point/normal. There is no observed missing actual query or material switch in this evidence. The failure is an **observer-accounting/schema-semantic mismatch**: a no-query sentinel is counted as a query. Detection occurs after the completed episode in the cardinality postcheck; tick 1 is its earliest explanatory record, not an unequal H/R physics tick.

This diagnosis does not waive the frozen hard gate, change its count, claim a strict negative pair, or promote the control to PASS. All nine internal assertions remain individually true while the overall control remains invalid. Later registered controls are NOT_RUN_EARLY_STOP. No diagnostic physics process or source fix follows. The separately retained `negative_controls/orchestration_diagnostic.json` records a StudyLock argument TypeError **before engine launch**, zero physical processes; that pure orchestration incident is not a second physical control attempt.

## Final scope

Precertification remains CERTIFIED on its documented scope. Primary BQ2 reference passed, but neither required vertical/asymmetric movement nor both-frequency lateral task eligibility is established. The later mandatory-control hard failure independently requires primary NO_GO. Even successful 120 Hz directional measurements must remain investigation evidence under this stopped campaign, not an approved aggregate optimizer benchmark.

No optimizer, private holdout outcome, default promotion, M7 or human playtest is justified. A future evaluation correction may distinguish no-query input sentinels from actual ray audits, but it requires new source identity and separately authorized primary work; no correction or rerun is made here. Final native/export/restoration/archive closure belongs to the integration lead and was not repeated by this reviewer.
