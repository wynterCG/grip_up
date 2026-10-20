# v1.3.2 independent physics review - prospective contract

Status: PROSPECTIVE / NO PHYSICAL OUTCOMES YET. This review and the fixture registries were written before any new fixture measurement or tape qualification. No engine was launched by this specialist. Nothing below claims successful preparation, clearance over an unobserved future path, search readiness or human enjoyment.

## Preservation and source scope

The full user specification `GRIP_UP_Evaluator_Qualification_Spec_v1_3_2_EN.md` was read. The reported canonical baseline is `0f1a4bf7c6c74c381301475bfcbc18f686e094aa`; the measured v1.3.1 implementation is `24b18d760604fffe3455c5b4c9b8b72f37577b4d`. These are distinct identities. The parent owns Git/engine execution/canonical synchronization. In the C mirror, all 815 entries in `builds/eval_v132/baseline/freeze.json` were independently read and SHA256-checked: zero differences at this preparation boundary. This check does not inspect private holdout outcomes.

Specialist additions are limited to new files in `features/evaluator_qualification/fixtures/`, the three named r1 fixture/preparation/scenario resources, and this specialist document directory. Gameplay controllers, mass, shapes, forces, old drivers, historical catalogues, project settings and prior evidence are untouched. Parent-owned new qualification driver/catalogue/Python changes are a separate part of the same evaluator revision.

The 12 kg single physical body, unchanged compound proxies, acquisition R approximately 0.65708 m, 360 N shared hands, 180 N shared feet / 120 N per foot, 20 Nm shared assist and 150 Nm combined moment remain mandatory. Existing A0 values remain .25 / .12 / .24 / .9. The new fixture creates ordinary static supports only; no joint, spring, adhesion, body-force or contact-state actuator is added.

## R0, R1 and phase review

R0 is the appropriate required implementation. Replay real action holds/releases and mouse/camera input at frozen physics ticks. Do not unproject a historical target through the new live camera and call that identical cursor replay. The source trace must retain both requested and accepted chronology, actual bindings, focus/UI ownership, actual ray hit/material-local point, hand endpoint/state/load and camera. Equal tape bytes establish requested-input identity, not accepted-input or contact identity.

The existing app input route reads `router.traversal_input()` and calls `controller.set_traversal_input(...)` in `grip_up_lab.gd`'s physics callback. The controller exposes that setter, but this alone is not an audited accepted-command injection seam: the app can overwrite it in the same tick, native walking uses its own Input-derived move intent, and hand requests pass through targeting and validation. Inserting a new callback, changing gameplay process order or suppressing the app would create a different test path. Recommended R1 decision: UNSUPPORTED_SEAM / NOT_USED for this scope, rather than claiming a shortcut through a public setter is equivalent to the complete route. Never reuse recorded ATTACHED or a past ray hit as authority.

The v1.3.1 shared probes/clock handshake/lifecycle should remain the truth source. Input is emitted before existing physics callbacks, observations read direct state at a named post-control hook, and no hook is called post-solver merely because it follows the controller. Actual delta must match requested Hz before any world construction. Every world must be constructed at the same post boundary after synchronous retirement of old physical subtrees. A 60 Hz and 120 Hz sample represent different integration intervals; do not require same tick number or identical trajectories across them.

Stop/neutral/brake/reverse onset is the actual raw accepted command tick, not its proposed tick and not the filtered intent tail. All initial bands must be checked again there. The .25 s quiet confirmation means elapsed intervals `(current_tick-first_quiet_tick)/Hz`, not N samples spanning only N-1 intervals. A stable-interval start time of zero is valid only after its future confirmation window has actually been observed.

## New symmetric clearance fixture r1

Authoritative public data: `features/evaluator_qualification/resources/fixture_registry_v132_r1.json`. It names two conditions, `qualification_mirror_v1` and `qualification_onehand_v1`, sharing geometry `symmetric_clearance_r1`. Both are new conditions, not silent replacements for an old level or the historical Hang/underside fixture.

