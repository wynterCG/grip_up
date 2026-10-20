# VC0 — independent input/physics authority audit

Date: 2026-10-20. Scope: prospective review for v1.3.2a, without engine execution or source edits. The full supplied `GRIP_UP_Virtual_Cursor_Isolation_Spec_v1_3_2a_EN.md` was read. Skills consulted: input-systems and godot-physics. Implementation ownership remains with the root agent.

The parent reports canonical baseline `0be1667310a62d66ac2c30b9aa5bbe632d81593d`, clean on E. This review reads the C mirror; it does not independently claim a Git clean-tree check. Earlier v1.3.2 evidence remains immutable. No claim is made that host activity caused its failures.

**Prospective conclusion:** a narrow input-only seam is feasible. Replacing only `pointer` or injecting `Input.parse_input_event` cannot establish isolation. The minimum implementation needs event guards, held/action accessors, focus and UI guards, and authoritative evidence readback. Camera scheduling remains a separate possible failure even after input isolation succeeds. No runtime `GO_INPUT_REPLAY` is granted by this audit.

## 1. Participating source and hidden readers

Line locations refer to the baseline bytes listed in section 7, before the root's implementation. All `Input.*`, mouse-position, `_input`, `_unhandled_input` and related focus/UI occurrences under `features/grip_up/scripts` were searched. There is no `get_mouse_position()` call in these participating gameplay scripts. Absence of that getter does not mean absence of hardware authority.

