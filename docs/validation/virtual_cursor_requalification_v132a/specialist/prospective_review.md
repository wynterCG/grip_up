# Independent prospective review — renewed virtual-cursor campaign

Date: 2026-10-20. Campaign proposed: `requal_20261020_r1`.

The parent reports a new explicit user authorization to run a new corrected-source campaign after the prior NO_GO. This is a new authorization and evidence set; it does not reopen, overwrite or relabel the failed historical qualification. The specialist reviewed code read-only, without running Godot or changing source.

## Scope approved in principle

New source captures at both60/120 Hz are the correct approach. Do **not** use the previous `diagnostic_only` derived tapes as ordinary qualification sources. Retain their old reports, file hashes, capture-source identities and limited diagnostic classification.

The new budget is separately declared: at most8 development physical processes and24 primary H/R/M/F ×60/120 ×3 runs. Parser-only checks and supplementary safety remain separately labelled. Any permitted post-gate diagnostic ceiling remains a ceiling for directly related diagnostics, not authority to average away a failed cell. New source/tapes must freeze before primary qualification; another edit invalidates those tapes for later qualification and must not silently recapture them.

A read-only hash comparison against the source map in the earlier d13 diagnostic artifact found changes in **only**:

- `features/evaluator_virtual_cursor/scripts/replay_input_provider.gd`;
- `features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd`;
- `tools/auto_tuning/virtual_cursor/run.py`.

The previously approved gameplay input seam, camera sampling mode, targeting, ground, controller, tunings and geometry are unchanged in that comparison. Additional comparator work announced by the owner was still pending during this review and requires final-byte review/freeze identity.

The changed provider adds bounded rejected-event detail, per-kind counts and focus observations; it does not gain physical authority. The driver adds a pre-world notice/lead-in and publishes those diagnostics. No new attachment, world-target injection, force, body-state write or solver path was found in this delta.

## Campaign identity and CLI wiring

The reviewed `execute` API accepts `campaign_id` and `human_lead_in_s`; the budget filter groups existing manifests by campaign. This is appropriate only if the actual entry point supplies those values and records them in session/run manifests.

**Finding sent to owner:** in the first reviewed revision, CLI `main` still had no arguments for the new fields and called `execute` with their defaults. That would place the run in the empty/old campaign budget and omit the lead-in. Before freeze either wire the explicit values through the CLI and session manifest, or use and hash an explicit orchestration wrapper that supplies them. A directory name alone is not the runtime campaign identity.

The campaign's evidence chain must include frozen runtime source/engine/benchmark/camera mode, explicit-aim tape file and content hashes, capture manifest/audit hashes, actual viewport and bindings. The old diagnostic compatibility escape must remain rejected for ordinary qualification. Do not call a capture adaptively authored during a primary run fixed replay.

## Lead-in timing and external activity

The proposed eight-second Label is created **before** the Lab, physics world and input provider, after which world creation still waits for the named post boundary. This does not add body forces, initialize a fictitious pose or advance an existing test body. The lead-in is preparation time and is excluded from the measured replay ticks.

Consequently:

1. Mouse/window activity during the lead-in cannot establish ACTIVE-provider noninterference. It is not observed by the not-yet-created provider.
2. If the user switches windows only during the lead-in and the world starts unfocused, the resulting run tests **started-unfocused/background execution**. This is useful evidence but not a focus transition during ACTIVE.
3. The current provider calls `focus_changed(app.has_focus())` at initialization and records it with tick0. That is an initial sample, not evidence of human Alt+Tab. Distinguish initialization from actual window callbacks, or classify it correctly in analysis.
4. To claim V0-F during-replay focus coverage, record genuine externally caused focus change(s) at measured tick>=1, plus the actual continuing tick cadence. A synthetic signal is not human evidence.
5. Rejected motion/button counts do not by themselves prove a human acted, and the game will not necessarily receive the mouse event delivered to another application. Use the actual user attestation/action interval alongside safe hardware diagnostics and focus observations; do not fabricate missing event origin.
6. If only lead-in or synthetic disturbance occurred, keep the narrower evidence and mark the intended active-interference coverage incomplete. Do not award a full V0-M/F cell solely from a command-line attestation flag.

No OS mouse warping/capture changes, window focusing automation or human gameplay ratings are introduced or approved by this review. Runtime suspension/throttling remains an environment outcome distinct from input contamination; the existing prospective250 ms wall-gap classification is unchanged.

## Comparator and physical review conditions

The existing layered order remains mandatory: identity/setup → exact requested/effective frame and edge sequence → actual camera/projection/ray → real collider/material point/normal → physical trajectory. Keep the earliest mismatch and bounded surrounding ticks, including an initial mismatch that later becomes irrelevant to the task outcome. A real catch does not erase a preceding input or selected-face mismatch.

The proposed anchor-chain normalization is appropriate if it replaces process IDs with a deterministic **within-run chain identity**, while retaining actual material support key/local point/local normal and state transitions. It must not collapse two distinct drop/regrip chains on the same material point, or treat all anchors as one constant. Validate normalization on synthetic same-chain/different-process-ID versus actual re-anchor examples before freeze. This is a comparison change and must receive a version/hash; it must not retroactively alter old comparisons.

During later review I will again inspect all published POST hand/foot/ground effort, pending-force zero, finite endpoints, real capture/load/source-release/same-anchor retention and ownership. The unchanged limits remain12 kg,0.65708 m reach,360 N hands,180 N feet/120 each,20 Nm assistance and150 Nm combined controlled moment. No universal continuous trajectory envelope or physical retuning is approved.

## Prospective disposition

**Proceed to corrected-source freeze and bounded tests after the identity/CLI wiring and comparator review points are resolved.** This is not `GO_INPUT_REPLAY`; the actual new evidence and genuine human M/F coverage are still required. The prior binary decision remains historical NO_GO. A later input-only GO would not authorize ML/Optuna/holdouts, approve the remaining evaluator domains or claim improved gameplay feel.
