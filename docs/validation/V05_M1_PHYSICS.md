# v0.5 M1 — diagnostic-only physics handoff

Date: 2026-10-19. Baseline: v0.4 snapshot `d53b43d` (2012 automated checks and37 native checks at each frequency, archived by root). M0 physical audit: [V05_PHYSICS_AUDIT.md](V05_PHYSICS_AUDIT.md).

## Scope and frozen behavior

Changed production: `features/grip_up/scripts/climbing_controller.gd` contains observational hooks only; new `scripts/transfer_diagnostics.gd` owns the journal and measurements. Added `tests/test_transfer_diagnostics.gd`. No actuator, planner, tuning, force limits, input mapping, body damping, reach, or physical state-update formula changed. No P1/P2 assistance was implemented.

The flag defaults false and acts only in control profile3. Existing profiles0/1/2 retain their behavior. The module has no force application, body pose/velocity assignment, prediction authorization, or target-planning API. It reads the existing step's applied values and observes state transitions. Final gesture travel includes the last contact segment. Applied-force samples are captured before integrity release can clear hand telemetry, so a force physically delivered on that final tick is still accounted for.

## API for root integration

```gdscript
controller.transfer_diagnostics_enabled = true # effective only in profile3
controller.transfer_event.connect(on_transfer_event)
controller.record_unselected_attempt(hand_id, "no_surface")
var compact: Dictionary = controller.transfer_diagnostics()
var complete: Dictionary = controller.transfer_diagnostics(true)
var events: Array[Dictionary] = controller.transfer_journal.events
var latest: Dictionary = controller.transfer_journal.last_by_hand.get(hand_id, {})
```

`transfer_diagnostics(false)` and `telemetry().transfer_diagnostics` are compact: `enabled`, `session`, `event_count`, `event_capacity`, `last_by_hand`, and `motion`. They omit the event ring. Explicit true adds `events`. Events and returned dictionaries are deep copies, with no mutable support/body references. The ring holds at most256 rows; live signal delivery is independent of ring eviction. Root should stream events once through the signal, and sample compact motion separately rather than writing the ring every frame.

Reset, profile change, or flag toggle clears journal/session state. Attempt serials remain monotonic over resets within one controller instance. Root's scene/session identity should namespace separate controller instances.

## Attempt semantics

Each intentional request begins a new `attempt_id`, clearing the previous attempt's failure state. An existing `hand.reason="manual"` never becomes the new rejection. Cleanup after an already closed rejection does not replace it. `ATTEMPT_STARTED` and `REQUEST_ACCEPTED` are neutral lifecycle observations.

Snapshots include time/step/hand/support identity, input and current candidate material/world points, original/current shoulder and hand positions, body pose/velocity/spin, anatomical distance/reach margin, target/actual length, observed elapsed travel and distance, currently remaining straight-line hand distance/time lower bound, observed in-range time, relative velocity/radial speed, load/capacity, and first failure code.

An empty pointer press has `has_candidate=false` and null world/local candidate and normal. No fictitious contact or anatomical distance to an arbitrary world origin is supplied. This yields `CONTACT_REJECTED` at REQUEST stage, not a physical catch failure.

| Code | Evidence / stage |
|---|---|
| `POSE_UNREACHABLE` | Actual rejected request exceeds current reach, or lies outside the allowed existing buffer entry window; REQUEST |
| `PATH_OBSTRUCTED` | Actual shoulder LOS or finite hand sweep obstruction; REQUEST or TRANSIT |
| `HAND_TOO_SLOW` | Observed candidate timeout while the target is still currently visible; TRANSIT |
| `TARGET_LEFT_REACH` | Actual moving candidate/hand path leaves reach, existing pending window expires, or retained arm exceeds its physical extension limit; stage distinguishes transit/retention |
| `CONTACT_REJECTED` | Invalid selection/current contact test rejection; actual reason is preserved |
| `SUCCESS` | Existing finite hand motion physically establishes attachment; CONTACT only |
| `CATCH_OVERLOAD` | Actual integrity threshold crosses during the existing force-blend plus overload-confirm interval (two physics-tick observation tolerance); RETENTION |
| `GRIP_SLIP` | Actual load-limit transition or overload release; RETENTION, including cases after successful contact |
| `SUPPORT_LOST` | Existing material support invalidates; TRANSIT or RETENTION |

`SUCCESS` does not promise retention: its immutable contact event remains successful if later events record load failure. First failure within that attempt remains in `primary_failure`; event `code` and `reason` describe the present observation.

