# Independent F0 review: first four fresh episodes

Read-only analysis, 2026-10-21. Inputs are the four `builds/foot_release_v14_r1/attempts/F0_B{0,1}_{120,60}_headless` folders. No engine was run by this reviewer. The original driver is preserved at `builds/foot_release_v14_r1/source_F0_original/foot_release_repro.gd`, exact SHA256 `395bf7549cf896f02ded36c483a0650f33ec7abcb69c58284dbbc5a167dad943`.

## Decision at this boundary

**F0 is not yet causally classified. B3 is not justified by these four episodes.** B1 reaches the localized wall/bar crossing at both rates; fresh B0 cannot complete the higher-left-wall transfer earlier in the route. The B0 result is missing localized coverage, not a matched experiment proving a B1 obstruction. Both B1 runs retain some real hand support throughout measurement.

## Independently read measurements

The following displacement numbers use the driver's recorded section START and END torso origins. They are not the difference between the first and last observer rows carrying a stage label; those different boundaries can differ by one integration. The body has configured zero local custom COM, but these are explicitly origin displacements.

| Condition | Result | W 3 s vertical rise | D .60 s horizontal displacement | A .25 s horizontal displacement |
|---|---|---:|---:|---:|
| B0 120 | Preparation failed at HIGHER_LEFT_WALL | +.163178 m | Not reached | Not reached |
| B0 60 | Preparation failed at HIGHER_LEFT_WALL | +.137873 m | Not reached | Not reached |
| B1 120 | Diagnostic block reached | +.271944 m | +.013698 m | -.036399 m |
| B1 60 | Diagnostic block reached | +.274638 m | +.035360 m | +.020626 m |

The earlier upward difference is consistent with useful physical foot contribution. It does not establish a controlled isolated measure of foot benefit, since subsequent body state and contacts differ.

During D .60 s, minimum summed opposing foot-force projection is 0 N at 120 Hz and -.300635 N at 60 Hz. A very small D displacement is therefore not explained by sustained large opposing foot force in that block. At 120 Hz the A reversal has 60 SUPPORTING/zero-force foot observations, with FootBase contacts reported in all 30 physics rows. At 60 Hz the A reversal has one loaded and one zero-force SUPPORTING foot throughout its 15 rows; opposing projection reaches -18.1333 N, with FootBase contacts in 4 rows. This is evidence of a possible mixed contribution in a reversal, not proof that the foot is erroneously pinning: actual body momentum still carries X forward during that short 60 Hz reversal.

Across the complete B1 traces there are 842 SUPPORTING/zero-force foot observations at 120 Hz and 336 at 60 Hz. The source permits visual anchoring in those states. These physics observations establish zero load with retained state; actual visible pinning must be checked by the separate render/IK review and the player's reproduction. They are not, by themselves, measurements of the final rendered bone or sole.

## Safety and observation scope

All 3,243 recorded physics rows were inspected for per-foot force magnitude, nonnegative compression, a tangent bound of .85 times normal force, zero force in FREE/SEARCHING/PLANTING, and zero hand force in FREE/REACHING/RELEASED. No violation was found at numerical allowances of .001 N for the cone/caps and 1e-6 N for zero-force states. The .85 test is the known nominal upper bound, not independent validation of each material's possibly lower coefficient.

Reported whole-attempt peaks:

| Condition | Shared hand force | Shared leg force | Combined moment |
|---|---:|---:|---:|
| B0 120 | 186.172 N | 0 N | 64.766 Nm |
| B0 60 | 172.654 N | 0 N | 53.209 Nm |
| B1 120 | 266.794 N | 95.680 N | 54.317 Nm |
| B1 60 | 209.872 N | 102.452 N | 41.966 Nm |

These remain below the unchanged 360 N / 180 N / 150 Nm limits. Per-foot peaks read from trace are 93.8455 N at 120 Hz and 78.1780 N at 60 Hz, below 120 N. No native contact buffer was marked full. Reported native contacts are affirmative API observations; their presence does not identify the share of causal resistance. A row without reported contact still is not an unlimited absence proof. Dynamic reaction pairing is only a source-law/derived diagnostic here; this static course does not independently measure a moving support's momentum.

## Authorized next intervention

The owner reserved two additional fresh B1-prefix episodes, 120/60 Hz, with an explicit `--ablate-at-cross` intervention. The existing UI feet-OFF setter is called synchronously immediately before the same diagnostic block. It resets the foot solver and changes physical-foot IK ownership as it normally does; it is not a pure actuator-only intervention. Its report labels `B1_TO_B0_ABLATION`, verifies unchanged body pose/velocity/spin, hand snapshots and native collider transforms/masks, and retains exact before/after state.

The switch is after the controller and observer in that physics callback. A force already submitted that tick is not retroactively removed: the first subsequent integration is a transition. Interpret later response with that known boundary, and retain native/hand/ground measurements. No new anchor, body write, impulse, geometry change or B3 algorithm is introduced. These episodes have not yet been reviewed in this document.

## Raw trace identities

| Attempt | physics.jsonl SHA256 |
|---|---|
| F0_B0_120_headless | `4cfbc2b1cad266159b21d13f3c5fe8f38b814cb5af806736e80666e999e7283f` |
| F0_B0_60_headless | `be0aee6c986ba2ba83281f9ebd8319359849cea7b45e79c20f6482ec68a70698` |
| F0_B1_120_headless | `18a9c499f48188ff1569c1e9cd98e58fadc9288acc61e96e7aa2a892f70d8f4f` |
| F0_B1_60_headless | `20233d0d14a2c2266a695ebbd0fca928f6ef7c5e8915b5b537c493075c83737b` |

No human-feel verdict follows from this automated block, and no footprint/contact-state label is promoted into a causal diagnosis.