| Part | Position / bounds (m) | Size / condition |
|---|---|---|
| Initial body | (0, 1.17, .4) | Existing arena8 spawn exactly |
| Wall | center (0, 2.1, -.2) | (4.8, 6.8, .4), front plane z=0 |
| Hand contacts | x=-.24 / +.24, y=2.1, z=0 | Real free points on that same wall |
| Four foot ledges | x=-.45 / -.15 / +.15 / +.45, y=.51, z=0 | Each (.24, .16, .22), top .59 |
| Initial spawn pad | x[-.24,.24], z[.32,.80] | top .25, bottom -.05 |
| Lower safety floor | center (0,-1.4,0) | (10,.3,8), top -1.25 |
| Initial camera | yaw0, elevation-.06, distance6 | Original follow behavior continues |

Geometry is exactly symmetric in X, without a negative-scale rigid body or reflected collider basis. Mirrored acquisition orders retain left/right hand IDs explicitly: first retained hand, then the other where needed; mirror the A/D command and measure in reflected local support coordinates. Do not equate opposite world-axis signs with identical contact histories. The original biped/feet implementation may still exhibit real bias; the fixture does not force equal trajectories.

The small spawn pad enables ordinary collision-backed acquisition. It remains physically present for the whole trial. The lower floor and pad reduce the historical broad-ground exposure, but are not an analytical promise that no pose can collide. A later real pad/floor event is a genuine interruption, never a reason to remove the pad, suppress its collider or continue crediting climbing. The wall/footholds remain normal native collision surfaces.

The one-hand condition is specifically a wall/B1 entry, not a repair of the old single underside bar. If it qualifies, that establishes only its named geometry/support condition. The old one-hand 60 Hz missing coverage remains historical and cannot be relabelled successful.

## Construction and clearance API

`qualification_fixture.gd` provides `static apply(app, definition) -> Dictionary`. Call it from the new driver after opening ordinary arena8 and before the first physics await/step. It rejects step/time already advanced, nonzero velocity/spin, active hands, unexpected freeze/hybrid authority, unknown fixture and a different initial spawn. It synchronously detaches the old level, creates the data-driven replacement, and returns its registry hash and receipt. The same torso, Resource, mass, velocities and collision proxies remain. The spawn must already match, so the function writes no body pose, even during initialization. The camera's symmetric initial condition is explicitly authored; its normal behavior is not disabled. Original initialization caches are kept coherent by retaining the existing body spawn.

Construction returns NOT_YET_NATIVE_AUDITED. Empty queries in a just-built space cannot certify flushed native geometry. The parent must call `audit_clearance(app, previous_actual_body_pose)` after actual physics callbacks, including before eligibility and across the measured path. This function observes, never moves or corrects the body:

- Each original active capsule/sphere/box proxy is queried against nongrippable ground/startpad layer1, excluding the actual body RID.
- Translation segments are at most 2 cm, orientation steps at most 2 degrees, with an explicit maximum of 128 subdivisions. A missing/unsupported proxy or excessive segment returns unknown/failure, not clear.
- Starting and final overlaps are queried separately from native translation casts. A query-only margin bounded by `(proxy radius + local offset radius) * angle_step` covers proxy rotation about the body origin. Physical shapes are not inflated. This can conservatively reject a segment; it cannot authorize motion or prove a collision response occurred.
- Potential intersections retain shape, fraction and collider identity where the native API exposes it. No collider ID is fabricated from cast_motion's fraction-only result.
- Reported actual native ground contact pairs and native ground-motor force/torque/grounded state are retained separately from geometric proximity. Wall/foothold clearance is not claimed by a layer1 sweep.

Important instrumentation limit: ordinary arena8 may have `max_contacts_reported=0`. This fixture does not silently change it. The receipt exposes contact reporting and saturation; an empty unreported native manifold is not proof of absence. CLEAR_QUERIED_SEGMENT plus zero ground authority is a conservative queried-geometry condition, not a universal certificate of zero manifold contact within solver skins. If complete native manifold absence is an essential claim, classify that subclaim UNKNOWN/NOT_QUALIFIED until a separately authorized and paired observation method exists. Do not convert query-only evidence into measured absence of all contacts.

## Bounded one-hand preparation registry

