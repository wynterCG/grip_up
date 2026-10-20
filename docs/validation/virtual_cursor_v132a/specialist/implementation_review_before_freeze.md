# Independent implementation review before source freeze

Date: 2026-10-20. This is a read-only review of the C mirror while the implementation owner was still applying review fixes. No engine was launched and no gameplay, evaluator or Python source was edited by this reviewer. It is not a qualification result.

## Reviewed scope

- The four approved gameplay diffs: `grip_up_lab.gd`, `climbing_input_router.gd`, `climbing_camera.gd`, `grip_targeting.gd`.
- New `grip_input_frame.gd`, `live_input_provider.gd`.
- New replay provider, virtual driver, entry and contract tests under `features/evaluator_virtual_cursor/scripts`.
- `tools/auto_tuning/virtual_cursor/run.py` and the prospective `protocol.md`.

The old versions of the four gameplay scripts were read from the immutable a06 source archive and independently matched to their hashes in `baseline.json` for baseline `0be1667`. This avoids assuming an unrelated archived source was the baseline. Controller, ground motor, hybrid controller, v0.8 coordinator, climbing tuning and biped tuning were independently compared to that baseline: their SHA-256 values remained equal during review.

The development capture reported by the owner, contact440/sourceFREE455/retained536, predates later guard changes. It is **development only**, not qualified replay evidence and not a tape reusable after source identity changes.

## Physical and input authority findings

The implementation routes V0 aim pixels through the existing `request_hand` and the existing seven-ray selector. Releases use existing release/pending APIs. No new direct attachment, anchor assignment, body pose/velocity mutation or force source was found in the reviewed new gameplay branches. The normal controller and actuator remain authoritative.

The optional selector audit reuses the results of the queries already executed, preserves ordered offsets/mask/exclusion, stops at the original first eligible hit, and copies the actual authoritative call's audit before later preview queries. It does not manufacture a central-ray hit when an offset wins. The additional `project_ray_normal` call is a pure projection read, not another collision query.

The V0 camera follows the prospectively approved contract: same follow equations, orbit/dolly limits and obstruction query, noninterpolated source pose, one fixed-physics update, no second render follow. The default LIVE follow remains render-driven and interpolated. This is a new sampling identity, not proof that virtual cursor isolation alone caused an improvement over historical R0.

The default LIVE path retains immediate event handling. A live physics snapshot supplies held/axis state to the router; ground preserves its previous-intent phase and the original `Input.get_vector` result. The W sign conversion is correct: ground Y negative versus traversal Y positive. LIVE frame objects currently summarize held state, while edges still execute via normal immediate events; they should not be described as validated replay tapes or as a refactored tick-quantized LIVE edge path.

V0 guards cover Lab `_input`, `_unhandled_input`, focus/boundary callbacks, actual grip polls and GUI-hover ownership. Unsupported hybrid/v0.8 cases are rejected; therefore their unchanged global readers do not silently become isolated. The new snapshot replaces the old reader's global held-button diagnostic with effective held state, preserving hardware focus as a separate observation.

## Findings sent to the implementation owner

The following issues were found before freeze. The owner was fixing them concurrently; the final freeze review must verify the final bytes rather than treat an acknowledgement as a runtime test.

| Finding | Importance | Latest review status |
|---|---|---|
| Matrix could omit tapes and execute adaptive CAPTURE while calling it qualification. | Blocking classification error. | Owner added mandatory tape requirement; final CLI tests required. |
| Replay scenario returned `completed:false` unconditionally, while parent accepted engine completion without a real retained task. | Blocking outcome contract error. | Observed corrected scenario result and parent contact/retention checks. |
| Retention and loaded flags could survive a gap/re-anchor and credit a short new chain; timestamp was overwritten. | Blocking false physical success. | Observed current-chain load and end-retention reset, first historical retention timestamp retained separately. Requires adversarial pure check. |
| Source Lab `_ready` applied profile2 capture before V0 arming. | Host capture side effect before isolation. | Observed `virtual_input_arming` installed before `add_child` and capture guard; ordinary default remains unchanged. |
| `RUNTIME_PAUSED` was accepted as a normal frame. | Incorrect environment classification. | Observed provider rejection of runtime-paused frame/tree. |
| `zip(frames,reference,ticks)` could silently truncate an empty/short reference and return PASS. | Blocking false comparison success. | Observed equal nonempty length guard. A read-only isolated Python check now returns `MISSING_TICK` for one frame/one audit tick/zero references; no engine was involved. |
| Tape engine/camera/benchmark identity, reference length and content provenance were not fully checked. | Replay provenance gap. | Observed added engine/camera/benchmark and reference-length checks in Python/Godot; final tamper tests required. |
| Replay `command_requested.keys` stayed at empty adaptive-driver bookkeeping despite nonzero canonical strengths. | Contradictory trace authority. | Observed replay reconstructing requested action labels from canonical strengths. Canonical strengths remain the numeric authority. |
| Physics first-difference normalization retained nested process `support_id`/`blocker_id`. | Can misreport runtime IDs as physical divergence. | Reported to owner; final normalization must retain stable material identity, local points/normals and forces while removing only process identities. |
| Overall picking PASS did not explicitly classify the recorded physical first divergence. | Risk of implying trajectory equality. | Reported: input/picking PASS can remain, but a separate diagnostic physics status is required when those gates match and body/hands differ; no continuous envelope is approved. |

