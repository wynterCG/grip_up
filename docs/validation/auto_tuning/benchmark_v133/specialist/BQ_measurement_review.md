# BQ v1.3.3 final measurement review

Reviewed on 2026-10-20 against frozen source `3c888c70a0b5a8bc427e3b68058ac744ba002db6`. Recommendation: **NO_GO_BENCHMARK** for campaign `benchmark_v133_r1`, because its canonical-environment prerequisite failed before any benchmark gameplay world existed. This is not a locomotion, Jolt, catching or human-feel failure.

The reviewer audited the specification, frozen plan, preflight source/manifests/results, four diagnostic receipts, measurement contract, comparator and pure tests. The reviewer authored the Python measurement module earlier in this campaign: this is an independent inspection of the environment evidence and final interpretation, with an explicitly disclosed self-review of that module. The separate physics specialist review is the independent semantic/source review. No engine, Git, sync, physics experiment, optimizer or holdout outcome was invoked by this reviewer.

## First failed gate and counts

`builds/eval_virtual_cursor/benchmark_v133_r1/preflight/headless_120_1_positive/manifest.json` requests `--headless --fixed-fps 120 --resolution 1024x576` and the frozen benchmark preflight script. Its actual result is:

- `ENVIRONMENT_NOT_COMPARABLE`, reason `BACKING_SIZE`, exit code 1.
- Actual root backing `[64,64]`; screen `-1`; window mode 1; position `[0,0]`.
- Engine revision `ed1daf0bf001b61586d9930840f2f1394092c079`; binary SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.
- `gameplay_bodies_created=0`; no task, contact, onset, replay-equivalence or ranking observation.

The first cause is the observed backing mismatch. The initial script rejects before entering its clock branch, so its result does not establish a bad physics clock or a successful settled clock. The initial result also does not publish a logical viewport measurement; that later observation belongs to diagnostics. The unavailable/headless screen index is not the rejection cause.

The plan contains 12 positive pure preflights and one deliberate wrong-size negative. Actual primary execution is one failed positive preflight, zero successful positives, 11 positive preflights not run, and the deliberate negative not run. The accidental failure of a positive must not be credited as the planned negative-control pass. BQ2's 12 fresh catch processes and BQ5's 72 new-domain processes remain not run, not failed gameplay attempts. Original reference regressions, ordinary startup and release checks are separate preservation evidence.

## Four bounded diagnostics

`diagnostics_session.json` preserves `primary_campaign_stays_stopped=true`, zero gameplay worlds and optimizer OFF. Its observations support only launch/setup diagnosis:

| Diagnostic | Actual result after observation/clock | Meaning |
| --- | --- | --- |
| D1 headless CLI, 120 Hz | Backing 64x64; visible 1920x1920; two deltas 1/120 s | Waiting for clock callbacks alone did not produce canonical size. |
| D2 rendered CLI, 120 Hz | Backing 1024x576; visible 1920x1080; two deltas 1/120 s; screen 0, position 2400,80 | This launch mode observed canonical dimensions; no gameplay or V0 equivalence demonstrated. |
| D3 explicit root-size initialization before a world, headless 120 Hz | 64x64/1920x1920 becomes 1024x576/1920x1080; two deltas 1/120 s | A possible initialization correction exists for a separately frozen future launch contract. |
| D4 same explicit initialization, headless 60 Hz | Same dimension change; two deltas 1/60 s | Limited setup observation at the other frequency; no qualification replication. |

D3/D4 change an explicit setup variable in diagnostic probes. They cannot replace the failed primary run, retroactively satisfy BQ1, prove all environment fields equivalent, or authorize continued benchmark expansion in this stopped campaign. No inference about inaccessible engine arithmetic or changed gameplay follows.

## Measurement contracts and pure verification

The frozen `metrics.py` hash recalculated during review is `3535f707236dc929a4a0cf64afa1249cf5e8dbd90a666692f8d958f73f9cacd1`, matching the source identity. Preflight and benchmark driver hashes also match their frozen identities.

A fresh review-time command executed only Python synthetic contracts:

`python -B -m unittest discover -s tools/auto_tuning/benchmark_qualification/tests -p test_*.py -v`

Result: **34 tests passed**, exit 0: 27 metric, four comparator and three tape-admission tests. The immutable receipt is `builds/eval_virtual_cursor/benchmark_v133_r1/contracts/BQpure_measurement_review_frozen.json`; log SHA256 is `48de084e398da77a11b78bdb1e905ff93b74ba10a4cae1b6304f007dc8bf729c`. This supersedes no prior receipt: `BQpure_initial.log` remains preserved and contains an earlier 29-test execution.

The contracts cover all six typed metric statuses and null preservation; accepted-onset identity; prior quiet dwell and recheck; missing/duplicate ticks; both frequencies; native-ground/clearance and anchor interruption; signed/mirrored progress; actual compressive foot load; full 3D stop path through confirmation; full-speed/spin settling; and null-safe required-cell A0/A1 canaries. Preexisting useful motion produces `PRECONDITION_NOT_MET/null`, `ALREADY_MOVING_BEFORE_ONSET`, preserving observed useful-event evidence without zero-latency credit. Catch/retention, braking/reversal and twist without a qualified frame remain explicitly outside the new task metrics where not applicable.

These tests qualify implementation branches under synthetic observations. They do not certify a real onset, actual runtime-summary agreement, observer overhead, candidate ranking, or any new benchmark domain. The required-channel comparator extends hands, rest lengths, applied intent, feet, reported native contacts, ground authority and planner channels; no fresh physical pair exercised those channels in this campaign.

## Closure requirements and eligibility

The final catalog/eligibility matrix must preserve all planned domain/mode/Hz cells as `MISSING_COVERAGE` or `NOT_RUN`, with canonical-environment hard-stop provenance. No domain is `ELIGIBLE_FOR_RANKING`; foot-step and release-stop already had diagnostic-only planned replication. One-hand 60 Hz remains OPEN. Old same-window catch evidence remains historically valid within its original scope but contributes zero new v133 pairs.

Publish the stopped result even where a mandatory output has no observations: CSVs retain schemas and explicit non-run rows, `first_divergences.json` identifies an ENVIRONMENT/preworld failure with no invented physical tick, negative controls distinguish not run from successful rejection, and requested per-tick archives are `NOT_APPLICABLE_NO_GAMEPLAY_TRACE`. Preserve every initial and diagnostic attempt. Report attempted/valid/invalid/aborted/early-stop separately; do not turn all absent matrix cells into parser or climb failures.

This review does not inspect final archive/release restoration receipts that are still being assembled. They remain closure checks for the integration lead. Nothing here authorizes parameter search, a default change, a human UX pass, or silently restarting the primary campaign. A future attempt needs a separately recorded initialization correction, new source/plan identity and fresh required gates; the original failure remains immutable.
