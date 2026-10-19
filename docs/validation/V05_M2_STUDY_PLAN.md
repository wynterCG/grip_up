# v0.5 M2 study preparation — no production change

Prepared 2026-10-19 after the M1 diagnostic gate. The M1 snapshot hash is pending root confirmation; no assistance implementation is authorized by this preparation. Existing v0.4 production, tuning, and tests remain unchanged. P2 is not pre-approved.

## Starting evidence

Root reports M1 full regression2144 checks passed, native3/3 at120/60 Hz, and0 new editor warnings. P0 completes both new flat-wall reference spacings0.12/0.14 m without WASD if the next press waits for actual reach (up to2 s per transfer). Reported summed reach waits are2.41/3.65 s. The earlier fixed1.1 s dwell failed at0.69369 m reach: an unavailable pose at press time, not proof that the sequence is mechanically impossible.

Therefore **completion count alone is insufficient to justify P1**. The comparison should measure how consistently and legibly the actual free-shoulder window opens, while retaining passive oscillation and deliberate swing. No route geometry, force cap, hand speed, arm planner comfort, damping, or timing threshold should be retuned to favor the candidate.

## Frozen P0 and controlled P1 hypothesis

P0 is the M1 snapshot with profile3 and the same selected v0.4 posture policy as the comparison. Do not confuse P0 with existing length policyA/HOLD_LENGTH. Record flags and policy per trial. Space, feet, catch buffering and prediction stay off for the first isolated comparison.

Current attitude combines all-axis absolute angular damping2, anatomical twist spring16/damping3, optional v0.4 tilt12/1.2 and supported swing18, all sharing20 N·m plus the existing150 N·m resultant limit. The current twist reference is cached world heading; the spring is projected about the anatomical spine and continuously fades near singular projections.

The smallest useful P1 hypothesis is **refining only the supported axial twist reference/rate**, not boosting orientation authority:

1. Use relative twist rate about the existing anatomical axis against the actual weighted support spin, rather than treating a rotating support as an inertial reference error.
2. Transport a bounded heading reference with actual support rotation; keep camera orbit and pointer out. Preserve world reference continuity across1→2→1 and smooth changes of support weights rather than recomputing a fresh heading from each catch.
3. Keep the same spring/damping gains and20 N·m cap initially. Keep all-axis damping and the v0.4 tilt block frozen for this first one-factor comparison. If global damping is studied later, use a separately labelled subvariant rather than bundling it into P1.
4. Blend acquisition/deactivation using actual engagement; log degeneracy and saturation. No support means zero new authority. Apply opposite moment through existing gripper reaction weights.

On a fixed wall with zero support spin, this minimal P1 may be nearly identical to P0. That is a valid result. Existing failures include trunk roll/lateral COM displacement, which an axial-only refinement may not remedy. Do not relabel roll as twist merely to show improvement; do not add P2 automatically because a P1 effect is small.

## Minimum harness, after snapshot authorization

Use a new standalone `test_posture_study.gd` rather than rewriting the preserved diagnostic/route tests. Root retains app/native route ownership. The harness should export observations and invariants; improvement is comparative evidence rather than a universal success assertion.

| Fixture | Controlled input | Measurements |
|---|---|---|
| Single static anchor, left/right | Initial small lateral displacement; neutral8 s | Pendulum amplitude, period and decay; trunk twist/tilt RMS; high-frequency angular residual; free-shoulder reach windows |
| Static yaw/roll perturbations | ±45/90° fixture orientation, physically finite attach | Twist settling versus legitimate tilt; caps, slip and contact retention; no state snap |
| Single anchor, deliberate lateral/depth swing | Same phase-triggered pump, neutral and opposing brake | Pair work, relative swing energy, amplitude gain/loss, saturation, reachable-window duration |
|1→2→1 | Same actual contact points and hold/release timings | Surviving target continuity; torque slew/impulse; heading-frame continuity; force allocation |
| Free moving/rotating support | Known initial translation/spin, no world hinge | Material-local anchor consistency, relative twist, opposite force/torque and closed pair momentum |
| World-hinged support | Same authored beam and input | External joint reaction acknowledged; relative spin/work and actual arm reach, without false closed-system conservation claims |
| Camera/pointer control | Same body/support state, orbit only | No changed arm goal, posture event, or injected effort |

Fixtures may assign initial poses/velocities only before the trial; all climbing movement thereafter uses existing finite actuators. Use identical scene/body geometry and explicit inertia for closed momentum fixtures. Run120 and60 Hz and include repeatability controls where floating-point phase can matter.

## Reach-window definition and failure separation

For each recorded fixed candidate, sample actual free shoulder distance, current LOS, hand position and finite-speed path lower bound. Report:

- Geometric eligibility: distance≤0.65708 m with the same margin used by the preserved route harness, and actual visibility.
- Total and longest contiguous eligible time; number of entries/exits; first entry delay; minimum reach margin.
- Transit lower bound from current hand position divided by4 m/s. This does not certify that the full swept approach path can complete before window closure.
- Separate actual successful finite catch and retention≥0.5 s when tested. Neither predictor availability nor a geometric window alone counts as success.

Root's route may use the same bounded timing-aware press rule for every variant. It should record total waiting, extra inputs, contact/retention failures and recoveries. Include the preserved fixed-dwell failure as a diagnostic comparison, not as the sole acceptance condition. Geometry must be identical for P0/P1.

## Motion and jitter metrics

Use the M1 anchor-to-COM pendulum angle/rate separately from anatomical trunk twist and tilt. These axes are not necessarily orthogonal; do not sum them into an invented exact energy decomposition.

For jitter, retain raw traces, then report a consistently defined residual (for example angular velocity minus a fixed-duration low-pass copy) and torque slew. Use the same time constant at60/120 Hz. Do not call the large, low-frequency gravity swing jitter. Report RMS and95th percentile alongside peaks to avoid one contact discontinuity dominating the result.

Power/work is the existing M1 applied axial pair power plus moment pair power, with gravity/contact/joint/drag and moving-support energy scope stated. Constant held input may replace dissipated energy; the relevant boundedness evidence is finite motion/speed/torque and reproducible phase-dependent pumping/braking, not a claim of zero motor work.

## Comparison decision

Keep all hard constraints exact: no hidden reach, no attachment without current physical contact, no body pose/velocity writes, no new airborne propulsion, no force/torque increase, correct dynamic reaction, pointer independence. P1 must also preserve useful passive swing and pump/brake distinction. Compare paired metrics at both frequencies; numerical samples need not match bit-for-bit.

Recommend KEEP only if P1 reduces a measured harmful twist or improves a useful free-shoulder window without meaningfully reducing deliberate swing or creating new failures. REVISE/REJECT is legitimate when P0 already provides usable timing and P1 offers no practical improvement. Human route ratings remain necessary after the isolated comparison.

Only a documented remaining support/COM geometry defect after that comparison can justify proposing P2. A P2 proposal must identify the finite moment-capable gripper mechanism, feasible support-relative attitude objective, rate/acceleration limits, saturation/slip release and player-swing authority. It must not use the next mouse-targeted hold or silently change absolute arm goals.

Next dependency: root provides the M1 snapshot hash and explicit production gate. Until then this plan is preparation only.