The parent now checks the full cleanup state, rather than only `provider_disabled`, and requires real contact and retained-at-end for ordinary qualification rows. Negative cases must remain explicitly separate so their deliberate failures cannot become ordinary task successes.

## Remaining guard and negative-test cautions

1. **Invalid frame versus cached actuation.** A Lab early return on INVALID prevents reading a fresh frame; it does not by itself stop the independent controller and ground callbacks from applying an earlier cached intent in that same tick. Delta/tick-gap early returns also need an explicit invalid-session label. Maintain hardware isolation until cleanup, mark the tick/run invalid, and do not claim that all physical force stopped immediately unless measured. Existing supporting force is not automatically an unauthorized thruster. No solver rewrite is requested.
2. **False-zero adversary must reach dispatch.** In the first N1 draft, an invalid-aim press was only schema-validated, followed by an observation of the original no-edge tick. That does not exercise dispatch. A meaningful negative must commit an explicit invalid-aim press, observe no new target/anchor/contact/force, then release. Held state may legitimately be true while no new target exists; it must not be misclassified as a fake attachment.
3. **Abort versus normal finish.** The first N4 draft cleaned up at normal episode end with a held hand. That demonstrates finish-held cleanup, not necessarily an in-flight abort. If the same cleanup function is used for both, record the actual abort branch and verify idempotence plus subsequent normal live focus release.
4. **Environment fields.** Provider checks cover viewport size/transforms, window size/mode, camera identity/projection parameters and bindings. Initial screen/DPI/scale are recorded separately; if these may change during a run, either extend the identity check or explicitly classify that part of window/environment isolation as untested. Do not claim a DPI invariant from an initial-only sample.
5. **No hidden invalid-to-live fallback.** Rejected/INVALID providers must retain input ownership until cleanup. Otherwise an OS key pressed during the rejected tick could become normal gameplay authority before the run terminates.
6. **Schemas and tape failure paths.** Malformed types, missing reference rows, unsupported action edges, wrong source/engine/Hz/camera identity and incomplete capture must reject explicitly before playback. `make_tape` must not mint a reusable tape from a failed runtime/capture receipt. The final parser tests should cover these pathways without relying on source code inspection alone.
7. **Human disturbance scope.** A command-line attestation or synthetic `Input.parse_input_event` test does not establish that a person actually moved/clicked/switched windows in every V0-M/F run. Record actual observed disturbances/focus and their scope; otherwise those cells remain incomplete. The spec does not authorize inventing human observations.

## Prospective disposition

The minimal architecture is compatible with the physics constraints, subject to fixing the false-success/provenance issues and proving the final guards. No evidence warrants changing strength, anatomy, contact logic, geometry, ground force or hybrid route.

The source was **not frozen during this review**. Reported fixes need final-byte confirmation and the owner's scheduled parser/negative/live regression evidence. The specialist has not granted `GO_INPUT_REPLAY`. Only a frozen explicit-aim tape, all required per-tick input/projection/material evidence, honest focus-cadence classification and the scoped matrix can support that decision. Search, holdouts and other evaluator capabilities remain closed.

## Final source reread within this review

The owner's subsequent changes were read again. The following are now present in source, rather than only acknowledged:

- Pre-ready `virtual_input_arming`, plus the explicit debug/CLI activation gate.
- Runtime-paused/tree-paused rejection and explicit provider invalidation for delta/gap failure.
- Equal nonempty lengths for frames/reference/audit, engine/camera/benchmark validation, rejection of minting a tape from an unaccepted capture, and matrix requiring frozen tapes.
- Replay requested-action labels derived from canonical strengths.
- Current-chain load/retention reset and first retained timestamp; actual task result no longer unconditionally false.
- Parent validation of task contact/retention, published invariants and full cleanup fields.
- Removal of nested process support/blocker/collider IDs from the diagnostic physical comparison, while preserving material geometry/forces, and a separate `physics_status` that does not confuse picking PASS with physical trajectory equality.
- N4 now triggers a labelled abort after 1.4 s with actual held attached support, uses normal cleanup and compares only the valid pre-abort prefix. N1 now dispatches invalid-aim press/release and explicit valid top-left press/release on dedicated ticks, as reported by the owner; runtime negative receipts remain pending.

No further source-level physical bypass was found after this reread. This is sufficient to proceed to the owner's bounded tests/freeze, **not** to grant the runtime qualification decision. The owner reports 24 existing regression processes / 884 checks passed, plus 21 Godot and 11 Python contract checks; this specialist did not execute those suites.

For the final evidence, distinguish repeatability of a newly selected reference face from correctness of the known underside test. If source capture60 itself selects front `+Z`, repeating that face does not demonstrate that intended underside `-Y` coverage was solved. Record original/resolved material point, request reach margin and initial static reach as read-only observations. No new force or target-selection rule is requested. Screen/DPI coverage and real human V0-M/F activity remain evidence limits, not reasons to silently broaden this supported catch-only implementation.
