# v1.2 Movement Mastery Course - fixture and feasibility handoff

2026-10-20. **Available for human practice; isolated A0/B1 physical feasibility demonstrated. Robustness is mixed and human mastery is not evaluated.** No M7 geometry, locomotion solver, body collision, strength, reach, animation or Jolt setting was changed by this work.

## Identity and scope

Source base at handoff: branch `feature/v1.2-locomotion-tests`, commit `328c4c82868ac97005badb81230ba7eb0346b537`, with the new v1.2 work uncommitted at test time. Final commit/build identity belongs to the main agent's integration manifest; these receipts do not claim to test a later exported binary.

Owned files:

- `features/locomotion_test_suite/scripts/mastery_course.gd`
- `features/locomotion_test_suite/resources/mastery_course_r1.json`
- `features/locomotion_test_suite/tests/test_mastery_course.gd`
- This report and the adjacent `mastery/` evidence directory.

Runtime adapter SHA256: `1abdd63633fc491d9ac26113dc08e5e3049ab2055b803d1201b21df5d97f6f20`.
Geometry revision 1 SHA256: `7568f3e54a1ac064ff8c4c78a9b3541853789c74b64f53eaa0292bc589cf4bf1`.
The complete final source hashes are in [mastery/manifest.json](mastery/manifest.json).

The adapter has no new player controller and does not edit `grip_up_lab.gd`. It uses the existing lab's explicit setup functions, then replaces only the fixture under `app.world`. Existing routes remain available. Scene setup and mirrored spawn placement happen before an attempt starts. Reset during an active attempt is refused. The evaluator reads real contacts, body origin and support state; it never calls movement/input methods or writes body/actuator state.

## Course structure and geometry

This is an ordered **three-segment course with explicit segment-floor checkpoints**, presented through the suite UI. The arenas are separate resettable fixtures, not one uninterrupted physical world. Each segment starts with no pre-existing grip and a real visible floor; the player can walk, aim and choose contacts normally. The suite's Next/Retry controls end measurement before preparing a segment. It must not report checkpoint skips as an uninterrupted full-course run.

All solid geometry is static and data-driven in the revisioned JSON. Paint and labels are non-colliding. The main comparison configuration is profile 4, A0, B1, feet ON. The main harness may choose a different declared variant after setup; the adapter records the actual active configuration at attempt start.

| Segment | Layout | Live goal |
|---|---|---|
| M-A controlled ascent | Wall centred `(0,2.3,-.2)`, size `(3.6,5.4,.4)`; floor top Y=.25; two broad foot ledges at X=-.24/.28, Y=.51. | A real wall contact in broad X[-1.1,1.1], Y[2.35,2.90], actual body-origin Y>=1.40, at least one same-hand regrip and .20 s stable contact. |
| M-B asymmetric traverse | Wall width4.2m; initial illustrative contacts Y2.10/2.26; two optional real foot supports at `(0,.51,0)` and `(.65,.65,0)`. | A real contact in broad X[.50,1.30], Y[2.15,2.80], body-origin Y>=1.25, signed body X>=.22, a same-hand regrip and .20 s stable contact. Mirroring transforms geometry and signed direction. |
| M-C swing and catch | Small floor beneath source, cyan support centred `(-.55,2.20,.15)` and amber destination `(.35,2.20,.15)`, both size `(.30,.10,.18)`. | Observe a real source grip while the ground motor is ungrounded, then catch the named destination with a material point that was beyond the actual hand's anatomical reach in that reference pose. Retain the same hand/anchor for .60 s without native ground. |

The M-C reference snapshot is explicitly the **first real ungrounded source grip**, not the later click or authored hand animation. The evaluator compares the eventual *actual caught point* against the corresponding shoulder from that snapshot; it does not substitute the target centre for the caught point. The final scripted proof additionally checks the actual caught point was still outside reach plus .02 m **after W preload and before lateral pumping**. Thus a nearer resolved surface point is not silently credited as an out-of-reach catch.

