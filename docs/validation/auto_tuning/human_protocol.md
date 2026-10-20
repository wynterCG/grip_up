# v1.3 human comparison protocol

2026-10-20. **Prepared protocol; no human sessions, preferences or ratings recorded here.** Automated optimization and physics checks cannot satisfy AT6. This study asks whether a frozen tuning helps a player control the existing character while preserving weight, inertia and manual skill.

## Entry and comparison conditions

Only test candidates that have passed the independent physics gates and frozen-shortlist validation. Keep BASE-A0-B1 available throughout. Compare A0 against each of at most2-3 frozen finalists separately; do not mix A1/B2, a different feet setting, camera assistance or swing-feedback presentation into that comparison.

Freeze source/build, candidate parameter hash, geometry revision, control bindings, mouse sensitivity/DPI where known, resolution, camera initial settings, graphics/frame pacing, physics frequency and feet flag. Default human comparison is120Hz after both60/120Hz technical validation. A later60Hz human block is separate evidence, not a pooled equivalent. Keep diagnostic overlays off during ordinary attempts.

Use short neutral labels A/B with a concealed mapping when a facilitator is available. Do not display “optimized”, scores or expected winner. A self-testing designer may recognize the baseline or know the mapping; record that as unblinded self-evaluation rather than claiming blind testing.

## Participants and minimum sequence

Start with the designer's controlled repeated A/B tests. Then invite3-5 people unfamiliar with the project **when available**. Use a short pseudonym, and optionally record familiarity with third-person games, mouse aiming and physics games. No names or unrelated personal data are needed.

For each baseline/candidate pair:

1. Explain existing controls neutrally. Give equal familiarization under each configuration and one untimed practice attempt per task/configuration. These are not clean measured successes.
2. Test four existing task families: Vertical Pull, Asymmetric Traverse, Swing & Catch, and continuous First Ascent including assisted top-out and normal walking. Keep hands, aim, route and timing fully player controlled.
3. Run at least **two paired measured blocks** for the designer. Each block includes one attempt per task under A0 and candidate; reverse the condition order in the next block. This gives repeated comparison without forcing a long uninterrupted session.
4. For unfamiliar participants use the same paired structure where comfortable; split into short sessions if needed. Rotate AB/BA starting order across participants. Balance task order using a declared schedule, keeping equal practice rather than always giving the candidate the benefit of later familiarity.
5. Where practical, repeat a small subset after a break or unrelated task. Label it retention. Extend to five measured attempts per selected task if studying learning, but do not demand extra attempts merely to obtain a favorable result.

Record actual session order and breaks. Stop or pause when the player requests it or sustained discomfort/fatigue interferes with play. A partial block remains partial evidence. Do not infer permission to finish it or fill missing data from elapsed time.

For more than one finalist, compare each against A0 on a separate balanced block. Do not run every finalist sequentially with no renewed baseline reference or rest. Candidate parameters stay frozen through the block; changing them creates a new candidate and comparison.

## Attempt record

Before each attempt save source=`human` or `developer_exploratory` as appropriate, pseudonym, familiarization/practice/scored/retention mode, condition code, candidate/build/geometry hashes, frequency and attempt order. Automated demonstration input is source=`scripted` and cannot be relabelled human because someone watched it.

Record completion, elapsed time, falls, retries, missed grips, accidental releases, actual contacts and retained catches, camera corrections and recoveries. Capture input/telemetry with the same settings under both conditions. Do not intervene in grip selection or run an automated route for a struggling participant.

First Ascent completion means the continuous climb/transfers followed by the explicitly assisted crossing, native sole support and at least30cm normal walking. A checkpoint skip or direct alternate line is recorded as such. Mastery M-A/B/C can provide extra segment practice, but they are separate checkpoint fixtures, not substitutes for a continuous First Ascent completion.

After a failure, ask the player to describe what they intended and what they believe happened before showing a technical diagnosis. Preserve their explanation separately from the log classification. Suggested optional tags: `MISREAD_HOLD`, `CURSOR_SELECTION`, `CAMERA`, `UNEXPECTED_PHYSICS`, `MISTIMED_SWING`, `BAD_SUPPORT_CHOICE`, `GRIP_OVERLOAD`, `FATIGUE`, `OTHER`.

## Eight ratings with anchors

