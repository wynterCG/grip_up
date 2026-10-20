# Independent measurement review of the v1.3.5a baseline stop

Decision: **BASELINE_NO_GO; measurement signoff REJECTED_BASELINE_NO_GO.** The mandatory baseline stopped on its second process. No negative/canary stage, fresh quality freeze, parameter proposal, confirmation, finalist or human test is authorized by the available evidence. The numerical reducer's passing offline tests and preflight do not replace the missing baseline.

This is a read-only audit of existing receipts. I launched no engine, changed no frozen source and accessed no private holdout. I authored the campaign integration; that source was separately reviewed by the integration owner and physics reviewer. This review independently reconstructs the captured arithmetic and failure evidence without modifying the campaign implementation.

## Identity and successful preflight scope

The frozen source is commit `fccd68b47696f78f8eee6b3cb3291dc8375f2259`, snapshot `f81b0b58f966b99ff79415edf856d6c2439c5826ccb9127cdf69246c9f8dd270`. The exact pinned Python environment fingerprint is `93880dfde2cb42fd3ab0fcd6b96b964d3dcc237b37d25f9e01e2f86976cb82f5`. I revalidated that fingerprint and329 frozen source/helper hashes in both C and E copies with no mismatch. The scalar reducer source remains `8264957f3acc818256055f61f6c94aa28d4fc85490713e430982948e730f7342`.

The real JSON/manifest tests and six zero-gameplay-world environment probes passed. Physical preflight used six processes: protected Swing & Catch at120/60Hz and four A0 task cells, V/R×120/60Hz. All six were `RUN_VALID`, used the identical full environment/reducer identity, and recorded successful input cleanup and exact Resource restoration. Catch recorded actual acquisition, loading, retention at the end and the known underside at both frequencies. This protected evidence remains outside training objectives.

For each of the four task cells I reran the summary/quality functions from the raw POST rows and separately reconstructed scalar path/progress without calling the reducer. All summary fields and published binary64 bits matched.

| Cell | Authorized POST interval | Segments | Path m | Binary64 big-endian bits |
|---|---|---:|---:|---|
| Vertical120 |425–545|120|0.2136800913483687|`3fcb59de8612e277`|
| Right120 |425–545|120|0.14608498335184178|`3fc2b2e9a8f7681e`|
| Vertical60 |236–296|60|0.21443387475428338|`3fcb7291b79cb2d2`|
| Right60 |236–296|60|0.1444232995560727|`3fc27c76722fd6d4`|

The complete A0 candidate-shaped dry-run passed scorer ingestion, SQLite persistence/readback, report and cleanup without starting parameter search. Independent score recomputation matched its report. Read-only inspection found one COMPLETE A0 trial with worst-frequency task objectives `0.20630919933319092` and `0.1435103751718998`. The database SHA256 before/after read-only inspection remained `ea6aefd17707677ff0b5f7c939590a6ff18013d6676fac87ab76de3ede930562`. The recorded fresh-connection settings were journal_mode=`delete`, synchronous=2, foreign_keys=0 and busy_timeout=5000. Connection-local observations are not claims of global persistent settings.

These are qualified preflight observations, not a completed benchmark matrix. The old R4 campaign remains closed and NO_GO; no old invalid candidate has been rescored as a new study entry.

## First mandatory baseline failure

The first new baseline H120 Vertical process `vertical_pull_clean_v134_r2_120_headless_r1_edaa4afc` completed validly. A supplementary frozen comparison against the same-mode preflight H120 observation returned `STRICT_MATCH`; it does not substitute for a planned H/R pair or baseline replication.

The second process, R120 Vertical `vertical_pull_clean_v134_r2_120_rendered_scripted_r2_deb07f25`, ended `RUN_INVALID`. Its top-level reason is `PICK_CONTRACT_FAILURE:INCOMPLETE_PICK_STREAM`; the scenario preserves the underlying `RUNTIME_SUSPENDED:TICK_GAP`. The measured maximum wall gap was257360µs, exceeding the existing250000µs guard. No evidence identifies the operating-system cause. There is no basis to attribute this gap to a mouse action, focus loss, physics regression or arithmetic mismatch.

Two correct preworld120Hz samples and canonical backing preceded world creation at global tick5. The replay then installed ten input frames, but retained11 POST observations. At POST11/global16 the requested/effective input still identifies frame10: frame11 was never installed after the guard aborted the pre-tick path. Both hands remained FREE, no pick was requested, the sidecar has zero records and measurement was inactive. There is no onset, authorized metric window or official numerical score. Missing measurement is unavailable, not zero.

Using the frozen channel-extraction/difference helpers on the available common prefix, the first input difference is tick11 (`input_source_sequence`11 versus stale10), followed at the same tick by a stale camera pose in the PICK layer. CONTACT/PHYSICS channels show no inequality through the available11 rows. This bounded diagnostic does not certify the interrupted replay or establish what would happen later. The full frozen comparator correctly returns `INVALID_SCHEMA:MISSING_TICK`, with no strict pair result. No later physical divergence can be observed because the failed trace ends there.

The incomplete pick-stream result is a subsequent integrity rejection of an already interrupted session. It is not an observed material-ray disagreement: there were no actual pick records to compare. All eight published physics invariant flags are false and Resource restoration flags are true, but the input cleanup receipt is empty. The run remains invalid; neither those flags nor the absence of script errors repair it.

## Coverage, budgets and terminal scope

Baseline planned24 processes; actual2, one valid and one invalid, with22 NOT_RUN. It completed zero of12 H/R pairs and zero of16 required within-mode comparisons. The matrix is unqualified. Negatives8, quality freeze, optimizer, candidate confirmation and protected finalists remain NOT_RUN. The dry-run's single A0 SQLite row is not an optimizer proposal. There are zero candidate proposals, zero shortlisted candidates, zero human sessions and no default promotion.

Eight qualification processes were actually consumed: preflight6 plus baseline2. Unused reserves are not transferred into retries or another campaign. Ordinary regression, launch/export/MCP safety checks are the integration owner's separate ledger; they were pending at this review and cannot turn this benchmark result into GO.

The spec requires stopping at the first invalid mandatory baseline. I reject search certification for this frozen campaign. No tolerance change, post-outcome repair, repeat baseline attempt or automatic v1.3.5b is approved. A0/B1 stays unchanged.

The companion JSON `finalmeasurement_baseline_stop_review.json` binds the source/environment, detailed evidence hashes, full frozen comparator rejection and exact first-prefix field differences. Its SHA256 is `3f67372e37b58e0dea90629a2dafbb773f1867987b8ea526579bac2e815a0743`.
