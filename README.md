# GRIP UP / physics climbing lab 0.3

Open `project.godot` in Godot 4.7.2, or launch `builds/GripUp-v0.3.exe`.
PC mouse and keyboard. Resizable 1920x1080 reference canvas; initial window 1440x810.
Integrated Jolt, 120 Hz. Core and complete routes also tested at 60 Hz.

This is a separate prototype. The Janga object grabber and its project are unchanged.

## 0.3: hold, drag and supported swing

The game now opens in **Profile 1**, following the user's request to use the
new controls immediately. Hold LMB/RMB to keep each hand attached. Move the
mouse up to shorten attached arm targets; move down to extend them. With both
hands attached the same drag changes both targets. Aiming for the next grip
intentionally keeps changing the supporting arm. A hand still reaching never
stores drag to apply later.

WASD requests supported 3D swing while gripping; W/S no longer change arm length.
Each held direction uses the camera frame captured when that key was pressed.
MMB orbit suspends arm drag, keeps the grips and discards camera mouse deltas.
Ground walking is unchanged. Space launch is OFF in this profile, available
only through an explicit comparison checkbox. Controls also offers sensitivity,
target speed, sound muting and the preserved **Profile 0** baseline.

This is an input experiment, separate from v0.2's posture milestone. Physics
limits remain 360 N shared hand effort, 20 Nm assistance and 150 Nm total.
Physical feet and predictive catches remain independently optional and OFF.
Automated checks do not establish comfort, fatigue or enjoyment: the 10-15
minute human A/B session and the final feel decision remain pending.
See `docs/validation/V03.md` for evidence and limits.

## M2: physical feet

Enable **Controls → Automatic foot contacts**, then select **04 FOOT SUPPORT**.
Select baseline profile 0, hold LMB/RMB on L/R, press W and compare feet OFF/ON.
Each foot independently searches, lifts over a step, plants, supports or slides.
It can push and transmit friction, with a shared 180 N leg budget; hands retain
360 N and the combined climbing torque stays capped at 150 Nm. Moving supports
receive opposite forces at actual material-local contacts. No forces before
planting, suction, body pose writes or extra launch impulses are added.

Existing planted feet can remain when hands release, while still geometrically
valid. Hands-free feet do not acquire new contacts. The central sole landing
hands control back to walking; normal arm launches temporarily disengage feet.
The visual biped follows these contacts within its measured leg lengths.

All **1,294 checks pass**, including the M1 suites and all three original routes
with feet ON at 60/120 Hz. In the controlled full-biped fixture, average arm
effort drops from approximately 141 to 43 N at 120 Hz (138 to 43 N at 60 Hz).
Legs do measured positive upward work. Godot MCP Pro captures show the same
support/load-reduction outcome through real held mouse input. Full results,
screenshots, model and limits: `docs/validation/M2.md`.

Both experiments default OFF for comparison. Search is local and heuristic,
and feet are virtual contact actuators rather than a leg ragdoll. Human feel
evaluation remains pending. M3 posture, M4 directional quality, M5 new reactive
challenge and M6 mantle remain future work; existing camera twist is unchanged.

## M1: baseline protection and predictive capture

The previous milestone implements M0 and M1 of `docs/specs/grip_up_v0.2.md`.
The immutable baseline is tagged `v0.1-baseline`; its configuration, 962 passing
checks and representative sessions are archived in `docs/baselines/v0.1/`.

In **Controls**, enable **Predictive catches** to compare the experimental M1.
It starts OFF. Aim at a surface marked NOW or SOON and hold the corresponding
mouse button. SOON prepares that exact material point for up to 150 ms until it
enters real arm reach. The hand then still travels at its existing finite speed;
attachment requires current, unobstructed surface contact. Releasing the button
cancels immediately, including over UI. There is no automatic retry or retargeting.
The 200 ms forecast is an estimate and may not cover the entire reaching gesture.
NOW means the point is currently selectable, not an immediate or guaranteed catch.
Toggle-to-grip retains its previous behavior without the held-intent buffer.

Tab adds optional reach, anchor, normal and force lines. **Record capture
diagnostics** writes sampled `user://capture_frames.jsonl`. Recording is OFF by
default. Uncertain contact times and errors are recorded as -1 rather than invented.

All 1,102 checks pass across 60/120 Hz, including the original 962. In the
controlled favorable matrix, currently reachable catches retain 24/24 with M1
OFF and ON at each frequency. Future-only held catches improve from 0/12 OFF
to 12/12 ON, with one-second retention. Adverse momentum/support cases remain
physical failures and are reported separately. See `docs/validation/M1.md` for
rendered evidence, timing uncertainty and the limits of this comparison.

