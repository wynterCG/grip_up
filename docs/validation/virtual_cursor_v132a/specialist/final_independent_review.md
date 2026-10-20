# v1.3.2a — final independent physics/replay review

Date: 2026-10-20. **Decision: NO_GO_INPUT_REPLAY.**

This is a read-only review of recorded evidence and source. The specialist did not run Godot, modify source, retune physics, change geometry, reopen a qualification matrix or access holdouts. The negative decision is a qualification outcome, **not evidence that the provider bypassed physics or that hardware contamination was reproduced in this version**.

## Scope and identities

- Preserved starting baseline: `0be1667310a62d66ac2c30b9aa5bbe632d81593d`.
- Frozen source captures: `5c9d6441c416044046c49d627faebb78e0249f3f`.
- Corrected parser / diagnostic runtime: `d13fd0cc8f34b52db1afc25d0cfce620ec2330e1`.
- Engine: Godot `4.7.2.stable.steam.ed1daf0bf`, binary SHA-256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.
- New test identity: `benchmark_eval_virtual_cursor_v1`, camera mode `V0_PHYSICS_FOLLOW`; this is not historical R0 or its original render-follow camera contract.

Evidence reviewed:

| Evidence | Location under `builds/eval_virtual_cursor/` | Meaning |
|---|---|---|
| Frozen source120 | `frozen_capture_r1/attempts/V0-H_120_r1_04f5b391/` | Actual source capture, not qualified fixed playback |
| Frozen source60 | `frozen_capture_r1/attempts/V0-H_60_r1_9b117cdb/` | Actual source capture, not qualified fixed playback |
| First qualification attempt | `qualification_r1/attempts/V0-H_120_r1_c56d2f29/` | Pre-world validation failure |
| N1 direct diagnostic120 | `direct_diagnostic_r2/attempts/N1_JSON_EDGE_GUARDS_120_r1_141946f2/` | Corrected numeric JSON/edge path, diagnostic only |
| Derived diagnostic provenance | `diagnostic_tapes_r2/catch_120.json`, `catch_60.json` | Separate tapes; only120 N1 was executed |
| Ordinary main / restore | `native/`, `safety/` | Supplementary startup, export and restoration evidence |

The early qualification stop is preserved: **one of 24 attempts executed, failed before a scenario/world; the other 23 are NOT_RUN_EARLY_STOP**. N2/N3/N4 were not executed after the stop. The later scope decision supersedes the earlier broad proposal to run them. Source captures, pure checks, N1 and ordinary safety runs are not replacement matrix repetitions.

## Qualification failure and the narrow diagnostic

The first qualification engine result is `BLOCKED_SETUP / INPUT_BUTTON_EDGE`, with zero scenario rows. The parser rejected a legitimate JSON hand index represented as a float, rather than an integer variant. It did not get as far as real picking or Jolt simulation. This is a serialized input-validation failure; it is not an observed physical miss, fake contact, cursor disturbance or solver divergence.

The repair requires numeric hand type, finiteness and exact integrality before conversion; fractional hand IDs remain rejected. Numeric wheel handling received the corresponding integral validation. This does not alter requested hand identity, pixels, anatomy, actuator targets or force authority.

N1 has nine recorded PASS checks, including real dispatch of invalid-aim press, actual valid top-left ray queries, source/viewport/camera guards, and duplicate/missing-tick guards. The explicit invalid aim emits `INVALID_AIM_NO_NEW_TARGET`; the valid `(0,0)` request runs real targeting and records seven misses. These are distinct outcomes: top-left validity does not imply a grabbable object exists there.

The diagnostic completed a real catch later in the same episode. It demonstrates a narrow repaired JSON/edge path in that run. It does not approve ordinary replay, rendered equivalence, human interference resistance or the skipped negative cases.

## All-POST physical review

The specialist read **all 1,335 POST snapshots**:536 at120,263 at60, and536 in N1. These are named post-control observations, not an assertion that the callback is Jolt post-solver.

Every snapshot reports mass12 kg, profile4 and no hybrid ownership. All body COM/linear-velocity/angular-velocity vectors checked were finite. Across both hands there were **474 REACHING samples**; every one had exactly zero published hand force. No hand outside ATTACHED/SLIPPING had nonzero published force. Thus the observed pending gestures did not acquire physical support authority.

| Published channel | Capture120 | Capture60 | N1 diagnostic120 | Existing cap |
|---|---:|---:|---:|---:|
| Shared hand force peak, N | 254.947983 | 242.386597 | 254.947983 | 360 |
| Total feet force peak, N | 45.470654 | 38.390640 | 45.470654 | 180 |
| Largest individual foot force, N | 45.470654 | 38.390640 | 45.470654 | 120 |
| Assistance magnitude peak, Nm | 20.0000014 | 20.0000009 | 20.0000014 | 20 |
| Combined ground/climb moment peak, Nm | 67.245478 | 76.760712 | 67.245478 | 150 |

The approximately micro-Nm rounding above20 is the norm of float vector components; it is not a new torque budget. All published invariant flags remain false. Foot normal force is nonnegative; the largest observed tangent/normal ratio is0.435194, below the unchanged coefficient0.85. No tangent force was observed with zero normal load.

Ground drive remains a distinct existing authority, with peak published ground force168.000014 N and ground torque65.000006 Nm across these episodes. It is not hand force, and the combined climbing/ground torque channel remains separately reported. These caps describe controlled actuator channels, not a claim that every native collision impulse is bounded by them.

REACHING endpoint-to-shoulder distance peaks at0.65708015 m, a float-scale difference from the unchanged0.65708 m workspace. Maximum ATTACHED separation is0.65408325 m at120 and0.65166825 m at60. The larger target-distance fields while REACHING refer to the distant selected target, not to a stretched physical endpoint. Reported relative gesture speed peaks at4.0000081 m/s, also float-scale rounding around the unchanged4 m/s limit; body-frame transport is a separate component.

