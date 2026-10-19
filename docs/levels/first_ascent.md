# First Ascent - continuous climbing greybox

Design snapshot: 2026-10-20. **Candidate geometry implemented in new level 21; overall physical verification remains pending at this update.** Root reports one 120 Hz scripted proof with 17/17 checks, all three route stages, native support and .3068 m walking. The 60 Hz replay is still being adjusted on a real bar contact. This is partial functional evidence, not both-frequency acceptance, measured player time or human enjoyment.

## Level name and theme

**FIRST ASCENT / The maintenance bay.** A compact industrial course joins floor movement, wall ascent, lateral transfer, arm-only suspension, a final rise and the retained Style V top-out. The user judged v1.0 good despite limited realism; this iteration exercises that mechanic in a continuous space rather than changes its feel.

The old approved **level 10 remains unchanged**. Level 21 subclasses its layout, then adjusts its two teaching bars and sample contacts to suit the new course's native-ground entry. These adjustments belong to the new level only. The new connection needs its own physical validation.

## Estimated play time

Target first successful attempt: **30-90 seconds**, excluding learning retries. This is a design target, not a measured result. Experienced direct runs may be shorter. No artificial delay should enforce the target duration.

## Player metrics and controls

All coordinates are metres: +Y up, +X right. The original wall front is Z=0. The two new-course bars and final deck share a front at **Z=.20**; the player approaches from +Z and finishes walking toward -Z.

| Existing property | Design consequence |
|---|---|
| Same 12 kg dynamic body; existing hand/foot/torque budgets | Reachability must come from geometry, actual contacts and ordinary input. No force increase, teleport or deleted floor. |
| Reach approximately .65708 m; imported arm approximately .54708 m plus .11 m palm allowance | Use actual loaded shoulder-to-contact witnesses, not just distances between clicked points. |
| Existing rest range .18-.62 m and actuator/rate limits | No instantaneous contraction or permanent arm overextension. |
| Held LMB/RMB; mouse selects surfaces | All existing grippable faces remain free. Paint and QA points are not sockets. |
| Intent profile 4: W/S up/down request, A/D lateral supported motion | Preserve the established controls and current feel. |
| MMB orbit, wheel dolly, R retry | No new camera or compulsory launch input. |
| Existing automatic feet | Retain real support; do not disable feet to manufacture a suspension measurement. |
| Style V v1.0, existing 1.15 s swept body route | No retime, Style C, classifier or second physics motor. |
| Actual attached static support, anchor within .20 m below the lip; body-relative eligibility | A real contact at Y=3.08 is .17 m below the Y=3.25 lip and may qualify. The hand does not have to reach Y=3.20. All other eligibility and path checks still apply. |
| Top probes lateral +/-.31 m and inward .08/.35/.65/1.12 m | Keep the intended finish away from side edges and provide a broad unobstructed deck. |

## Layout diagram

Front view toward -Z; this is a spatial guide, not hand positioning instructions.

```text
Y 3.85    original wall ends
Y 3.25                                   +====================+ FINAL DECK
Y 3.08                                   |  4 / CLIMB UP      |
Y 2.85                                   |                    |
Y 2.55          2 / CROSS ==== 3 / SWING ===|                    |
Y 2.35       1 / CLIMB                    |                    |
                  wall                   |   static slab      |
Y  .73         foot lips                 |                    |
Y  .25   ================= SAFE BASE ====|                    |
       X -.75       .5    1.1    1.75 1.95    2.60         4.35
```

Top view: deck X[1.95,4.35], Z[-2.60,.20]. Both bars' front faces also lie at Z=.20; the original wall remains at Z=0. The deck begins .70 m beyond the tall wall's right edge. The broad floor remains underneath the approach and most of the traverse.

## Implemented primitive schedule

Values are box centres and full sizes. All structures are static. The following table describes **level 21**, not a replacement for level 10.

| Primitive | Centre (X,Y,Z) | Full size (X,Y,Z) | Status in new course |
|---|---|---|---|
| Route wall | (.25,2.05,-.20) | (2.00,3.60,.40) | Inherited unchanged; front Z=0. |
| Safe base | (.65,.10,.75) | (4.80,.30,3.60) | Inherited unchanged; actual floor top Y=.25. |
| Lower lip | (0,.51,0) | (.95,.16,.22) | Inherited unchanged; real foot support. |
| Traverse lip | (.62,.73,0) | (.60,.16,.22) | Inherited unchanged. |
| First hanging bar | (1.10,2.56,.08) | (.85,.12,.24) | Wider/lower teaching bar in level 21 only. |
| Last hanging bar | (1.75,2.55,.08) | (.45,.12,.24) | Lower, coplanar front in level 21 only. |
| Final static deck | (3.15,1.425,-1.20) | (2.40,3.65,2.80) | Added; X[1.95,4.35], Y[-.40,3.25], Z[-2.60,.20]. |