| Source / baseline location | Existing authority | Narrow hook or explicit exclusion | Owner |
|---|---|---|---|
| `grip_up_lab.gd:437–478` `_input` | Escape/settings; pointer overwrite; MMB release; launch release; rebinding; physical hand release | In V0, reject hardware events before any of these effects and before GUI delivery. Route virtual edges through the same gameplay actions, not an extra physical request path. LIVE branch unchanged. | Root |
| Lab `480–528` `_unhandled_input` | Click-to-resume; Space charge; pointer and relative motion; orbit/dolly; hand request; reset/debug/fixed-beam | Same V0 guard. A virtual frame must not also cause these handlers to dispatch a duplicate grip. Preserve explicit action ordering, including motion/orbit before edge selection when declared. | Root |
| Lab `576–586` | Physical grip polling cancels buffer and persistent REACHING | Use effective per-tick held state while V0 owns input. Otherwise a real release can cancel a legitimate virtual pending attempt even if aim is isolated. | Root |
| Lab `588` | `Input.get_vector` feeds ground movement | Read equivalent source values without changing motor or the historical consumption phase. W has **negative ground Y** here. | Root |
| Lab `590`, `593`, `600`, `613`, `618` | Legacy action strengths, swing routing, traversal routing | Source-aware reads. Profile4 traversal W is **positive Y**, opposite to ground's input convention. Do not pass one vector to both without the existing sign conversion. | Root |
| `climbing_input_router.gd:87–103` | `Input.is_action_pressed`, strength, axes; per-action cached swing directions | Optional effective-input accessor/snapshot, default absent means original Input reads. Preserve action strength, diagonal limiting and the per-action gesture latch; do not rotate a held gesture afresh after camera movement. | Root |
| Lab `1532–1535`, `1549–1550` | Hold-mode transition and `_held_grips()` poll physical held state | Use the same effective held authority, including transition-time calls, not just the main physics loop. | Root |
| Lab `1555–1564` `_control_owner` | UI visibility, orbit, viewport boundary and **real GUI hover** | Under V0 derive owner from explicit frame/session policy and locked UI. `gui_get_hovered_control()` is a hidden hardware-input route even when pointer is virtual. | Root |
| Lab `161–206` window signals | Mouse boundary, focus enter, **focus exit releases grips**, resets router, cancels launch and releases global actions | V0 records external focus/boundary separately and does not run LIVE release cleanup while valid ticks continue. Genuine pause/suspension invalidates the run. LIVE behavior must still release immediately as before. | Root |
| Lab `181–187` size change | Resets contextual input; viewport identity changes | During V0 abort/mark environmental non-comparability before another request. Never clamp or rescale aim to salvage a run. Keep normal LIVE resize behavior. | Root |
| Lab `145–155`, `1566–1589`, `1690–1702` | Startup creates profile2, calls mouse capture; profile change/visibility/exit changes mouse mode | Arm the test policy explicitly before `_ready`/world startup can apply capture. Do not warp or periodically recenter hardware. Disabled ordinary startup remains profile2 and retains capture behavior. | Root |
| Lab UI `1111–1118`, `1146+`, `1253+`, `1500–1523` | Buttons/selectors/spinners/LineEdit signals can change scene/profile/flags/tuning/bindings, ratings or settings | Guard GUI delivery and/or recursively lock interactive controls during V0. An `_unhandled_input` guard alone is too late for GUI controls. Direct programmatic scenario configuration remains declared setup, not a hardware UI event. | Root |
| Lab `257–258`, `200–205` | `Input.action_release` on reset/focus affects global Godot action state | Virtual cleanup clears virtual state and performs normal physical release/cancel APIs; do not depend on global action injection for isolation. Separate any legacy cleanup from virtual authority. | Root |
| `hybrid_mantle_controller.gd:159–172` | Polls physical grip/contract for rearm and commit, priority -30; reads settings | Catch-only V0 may require this module absent/disabled and reject a session that enables it. Broader hybrid isolation needs optional source-aware action reads and focus handling; otherwise `INPUT_ISOLATION_INCOMPLETE`. No motor/route change is authorized. | Root; additional hook only if explicitly included |
| `mantle_support_coordinator.gd:136` | Physical grip buttons participate in `no_hands`, affecting completion/stance | v0.8 module absent in catch baseline. Explicitly exclude it or use the same input accessor if a later supported V0 case includes it. Its physical allocation must remain untouched. | Root; otherwise excluded |
| `ground_locomotion.gd:38–148` | No global Input reader. Consumes stored `move_intent`, camera, contact and physical states | No force/solver hook needed. Audit which frame supplied `move_intent`; do not silently repair an old input-delay behavior. | Root input integration only |
| `climbing_camera.gd:25–52` | No global Input. Lab calls orbit/dolly; `_process` follows interpolated body and smooths with render delta | Reuse orbit/dolly. Record actual camera immediately before each pick. Do not freeze/reset camera transform each tick to force equality. Any alternative evaluation camera-update phase must be explicit, guarded and versioned. | Root; prospective reviewer |
| `grip_targeting.gd:3–15` | Uses passed camera/pointer, seven real rays and collision mask3 | **No edit required.** Preserve this canonical selection method. | Protected |
| `climbing_controller.gd` | No global Input reader found; normal request/finite reach/actual capture/force authority | **No edit required.** No virtual-input authority enters physics state. | Protected |
| `contextual_arm_input.gd` | No global Input. Profile2 consumes event-relative motion and camera basis for anatomical free aims and effort | LIVE regression only; a default-off V0 implementation must not alter its event semantics or gesture signs. | Protected; Root Lab guards |
| `evaluator_reliability/scripts/physics_snapshot.gd:89` | Diagnostic `hand_held` still reads global Input; focus is hardware | Do not modify historical reader. New V0 evidence must distinguish effective virtual held state from hardware held/focus, or adapt a copy of its result explicitly. Otherwise a correct replay can be falsely reported as contaminated. | Root new feature |

`biped_preview.gd` has an `_unhandled_input` for its independent preview scene. It is not loaded by the gameplay Lab. The optional locomotion test UI/mastery course and old evaluator drivers also inject/release Input; they must not be mounted or run concurrently with V0. `project.godot` has no autoload reader. The ordinary bindings are action-based and may be loaded from `user://controls.cfg`; the actual mapping must be recorded and frozen for each session, not overwritten with hardcoded assumptions.

## 2. Existing order and minimum causal guard

Source-observed order, not a measured post-solver guarantee:

1. Lab `_ready` builds camera/UI, loads ordinary test0, then applies default profile2. An evaluator later opens profile4.
2. Hardware `_input` can update pointer, menus, releases and launch. GUI controls may receive events; `_unhandled_input` then selects contacts and updates camera commands.
3. Where enabled, hybrid runs at physics priority **-30**, v0.8 coordinator **-20**, ground in profile4 **-10**. Lab and climbing controller use default priority0, with parent Lab preceding its world children in the current tree. Ground therefore consumes `move_intent` assigned by an earlier Lab callback; it does not currently obtain Lab0's new value first.
4. Lab0 updates held/pending authority and controller intent; controller advances its existing physics requests. The named evaluator PRE/POST hooks bracket callbacks but are not asserted to be Jolt post-solver.
5. Camera `_process`, priority50, follows `torso.get_global_transform_interpolated()` with render-delta lerps. Lab `_process` independently samples a visual preview candidate. `request_hand` **recomputes** the authoritative candidate when a grip edge is dispatched.