Authoritative timings and ordering are in `preparation_registry_v132_r1.json`. All operations use existing real acquisition/release/key input, preserving finite hand travel, actual range/contact/load gates and smooth support transitions. `retained` maps to hand0/1 from the scenario, `other` to its complement, and target to that hand's actual fixture contact. No pose/velocity assignment, freeze, artificial impulse, hand snap or mid-run collider change is allowed.

1. P0_DIRECT_R1: acquire retained hand (max1.5 s), W1.5 s, neutral .15 s.
2. P1_DUAL_NEUTRAL_RELEASE_R1: acquire retained then other (each max1.5 s), W1.75 s, neutral .25 s, real release of other (max .3 s to verify), neutral .5 s.
3. P2_DUAL_LOADED_RELEASE_R1: acquire retained then other, W2.5 s, real release of other while W is held (max .3 s), W .35 s, neutral .25 s.

The common two-hand reference remains declared separately: acquire retained/other in mirrored order, W1.5 s then neutral .15 s. The parent executes the declared post-prep gates. Quiet full relative velocity <=.10 m/s and spin <=.20 rad/s must persist .25 elapsed seconds within 5 s. Directed stop/brake/reverse entry requires [.15,.50] m/s within the unchanged 2 s preparation bound; counter entry remains [-.50,-.02]. The other hand must have no live anchor and zero actual force, not merely a button-up request. B1 load is measured, not renamed arm-only.

Screening budget is three ordered scripts x two retained sides x two Hz x two execution modes, one first screening per cell: maximum24 attempts. First qualifying physical onset is the selection rule, not maximum movement score. Freeze the exact script ID before qualification/replay and use at least three independent repeats for any claimed primary cell. Failed scripts remain in the denominator. If all three fail, report missing coverage and stop; do not extend W durations or loosen bands after outcomes. This is bounded fixture preparation, not optimization of gameplay parameters.

## Prospective envelope and eligibility position

No continuous-score envelope is approved by this prospective review. The v1.3.1 observed 15 cm path separation or 8 cm progress range cannot become an acceptance threshold by retrospective decree.

Hard identity checks are exact: source/engine/fixture hashes, geometry values, physics Hz, profile/resource values, input phase, action/held chronology, material support identity and requested/accepted logical streams. Runtime IDs and automatic node names are process identities, not geometry differences. A numeric comparison epsilon (for example 1e-6 used by a reporter) is not automatically a physical equivalence band.

In R0, a requested, accepted, camera-target or grip-decision mismatch ends the corresponding like-for-like comparison at that tick. Physical-response equivalence after a different anchor or accepted command is not approved. Native illegal contact/authority/force is a hard failure; no event envelope can excuse it. In Lane A, different legitimate commands are part of the measured policy response and must be analysed as distributions, not forced frame equality.

At least three A0 references per actual mode/Hz/context must establish attainable onsets, matching windows and scatter. Any proposed numeric score then needs its own bounded envelope signed off before new candidate data: position/path, relative velocity, twist, contact-time quantization and stopping/censor status are not interchangeable. Separate 60 and 120 Hz baselines; do not pool modes with different accepted histories. n=3 is feasibility evidence, not a rare-failure guarantee. An unstable or biased cell remains DIAGNOSTIC_ONLY/QUARANTINED, and an unavailable one remains MISSING_COVERAGE. Binary contact safety can qualify separately from continuous trajectory metrics, without erasing genuine catch failures.

## Delivery state and independent decision boundary

New `scenarios_v132_r1.json` supplies16 named controls: clean/counter left-right, two-hand release/brake/reverse/low-energy, and left/right retained one-hand versions. The parent adds the six explicit prep-screen cells and owns the driver/runner/report integration. A 13-check pure fixture contract is supplied for the single scheduled engine worker; it has not been executed by this specialist. It tests declared symmetry/IDs/bands/budget, actual proxy-radius query bounds and rejection of construction after controller advancement.

All outcomes and envelope signoff are PENDING. The final independent recommendation may be NO_GO. No search, private holdout outcome, new gameplay default, source mutation among the815 protected files or human-rating claim is authorized by this delivery.