## Real contact, load and retention

| Case | Actual contact | Origin FREE | First required retention | Request distance / reach | Actual final chain duration |
|---|---:|---:|---:|---|---:|
| Source120 | 440 | 455 | 527 | 0.81492168 / 0.65708 m | 0.675 s |
| Source60 | 215 | 223 | 259 | 0.80771643 / 0.65708 m | 0.666667 s |
| N1 diagnostic120 | 440 | 455 | 527 | 0.81492168 / 0.65708 m | 0.675 s |

All three select actual destination `catch` with material normal `[0,-1,0]`, admit load and finish with the destination attached while the origin is FREE. The final uninterrupted same-runtime-anchor chains were independently recomputed from the rows, not inferred from the process exit code. Final-chain destination load reaches100.83370 N at120 and75.75510 N at60. Initial request distance exceeds reach by more than the pre-existing0.02 m policy margin; no enlarged reach was needed.

The source and N1 120-Hz sequences have exactly equal recorded COM, linear velocity, angular velocity and force-budget values across all536 corresponding POSTs. Their first four input/picking frames deliberately differ for N1; they are not an identical-input comparison. This single diagnostic observation does not establish a general continuous equivalence envelope or isolation from real OS activity.

The tasks are **not arm-only**: source120 and N1 contain160 ground ticks and26 foot-loaded ticks; source60 contains107 and25 respectively over the whole episode. These counts include preparation and do not imply ground contact at final capture. There is no dynamic-support pair-conservation qualification in these static catch fixtures.

## Provenance of derived tapes

Both derived diagnostic artifacts explicitly say `diagnostic_only:true` and `DIAGNOSTIC_ONLY_NOT_RECAPTURED_OR_QUALIFIED`. Independent checks confirmed:

- The original frozen tape file hashes match the recorded parent hashes.
- Derived `frames` and `reference_ticks` are exactly equal to their frozen originals.
- `capture_source_hashes` exactly preserve the original capture's source map.
- New replay source hashes are separate, with per-file old/new approved deltas covering the numeric contract/tests/driver/transport, rather than a false claim of unchanged capture source.

The parent reports Python and Godot reject these diagnostic tapes outside the explicit negative-case path. The120 N1 evidence remains tied to that path; the existence of a derived60 file is not a60 replay measurement. No source capture was regenerated or old qualification receipt overwritten.

Original tape file SHA-256 values:

- 120: `870532a956e393177b5749639405ef1911e3074f94210780e8b49341407efdcb`.
- 60: `7e0ea5d3c75c201275085197ea7d5f0a280ee9e39adbe5109b5183b6c6ab5776`.

Derived diagnostic file SHA-256 values:

- 120: `fefef55a3ea3304866d00f0f03415d51bd463494f5f2e269a7215ca32d6d6c8f`.
- 60: `4245f06693983a699b2e925aa1472dd7cba3dec22a8c3d0d445cd609e88c7e95`.

## Production safety and restoration

The baseline comparison in this review found only the four approved gameplay input/camera/audit scripts and `export_presets.cfg` changed among pre-existing tracked paths. In particular, climbing controller, actuator/solver resources, ground motor, hybrid/v0.8 mechanism and geometry were not modified to pass the replay. The approved camera sampling change is opt-in; the ordinary LIVE path remains the default.

The reviewed cleanup receipts have provider DISABLED/removed, router frame removed, camera back to LIVE, orbit off, held buttons false and physical hands RELEASED. Resource/Hz/startup/source restoration receipts are true in all three measured-world runs. Static source audit plus these guards support the no-new-physical-authority conclusion; a false-valued mutation flag alone would not prove it.

The ordinary Godot MCP Pro1.17.1 check is **supplementary main safety**, not V0 qualification. Its receipt records monitor0, profile2, LIVE, provider disabled, arming false, virtual camera false,120 Hz,12 kg, reach0.65708, A0 values0.25/0.12/0.24/0.9, original bindings, hold mode true, feet/observer/capture false, and zero errors after the check. Project restoration records the original SHA-256 `6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9` on C/E and closure of the owned editor.

The fresh headless safety snapshot reports the same ordinary settings. Release export and180-frame executable smoke receipts have exit0 and no script errors. Pack inspection reports the research provider/drivers excluded and ordinary profile2/provider disabled. That inspection was run with the debug engine (`release_template:false` in the inspection row); it verifies packed contents/startup, not the release binary's `OS.is_debug_build` value. The actual exported executable has a separate release-export/startup smoke receipt. The parent reports884 existing physics checks in24 processes,24 Godot contract checks and11 Python checks passed; those are preservation/contract evidence, not replacement V0 repetitions.

## Final decision and coverage limits

**NO_GO_INPUT_REPLAY** is required because the frozen qualification failed before world creation and stopped. There are no qualified rendered repeats, no measured real-person V0-M/V0-F interference cases, no completed N2/N3/N4 evidence and no approved continuous camera/contact/physics envelope. The passing N1 repair diagnostic cannot fill those gaps.

Conversely, these records do not establish an actuator bypass, fake attachment, excessive force, invalid anatomical extension, input contamination under real user activity, or a Jolt defect. The source captures and N1 show real bounded physics in the observed headless cases. Input isolation and picking repeatability remain **unqualified**, rather than disproved by a measured interference event.

No ML/Optuna/Jev/RL, candidate promotion, holdout access, M7 or gameplay-default change is approved by this review. Preserve all old and new failures, the source/delta identities and the early-stop table. Any later qualification requires a separate prospective decision; this report does not initiate another repair/matrix cycle.
