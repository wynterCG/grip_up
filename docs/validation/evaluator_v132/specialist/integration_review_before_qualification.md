# Integration review before v1.3.2 qualification

Scope: read-only review of the new qualification driver, runtime metric helper, input validator and prospective experiment plan. No engine was launched and no production or evaluator source was edited by this review. This is not an outcome or envelope signoff.

## Preparation-screen amendment

The declared suffix is a valid diagnostic distinction: after the fixed script and quiet-onset observation, apply the same bounded directional input used by motion preparation (maximum2 s), then request real neutral for one tick and recheck actual accepted input, directed speed, support and clearance. This distinguishes a script that can reach quiet hanging from one that can also enter a useful [.15,.50] m/s stop/brake/reverse state. It adds no body force, reacquisition, reset, velocity assignment or changed readiness threshold. Separate quiet and motion selections must remain versioned and frozen before qualification; development outcomes cannot be relabelled as qualification.

Motion selection must also require the same quiet eligibility traversed by the actual motion-control path. A screen with quiet=false / motion=true does not establish that the complete real control preparation will pass its preceding quiet gate. Use explicit conjunction or keep that state unselectable for the existing flow. Preparation IDs differing between headless and rendered runs are valid coverage evidence in Lane A, but not the same setup for fixed-input physical equivalence.

## Review findings sent to integration owner

1. Fail closed for R0 outside its implemented catch/context path. A new control/prep ID must not silently execute Lane A while labelled R0. A preceding adaptive context episode may be explicitly A_CONTEXT; that does not make its commands part of a certified R0 distribution. The owner subsequently reported rejection of unsupported R0 contexts and explicit A_CONTEXT metadata.
2. Recheck counter signed entry [-.50,-.02] and clean quiet lateral/spin criteria at actual accepted onset, as already done for directed motion and full-norm low-energy. A qualifying prior snapshot is not proof that the next accepted snapshot stayed inside the interval. Failure should be PRECONDITION_NOT_MET, with no retry or body correction.
3. A conservative sweep result is geometric certification information. A query-only POSSIBLE_GROUND_INTERSECTION must not be described as an actual native contact. Preserve distinct reasons such as CLEARANCE_NOT_CERTIFIED versus ACTUAL_SUPPORT_INTERRUPTION. If raw case validity and a typed metric differ because of that conservative query, retain an explicit flag/scope rather than silently asserting a fully certified window.
4. Preserve original requested tape fields. Reading actual Input held state or current pointer and writing them over replay-requested fields can hide the requested/accepted distinction. Keep observed emission state separately and compare it to the frozen tape. The Python validator already rejects unsupported nonzero camera input; the direct Godot route should reject it too if orbit/dolly are not implemented.
5. Name the retention timestamp precisely. Repeatedly assigning retained_tick after a .6 s confirmation reports the last such tick, not its first confirmation. Record the first confirmation or expose first/last separately; this is timing semantics, not a change to grip physics.

These are integration-owner findings. This document does not claim they were all fixed without a subsequent source/test receipt. The source amendment invalidates any earlier tape as intended; create a fresh content-addressed tape after the complete freeze.

## Metric interpretation

The runtime helper uses actual COM path and full linear/angular quiet bands. It reports the first stable-interval start after future .25 s confirmation, not an instantaneous stop. Active-brake fractions must occur while the actual opposite command remains accepted; passive damping after release cannot earn the fraction. Ground/anchor interruption and conservative clearance uncertainty are separate from an actual failure to decelerate. Static-frame-only formulas should explicitly reject unknown moving support frames rather than insert zero velocity.

The prospective controls protocol is adaptive preparation followed by fixed observation commands, not an additional qualified R0 acquisition/replay lane. The full specification's R0-control comparison remains unestablished unless implemented and audited separately. A partial diagnostic delivery is acceptable with named missing coverage and NO_GO where that capability is essential; fixed observation commands alone must not be advertised as a full fixed replay.

No numerical cross-mode score envelope is approved here. Separate reference distributions per Hz/mode/fixture/preparation, compare physical trajectories only while accepted commands and effective targets match, and retain the historical adaptive catch branch sensitivity. These observations do not justify a controller, force, threshold or geometry change to obtain passing qualification results.
