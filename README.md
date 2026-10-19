# GRIP UP / physics climbing lab 0.1

Open `project.godot` in Godot 4.7.2, or launch `builds/GripUp-v0.1.exe`.
PC mouse and keyboard. Resizable 1920x1080 reference canvas; initial window 1440x810.
Integrated Jolt, 120 Hz. Core and complete routes also tested at 60 Hz.

This is a separate prototype. The Janga object grabber and its project are unchanged.

## Controls

| Input | Action |
|---|---|
| Hold left / right mouse button | Hold cyan / amber hand; releasing the button lets go |
| WASD, grounded and hands free | Walk relative to camera, with braking and turn-to-move |
| W, gripping | Contract attached arms using finite tension |
| S, gripping | Extend target lengths for controlled lowering; no pushing |
| A / D, gripping | Left / right relative to camera; bounded swing with one hand, bias toward that side's anchor with two |
| Hold Space, gripping; release Space | Load the arms, then pull rapidly and launch; click/hold again to catch a higher surface |
| Middle mouse drag / wheel | Orbit / dolly |
| R | Immediate retry from checkpoint or start |
| Tab | Physics diagnostics |
| F, reactive test | Restart same geometry fixed or hinged |

Controls opens remapping with conflict checks and saved bindings. Hold-to-grip is
the default; disable its checkbox to compare toggle mode. Mouse-up cancels a
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
steering. No full ragdoll or independent foot grips have been added.
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

This is a visual IK layer over the existing single-body contact simulation.
Body mass, arm forces and reactions on movable grips retain their existing
behavior. The original rigid robot-like leg pose is no longer used in the air.

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

## Three experiments

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
