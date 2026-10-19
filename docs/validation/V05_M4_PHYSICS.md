# v0.5 M4 — reach assessment physical review

Date: 2026-10-19. Scope: read-only review of root-owned `scripts/reach_assessment.gd`, plus new `tests/test_reach_assessment.gd`. The specialist changed no wrapper, controller, actuator, predictor, input, production tuning, E source or active runtime.

## Review conclusion

The wrapper is suitable as **advisory**, with current contact/reach/force/integrity checks retaining sole physical authority. It reuses the existing finite-path short-horizon predictor rather than implementing a new capture controller. Every assessment has `authorization=false`; predicted timing remains uncertified. Assessing never starts reach, enables the physical buffer, changes hand state or supplies force.

Root corrected two issues raised during review: window exits now use the last sampled inside pose and expose sample resolution; `PREDICTED CATCH WINDOW` now requires both future geometric entry and a finite predicted contact time. A future anatomical window with unknown hand arrival retains an explicit `geometric_window_only; finite_hand_arrival_unknown` advisory reason. Confidence is also reduced for rotating bodies, known ground contact and existing supported dynamics.

The model uses actual COM offsets from the physics direct state, including AUTO COM, for point velocity and effective point mass. For a unit current force axis, inverse effective mass is `1/m + (r×axis)·I_inverse·(r×axis)`. A dynamic support contributes its own inverse effective point mass. Current radial velocity is positive when the shoulder separates from the material target. This sign and the physical COM lever were verified in real Jolt fixtures.

## Tests and outcomes

```text
python tools/project.py test test_reach_assessment
python tools/project.py test test_reach_assessment -- --60hz
```

**39/39 checks pass at120 Hz and60 Hz.** Logs: `builds/test_test_reach_assessment.log` and `_60hz.log`.

Coverage:

- Fixed actual surface eligibility; pointer-like API traffic and arbitrary camera orbit produce bit-identical assessment for the same selected world/material point.
- Evaluation preserves exact body/support transforms, linear/angular velocities, hands, metrics and predictive-buffer flag. It cannot attach later merely because the body subsequently enters reach.
- A valid current target whose finite hand travel exceeds the0.20 s horizon remains IN RANGE. The existing controller actually reaches it after the forecast horizon and retains it for0.5 s, without changing the original unknown prediction.
- A geometric-only future entry is not represented as a certified catch. Another real fixture predicts entry at75 ms and contact at166.7 ms, correctly labelled PREDICTED CATCH WINDOW with no authorization.
- Predicted contact-relative point velocity agrees with later unconstrained rigid-body motion. Merely passing the predicted arrival time leaves the hand FREE and attempts at zero.
- A closing window's returned entry/exit are inside the anatomical sphere; the next sample after an unclipped exit is outside. Resolution is explicit and bounded at1/120 s.
- Moving, rotating, grounded, body-spin and physically attached-arm cases receive reduced confidence. A busy hand cannot be advisory-retargeted.
- Custom COM and deliberately asymmetric AUTO-COM fixtures distinguish actual centroid from body origin, verifying both point velocity and rotational effective mass.
- An outward-speed warning does not deny an otherwise currently valid real request. Actual LOS obstruction still rejects through the unchanged physical path.
- Finite4 m/s reaching, no pre-contact force and existing force/torque limits remain intact during physical verification.

Selected quantities at120/60 Hz:

| Quantity |120 Hz |60 Hz |
|---|---:|---:|
| Free translating/rotating material point:100 ms position forecast error |1.49e−8 m |1.49e−8 m |
| Same actual material-point displacement |0.03915 m |0.03915 m |
| Separating fixture effective point mass |4.42731 kg |4.42731 kg |
| Current outward speed |2.12132 m/s |2.12132 m/s |
| Current-axis outward kinetic estimate |9.96144 J |9.96144 J |
| Remaining extension |0.02360 m |0.02360 m |
| Force-times-distance stopping-work upper estimate |8.49742 J |8.49738 J |

The exceptionally small trajectory error is a **well-conditioned unconstrained zero-gravity/zero-drag rigid-motion fixture**. It does not establish similar accuracy for a hinge, a collision, a loaded arm or active posture torque. The tests deliberately keep that distinction.

Root separately reports app integration25/25 at both frequencies, including advisory OFF/ON physical equivalence, buffer OFF rejection versus ON real catch, immutable press assessments and ownership cancellation. Those app results are root-owned; the specialist suite does not substitute for UI/native or human validation.

## Limits and interpretation

1. **Finite horizon:**0.10–0.25 s, normally0.20 s. Absence of a predicted contact inside it means unknown arrival, not proof that an otherwise valid physical request is impossible. Current straight-line hand time is a lower bound, not full path certification.
2. **Sampled window:** endpoint samples are conservatively inside, but the path between samples and future collider interactions remain approximate. Actual finite swept hand motion still decides contact. A predicted sphere intersection never grants an attachment.
3. **Dynamics:** the predictor extrapolates current body gravity/force and approximately constant spin; target motion uses constant COM velocity/spin. Unknown future contact impulses, support gravity/constraint reactions, changing arm allocation, angular acceleration and P1/P2 assistance are not fully integrated. Confidence must stay reduced in such cases.
4. **Load warning:** the estimate uses the current axis, instantaneous effective point mass, current separating speed and finite remaining extension. Force×distance is only a component-wise upper estimate. Force blend, sharing, other grips, torque work, rotation, changed pose and contact can alter actual retention. UNSAFE CATCH remains a warning, not a new arbitrary velocity denial or an impossibility proof.
5. **Frames:** AUTO-COM offsets and angular point velocity matter; replacing them with body-origin velocity would be wrong for asymmetric or rotating supports. Existing direct-state handling is appropriate. Caller inputs assume a valid configured controller and ordinary unit-scale physical bodies.
6. **Intent:** forecasts belong to the immutable selected material point at press time. Hovering another surface cannot rewrite an attempted target. Advisory and buffer controls remain separate; release/focus/UI cancellation must prevent deferred automatic reattachment.

No force or reach increase is justified by this review. No new controller/handoff redesign is indicated by these tests. Keep prediction/buffering explicit and switchable; evaluate whether the developer feedback and bounded buffer actually improve user consistency through the remaining native/human gates.

**M4 physics advisory review: passed with the above limits.** P2 remains opt-in/rejected as a default improvement per its separate study. Human comfort, agency and multi-session ten-transfer repeatability are not claimed here.