A V0 frame must be committed once before the earliest participating consumer. A guarded early input callback is reasonable, with duplicate/missing-tick assertions. That requirement does **not** authorize moving ground force evaluation or changing its historical intent latency. Commit availability and gameplay consumption timing must be documented separately. Reuse `request_hand` for actual selection and normal release/launch/camera entry points; do not call it from both an injected event and a frame edge.

Live default behavior deserves a separate guard: migrating all LIVE event edges into physics ticks would change event-to-request timing. Prefer a default-off branch preserving the existing live dispatch, or demonstrate equivalence before changing it. The canonical V0 frame can be an input-source contract without refactoring unrelated controller behavior.

### Camera and seven-ray detail

Targeting tries ordered offsets `(0,0)`, `(12,0)`, `(-12,0)`, `(0,12)`, `(0,-12)`, `(8,8)`, `(-8,-8)`, and selects the first ray hitting a grippable real collider. An occluding nongrippable solid wins each individual query but the sampler may proceed to another ray. A central input ray must not be labelled as the winning physical ray when an offset supplied the hit.

Without modifying targeting, logging the input ray and actual material result as distinct fields is truthful. If winning offset/rejection details are unavailable, say unknown; do not invent them from the central ray. Preview data from `_process` cannot substitute for the actual grip edge's selection result.

Camera follow remains render-dependent even with identical orbit/dolly commands. Hence the prospective order is input equality, then actual camera/projection equality, then ray and material identity, then physics. A camera mismatch is a valid negative outcome of this patch. It must not be hidden by writing a historical camera pose each tick or feeding the desired world anchor into a second picker.

## 3. Input ownership contract recommended

- Explicit DISABLED/ARMING/ACTIVE/FINISHING/INVALID states, session and tape identity. A pre-ready test-only guard must exist before capture/focus/GUI side effects; no implicit activation by file presence/plugin.
- Store immutable, finite viewport-local aim with a separate `aim_valid`; `(0,0)` can be valid only with that explicit bit. Invalid aim cannot create a new target. Existing held target preservation and release remain existing gameplay rules.
- Held states, edges, MMB orbit state/delta, ordered wheel steps, move actions and action edges are separate. Validate edges against preceding held state. Consume them once. No hidden Input polling may supply missing fields in ACTIVE.
- Existing legacy zero prelude is ambiguous. Do not fill it with viewport centre, a cached physical pointer or a chosen first target. Produce a newly identified explicit-aim tape, or reject `LEGACY_POINTER_AMBIGUOUS` if provenance cannot establish validity.
- A frame supplies **pixels/actions only**. Its playback cannot carry authoritative collider IDs, world target coordinates, normals, grip state, force or body pose. Expected material identity may exist only as an audit oracle after the real selection.
- Hardware aim/focus/events are bounded diagnostics, never fallback values. Ignore hardware events before `_input`, GUI or `_unhandled_input` can mutate gameplay, while leaving the operating system free for the user.
- Physical focus loss remains a live safety release. V0 focus loss records external focus and continues only while actual ticks and scene/camera/viewport remain valid. Real suspension/tick gaps are environmental failure, not invented simulation time or a forced clock change.
- On finish/abort release virtual holds through normal game input APIs, clear virtual edges/gestures/camera deltas and remove authority idempotently. Do not leave a virtual hold latched in LIVE or synthesize a fresh physical press on return. Verify normal focus-release and subsequent genuine press behavior.
- Reject or disable all lab controls that could change a measured scene/profile/binding/parameter. `_control_owner` must not inherit real hover. External window close, resize or camera disappearance can invalidate/terminate the session honestly.
- Leave physical controller, feet, supported swing, force budgets, geometry and static hybrid1.15 s route unchanged. If a case includes hybrid/v0.8 without source-aware action readers, reject it as unsupported instead of claiming isolation.