The M1-only snapshot remains tagged `v0.2-M1`.

## Controls

| Input | Action |
|---|---|
| Hold left / right mouse button | Hold cyan / amber hand; releasing the button lets go |
| WASD, grounded and hands free | Walk relative to camera, with braking and turn-to-move |
| Hold grip + mouse up / down | Shorten / extend attached arm targets |
| W / S, gripping | Request forward / backward supported swing |
| A / D, gripping | Request left / right supported swing |
| Space | Disabled by default in profile 1; optional launch comparison in Controls |
| Middle mouse drag / wheel | Orbit / dolly |
| R | Immediate retry from checkpoint or start |
| Tab | Physics diagnostics |
| F, reactive test | Restart same geometry fixed or hinged |

Controls opens remapping with conflict checks and saved bindings. Hold-to-grip is
mandatory in profile 1; select baseline profile 0 before comparing toggle mode. Mouse-up cancels a
pending reach too, including over UI. Losing window focus releases held grips.
Neither hand gives any midair steering when unattached.

## Biped experiment

The playable character is the CC0 Quaternius mannequin, with 65 bones and a
render-only arm/leg IK rig. Its pelvis follows one simulated RigidBody3D. Three
simple head/torso/leg proxies and a flat sole belong to that same body; limbs are not rigid bodies.
The grip force solver remains unchanged. Following the user's explicit change
to the original scope, free hands plus ground contact enables a separate
third-person walking motor. WASD applies bounded ground effort; the body turns
toward movement and the visual legs step. Any reaching/attached/slipping hand
disables that motor, and the same inputs control climbing. There is no midair
steering. The optional M2 adds independent compressive foot contacts; no full
ragdoll or tensile foot grips have been added.
The biped, hold-to-grip and ground walking are the user's explicit changes to
the v0.1 robot/toggle/no-leg-locomotion defaults.

Physical shoulders match the imported skeleton. The shoulder-to-wrist chain is
0.547 m plus an approximately 0.11 m palm; selection reaches the complete
0.65708 m chain. Spring target length stays capped at 0.62 m, with a 0.04 m
elastic limit. Reach and the surface-approach waypoint use the anatomical
radius, so a fully extended point is selectable without extending the bones. Collider
friction 0.12 avoids the measured high-friction body/wall lock; support grip load
limits and the shared 360 N / 150 Nm effort budgets are unchanged.
Tune these values in `features/grip_up/resources/biped_tuning.gd`.
The flat sole supplies a physical support area while idle, so the character
does not balance on a rounded capsule tip and topple before the first grip.

Climbing legs use passive hip pendulums driven by gravity and hip acceleration.
They retain their own inertia while the torso swings and share a soft
directional/velocity coupling, so they follow each other
without becoming one rigid pose. A foot on a real support remains independent.
Unsupported legs extend
to near their measured natural length; ground and obstacle contacts shorten the
foot targets and let the knees bend. Leaving an available support unfolds the
leg continuously. Per-foot floor and toe queries avoid posing feet through
nearby surfaces. Target integration runs at the fixed physics rate and its
rendering is interpolated.

With M2 OFF this remains a visual IK layer over the existing single-body contact
simulation. M2 consumes valid physical foot states when enabled. Body mass and
arm tuning remain unchanged. Suspended legs keep their passive motion.

Ground movement now uses the model's authored Idle/Walk animations, blended into
physical IK when reaching starts. Ground acceleration/braking are 14/18 m/s²;
a bounded angular-velocity servo turns toward camera-relative movement.
Climbing commands ease over 120 ms and effort allocation over 140 ms. A separate
16 Nm/rad, 3 Nms trunk-twist assist keeps the torso facing the camera reference
without locking pendular tilt. This shares the existing 20 Nm assist / 150 Nm
total torque limit and supplies the opposite reaction to movable supports.
Arm spring stiffness and damping remain 6000/220; catch blending is 100 ms.

The user has also overridden the original designated-surface restriction:
all ordinary level solids, including the wall and frames, accept grips anywhere
on their real visible surface. The coloured holds are optional route references.
The out-of-bounds safety floor remains excluded. Regripping on the same surface
first lifts the hand outward before moving to the next point, with finite speed
and collision sweeps. Range, obstruction and shared strength limits still apply.

For a vertical launch, keep a grip and hold Space for about half a second.
The arms extend to prepare the stroke. Release Space: a faster contraction
builds upward momentum for up to 0.30 seconds, then automatically releases the
original grips. Click/hold again on a higher surface to catch it. A new grip
acquired during the pull is preserved. Charge status appears in the HUD;
rebinding, focus loss, controls-panel cancellation and reset are supported.
The same finite force budget and opposite reactions remain active. Height
depends on the available arm stroke, support motion and nearby geometry.