After each measured condition block, ask for1-5 on each item and a short reason. Missing answers stay null. Do not combine them into one preference score.

| Item | 1 | 3 | 5 | Direction |
|---|---|---|---|---|
| Input responsiveness | Hard to connect input to movement; long or erratic response | Usually responds, with noticeable hesitation | Reacts reliably when intended | Higher is better |
| Precision | Cannot stop, align or correct where intended | Can correct with extra effort | Can deliberately position and stop | Higher is better |
| Swing control | Motion and catches feel mostly accidental | Can sometimes pump/brake and explain a catch | Can intentionally build, brake and reproduce a catch | Higher is better |
| Perceived physical weight | Gravity/inertia feel incoherent or easily ignored | Some convincing weight with inconsistent moments | Weight and momentum feel coherent while still controllable | Higher is more coherent, **not heavier** |
| Fairness | Success/failure feels arbitrary | Can explain some outcomes | Can anticipate limits and explain why a move worked or failed | Higher is better |
| Fatigue | No meaningful physical or mental fatigue | Noticeable effort; a break would help | Strong fatigue; would stop or change activity | **Higher is worse** |
| Skill expression | Results depend on luck or automatic motion | Some useful techniques can be learned | Practice enables deliberate, repeatable choices | Higher is better |
| Willingness to play again | Would stop now | Might try another attempt | Actively wants another attempt | Higher is better |

Fatigue is intentionally recorded in its natural direction; do not silently reverse it in charts. Physical weight rates coherent consequences, not maximum slowness or realism. Swing control may be `NOT_ASSESSED` for a block with no meaningful swing opportunity; never impute5 from a quick vertical completion.

The existing v1.2 UI has seven different rating labels and a free-text fatigue note. It does **not** already implement these eight v1.3 items or their anchored scale. Until an explicit v1.3 form exists, use a separate labelled response record linked to the real attempt/session ID. Do not reinterpret old comfort as measured fatigue, invent a physical-weight score, or describe this prepared protocol as a completed UI feature. Include the complete candidate parameter hash/values in that linked record; v1.2's abbreviated tuning display is not sufficient candidate provenance.

## Forced preference and interview

After both sides of a measured pair, ask:

> If you had to keep one for the next session, would you choose A or B? Give one short reason.

Record the forced choice, confidence (`low`, `medium`, `high`) and the player's wording. If the difference felt negligible, retain their required A/B choice with **low confidence** and “no meaningful difference” in the reason. Do not present that as a strong preference. If one side was not actually tried, mark comparison incomplete and do not invent a forced choice.

Then ask a small neutral subset:

- Which action was hardest to make the character do?
- What caused the last failed catch, in your view?
- Could you reproduce the movement on purpose?
- When did the camera or grip aiming interfere?
- Did anything feel wrong even when the move succeeded?

Avoid “Was the optimized version smoother?” or revealing which choice would agree with telemetry. The designer may prefer A0 despite a faster candidate; that disagreement is useful evidence.

## Interpretation and decision

Report within-person paired outcomes, raw ratings, choices/confidence and notes. Include order, practice, breaks, valid attempts, failures and incomplete comparisons. Summarize spread and worst cases rather than just means. Separate learning the layout from learning reproducible swing/control; a single faster run establishes neither mastery nor a better controller.

- **KEEP as a selectable experiment:** physically valid, no major held-out loss, and a repeatable perceived benefit without removing meaningful difficulty or manual choice. Retain baseline. Default promotion still needs the user's explicit decision.
- **REVISE:** mixed preference, fatigue/precision trade-off, or a clear issue that warrants a separately scoped new candidate and fresh comparison.
- **REJECT:** instability, overfit, unwanted automatic behavior, reduced expressiveness or consistent preference for A0 without compensating benefit.
- **INCONCLUSIVE / AT6 pending:** insufficient authentic trials, inconsistent weak preference, missing comparisons or no participant yet. This is an acceptable outcome.

Three to five unfamiliar testers form a small design pilot, not evidence of broad consumer preference. Designer self-tests and unfamiliar-player sessions are separate evidence streams. If no additional participants are available, report that fact; do not fabricate attendance, scores, quotes, agreement or improvement.

No human result is entered by this protocol document. Session artifacts must come from actual play and preserve that provenance. M7, RL research and shipping/default adoption do not start automatically when this protocol or the optimizer completes.