## 4. Prospective qualification and first-divergence decision

The spec's fixed budget is approved as **24 qualification runs**: four conditions H/R/M/F × two frequencies × three repetitions. This is 24 runs total, not 24 cells each repeated three times. Up to four directly related negative/diagnostic physical runs may follow a hard gate, as prospectively declared. Pure parser/frame tests and existing safety regressions are separate recorded activities, not replacement qualification repetitions. Required adversarial checks must be mapped to those activities before execution rather than expanded indefinitely after failure.

Use a new `benchmark_eval_virtual_cursor_v1` and explicit-aim tape; never mix V0 with legacy R0/A score data. Keep three repetitions of each same-Hz condition tied to source/scene/bindings/viewport/camera seed and setup identity. A condition requiring external user activity is only covered when that disturbance is genuinely observed/recorded; a synthetic injected event alone is not proof that the person moved the mouse or switched windows. If no disturbance happens, report incomplete coverage.

Prospective ordered classification:

1. Schema/source/engine/scene/viewport/setup disagreement: environment/identity rejection, before simulation comparison.
2. Missing/duplicate/out-of-order tick or frame: `MISSING_TICK` / `DUPLICATE_TICK` / source mismatch. Preserve actual step cadence; no reindexing to align outcomes.
3. Requested/effective canonical input or edge sequence mismatch: `INPUT_SOURCE_MISMATCH`. Exact equality after **predeclared representation normalization**, not post-hoc cursor tolerance. Finite Vector2 float conversion/JSON round-trip must be canonicalized once and unit-tested; do not compare float64 authored values to float32 readback as if an undocumented epsilon were an approved input envelope.
4. Same effective input but camera/projection/viewport differs: `CURSOR_OR_CAMERA_MISMATCH` or environmental non-comparability. Log the first field/tick and bounded surrounding frames.
5. Same input/projection but different real collider face/material contact: `CONTACT_SELECTION_DIVERGED`. The known underside `-Y` versus front `+Z` case must stay explicit. A successful later attachment cannot erase this failure.
6. Only after those gates match may divergence be labelled `PHYSICS_DIVERGENCE_AFTER_MATCHED_INPUT_AND_PICKING`. No global 15 cm envelope, causal claim about Jolt or cross-frequency identical-tick comparison is approved.
7. Real pending, contact, admitted load, source release and same-anchor retention are separate fields. A process completing, or a contact lasting one tick, is not the Swing & Catch task gate.
8. If focus suspends actual ticks or invalidates the environment, label that condition separately and do not award input-isolation PASS from an incomplete run. No input abstraction can prove background scheduling by itself.

Final decision is only **GO_INPUT_REPLAY** or **NO_GO_INPUT_REPLAY**, scoped to observed supported cases. GO does not reopen ML, holdouts, M7 or continuous trajectory ranking. One-hand60, mirrored clearance and other incomplete v1.3.2 domains remain open.

## 5. Physical authority review conditions

No physics edits are needed for this task. The existing pipeline must still perform candidate raycasts, normal controller requests, finite hand gesture, current contact validation and material-local anchoring. The input provider may request a hand; it may not set ATTACHED, rewrite an anchor, infer grip force from a button or command a body pose.

During runtime review I will check actual post-budget hand force is zero while REACHING, current anatomical reach and resolved-vs-original selection fields, admitted contact/load and retained identity, real feet/ground contributions, and ownership tags for any hybrid phase. Existing invariants stay12 kg, reach0.65708 m,360 N hands,180 N feet/120 N each,20 Nm assistance,150 Nm resultant climbing moment; no tuning/control change is proposed. Static supports in a catch case do not independently qualify dynamic reaction conservation.

The final safety review must compare profile2 normal startup, bindings and saved controls, hold-to-grip, contextual mouse effort, MMB/wheel behavior, real focus cleanup, settings/rebind/reset UI, ground walk and virtual cleanup. Export/release must not acquire provider authority. A gamepad action read is covered by source selection only if all Input polling truly uses the effective frame; this audit does not assert tested gamepad support.

## 6. Open risks before implementation

