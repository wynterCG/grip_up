# F0 - foot-release diagnosis, v1.4

**F0_PARTIAL. Provisional decision: KEEP_B1. B3 is not implemented.**

The player localized the problem to the side of the first wall of The First Ascent, while crossing toward the second section/bars. That observation remains valid. The six automated attempts do not yet isolate the exact episode felt by the player or establish actuator release as its repair. No automatic result is human acceptance.

## Observed evidence

| Attempt | 120 Hz | 60 Hz |
|---|---|---|
| B1 from spawn, A0/B2 OFF | Localized block reached | Localized block reached |
| B0 from spawn | Preparation failed at HIGHER_LEFT_WALL | Preparation failed at HIGHER_LEFT_WALL |
| B1 prefix, feet OFF at crossing | Diagnostic block executed | Diagnostic block executed |

Inputs use real actions and delivered mouse events, without artificial foot anchors, body-pose writes or geometry changes. Contact acquisition in preparation is adaptive; the final block has fixed commands/durations. B0 preparation failure is not a successful desticking comparison at the crossing.

At the switch, body transform/velocities, hands and native geometry are unchanged. The first state divergence is tick 900/455 after switch898/453, consistent with a previously submitted force not being retroactively removed. Subsequent neutral motion and contacts evolve differently, so later reversal onsets are not state-matched. The existing OFF setter changes both foot solver and visual ownership; it is not actuator-only ablation.

X displacement between first and last POST observer rows in each stage:

| Hz | Stage | B1 | After OFF at crossing |
|---|---|---:|---:|
| 120 | D .60 s | +.017361 m | +.045696 m |
| 120 | A .25 s | -.037362 m | -.031661 m |
| 120 | Requested one-hand D .45 s | +.043179 m | +.020768 m |
| 60 | D .60 s | +.035272 m | +.028373 m |
| 60 | A .25 s | +.017590 m | -.010264 m |
| 60 | Requested one-hand D .45 s | +.116649 m | -.020986 m |

OFF does not consistently improve D. During A60 there is real physical resistance: the right foot supplies +4.0502 Ns X against -7.3317 Ns from hands. It also supplies 27.58-37.05 N upward, has a valid path and 4.2-4.8 cm workspace margin. A points toward that support's side. Opposed force alone does not establish unwanted away-retention.

During A120 both feet remain SUPPORTING with zero applied force and nearly fixed visual targets while COM moves about3.74cm left. Native FootBase contacts are reported in all30 ticks. Unloaded visual anchoring and native contacts coexist; this is not a demonstrated visual-only cause. No persistent frozen FREE-foot anchor was observed.

## Interpretation and unknowns

Current classification: **mixed physical support/resistance, unloaded visual anchoring and native contact**. Their contribution to the player's episode is not yet established. Feet also assist the initial upward movement; removing them from spawn prevents this automatic preparation at both rates.

Passive leg endpoints feed future foot placement. Changing that logic is not necessarily appearance-only. Existing IK influence is shared across all four limbs, so globally fading it also affects hands. Neither an IK repair nor speculative B3 was applied.

The observer distinguishes actual force from cache, derived reaction from independent sensing, available native contact from UNKNOWN, and POST physics from post-modifier render observations. Rendered sole is a rest-calibrated proxy, not mesh contact sensing. The static course does not independently measure moving-support reaction momentum. Normal unobserved physics performance is not measured here.

## Concrete next step

First Ascent was opened on monitor1 through Godot MCP Pro, with B1/A0, profile4, hold-to-grip and opt-in recording. Reproduce the reported crossing, identify the moment it sticks and distinguish body blockage, visually stuck leg, or both. The panel permits fresh B0/B1 attempts and recording stop/restart without overwriting previous takes.

A localized episode with physics/render evidence will determine whether B3, presentation repair, or native/other-support investigation is appropriate. F1-F7 and a B3 human pilot are not complete.

Evidence: [independent physics review](F0_ABLATION_REVIEW.md), [IK review](ik_review.md), [recomputed measurements](F0_measurements.json), [delivery report](report.md). All six attempts, including failures, are preserved in F0_raw_attempts.zip with SHA/CRC readback in F0_archive_receipt.json.
