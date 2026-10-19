# v0.5 M2 — P0/P1 twist study

Baseline frozen commit: `db6ea96`. Date: 2026-10-19. P1 implemented only after the M1 gate. P2 remains reserved and unimplemented pending a separate decision.

## Change and physical mechanism

Production changes: new `scripts/supported_twist_refinement.gd`; narrowly scoped hooks in `climbing_controller.gd`; three new v0.5 fields in `resources/climbing_tuning.gd`. Added standalone `tests/test_posture_study.gd`. No main/input/camera/level, original actuator, v0.4 length planner, force limits, reach, hand speed, mass, K/D or body damping changed.

API:

```gdscript
controller.transfer_assist_enabled = false # default
controller.set_posture_variant(0) # 0=P0, 1=P1, 2=reserved P2
```

Only profile3 uses the new helper. P0 which has never enabled P1 retains the original v0.4 attitude calculation. Disabling an active P1 blends its correction out over0.20 s, then returns to P0; the transition is explicit in telemetry. Selecting unimplemented2 reports `P2_NOT_IMPLEMENTED`, `available=false`, and cannot silently enable P1. Existing profiles0/1/2 ignore the feature.

P1 changes only the existing **axial twist term**:

1. The reference initially equals the existing cached supported heading. Actual observed support-basis increments transport a material-relative target. The code does not predict support rotation from spin, reset heading on every new hand, or use the cursor/next hold.
2. Shared support weights combine allocation×real grip blend. Two hands on one beam produce one material frame. New support membership starts with its actual current basis rather than imposing an acquisition orientation jump.
3. Reference tracking has a2.5 rad/s target-rate cap and0.10 s response. Small basis increments use explicit normalized quaternion vector/`atan2` extraction to avoid losing rotation magnitude at120 Hz.
4. The original16 N·m/rad twist spring and3 N·m·s damping remain. Only the damping rate becomes body spin relative to the weighted current support spin. Anatomical-axis projection and singularity fade remain.
5. The correction replaces the baseline raw twist contribution before the existing common20 N·m cap. It is not a second20 N·m motor. Existing paired support torque reactions and the150 N·m resultant allocator remain authoritative.

The finite torque-capable gripper approximation documented in M0 is unchanged. No moment-free point constraint is claimed. Global angular damping2, v0.4 tilt assistance, supported swing18 and all length actuation are frozen for this one-factor comparison.

New defaults versus P0: only `transfer_twist_blend_time=0.20`, `transfer_twist_frame_max_rate=2.5`, `transfer_twist_frame_response=0.10`. These configure reference/authority transitions, not stronger actuators.

## Study and results

Commands:

```text
python tools/project.py test test_posture_study
python tools/project.py test test_posture_study -- --60hz
```

**58/58 checks pass at120 Hz and60 Hz.** Raw reports are `builds/posture_study_120hz.json` and `_60hz.json`; console logs are `builds/test_test_posture_study.log` and `_60hz.log`. Both JSON reports contain finite, parseable values; unavailable hand times use−1 rather than infinity.

The isolated trials use existing HOLD_LENGTH policy0 to keep arm targets fixed and isolate the twist change. This is not a claim that policy0 represents all v0.4 B/C wall-route behavior. Fixtures initialize pose/momentum once; subsequent motion is entirely physical. Dynamic closed-system fixtures use zero gravity/drag and explicit isotropic inertia to isolate paired actuator momentum.

