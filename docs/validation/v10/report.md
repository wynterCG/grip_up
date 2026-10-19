# GRIP UP v1.0 — M0 baseline audit

Status: **M0 technical reproduction complete; human baseline assessment PENDING.**
Decision: **KEEP v0.9 unchanged for the baseline pilot.** This is not delivery or
acceptance of a refined v1.0 animation.

## Source and checkpoint

- Working project: `E:\Godot Games\grip_up`.
- Branch: `feature/v1.0-contextual-vault`.
- Recoverable baseline: annotated tag `baseline/v0.9-pre-contextual-v1.0`, pointing
  to `99eb1040ecf45c389757bd07544fda6a4a68d508`.
- Source implementation commit: `45a3120fe4609e3520e10d47fe9347deeec1e0bc`.
- User specification archived verbatim at `../../specs/grip_up_v1.0.md`.
- Existing verification and full regression evidence remain under `../v09/`.

The 334 feature files match the v0.9 SHA256 manifest in both the working mirror
and E: project. No gameplay scripts, animation resources, input, route duration,
collision profiles, default flags, or builds were changed for M0.

The spec section 1 explicitly requires: “Preserve v0.9 unmodified as an opt-in
baseline and collect a small human quality assessment first.” Automated playback
below does not meet that human requirement. A feedback request is pending.

## Fresh automated reproduction

Godot 4.7.2 / integrated Jolt, baseline feature profile, monitor 1 (screen index 0).

| Session | 120 Hz | 60 Hz | Evidence |
|---|---:|---:|---|
| Rendered MCP Pro low/high approaches, real grips, W commit, dynamic restore, native upper support, ordinary 30 cm walk | 13/13 | 13/13 | `m0/hybrid_native_*hz.json` and `m0/v09_*hz_*.png` |
| Headless saved E: project, left/right approaches and two successive ledges without resetting body | 12/12 | 12/12 | `m0/hybrid_sequence_*hz.json` and `m0/test-saved_*.txt` |

**50 fresh checks, zero failures.** These are targeted baseline reruns, not an
additional full 4,356-check certification or human playtest. The prior full
matrix remains recorded as 4,356 checks / 139 runs / zero failures in v0.9.
Current editor diagnostic query returned zero errors. Rendered scripted tests
used in-application input; no person supplied their controls or quality ratings.

The new receipts were generated on 2026-10-19 around 21:57 UTC. Both native runs
completed before their final receipts and screenshots were archived. Screenshots
cover approach, approved progress .30/.60/.90, standing, and normal walking.
They are still evidence, not a measured assessment of temporal smoothness.

## Concrete findings for M1

### Unilateral right-hand anchor mapping defect

`mantle_candidate_detector.gd` compacts `hand_anchors_world` in `source_hands`
order. `mantle_animation_driver.gd:begin` instead reads that array by anatomical
left/right index. With only right hand ATTACHED (`source_hands=[1]`), the one
supplied anchor is assigned to the left hand; the attached-right fallback then
assigns the same contact to the right hand. This can create a false two-hand
presentation. It does not create a second physical grip in the retired motor.

Both physics and animation audits independently found this source mismatch.
Existing two-hand animation fixtures do not cover it. **Not fixed in M0**, so
the baseline remains reproducible. The next experiment needs explicit hand-ID
mapping, support-local contacts, and left-only/right-only/both-hand cases.

### Reach limits constrain the release window

The certified route duration is 1.15 s. Current contact release blends over
progress .25–.38 (about .288–.437 s). The body rises during .20–.50; crossing
starts at .50 (about .575 s). Simply retaining wrist IK until crossing would
stretch arms beyond their reach.

The animation specialist's approximation from archived v0.9 native samples,
using physical shoulder positions, found low-entry shoulder-to-palm distances
growing from about .471 m at p=.319 to .703 m at p=.362. High-entry samples grew
from about .394 m at p=.304 to .623 m at p=.355 and .987 m at p=.406. The current
maximum reach is about .657 m. These are audit estimates, not a certificate for
every admissible initial posture or a justification for new global thresholds.

M1 should clarify brace and release within the actually reachable interval and
audit each real hand separately. Holding contacts longer would require a
compatible separately certified route. No timing value has been selected or
validated for v1.0 yet.

### Entry, feet, exit and authority

The authored resource has rotational bone tracks and no independent root travel.
Approved route progress drives both presentation and the swept motor. The
motor's 3 mm travel bound, original shapes, restricted native-proven outward
recovery, static-support guard, and native-ground/walking finish are retained.

Hands blend away from remembered world positions in v0.9; explicit per-hand
support-local snapshots remain M1 work. Exit clears hand targets and fades leg
IK over .18 s. Old raw foot errors after contact ends must remain labelled stale;
they do not prove a continuing planted-foot error. Tucked-foot clearance and the
vault silhouette remain visual questions for the human pilot. Existing v0.8
pure-physics top-out failure remains accurately reported as a failure.

Two further presentation findings need coverage in the next flagged experiment:
the palm-alignment modifier has one shared weight and can orient an unattached
hand using a stale direction; the exit blend selects Idle for .18 s before the
ordinary biped chooses Walk, even if physical walking has already resumed. These
are source-level findings, not a measured human complaint. Neither changes
physical grip forces. Foot IK dominates the authored leg keys after p=.15, so
editing only those keys would not reliably change the final leg silhouette.

The physics audit also identified an **unreproduced inspection risk**:
`_same_support()` is checked during `ASSISTED_TRAVERSE`, while
`RESTORE_DYNAMIC` checks sole contact, clearance and uprightness without another
explicit static-transform check. A support beginning to move specifically after
unfreeze and before native support confirmation needs an adversarial test. The
existing passing moving-support tests must not be claimed as proof of that exact
window. No runtime reproduction or correction is claimed in M0.

## Human assessment and next decision

Use `pilot.md` for three brief labelled manual sessions covering low, high,
near-stationary/off-centre entries and the two-ledge course. All ratings and
counts are intentionally blank; no automated session is labelled human.

After baseline feedback: refine the single Style V presentation in an opt-in
experiment, retain the certified body route first, and compare against this tag.
Retiming needs its own flagged A/B and new safety validation. Style C requires
repeated human-observed high/slow mismatch **after** tuning V. No classifier,
second style, altered route, or default promotion has been implemented.

This milestone adds only the archived specification, audit/pilot documents and
fresh evidence under `docs/validation/v10/`. Recommendation: **KEEP baseline;
await human observation before presentation changes.**
