# Independent F0 ablation review

2026-10-21. Read-only review of the four original episodes and the two authorized in-state ablations. No engine was run by this reviewer and no gameplay source was changed. The two new raw folders are `builds/foot_release_v14_r1/attempts/F0_ABLATION_120_headless` and `F0_ABLATION_60_headless`.

## Explicit gate judgment

**F0 PARTIAL: keep B3 dynamics blocked at this boundary.**

B1 is demonstrably a physical contributor to resistance during the 60 Hz A reversal. It is not merely a visual effect in that particular interval. The evidence does **not** establish that the reported sticky-away problem is caused by unwanted B1 retention, or that releasing that useful support is the appropriate repair. The localized D comparison is mixed across frequencies and one-hand stages. The stronger measured A counterforce occurs while moving toward the patch, with useful upward compression and valid geometry, rather than an overextended foot resisting departure.

This is not an assertion that B1 is harmless, that the user did not encounter sticking, or that native contact alone caused it. It is a narrower classification: physical support resistance is present in one reversal; unloaded retained state and native contacts also occur; unwanted actuator retention remains unproven. Do not implement B3 from an opposed-force sign alone. Prioritize the independently owned presentation review and the visible/player-localized reproduction, keeping the physical baseline intact.

## Intervention validity and phase

Both ablations prepare with B1, A0, B2 OFF and profile 4, then invoke the existing `app._set_physical_feet(false)` immediately before the diagnostic block. The common prefix matches the corresponding B1 run exactly in COM, velocity, spin, hand snapshots and native collider transforms. The switch is tick 898 at 120 Hz and 453 at 60 Hz. The immediate before/after receipt confirms unchanged body pose, velocities, hands, collision layers/masks and collider transforms.

The first subsequent POST body state is still identical at ticks 899/454. The first body/velocity/spin/hand-force differences occur at 900/455. This matches the declared boundary: a force already submitted before the toggle is not removed retroactively. There are 369 and 185 post-switch observer rows respectively, all with zero applied foot force. Native colliders remain active. No real hand support is lost before intentional cleanup in either ablation.

The existing switch includes ordinary foot-solver reset and changes physical-foot visual ownership. It is a legitimate state-matched intervention on the B1 system. It is not a later, independently matched A-onset intervention: the first neutral interval has already changed the subsequent motion, hand loads and native collision history. The hand-defined frame remains world right/up/back in both runs, so the recorded A/D axes themselves did not flip.

## Matched command blocks, different evolving physical states

These displacement numbers compare first and last POST COM samples carrying the named stage, matching the integration owner's comparison. They differ from the driver's section START/END boundary convention used in the earlier review.

| Hz | Block | B1 COM X displacement | After feet-OFF switch |
|---|---|---:|---:|
| 120 | D .60 s | +.017361 m | +.045696 m |
| 120 | A .25 s | -.037362 m | -.031661 m |
| 120 | Requested right-hand-only D .45 s | +.043179 m | +.020768 m |
| 60 | D .60 s | +.035272 m | +.028373 m |
| 60 | A .25 s | +.017590 m | -.010264 m |
| 60 | Requested right-hand-only D .45 s | +.116649 m | -.020986 m |

OFF does not consistently improve the requested D response. In the 60 Hz D block, B1 starts at X velocity +.00529 m/s while the switched trial starts at -.40054 m/s after the preceding neutral. In the later right-hand-only D block, the corresponding starting velocities are -.04910 and -.61410 m/s. Comparing only displacement would mislabel those changes as better/worse release without accounting for momentum and support utility.

At 120 Hz D, net foot X force assists the requested direction; nevertheless the switched trajectory advances farther. That observation can include changes in moment, vertical support, hand force and collisions. It is not direct evidence of negative lateral foot force pinning the body. At 60 Hz D, the loaded foot strongly assists rightward movement. FootBase is reported in 0/36 B1 rows and 23/36 switched rows, demonstrating that physical native contact can remain or increase with feet OFF.

## The actual physical resistance at 60 Hz A

During ticks 526-540, both hands remain ATTACHED. The right foot is SUPPORTING on `Traverse lip`; the left foot has zero applied force. There is no ground-motor force in either comparison's diagnostic blocks.