Manual, launch, mouse/UI release, `input_released`, `input_focus_lost`, and `hold_mode_enabled` are neutral `CANCELLED` during reaching or `RELEASED` after attachment. They do not fabricate a primary failure. The tests exercise the actual `grip_intent_buffer.gd` early-release reason and app focus-loss reason.

There is no new future reach prediction. `window_remaining=-1`, `predicted_contact_time=-1`, `prediction="not_evaluated"`. Remaining hand time is a geometric lower bound at the unchanged4 m/s, not a promised collision-safe arrival. The existing predictor/buffer operates unchanged when explicitly enabled; its classification is not silently treated as physical contact.

## Motion, work and reaction telemetry

`motion` separates:

- Anchor-to-COM pendulum angle/angular velocity, with a validity bit; anchor frame and relative velocity use allocation-weighted actual supports.
- Anatomical trunk-axis twist angle/rate and trunk tilt, with projection-degeneracy validity. This is not an Euler yaw lock or a claim that twist and pendulum components form an orthogonal decomposition.
- Body kinetic energy relative to the weighted support frame, including rotational inertia; this is not the total closed-system mechanical energy.
- Axial pair power `Σ F·(v_shoulder−v_anchor)` and common grip-moment pair power `τ·ω_body + Σ τ_reaction·ω_support`; integration yields estimated work over enabled diagnostic time.
- Applied attitude, posture tilt, swing, shoulder/leg moment, resultant moment, raw/applied hand-force sum, existing caps/allocator scale, actual swing lever/engagement and torque-reaction weights.
- Per-support aggregated opposite forces and moment couples. Two anchors on the same dynamic beam yield one summed opposite moment, not twice the body moment. Static-support values describe implied world reaction rather than a simulated moving body.

The energy scope explicitly excludes gravity, collision, joint, drag work and support kinetic energy. Power uses the physically applied force/moment on the current tick, not raw uncapped demand. Values are sampled observations, not a stiffness/power controller. No claim of a complete energy conservation proof is made.

`SWING_AXIS_UNACTUATED` is emitted once on entry when nonzero supported WASD is parallel to the actual blended COM→shoulder lever and therefore cannot produce the requested couple. Geometry and applied swing torque accompany the event. It does not add a replacement force. This condition resets when the geometry/request regains authority.

## Validation

Commands:

```text
python tools/project.py test test_transfer_diagnostics
python tools/project.py test test_transfer_diagnostics -- --60hz
```

**54/54 checks pass at120 Hz and60 Hz.** Logs: `builds/test_test_transfer_diagnostics.log` and `_60hz.log`. Fixtures cover real pose rejection, actual LOS obstacle, finite-path timeout, moving support leaving reach, disappearing support, finite contact, observed overload/slip after successful contact, neutral owner cancellation, bounded immutable journal, profile/flag gates, dynamic reaction decomposition, rolled-body unactuated axis and budgets.

Physical equivalence used four complete trials (OFF/OFF and ON/ON controls, then OFF/ON) with a shared dynamic beam, two real finite grips, unchanged automatic posture and supported swing reversal. At **both frequencies every measured difference was exactly0**: position, velocity, angular velocity, arm force, assist torque, arm target length and hand states. Tolerances are tied to control-trial repeatability with hard repeatability ceilings; no tolerance was enlarged to hide a diagnostic effect.

Existing independent-physics suite remains89/89 at both frequencies during this work. Root additionally reported M1 integrated aggregate196/196 (54 diagnostic +32 input +12 route checks at each frequency), with native diagnostic/route capture validation. Final whole-project/native archival remains root-owned.

The three Vector3/null ternary warnings identified by the editor were removed with separate nullable dictionary assignments. Final native editor warning verification belongs to root's active editor session; this agent did not open another editor.

## M1 conclusion and limits

Diagnostics now distinguish a physically unavailable pose from failed transit/contact and failed retention without changing assistance. Root reproduced the center-lane v0.4 issue and also demonstrated that waiting for an actual natural reach window can complete the new basic route without WASD or new force. This is evidence for timing diagnosis before adding posture control, not proof that every transfer is automatically viable.

M1 physics is frozen for root review/commit. Next gate remains explicit: P1 twist-only study with the same20 N·m authority; P2 only if measured P1 limitations justify it. Human comfort/agency, ten-transfer repeatability over sessions, and classified video remain gameplay validation, not outcomes inferred from54 headless checks.