The first bar spans X[.675,1.525], the last spans X[1.525,1.975]. They touch laterally; the last overlaps the slab by .025 m in X. Their aligned Z=.20 fronts remove the initial design's hidden backwards step to the final face. The first bar is wider/lower to offer arm slack under native-ground entry. These are geometry refinements, not extra strength or reach.

Spawn remains **(0,1.17,.40)**, on the real Y=.25 base. No pre-attached hand or suspended start. The painted final face is centred at (2.72,2.99,.209), size (1.02,.48), visual-only. Intended central lip approach is around X=2.60; X=2.26 is only the mathematical left probe limit and not a preferred centre.

At X=2.60, the retained motor's standing destination is approximately **(2.60,4.175,-.45)**. Compute exact Y from its actual lowest-point function. The deck leaves room for the existing .30 m normal supported walk toward -Z. All head/torso/leg/tuck clearance remains subject to full preflight and runtime sweeps in this geometry.

## Critical path

1. **Climb:** acquire real wall contacts around Y=2.10 from the floor and pull toward the cyan region. Existing lips provide real foot support and the base catches early mistakes.
2. **Cross:** alternate hands across the wall toward +X, retaining a real support, then take the wider first bar. Amber paint suggests the route without restricting grip selection.
3. **Swing and reach:** transfer across the connected bars and show actual arm-only suspension on the named last bar. Try small A/D loading/reversals while keeping a supporting hand, then reach onto the coplanar final face.
4. **Rise and climb up:** progress along freely selected front-face contacts until the actual hand/body configuration enters the existing mantle envelope. An anchor at Y=3.08 can be sufficient; reaching the sample point at Y=3.20 is not required. Hold W to request the certified transition, then release and walk normally onto the deck.

**Swing is encouraged, not a compulsory ballistic gate.** The bars are contiguous. This route permits pull/traverse and pendular play; it does not prove that a required gap or momentum puzzle is solved. Record actual body oscillation and supported input rather than calling every lateral transfer a swing. No Space launch or forced all-hands-off catch.

## Representative test contacts

These are the new level's stored QA selections. They are not grip sockets, body targets or proof that either hand reaches from every posture. Points 5-9 were refined with the new bars; the original level 10 sequence is untouched.

| Index | World selection (X,Y,Z) | Surface / intent |
|---|---|---|
| 0 | (-.24,2.10,0) | Initial left wall. |
| 1 | (.24,2.10,0) | Initial right wall. |
| 2 | (-.24,2.43,0) | Higher left wall. |
| 3 | (.24,2.64,0) | Higher right wall. |
| 4 | (.45,2.55,0) | Traverse entrance. |
| 5 | (.60,2.60,0) | Wall contact closer to the teaching transfer. |
| 6 | (.90,2.53,.20) | First bar front. |
| 7 | (1.25,2.55,.20) | First bar farther right. |
| 8 | (1.15,2.53,.20) | Alignment / uncross. |
| 9 | (1.75,2.53,.20) | Last bar front. |
| 10 | (1.80,2.53,.20) | Additional last-bar selection. |
| 11 | (2.03,2.65,.20) | First deck face selection. |
| 12 | (2.30,2.85,.20) | Central deck approach. |
| 13 | (2.60,3.20,.20) | Higher selected destination; exact height is not mandatory. |

Physics testing may insert intermediate free-face regrips or select a final actual contact around **(2.60,3.08,.20)**. Preserve actual shoulder, hand path, support and anchor evidence. The existing out-of-reach resolver can produce a nearer real contact than the selected point; that contact, rather than the click location, governs attachment and eligibility. Never change the detector's .20 m near-lip rule simply to pass the course.

## Broad progression and completion

The first two inherited CLIMB/TRAVERSE zones retain their previous broad contact rules. The level-21 suspension zone is **AABB origin (1.40,2.42,-.10), size (.55,.40,.45), minimum actual body Y=1.50**, on the named last bar. It still needs .20 s stable real contact, no ground and foot load at or below the existing 1 N threshold.

The course badge requires the observed three-zone sequence **and** this attempt's genuine final-deck completion: approved transition, valid standing body clearance, restored dynamic state, actual native top support and at least .30 m ordinary supported walking. An animation ending or bar grip alone is insufficient. Keep climb observation through expected committed hand retirement; do not pretend those old grips remain active or change the old level 10 reset contract.