For M-A/M-B, `attempt.transfers` counts same-hand changes of material contact point/support, used only as a minimal course regrip condition. It is not the suite's complete handoff metric: M-C may correctly show zero same-hand regrips while performing a source-hand to destination-hand transfer. The suite observer owns the full contact/handoff history.

There are no exact grip sockets, required hand sequence, jump/Space requirement, auto-grip, launch impulse or mastery score derived from copying the reference script. The M-A/M-B walls permit many lines. M-C exposes a broad destination, and the reference proof selects a nearer part of its existing underside rather than moving or enlarging the hold. No final top-out is included, so authored crossing cannot dominate this physical locomotion evaluation.

## Attempt and reset API

```gdscript
var course = preload("res://features/locomotion_test_suite/scripts/mastery_course.gd").new()
add_child(course)
var setup = course.apply_segment(app, 0, false) # 0=A, 1=B, 2=C; reset only
# Main harness selects its declared V0/V1/V2/V3/V4 here, outside measurement.
course.begin_attempt("practice", "human")
var outcome = course.evaluate()                # observation only
course.end_attempt("CANCELLED")                 # no player transport
course.apply_segment(app, 1, false)             # explicit floor checkpoint
course.restore(app)                            # original scene/settings, outside attempt
```

Modes are `familiarization`, `practice`, `scored`, `retention`; the first two explicitly set `scored=false`. Recording sources are `human`, `scripted`, `developer_exploratory`. Outcome history is bounded to128 attempts. Full per-attempt persistence, pseudonymous participant identity, balanced variant order, five measured attempts, later retention trial, ratings and failure tags belong to the main suite harness/recorder. No human sessions were performed by this agent.

`apply_segment()` returns ID/revision/resource hash, spawn, broad regions, goal specification, sample contacts and live support references. `supports` contains Godot objects for runtime use and must be normalized before JSON serialization. Unknown segment IDs and an active-attempt reset return explicit failures. Restoration reinstates the original scene, profile, foot/movement variants, posture settings, targeting, launch and diagnostic selections.

The original lab's R handler can reload its original arena rather than the substituted fixture. The suite must route its Retry action through end-attempt then `apply_segment`, and stop a run if an external reset changes the fixture. The adapter detects `FIXTURE_CHANGED`; it does not secretly move the player back.

## Final isolated technical evidence

Engine: Godot4.7.2 integrated Jolt, `ed1daf0bf`. Each accepted row ran in a fresh engine process; canonical and mirrored cases remain within that segment's process. This avoids treating accumulated solver/world history from unrelated segments as a controlled starting condition.

| Frozen isolated suite | 120 Hz | 60 Hz |
|---|---:|---:|
| M-A canonical + mirrored | 18 checks /0 failures | 18 /0 |
| M-B canonical + mirrored | 20 /0 | 20 /0 |
| M-C canonical + mirrored | 28 /0 | 28 /0 |
| Setup, practice, read-only evaluation, invalid reset and restoration contracts | 11 /0 | 11 /0 |

**154 distinct final checks across8 isolated executions;0 technical failures.** These checks establish feasibility and adapter contracts, not human control quality or a zero-failure player success rate. Archived development attempts and repeated earlier runs are not added to this total.

| Final M-C measurement | 120 Hz canonical / mirrored | 60 Hz canonical / mirrored |
|---|---:|---:|
| Actual caught point distance from free shoulder immediately before lateral pumping | .81314 /.95945 m | .80489 /.96099 m |
| Same real anchor retained | .60 /.60 s | .60 /.60 s |
| Scripted segment time, including grip/preload | 4.875 /4.250 s | 3.600 /4.050 s |

The proof uses normal mouse/action events, W preload, phase-based lateral input, finite braking from measured body velocity, then retained new contact after releasing the old hand. No transform, velocity or force writes occur during the measured attempt. The profile4 mouse remains targeting only. Shared admitted force/moment limits are checked throughout.

