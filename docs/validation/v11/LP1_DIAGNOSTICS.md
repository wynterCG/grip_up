# v1.1 movement observation and transition diagnosis

LP1 adds an opt-in read-only observer and corrects the public swing-request
source. The observer does not set forces, targets, poses or velocities. Its
checkbox starts OFF; A0 remains the default movement allocation.

## Correct request source

Profile 4 drives `intent_locomotion.swing`, while `_swing_requested` belongs to
older inputs and is normally zero in that profile. Previously the generic
telemetry and `SWING_AXIS_UNACTUATED` observation read the older field.

`get_effective_swing_request()` now centralizes the already-existing selection
of the actual request. The actuator uses the same expression as before; public
telemetry and the journal use that selected request too. The old raw field is
retained as `swing_requested_legacy`. During committed hybrid ownership, the
effective normal swing request is zero.

## Per-tick observation

With diagnostics enabled, `locomotion_observer.gd` records:

- Requested and achieved velocity projected on the current supported intent.
- Body velocity, angular velocity and finite-difference acceleration/jerk.
- Actual hand force vectors, target/actual arm lengths and hand states.
- Ground force, torque, authority and the ground detector's state.
- Native FootBase contacts separately from ray-based grounded reporting.
- Feet under load, including SLIDING contacts, normal/tangent force and reason.
- Support frame and its angular change, effective swing request, applied swing
  moment and the existing incremental power/phase proxy.
- Movement owners as a bitset: ground1, hands2, feet4, swing8, hybrid16.

Existing planner feet/frame semantics are not silently changed by counting a
loaded sliding foot in this observer. The real load and the old classification
are available separately. The planner's relative velocity is still its existing
hand-weighted estimate; no claim of a complete multi-contact velocity solve is
made.

Ownership or hand/foot state changes preserve up to half a second before and
after the event at the actual physics rate. Completed/pending windows are
bounded to16 each and available from `transition_windows()`. CaptureTrace saves
compact current observations at its existing interval; full windows are exported
explicitly instead of repeating them in every JSONL line.

Derivative fields include warm-up validity. Jerk includes gravity/contact and
the explicitly assisted transition. No universal comfort threshold, artificial
zero-jerk requirement or new damping is imposed. Incremental swing power is an
actuator diagnostic, not a conservation-of-energy proof.

## Player feedback

The optional diagnostic mode can explain unsupported movement, poor leverage,
limited effort and blocked hand paths without presenting internal solver names
in the normal flow. Normal grounded walking is not labelled unsupported merely
because there is no climbing hand. Foot planting has its own informational code.
The debug view shows current allocation, foot policy, useful velocity, loaded
feet, owners, transition count and swing phase/power.

## Validation and limits

The dedicated observer suite passes20 checks at120 Hz and20 at60 Hz. It uses
real finite grips, actual two-to-one/one-to-two handoffs, an unsupported release
after physically leaving the start floor, live request parity, read-only state
checks and explicit rollback/retry settings. A small pure classification fixture
checks loaded SLIDING versus unloaded PLANTING; it is not claimed as a physical
planting trial.

The first diagnostic trial selected a bar but remained on its starting floor.
The fixture now earns actual suspended height before testing unsupported release;
the failed receipt remains in `lp1/attempt_001/`. An initial inference parse
error is preserved under `development/`, compressed with a readable preview.

The hybrid observer regression defaults to A0 and checks both existing static
top-outs, native support,30 cm walking, the1.15 s route and sole assisted
ownership. `--a1` intentionally enables the experimental allocation comparison;
the failed60 Hz high-ledge result remains in `lp1_hybrid/attempt_001/` and is part
of the A1 REVISE decision, not a passing hybrid acceptance.

Human discomfort/benefit ratings remain pending. LP1 establishes better
observability, not improved physical movement by itself. No transition motor,
contact, collision or hybrid trajectory was redesigned here.

Final trace review found that assisted rows inherited the last cached hand-force
vectors even though the motors had retired and the aggregate force was zero.
The read-only observer now explicitly records zero normal hand forces while
hybrid ownership is active. No physical actuator changed. The hybrid suite now
checks this on every assisted observation; observer/hybrid/course suites were
repeated at both rates in `assisted_observer_fix/attempt_001`.
Earlier native traces remain archived as historical runs and contain that stale
diagnostic field. The final native archive and `verification.json` identify the
corrected source and verify zero recorded hand force during assisted ownership.
