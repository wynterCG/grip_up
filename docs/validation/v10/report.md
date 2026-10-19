# GRIP UP v1.0 - M1 refined vault presentation

Decision: **KEEP the opt-in Style V candidate for human A/B; no default promotion.**
M1 implementation and technical validation are complete. The user judged the new
candidate good despite limited realism. Structured human acceptance is still
**PENDING**. This is an animation-assisted crossing; ordinary
climbing and walking remain physical.

## Baseline and human observation

Branch: `feature/v1.0-contextual-vault`. The recoverable unmodified v0.9 baseline
is tag `baseline/v0.9-pre-contextual-v1.0`, commit `99eb1040ecf45c389757bd07544fda6a4a68d508`.
The earlier audit and its pending ratings are archived in `m0_audit.md` and `m0/`.

After trying that unchanged baseline, the user reported that the feel seemed the
same. This is limited qualitative feedback on the baseline, not numeric ratings,
three completed manual sessions, a high/slow contextual mismatch, or acceptance
of v1.0. It motivated delivering an actual presentation comparison.

After the new candidate, the user said: "não está mega realista mas está bom"
and asked what comes next. This supports retaining the refined single style for
the next gameplay iteration. It does not supply three recorded sessions,
frequency/context breakdowns or numerical acceptance scores. No human sessions
or comfort scores have been invented.

## What changed

- `contextual_vault_v10_enabled=false` on lab, transition controller and animation
  driver. Controls now offer explicit v0.9 and v1.0 low/high/two-ledge buttons;
  R retains the selected experiment. Normal startup remains the old profile.
- A separate `mantle_vault_v10.tres` has 17 rotational bone tracks, 1.05 s,
  altered arm/torso poses, and no independent root translation. All six original
  leg tracks and their keys remain unchanged. The certified body route is still
  1.15 s; this is not a faster physical lift or new locomotion solver.
- Contacts are mapped by hand identity, fixing the compact right-only anchor
  array creating a false left-hand contact. Each real hand stores its support
  identity and material-local point; visual world targets use the interpolated
  support frame. This does not authorize moving-platform top-outs.
- Palm alignment now has per-hand weights. The free hand does not inherit an
  old contact direction. Ordinary modifiers keep their original empty-array
  behavior when the experiment is off.
- A brace/release blend at approved progress .27-.34 is further limited per arm
  using actual rendered shoulder position and the imported rig's arm lengths.
  Release cannot pin a wrist beyond reach. It advances on the approved progress
  clock, without a separate playback timer or force source.
- The first authored revision dropped hands toward the hips too abruptly.
  Render review rejected that presentation despite functional success. Revision
  2 keeps the hands forward/up on release and lowers them progressively during
  crossing. Both revisions' evidence remains available.
- Exit immediately selects Walk for actual supported horizontal movement rather
  than forcing Idle throughout the existing .18 s pose blend. Temporary hand
  contacts clear and leg IK fades out before ordinary gait fully resumes.
- A support becoming invalid specifically during RESTORE_DYNAMIC now freezes
  the current solved pose under the v1.0 flag, retains original standing shapes,
  and exposes R. It does not rewind, rebuild the motor or return walking authority
  on a newly moving/deleted support. Completed ordinary walking stays dynamic.
- Commit telemetry records body-relative lip distance, incoming velocity,
  angular velocity and real hand count. Presentation telemetry labels the seven
  phases, real arm reach, per-hand weights and release reasons. There is one
  refined style; the logged choice explicitly says no classifier exists.

The 12 kg body, dynamic grip/foot/torque budgets, Jolt settings, swept motor,
3 mm certificate bound, HEEL_BACK profile, narrowly scoped native-contact
recovery, static eligibility and native top-ground/30 cm finish are preserved.
The original v0.8 full physical top-out remains a documented failure.

## Validation

| Final accepted coverage | 120 Hz | 60 Hz |
|---|---:|---:|
| New presentation/material-point/one-hand/exit fixtures | 41 | 41 |
| Low/high, left/right approaches, two successive ledges | 29 | 29 |
| Pause, camera, rearm, obstacle, focus/reset and refusal contracts | 59 | 59 |
| Exact RESTORE support-invalidation guard, OFF/ON controls | 57 | 57 |