**Feet still matter:** B1 remains ON. Real feet contributed during preload and portions of the motion (sampled peaks approximately39-97N across the four final M-C runs). `ground_motor.grounded=false` does not imply arm-only suspension. These are physical catches using the baseline's actual supports, not proof of a pure arm-only pendulum. T06/T07 isolated capabilities and observer load accounting must keep that distinction. The proof does not claim the baseline's swing behavior is intuitive or that a human can reproduce it reliably.

## Failed attempts and robustness

[mastery/manifest.json](mastery/manifest.json) indexes30 development receipts, including the final8;13 of those development receipts have failing checks. Complete JSON traces are gzip archived beside available raw logs. Failed attempts were not overwritten. Development source was edited between recipes without an individual source snapshot for every edit; those historical receipts are exploratory debugging evidence, not valid paired A/B comparisons. Final isolated runs carry the frozen source hashes.

Important failures retained:

- The first mirrored ascent script used the wrong anatomical hand identity. Correctly reflecting the hand order fixed that test error without changing geometry.
- Early M-C input started while native ground still owned walking. It could catch a destination but could not demonstrate the intended supported swing setup. Later proof explicitly pulls away from native ground first and records real foot load separately.
- Catch alone was easy to mistake for success. Several trajectories reached real contact and lost it through extension/load shortly afterwards. The goal requires the same real anchor for .60 s; no forecast or short contact is credited as retained.
- A long preload could make a nearer surface point already reachable before pumping. Additional actual-point pre-pump checks caught that issue. The final proof passes the stricter check without changing geometry or reach.
- Fixed script deadlines cut off valid stable-contact observations just below .20/.60 s. The final helper waits a bounded interval for the real criterion rather than lowering its thresholds.
- **An ALL-segments120Hz execution still failed the canonical M-C catch after earlier arenas**, despite an isolated M-C pass. Receipt: `mastery/development/2026-10-20T00-39-29_38500_120hz/`,75 checks/2 failures. The matching ALL60Hz run passed77/77. This history sensitivity is not hidden by the later isolated successes. The reference input recipe is not a robust universal winning route.
- One parallel development log filename collided because timestamp resolution was insufficient. Per-run result directories remained unique. Final isolated logs use a process identifier and distinct filenames; no acceptance depends on the collided raw log.

**Geometry stayed revision1 throughout.** No support was moved, force tuned, body teleported during measurement or baseline behavior changed to improve comparisons. Changes between exploratory receipts were test hand order, input/preload/braking policy, timing bounds and stricter validation of what was being claimed. No variant superiority study was run here.

## Reproduction

Run each segment in a separate engine process. Add `--60hz` after the final separator for the comparative frequency; physics120Hz is default. `--segment-a`, `--segment-b`, `--segment-c` and `--safety` are accepted aliases.

```powershell
& 'C:\Users\Wynter\WrapRush\tools\godot.exe' --headless --path 'C:\Users\Wynter\grip_up' --script res://features/locomotion_test_suite/tests/test_mastery_course.gd --fixed-fps 120 --quit-after 30000 -- --segment=A
# Repeat in separate processes with --segment=B, --segment=C, --segment=SAFETY.
# Repeat each with --60hz appended.
```

On Windows use a process runner that waits for the GUI executable, such as Python `subprocess.run`, and capture stdout/stderr. A bare PowerShell launch may return before the engine finishes. Every test writes a unique `builds/v12_mastery/<timestamp>_<engine-pid>_<hz>/result.json`. Final accepted evidence is under `mastery/isolated_A_120hz/`, etc., with concise `summary.json`, raw output and compressed full trace.

## Decision and next action

**KEEP as an opt-in evaluation fixture; robustness INCONCLUSIVE; human mastery NOT_EVALUATED.** The suite can expose sequential practice/scored attempts and offer a later retention retry. Start the real familiarization/practice protocol, allow alternative player solutions, and measure catch failures and support load honestly. A reference automated run is feasibility evidence only.

Do not promote a movement variant, infer human learning, call this an uninterrupted route, or proceed to M7 based on these counts. Main-agent native monitor1 replay, integration/export validation, genuine participant attempts and the cross-task decision remain separate deliverables.