1. Event guard applied only in `_unhandled_input` leaves `_input` and GUI mutation paths open.
2. Virtual aim plus physical `_held_grips`/pending polls still permits dropped grips.
3. Focus and GUI hover can change owner or release hands even with exact pointer pixels.
4. Input evidence can falsely report hardware held states unless the frozen old snapshot reader is adapted in the new lane.
5. Early provider availability must not silently change ground input latency or live event timing.
6. Render-dependent camera follow may still change the actual ray and selected face; input isolation alone is not picking qualification.
7. Baseline catch excludes hybrid and v0.8. Leaving their Input readers untouched is acceptable only with explicit case guards and limited claims.
8. Legacy pointer zero is not a usable explicit initial aim without new provenance.
9. External interference and external suspension must be distinguished from deliberate virtual camera/menu actions.

## 7. Baseline bytes read

| File | SHA-256 |
|---|---|
| `project.godot` | `6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9` |
| `features/grip_up/scripts/grip_up_lab.gd` | `4816cfda13bb74d4b676f678107dcb579c67a382f98768abd2ffd9e849a8155c` |
| `features/grip_up/scripts/climbing_input_router.gd` | `907b9e787a506b15347391e3843a04a86a3458bf66f7414d6b70402424c2344b` |
| `features/grip_up/scripts/climbing_camera.gd` | `104ce1d619513388b5a849311d2fde47b1ae5a93e9822ed9d6803a80f9edd1ef` |
| `features/grip_up/scripts/ground_locomotion.gd` | `26178a4b0bd0083f20a4ecf82a501f3b56815ac561f40aeb994b530f99b91798` |
| `features/grip_up/scripts/grip_targeting.gd` | `b624a011f4e767f613484cff50a70c02240cd6fc70ed47af0835202c8647dc5c` |
| `features/grip_up/scripts/climbing_controller.gd` | `1e7a5add7ae2372bf9adaca0d8e4827689407f0b2cd7539afb30a844b1e333c4` |
| `features/grip_up/scripts/hybrid_mantle_controller.gd` | `00579a4030cf23a17e498c32cace29a4a72b83c56dfcb8dee6a828ac528808bd` |
| `features/grip_up/scripts/mantle_support_coordinator.gd` | `bd43a9d5f3ba93ecf0a43ab8135b8e4d58be9cc21df370a74fb33c64fe136156` |
| `features/evaluator_reliability/scripts/physics_snapshot.gd` | `c8f873f2908067f449edfc7a7c98cbfd6cc21f7fc96c142a9c38202720745f85` |

All changes in this specialist task are confined to this new document. Runtime isolation, warning-free import, regressions and physical qualification are pending the implementation owner's scheduled evidence.

## 8. Prospective approval of the proposed V0 camera phase and query audit

After this audit, the implementation owner proposed retaining historical ground-10 / Lab0 input latency and the immediate LIVE event path. V0 commits its frame and dispatches normal edges at an earlier test-only callback. Hybrid/v0.8 and profiles other than4 are rejected before arming. Those scope guards are acceptable and avoid changing unrelated physical readers.

The proposed `V0_PHYSICS_FOLLOW` camera mode is **conditionally approved as a new test sampling contract under spec sections5/6**, not as a gameplay camera-feel change or proof of a unique historical cause. It must reuse the existing follow/smoothing, velocity look-ahead, orbit/dolly limits and obstruction query equations. Its only intended differences are noninterpolated current body pose as the evaluation source and one fixed-physics scheduling point before picking; render `_process` must not also advance this camera while V0 owns it. No captured camera transform, desired world contact or destination may drive the follow. Record mode, source pose, phase and actual delta. The original LIVE interpolation and render-priority50 path must remain unchanged by default.

Because this changes both input isolation and camera sampling relative to historical R0, V0 success cannot retroactively prove which one caused an old failure. Same-Hz V0 comparisons use this new, explicitly named phase consistently. Normal body input axes continue to use the actual current camera as before; there is no new body force source.

An optional diagnostic hook in `grip_targeting.gd` is also conditionally approved: it may record only the queries already executed, without changing offsets, order, masks, exclusions, hit eligibility, first-hit selection or the existing break. Do not run the remaining rays after a winner merely to populate a seven-ray report. Default OFF preserves the existing path. Copy the authoritative request's diagnostic result immediately so a later visual preview call cannot overwrite its identity. This is an approved read-only instrumentation diff to the previously protected selector, not permission to alter target selection.