**372 new checks / 8 runs / zero failures**, plus the complete preserved baseline
matrix **4,356 checks / 139 runs / zero failures**. Total distinct accepted
headless coverage: **4,728 checks / 147 runs**. The later parameter-shadowing
cleanup was checked again with 140 targeted presentation/functional checks; these
repeat coverage and are not added to that total.

Receipts: `m1/attempt_004/`, `final_check/attempt_001/`, and `../v10_baseline/`.
Earlier attempts are not silently discarded. Attempt 001 ran during development
and caught an incomplete flag integration plus typed-array assignments that
parse-only checks missed. Complete large failed logs are retained as gzip with
readable previews. Attempts 002/003 passed earlier presentation revisions.

The exact RESTORE defect was reproduced before fixing it: OFF could hand walking
to a support with nonzero material velocity. The pre-fix runner reports 13
failures per frequency; its development receipts also contain the then-unfixed
presentation array error and are labelled accordingly in `restore_reproduction/`.
Final guard tests have no script errors and validate velocity/move/delete faults,
no body transport, shape-resource identity, zero old forces, explicit R recovery,
valid native top support plus 30 cm walking, and ordinary post-handoff physics.

Final rendered MCP Pro evidence is `native/attempt_002/`: 13 checks per frequency,
both low/high complete from normal input, actual native ground and normal walk.
120 Hz uses an oblique camera and cyan physical-collider overlay; 60 Hz uses the
normal view. These are scripted inputs, not human sessions or quality ratings.

| Final rendered measurement | 120 Hz low/high | 60 Hz low/high |
|---|---:|---:|
| Ordinary post-restore walk | .31389 / .31376 m | .31609 / .31608 m |
| Assigned interpolated visual-root error | 0 / 0 m | 0 / 0 m |
| Sampled anchored palm error, actual IK weight >= .99 | 16.35 / 11.90 mm | 20.46 / 12.76 mm |
| Sampled fully corrected foot error | 1.71 / 2.12 mm | 1.55 / 2.18 mm |

Raw errors outside intended contact remain in logs; released hands and walking
feet versus an old sole target are not reported as continuing planted contacts.
Screenshots support frame review, not proof of temporal smoothness or comfort.
Windows export and a three-frame startup smoke pass. Final editor diagnostics,
source/build hashes and the prepared monitor-1 session are in `verification.json`.

## Files and reproduction

Production changes: `scripts/grip_up_lab.gd`, `hybrid_mantle_controller.gd`,
`mantle_animation_driver.gd`, `biped_hand_pose.gd`, plus
`resources/mantle_vault_v10.tres` under `features/grip_up/`. Authoring source:
`tools/author_vault_v10_clip.gd`. Build metadata and task helpers select
`GripUp-v1.0-experimental.exe`; the v0.9 executable is preserved.

Tests: `test_vault_presentation.gd`, `test_vault_v10.gd`,
`test_vault_resilience.gd`, `test_vault_restore_guard.gd`, `vault_test_lab.gd`,
and `capture_contextual_vault.gd`. The old native helper gains opt-in capture
parameters with unchanged defaults. `tools/run_contextual_vault.py` preserves
numbered receipts; `run_regressions.py v10_baseline` archives the full old matrix
separately rather than overwriting v0.9 evidence.

```
python tools/run_contextual_vault.py m1 vault_presentation vault_v10 vault_resilience vault_restore_guard
python tools/run_regressions.py v10_baseline
python tools/project.py export
python tools/project.py smoke
```

## Remaining decision

The new candidate is left ready on monitor 1 at 120 Hz, low static ledge, v1.0
enabled explicitly. Compare Controls / v1.0 against v0.9; input remains held
LMB/RMB, W to climb up, MMB orbit, scroll dolly, R retry. The same physical route
means overall ascent timing and ordinary grip feel deliberately remain similar;
the change is contact presentation and return to gait.

**No retime, Style C, contextual classifier or default promotion.** A second
style still needs repeated human-observed mismatch after this refinement. The
three-session low/high/two-ledge human gate and numerical ratings remain pending
in `pilot.md`. Safety/functional tests passing do not establish player enjoyment.
Recommendation: **KEEP V as an opt-in candidate. Next, exercise it in a short
continuous gameplay route; no current player evidence justifies Style C.**