## Original three experiments

These preserved route instructions use **baseline profile 0** in Controls.
Profile 1 replaces their W/S arm commands with mouse drag.

1. **Static climb:** choose any wall point within reach and alternate hands to climb. The small rounded holds provide an optional route: aim at hold 01 and attach cyan. Hold W. Catch 02 with amber,
   wait until ATTACHED and let both hands stabilize. To reach 03, release only
   LMB and press/hold it again over 03 while keeping RMB held. Alternate which
   hand moves, keeping the other button held, up to 06. Aim at the
   near edge if a grip is out of reach. Reaching checkpoint height saves a checkpoint once
   the body settles; its safe landing is created on retry, clear of the first ascent.
2. **Swing & catch:** left hand on 01; hold W + D. As the body swings across,
   aim at the underside / near edge of 02 with the right hand. Wait for ATTACHED,
   release LMB and D, continue W. The tested catch window opens about 0.56 seconds
   after contraction starts; it is not a scripted animation.
3. **Reactive structure:** hold RMB near the middle of the amber beam,
   then W. Player load rotates the balanced beam. Hold LMB farther along the
   beam toward its tip, stabilize with both hands, then release RMB. Advance
   hand over hand using intermediate placements instead of crossing the torso.
   Keep W,
   catch the underside of EXIT with RMB, wait for ATTACHED and release LMB. F compares
   the exact same beam fixed and hinged. Ballast near the pivot represents its
   configured center of mass; the joint has no motor.

Finishing the wall means reaching finish height on any chosen wall route;
the other experiments finish on their exit hold. Stabilize for 0.5 seconds.
Optional 1-5 ratings appear after completion. Trial JSONL records and remapped
controls are saved in Godot's `user://` folder (`%APPDATA%/Godot/app_userdata/GRIP UP`).
Logs include times, requests, misses, slips, transfers, falls, input count,
maximum speed/spin and a coarse large-step detector. They do not certify realism.

## Reused physics

The arm adapter adapts Janga's material-local anchors, angular contact-point
velocity, rotational effective mass, implicit spring denominator, attachment
blending and magnitude-sum force / resultant-torque allocation. The original
6DOF pose servo is not used as a torso position controller. Two arms share
360 N and 150 Nm; adding a hand does not double those budgets.

Every attached arm applies tension at a shoulder, and a dynamic support receives
the opposite force at its material anchor. Hands reach over time with swept paths
and a finite surface-approach waypoint. A simple deterministic overload threshold
provides strain, slip, recovery and release reasons. There is no directional finger
friction model, solid hand volume, full ragdoll or mobile support in this version.

Detailed provenance, joint comparison and limitations:
`features/grip_up/tests/physics_decisions.md`.

## Repeatable checks

The complete v0.3 run has 1,556 passing checks: `python tools/run_regressions.py v03`.
The new input and physics suites are `test_drag_input.gd` and
`test_drag_swing_physics.gd`, each supporting 60/120 Hz.

From the project directory, replace `godot` with your executable:

```powershell
godot --headless --path . --script res://features/grip_up/tests/test_physics.gd --fixed-fps 120 --quit-after 20000
godot --headless --path . --script res://features/grip_up/tests/test_playthrough.gd --fixed-fps 120 --quit-after 20000
godot --headless --path . --script res://features/grip_up/tests/test_swing_playthrough.gd --fixed-fps 120 --quit-after 20000
godot --headless --path . --script res://features/grip_up/tests/test_integration.gd --fixed-fps 120 --quit-after 20000
godot --headless --path . --script res://features/grip_up/tests/test_biped_profile.gd --fixed-fps 120 --quit-after 20000
godot --headless --path . --script res://features/grip_up/tests/test_biped_visual.gd --fixed-fps 120 --quit-after 20000
```

These six accept `-- --60hz`. Check their RESULTS footer, zero failures
and absence of SCRIPT ERROR; this Steam engine sometimes reports exit code zero
even after a failed scripted test. Integration includes actual viewport mouse
events, camera independence, safe reset/checkpoint, remapping conflicts,
fixed-versus-hinged physical response and enlarged-window HUD layout.

## Evaluation decision

Technical feasibility is demonstrated by complete physical routes. Human comfort,
aiming under pressure and willingness to retry remain to be evaluated. This is a
playable test build, not a claim that climbing feel or level pacing is final.
Keep iteration on these three tests before producing more content.