The broad base permits a direct approach to the final face. This is a legitimate free-climbing alternative and may achieve a real top-out; it does not earn the full-route badge. The HUD distinguishes it as **TOP REACHED / ROUTE X OF 3** and explains: "You reached deck by another line. R to try marked route." There is no physical barrier, penalty, automatic reset or transport. Broad regions observe progress without becoming input locks or exact grip requirements.

## Optional paths and recovery

- Choose higher/lower contacts on the original wall and rejoin the bars.
- Walk right and practise the deck directly, with skipped beats reflected in the result.
- Try lateral loading/reversal on the connected bars. A later optional gap would need separate measured geometry and is not part of this candidate.
- Early falls naturally land on the base where geometry permits; ordinary locomotion returns the player to the wall. Existing fall/reset behaviour handles other falls.
- R restarts this course in the same selected mode and clears attempt evidence. The old comparison course remains separately available.
- A rejected preflight keeps ordinary physics. Committed obstruction uses the existing blocked recovery/R contract, without rewind or rescue lift.

## Encounter list and pacing chart

These are design targets, not measured timings or time gates. There are no enemies or stamina/timer pressure.

| Beat | Target first-run window | Intensity 0-1 | Experience |
|---|---:|---:|---|
| Floor and first grips | 0-10 s | .10 | Orient and use broad surfaces with real feet support. |
| Wall ascent | 10-25 s | .35 | Choose a higher contact and feel supported pull. |
| Traverse | 25-40 s | .50 | Alternate hands and move weight right. |
| Arm-only suspension | 40-50 s | .65 | Read the final face while supported by arms. |
| Deck rise | 50-70 s | .70 | Load, regrip and gain the last height. |
| Assisted crossing | Existing 1.15 s after valid commit | .50 | Clear mode change with the existing input. |
| Ordinary deck walking | Final 5-10 s | .10 | Recover locomotion and finish above the route. |

## Readability, narrative beats and audio cues

The spatial beat is simple: start below the maintenance structure and finish above it. No new lore or quest system. The implemented world labels are **1 / CLIMB, 2 / CROSS, 3 / HANG, 4 / CLIMB UP, FINISH**. The contextual HUD explains swing/reach and ordinary walking. Paint remains visual-only; avoid placing labels over likely hand targets.

Keep the finish visible from the approach and enough +Z camera room to inspect the bars/face using existing orbit and dolly. Do not force a cinematic camera during transfer.

Retain current grip/load feedback and ordinary footsteps. No new music system is required. A later audio pass could contrast suspended ambience and deck footsteps; that is a suggestion, not implemented work in this design handoff.

## Validation handoff and risks

Root implemented the new level and the physics agent supplied an actual-input replay. Final headless and visible MCP receipts, with their exact source manifest, are indexed in `../validation/v10/course_verification.json`. Automated completion does not establish human comfort or enjoyment.

1. Keep the original level 10 regression unchanged. Prove the new course independently at 60 and 120 Hz from actual floor spawn, with finite held inputs and no body transform/velocity writes, deleted floor, force multipliers or direct commit shortcut.
2. Record real contact positions/supports and reach, force/torque peaks, foot load, falls and broad-zone history. Prove actual last-bar arm-only suspension before the deck bridge, without suppressing feet.
3. Record real lateral pendulum motion under supported input. Its amplitude and comfort remain measurements to obtain, not implied by the label.
4. Validate the complete final swept route, standing footprint, off-centre valid approach and too-near-edge refusal in the new geometry. The old motor's certificate does not certify a newly arranged scene.
5. After genuine commit, release grips and W, restore on the named deck and walk at least .30 m through normal locomotion. Check rearming and R. Preserve current-attempt route evidence through hand retirement.
6. Replay visibly on monitor 1 through Godot MCP Pro. Automated playback is functional evidence; the user's playthrough judges readability, comfort and enjoyment.

Remaining risks: the .025 m bar/slab X overlap can produce awkward crossing-hand routes; a contact near X=2.03 is outside the safe mantle corridor; appending the slab must not turn an old `holds[-1]` assumption into false suspension or victory; full-route evidence must distinguish direct approaches; lip height is body-relative eligibility, not an absolute-height guarantee. A real anchor at Y=3.08 can qualify without stretching the arm to the Y=3.20 click, but only actual contact and full preflight prove that case.

Default promotion, retiming, Style C, moving supports, a new locomotion solver and compulsory jumping remain outside this course iteration.