The right foot has a negative projection onto requested A, reaching -18.1333 N. Its world-X applied-force integral over these 15 current-control rows is **+4.05020 Ns**; the hands' corresponding world-X integral is **-7.33166 Ns**. The switched trial has no foot impulse and a similar hand integral of -7.22924 Ns. It reaches a more negative end X velocity (-.31454 versus -.05683 m/s), despite starting with more positive X velocity (+.27240 versus +.18216 m/s). This is meaningful evidence that foot support contributes to the slower reversal. These integrated submitted forces are not presented as a closed momentum balance: native impulses and reported force rows have their own integration phase.

The same foot also supplies **27.58-37.05 N upward**, an 8.00937 Ns upward applied-force integral during the block. Its anatomy/path validator remains valid. Workspace margin is .0420-.0482 m, not an observed reach failure. The support-to-hip axis dotted with A is about -.43 to -.45: the requested movement is toward that support's horizontal side. Actual hip distance rises slightly through coupled vertical/rotational motion; that does not turn A into a demonstrated command to move away from the patch. Retaining a compression target can resist such bending while carrying genuine load. Automatically releasing it needs a deliberate design/policy justification beyond the measured counterforce.

Native FootBase contact is present in 4/15 B1 A rows and all 15 switched A rows; torso contact is also reported. At A onset, B1 COM is approximately (.73798,1.56384,.29982) with substantial pitch velocity, while the switched trial is (.75228,1.58359,.24219) with different spin. Thus the A comparison has not isolated identical geometry/momentum at its own onset. The change is causally downstream of removing B1 at the common prefix, but its later magnitude cannot be attributed entirely to one retained foot force.

At 120 Hz A, both feet instead remain SUPPORTING with zero force. That reversal already moves left under B1. Native FootBase contacts remain present throughout both runs. This is a useful control against claiming a universal actuator-glue mechanism at the same named section.

## Safety and limits

Both ablations finish the diagnostic block without script errors or reported cap violations. Their whole-attempt peaks are the same pre-switch peaks as the corresponding B1 preparation: hands 266.794/209.872 N, legs 95.680/102.452 N and combined moments 54.317/41.966 Nm at 120/60 Hz. Those remain below the unchanged 360/180/150 ceilings; native collision impulses are not additional foot-actuator authority. No body or native geometry was changed by the switch. This static route does not independently test dynamic-support reaction momentum.

Reported native contacts are affirmative observations, not proof that every relevant constraint is fully represented or that a particular contact causes the symptom. Zero-load SUPPORTING observations establish retained state, not the final rendered foot pose; the separate IK review must assess that presentation. No headless result provides a human feel verdict.

## Immutable evidence identities

| File | SHA256 |
|---|---|
| F0_ABLATION_120_headless/physics.jsonl | `e1178bacfa5bfb2abbb22b015866a0d8a888b31a9aa9f2a8894bfc2d81b5bdb1` |
| F0_ABLATION_120_headless/attempt_report.json | `9912e52a1ff62aff23bd65034b3cc0aea2fcf87b7e288835f0d74b846f4d8fd4` |
| F0_ABLATION_60_headless/physics.jsonl | `cca01b20756be1eb14dc07afb02c1180d515c2d32bf30a44870b2755c9a1f471` |
| F0_ABLATION_60_headless/attempt_report.json | `dfd689f38455c5b722081a409be1d9f8358c235290929c2e1739b057db48f680` |

The original four traces retain the hashes recorded in `F0_INITIAL_TRACE_REVIEW.md`. The ablation driver SHA256 is `b2178440dc39af411d6b7c2bb587026ec374fe08d5f8bf28c164598391eaa5af`; the original driver is separately archived with exact SHA256 `395bf7549cf896f02ded36c483a0650f33ec7abcb69c58284dbbc5a167dad943`.

**Recommendation: no B3 dynamics change at this F0 boundary.** Preserve the useful compression evidence, the real 60 Hz reversal resistance and the mixed negative results. Do not relabel this partial diagnosis as an improvement or a full explanation of the player's localized complaint.