| Measurement |120 Hz P0→P1 |60 Hz P0→P1 |
|---|---:|---:|
| Rotating support, actual support-relative trunk twist RMS |1.3291→0.1265 rad |1.3339→0.1209 rad |
| Same, trunk tilt RMS |0.0201→0.0289 rad |0.0201→0.0288 rad |
| Same, linear momentum residual P1 |3.82e−6 kg·m/s |3.82e−6 kg·m/s |
| Same, angular momentum residual P1 |2.45e−4 kg·m²/s |2.37e−4 kg·m²/s |
| Fixed support neutral pendulum peak |0.16182→same rad |0.16244→same rad |
| Same, third/first peak decay |0.65902→same |0.65843→same |
| Initial roll fixture trunk tilt RMS |0.41510→same rad |0.41379→same rad |
| Same, axial twist RMS |0.01479→same rad |0.01491→same rad |
| Same, longest actual geometric+LOS free-shoulder window |0.175→same s |0.1667→same s |
| Same, minimum finite hand-travel lower bound during windows |0.3113→same s |0.3128→same s |
| Timed pump, paired grip-moment work |+5.437→same J |+5.936→same J |
| Opposing angular-phase brake, paired grip-moment work |−2.320→same J |−2.434→same J |

P1 reduces **support-relative** axial error by about90% on the rotating fixture. World-heading twist grows as the torso legitimately follows the moving support; it is not appropriate to call that larger world angle a failure. Overlay comparison should use `transfer_posture.twist.axial_error`, actual support-relative geometry, and the stated reference frame.

All fixed-support neutral, roll, pump and brake measurements were identical between P0/P1, including work, pendulum period/decay, free-shoulder windows and high-pass angular residual. No wall-climbing improvement is claimed. Root separately reported identical real-input reference-route timings for P0/P1 at both frequencies: this agrees with the isolated result.

The high-pass proxy uses a fixed0.08 s filter; it includes legitimate motion harmonics and is **not** proof of numerical solver chatter. P1 necessarily adds legitimate body motion when following a rotating support, so a larger residual there is not evidence of instability by itself.

Checks also cover target-frame rate bounds, unchanged force/torque limits, actual finite1→2→1 acquisition/release, survivor target continuity, exact instantaneous pose/velocity preservation on setters and release, cached-frame independence from camera/pointer setters, bounded enable/disable, legacy-profile isolation and zero assistance with no valid grip. The dynamic2→1 trial retains paired momentum and material-frame continuity.

## Reachability interpretation

The measured rolled-body fixture has little axial twist (≈0.015 rad) but substantial trunk tilt (≈0.415 rad). Its visible geometric reach windows are shorter than the current free hand's minimum straight-line travel time. This distinguishes a remaining **support/COM pose plus finite-transit issue** from axial instability; P1 is intentionally unable to correct that roll.

These sampled windows are not successful contact guarantees or a proof that the whole route is impossible. The helper uses an actual separate target sphere with LOS; it does not move the target or attach it automatically. On the rotating case, P1's120 Hz longest window is fragmented by a near-boundary sample (2.058 s longest,2.983 s total versus P0's3 s);60 Hz records3 s. This is not advertised as a universal reach-window improvement. Root's authored route/capture outcomes remain the gameplay gate.

Root reported the actual-input basic route already completes ten transfers in P0 by waiting up to2 s for actual reach, with no added swing or force. Root's separate M3 swing-required test uses phase pumping and an actual visible underside catch; front-face obstruction was preserved as an adverse case rather than bypassed. This study does not convert those automated/native input demonstrations into human comfort ratings or three-session repeatability claims.

## Recommendation and next gate

**KEEP P1 as an opt-in moving-support refinement; KEEP P0 recoverable.** It measurably corrects relative axial twist with the same physical authority and reactions, while fixed-support motion remains unchanged.

**Do not claim P1 fixes static roll or makes aiming easier on the wall.** A P2 proposal is defensible only for the measured remaining support/COM placement and short free-shoulder window, not because ten transfers require guaranteed automation (they do not).

Before P2 implementation, root should approve a soft feasible support-relative attitude objective with explicit roll/shoulder-window comparison, identical geometry/budgets and no next mouse-target attraction. Keep existing arm length goals frozen for that comparison if possible, blend authority and respect slip/saturation/player swing. Reject a P2 which merely suppresses useful pendular motion or forces the next catch. No P2 code has been introduced by this milestone.
