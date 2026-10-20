# Frozen comparator, frame chronology and first rendered gate

Date: 2026-10-20. Read-only specialist review; no engine run or source modification.

## Identity and scope

New campaign: `requal_20261020_r1`; frozen commit `036a9dc719baef92d9dc41408e20d90ce50bad85`, with280 recorded public source hashes and a clean identity in `source_identity.json`. Wrapper SHA-256 is `267b78294c1bd4d9d16a0a72dec0f0dcd91497ae3b4a1ccc1bf7cb89b7351c77`; protocol SHA-256 is `0979e60d1807869182c23fc4578889996755119132a545faf0a4d7d3b22832e1`.

The new wrapper now supplies the explicit campaign identity and human lead-in. New corrected-source captures are used; the earlier diagnostic-derived tapes are not qualification sources. The old NO_GO and outputs remain separate historical evidence.

This review covers `layered_comparison.py`, its seven authored unit cases, wrapper sequencing, and the seven baseline attempts completed when reviewed. It does not certify pending human conditions or all physical state channels.

## Anchor-chain normalization

The comparator maps each hand's first-seen runtime anchor to a local ordinal, retaining state, stable support key, exact local point and local normal. It does not require runtime integers to match across processes. A later new anchor receives a different ordinal, even at the same point.

This is appropriate for the current controller, which creates a new anchor for a genuine new selection/regrip. The ordinal begins when that anchor first appears, including pending REACHING; it is therefore a **selection-anchor identity**, not by itself a proof of load-bearing retention. State and actual contact/load/retention evidence remain necessary. The comparator's replacement test checks that an additional anchor in one run is detected.

No authority to merge drop/regrip episodes or ignore material-coordinate differences is granted. A future implementation reusing one anchor object across distinct grip episodes would need an episode-aware mapping; that is not an observed current mechanism or an authorized change.

## Frame chronology and layer scope

Independent reading of all2,933 recorded POSTs from the seven attempts found:

- Consecutive row ticks starting at1, with matching requested and effective frame indices.
- Exact requested/effective canonical values in every row, including the rejected rendered run.
- Actual row phase consistently `post_control`.

The layered report labels the first four layers `pre_control` because those input/camera/pick values originated in the pre-input callback. They are read back from POST snapshots; this label must not be described as an independently sampled PRE snapshot or as Jolt post-solver.

The physics layer compares selected body pose/COM/velocity/spin/mass, published force budgets and hand state/force. It is not a comparison of every foot contact identity, native collision manifold or internal solver cache. Its output is explicitly exact numeric diagnostics, with no approved continuous-error envelope or cross-Hz equality requirement.

Count mismatch yields `MISSING_TICK`, even though the available common prefix can still be examined. The first recorded difference in every layer is retained, then the earliest overall field is ordered by tick and layer. A physical difference is not hidden merely because picking otherwise passes. This is an observation order, not proof of causation.

## Observed headless baseline

All three H120 and all three H60 repetitions passed the existing and layered contracts with first-overall null. They exercised corrected JSON admission and exact recorded input/picking/anchor/selected-physics-field replay within each frequency.

Those are six positive headless repetitions of the specified task and sampling mode. They do not establish rendered or hardware-interference equivalence and do not qualify unrelated one-hand, mirrored or continuous metric domains.

## First rendered rejection

Attempt: `baseline/attempts/V0-R_120_r1_f2b1ab4d`, under `builds/eval_virtual_cursor/requal_20261020_r1`.

The first strict gate is at tick282 in the destination pick:

- Input and cursor layers have no difference across the full536 ticks.
- Pixel `[1080.12780761719,450.161193847656]`, ray origin, winning offset `(0,0)`, recorded pick camera pose and the complete4×4 camera projection matrix are exactly equal.
- Expected direction is `[-0.114437021315098,0.145538344979286,-0.982712030410767]`; actual is `[-0.114437118172646,0.145538330078125,-0.982711911201477]`.
- Direction-vector difference norm is `1.54318774049e-7`.
- Both real queries select stable collider `catch`, shape0, underside normal `[0,-1,0]`. There is **no underside-to-front face change** in this attempt.
- Selected local-point difference norm is `8.10710818482e-7 m` (approximately0.811 micrometres). Its X component differs by about0.656 micrometres.
- Contact resolution is not applied; this is not an anatomical clamping change.

The layered first ray/material difference is282; first published force-budget difference is440; linear and angular velocities first differ442; source-body-pose metadata first differs443; COM first differs449. The task still records real contact440, sourceFREE455 and retention527, on the intended underside and beyond static reach.

The strict preregistered contract therefore correctly rejects the run as `CONTACT_SELECTION_DIVERGED`. A successful physical task does not erase that gate. Equally, the numerical ray/material mismatch must not be presented as a gross wrong-face failure, recurring cursor contamination or demonstrated Jolt nondeterminism. No new tolerance was introduced to rescue the attempt.

### What is known and what is not

The initial environments differ in declared backing-window state despite the common logical viewport1920×1080 and identity canvas transform:

| Environment | Headless source | Rendered attempt |
|---|---|---|
| Window size |1024×576 |1440×810 |
| Final viewport transform scale |0.533333361148834 |0.75 |
| Window mode |1 |0 |
| Display server |headless |Windows |

These are recorded contextual differences, not a measured explanation. Equal serialized node pose and projection matrix do not necessarily expose every internal camera transform/cache or every projection conversion used by native APIs. Additional effective camera/viewport state is a possible residual; **its causal role is unproven**. The observation does not authorize changing camera code, window sizing, solver, geometry or numeric thresholds after freeze.

## Disposition and bounded diagnostics

The primary campaign has reached its hard picking gate: six accepted headless runs and one rejected rendered run. Qualification must not resume or average that failure away; the remaining primary cells stay not run under this frozen decision.

The owner's proposed four direct comparisons—render60, human mouse/focus disturbance at120 and60, and an additional quiet render120—are acceptable as **DIAGNOSTIC_ONLY** under the renewed user's explicit comparison request and the new prospective protocol. They must use the same frozen source/tapes, preserve failed comparisons and not become completed V0-M/F/n3 cells. A quiet repeat is useful for observing whether the tiny render difference repeats; it cannot explain a cause by itself.

Human-versus-quiet-render comparison should be retained in addition to each attempt's comparison against the headless source. Any conditional equality applies only to that observed pair; it cannot override the original headless/render rejection. Initial focus tick0 and activity in the no-world lead-in remain distinct from genuine ACTIVE interference.

No final human-condition or physical safety signoff is issued here. The current qualification outcome remains negative at the strict gate; the later final review must include the explicitly labelled diagnostic outcomes and missing coverage without claiming ML readiness.
