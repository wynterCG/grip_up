# Contextual Arm Control: user-directed experiment

This replaces the deliberate aim/arm-length coupling in the earlier v0.3
experiment. Profile 0 (baseline) and profile 1 (relative pixel-driven arm
lengths) remain comparison modes. The new default is **profile 2**.

| Situation | Relative mouse movement |
|---|---|
| No attached hands | Direct both free-hand virtual targets toward potential supports |
| One attached hand | Direct the free hand and request supported physical effort through the attached hand |
| Two attached hands | Request supported posture and effort through both arms |
| W/S | Camera-relative supported depth swing |
| A/D | Camera-relative supported lateral swing |

The user explicitly wants aiming to another position after a full pull to be
possible without obligatorily extending the supporting arm again. Renaming
the previous pixel-to-length accumulator as relative input would not meet that
requirement. No Shift/Alt clutch or toggle grip is required in this experiment.

## Concrete implementation for this prototype

Relative mouse is captured during play. Each free hand has its own camera-plane
virtual target, centered on its anatomical shoulder and clamped to the measured
reach sphere. Real camera raycasts choose visible grippable surface points;
the existing physical reach checks, finite endpoint movement and obstruction
sweeps remain authoritative. Hold LMB/RMB to reach and keep each selected grip;
mouse-up releases that hand immediately.

Horizontal delta requests transient lateral effort; downward delta requests
transient pull, following the user's subsequent inversion request. Upward delta
moves free-hand aim and requests active physical extension, following the user's
correction that contraction alone was insufficient. Supported arm targets are
derived from actual geometry and bounded
effort, retaining only achieved contraction with the existing elastic tolerance.
Mouse pixels do not accumulate arm length. An obstructed body cannot accumulate
an arbitrarily shortened target. The body remains dynamic at all times.

The two-hand case uses the same shared budgets. Mouse posture effort and WASD
swing share the existing assistance cap. Dynamic supports receive opposite
reaction forces and moments; an ungripped character receives no air motor.

MMB orbit owns mouse motion. Escape opens/closes Controls and releases/recaptures
the cursor. Focus loss clears intent and releases grips; a resume click is
consumed without accidentally catching. UI, capture and resize transitions
clear stale relative deltas. The existing wheel dolly remains available.

## Limits to evaluate

One attached hand shares aiming and supported effort: upward aiming can now
physically lower the body. The virtual aim remains independent of screen edges
and no target length is computed from cursor position. Virtual aim uses a
camera-facing reach plane, not full independent 3D hand-depth input.
Both free hands share the mouse motion until one attaches. These are explicit
prototype choices, not claims about another game's implementation.

Test actual rise, retained posture during reverse aim, second-hand acquisition,
release/regrab, camera/UI ownership, physical obstacles, dynamic support
reactions and 60/120 Hz. Human coordination, comfort and enjoyment remain
playtest questions rather than automatically verifiable outcomes.
