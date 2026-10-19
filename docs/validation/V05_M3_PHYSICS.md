# v0.5 M3 — supported swing work and phase audit

Date: 2026-10-19. Scope: read-only swing diagnostics and validation of the **existing** swing mechanism. P2 physical code/tuning remained frozen; its M2 recommendation remains REJECT as a default improvement. No new motor, strength, reach, impulse, pose write or input mapping was introduced.

## Added telemetry

`transfer_journal.motion` now exposes:

- `swing_power` in watts: the applied incremental swing torque after the common assist cap dotted with body angular velocity relative to the **actual allocation×grip-blend reaction-weighted support spin**.
- `estimated_swing_work` in joules: integral of that power over enabled diagnostic time; reset follows the existing diagnostic session reset.
- `swing_phase`: `PUMPING` above+0.01 W, `BRAKING` below−0.01 W, `NEUTRAL` within that diagnostic deadband.
- `swing_phase_epsilon_w=0.01`, `swing_relative_spin`, and `swing_work_scope` stating the incremental-after-cap/reaction-weighted interpretation.

Only `scripts/transfer_diagnostics.gd` production code changed in M3. No value feeds back into the solver. The sign threshold never authorizes/rejects a grip or modifies actuation.

The torque is the difference between assist with the swing request and its preceding capped attitude request. At the shared20 N·m cap this incremental contribution can include redistribution of the earlier attitude component; it is not a separate18/20 N·m motor. The power sign describes the measured incremental contribution, not necessarily the player's intended phase or the sign of the entire body's energy derivative.

The pair-work formula accounts for the opposite moment delivered to dynamic supports. Static supports imply world reaction. It excludes gravity, contacts, joints, drag, axial spring work and support kinetic energy from this **incremental** figure. Existing total grip-moment and axial work fields remain separate. No claim of complete mechanical energy accounting is made.

## Validation and artifacts

New standalone `tests/test_swing_diagnostics.gd` reuses fixtures and measurement methods in `test_posture_study.gd`. It is separate because combining every M2 fixture with all M3 long holds exceeds the project helper's20000-frame watchdog. M2 remains its own110-check runner; an aborted combined development run is not counted as a result.

```text
python tools/project.py test test_swing_diagnostics
python tools/project.py test test_swing_diagnostics -- --60hz
```

**67/67 checks pass at120 Hz and60 Hz.** Artifacts:

- `builds/test_test_swing_diagnostics.log`, `_60hz.log`.
- `builds/swing_diagnostics_120hz.json`, `_60hz.json`: per-trial phase counts/work and six constant-held cases.
- M2 revalidated on final diagnostic code: **110/110 at both frequencies**. Logs also preserved as `builds/v05_m2_posture_final_120hz.log` and `_60hz.log` so later exploratory runs cannot obscure that evidence.

All P0/P1/P2 trials use unchanged geometry,360 N hand sum,20 N·m common assistance and150 N·m resultant caps. The neutral, periodic pump and opposing angular-phase brake are physical finite-support trials; no attached body pose or velocity is overwritten to make them succeed.

| Incremental measured swing work |120 Hz |60 Hz |
|---|---:|---:|
| P0/P1 coast |0 J |0 J |
| P0/P1 timed pump |+7.835 J |+8.449 J |
| P0/P1 phase brake |−2.099 J |−2.193 J |
| P2 coast |0 J within numerical tolerance |0 J within numerical tolerance |
| P2 timed pump |+11.369 J |+12.170 J |
| P2 phase brake |−2.317 J |−2.378 J |

Each pump contains both positive and negative instantaneous phases because input timing, finite ramping and body oscillation matter; its integrated swing contribution is positive. The brake predominantly reports BRAKING and has negative integrated swing work. Coasting reports only NEUTRAL. P0/P1 remain identical on these fixed supports, as expected. This does not reverse the M2 finding that P2 changes passive settling and can shorten useful reach windows.

## Held-command boundedness / camera / no-air checks

For **each** variant, one-hand and two-hand attachments hold a fixed world-depth command for12 s while the supplied camera reference rotates. All six120 Hz and all six60 Hz cases retain contact and preserve supporting-arm targets and the cached heading. At the end, releasing real supports eliminates assistance and does not permit continued horizontal airborne propulsion.

Measured peak/late linear speeds (m/s):

| Variant / grips |120 Hz peak / late |60 Hz peak / late |
|---|---:|---:|
| P0/P1 single |0.589 /0.0611 |0.586 /0.0620 |
| P0/P1 dual |0.303 /0.00376 |0.299 /0.00379 |
| P2 single |0.609 /0.0556 |0.607 /0.0564 |
| P2 dual |0.346 /0.00253 |0.342 /0.00265 |

The last2 s relative body kinetic-energy peaks are0.000056–0.031 J, lower than the preceding2 s peaks in these cases. Existing force/torque cap checks remain active throughout. This demonstrates bounded settling over the tested12 s, **not** a mathematical proof covering arbitrary contact geometry or infinite time. A continuously driven finite motor may still perform work to replace losses; bounded motion does not imply bounded cumulative motor work.

The current supported action is the finite grip-reaction couple documented in M0, with a speed governor and opposite reaction path. The M2 loaded dynamic-support test exercises actual nonzero P2 moment and paired momentum. The asymmetric two-hand test verifies the exact applied blended shoulder lever is used for unactuated-axis diagnostics. No missing axis is replaced with a translational thruster.

Root separately validated the swing-required actual-input catch on identical geometry: selecting the physically visible underside succeeds, whereas the preserved front-face attempt was genuinely obstructed. That is an approach/contact distinction, not a justification for bypassing rays or changing force. Human session ratings remain separate.

## M4 conceptual review

Read `V05_M4_PLAN.md`. Reusing the existing predictor and held-only buffer is consistent with the physics constraints. The following boundaries matter:

1. Advisory ON / buffer OFF must not silently enable `tuning.predictive_grip` and its contact-evaluation path. Keep advisory and physical buffer flags separate and preserve baseline comparisons.
2. `360 N × remaining stopping allowance` is an upper bound, not actual available catch work: force blending, support inertia, other grip sharing and force direction can reduce capacity. An UNSAFE estimate is advisory, not an arbitrary new speed denial or a guarantee of retention.
3. A currently valid NOW request can need longer than the0.20 s forecast to complete its finite hand path. Unknown horizon must not deny that valid actual request.
4. Hinges, future collisions, changing posture torque and high support spin limit constant-motion prediction. Reduce confidence rather than fabricate future constraints or promise capture.
5. Target point velocities must use the actual COM offset, including AUTO-COM supports; the current predictor's direct-state path is appropriate. Preserve material-local target identity through the held gesture and cancel on mouse-up/focus/UI ownership changes.
6. Immutable press-time assessment and observed pose/transit/contact/retention events remain separate. A hover forecast must never rewrite the attempted point, authorize attachment through space or re-enable a cancelled gesture.

**M3 physics gate: satisfied.** Proceed to root-owned M4 advisory/buffer integration without rewriting the arm actuator. No M4 production code was implemented by this agent.
