# GRIP UP / physics climbing lab

Open `project.godot` in Godot 4.7.2, or launch the preserved normal Windows build
`builds/GripUp-v1.2-pre-v1.3.exe`.
PC mouse and keyboard. Resizable 1920x1080 reference canvas; initial window 1440x810.
Integrated Jolt, 120 Hz. Core and complete routes also tested at 60 Hz.

This is a separate prototype. The Janga object grabber and its project are unchanged.

## v1.3 / Offline physics auto-tuning lab

An isolated research tool compares four bounded A0 planner parameters through
the existing controller. Python/Optuna runs offline and is excluded from the
game. Normal startup remains profile 2; explicit research comparisons use
profile 4 with A0/B1. No candidate is automatically adopted, and M7/RL remain
separate. The pre-lab source is recoverable at `baseline/pre-v1.3-auto-tuning`.

See the [experiment record](docs/validation/auto_tuning/README.md) and
[reproduction commands](tools/auto_tuning/README.md). Automated results measure
declared physics tasks; they do not establish better feel or human preference.

Consolidated Portuguese implementation report before the v0.7 M7 reactive
challenge: [system state, physics, controls, top-out, evidence and remaining work](docs/reports/SISTEMA_IMPLEMENTADO_PRE_M7_PT.md).

## v1.1 pre-M7 locomotion experiments

The original controls remain the default and are recoverable at
`baseline/pre-v1.1-locomotion`. Controls now offers independent A0/A1 allocation,
B1/B2 foot selection, optional one-hand swing effort feedback and a read-only
movement/transition observer. Select profile 4 to compare supported intent.
Enable physical feet separately to compare B1/B2; B0 is physical feet OFF.

A1 is **REVISE**, not an improvement: asymmetric movement and twist regress,
and a high-ledge approach fails at 60 Hz. B2 corrects effort direction in an
isolated fixture but has no demonstrated general benefit on Step. Keep A0/B1
as reference. Swing feedback changes no physics. New switches start OFF;
profile 2 remains startup. There are no new grip-strength or camera rules.

See the [v1.1 report and separate decisions](docs/validation/v11/report.md),
[milestone status](docs/validation/v11/status.md) and preserved
[baseline protocol](docs/validation/v11/LP0_PLAYTEST_PT.md). Automated evidence
does not substitute for human A/B or authorize default promotion/M7.

## PLAY / The first ascent

Controls / **PLAY / The first ascent** opens a continuous greybox: climb the
wall, traverse the bars with real arm support, climb the final face and use W at
its upper lip. Finish with actual dynamic walking on the deck. The guide regions
are broad; grips remain freely selected. R retries, MMB orbits, scroll zooms.

The old first route and v0.9/v1.0 comparison fixtures remain available. Only this
new course adapts the teaching bars for clearance. The physical solver, grip
limits and vault route are unchanged. A direct alternative line can reach the
top; the complete marked-route badge also requires the three observed regions.
See [level design](docs/levels/first_ascent.md) and
[course verification](docs/validation/v10/course_report.md).

## v1.0 vault presentation experiment ? explicit A/B

Choose **Controls / v1.0 / Climb Up 1.25 m**, **2.10 m**, or **Two ledges**.
The experiment has its own authored arm/torso sequence, hand-specific material
contacts, anatomical release limits and immediate visual Walk selection during
handoff. A support becoming invalid during RESTORE now holds a controlled reset.
The body route remains 1.15 s with the same swept motor and collision profiles.

The v0.9 buttons restore the baseline. `contextual_vault_v10_enabled` defaults
false; this is a presentation/safety experiment, without retiming, a second style
or default promotion. Human comparison remains pending. See the
[v1.0 report](docs/validation/v10/report.md) for receipts and known limits.

## v0.9 hybrid mantle — static technical gates pass

Choose **Controls / v0.9 / Mantle 1.25 m** or **Mantle 2.10 m**. Reach a real
grip near the upper edge and hold W: the character performs a short assisted
transition over the lip. Once committed you can release both mouse buttons and
W. Normal dynamic walking resumes on actual upper-platform contact. MMB orbits,
scroll zooms, R retries; Tab shows the collision body and diagnostics.

This deliberately uses an authored animation and a collision-checked kinematic
body route during the mantle. Ordinary climbing, swinging and walking retain
their dynamic controllers. It is an intentional design exception to pure physics.
The body keeps its world collisions and original standing profile on exit.
Moving supports, narrow tops and obstructed paths are refused safely.

**4,356 checks across139 runs pass at60/120Hz**, including both full static
top-outs, real support,30cm walking, varied approaches, two consecutive ledges,
interruptions and all earlier regression suites. Native Godot MCP Pro runs also
complete both platforms at both rates. **Human feel remains unvalidated**: the
crossing currently reads as an assisted lift, with visible tucked-foot clearance.
The hybrid feature stays opt-in; the approved route is unchanged.

See the [v0.9 implementation and gate report](docs/validation/v09/report.md),
[physics audit](docs/validation/v09/motor/M1_PHYSICS.md),
[animation review](docs/validation/v09/animation/report.md) and
[interruption tests](docs/validation/v09/resilience/report.md).

## v0.8 physical palm and leg-clearance experiments

**Full top-out is still not achieved.** Finite-area palm compression, an explicit
bounded wrist moment and swept lower-body collision proxies now work in isolated
fixtures. H0 release/regrip reaches the top and briefly carries load in the
combined hanging test, but rotation takes the supporting arm outside reach.
There is no successful transfer to actual upper-ground support or walking.

Open **Controls / v0.8 / Low ledge 1.25 m** or **High ledge 2.10 m** to compare.
Hold LMB/RMB to grip, release one and select a real upper surface for a palm;
W requests physical effort. R retries, MMB orbits, scroll zooms, Tab shows real
collision proxies. Separate buttons compare fixed legs, palms OFF and axial
palms. These experiments remain opt-in; **PLAY / The first route** is preserved.

The master, palm, wrist, adaptive-collision and handoff flags default OFF. H1
automatic palm roll is unimplemented. Independent geometry tests are available
as `tests/palm_compression_lab.tscn` and `tests/mantle_leg_clearance_lab.tscn`.
The first is a simplified physics fixture; the second visibly exercises safe
folding and blocked unfolding with gravity and controller forces disabled.

See the [v0.8 milestone ledger](docs/validation/v08/status.md) and
[implementation, evidence and missing capability](docs/validation/v08/report.md).
Automated safety passes are distinct from the deliberately failed full mantle
gate and from a human playtest. Test/editor windows use monitor 1 locally.

## v0.7.4 ledge capability experiment — M6 gate not met

**Controls / Ledge experiment / hands + feet** opens a solid platform with
two low foot lips. Hold the edge using LMB/RMB and request travel with W.
The hands-only button provides the same geometry without physical foot forces.
This is an isolated engineering experiment, not a finished mantle mechanic.

The system identifies a real bearing top on the gripped material, checks the
standing destination for obstruction, and requests a finite reacted lean inside
the existing 20 Nm attitude and 150 Nm common moment limits. All translations
still come from the existing contact forces. It does not certify a continuous
collision-free route; actual intermediate body collisions remain authoritative.

**The character cannot yet complete an ordinary top-out.** Traction-only arms
and the fixed calf/sole compound prevent the required support and leg clearance.
The next physical capability needs to be designed and tested explicitly; there
is no hidden lift, body animation, collider removal or larger strength budget.
Completion requires actual platform ground, hands free, then 30 cm of walking.
Gripping an edge never reports success.

The designer's "muito bom" feedback applies to the v0.7.3 course. That course
remains available via **PLAY / The first route**, with the mantle experiment OFF.
See the [M6 decision and limitations](docs/validation/m6/decision.md).

## v0.7.3 the first route

**Controls / PLAY / The first route** opens one short continuous course:
climb, cross right, then transfer along the hanging bars to the turquoise finish.
The coloured wall areas are broad goals. Every eligible face remains grippable;
the course never chooses a handhold or moves the character for you.

Hold LMB/RMB, use W to rise and W+D to cross, and move each hand along the first
bar before reaching the last one. R restarts immediately. Falling onto the safe
base resets progress; completion leaves control available. The final stage needs
actual suspension, with no ground or meaningful foot load, on the finish material.

This adds an authored M5 comparison route. The v0.7.2 maximum-reach controller,
physical budgets and earlier labs are preserved. There is no new mantle or launch.
See the [route report](docs/validation/v073/comparison_summary.md).
**3636 automated checks +34 scripted Godot MCP Pro checks pass at60/120Hz.**

## v0.7.2 reach toward a surface

Choose **Controls / The Step / max reach + feet**. Hold LMB/RMB toward a wall.
When a click overshoots arm reach, profile4 can resolve an actual reachable
contact on the same surface and move the hand there at its existing finite speed.
The arm uses its complete anatomical reach; contact must happen before force.
If no eligible surface is reachable, the hand remains pending and unladen.

The chosen contact stays fixed on its material after selection. Camera or body
motion cannot slide an attached hand around the wall. Profile3 retains the older
exact-point early-target comparison. Grounded pending hands now visibly extend
while the legs keep their ordinary gait. Physics gains and limits are unchanged.

See the [v0.7.2 report](docs/validation/v072/comparison_summary.md).
**3582 automated checks +26 scripted native checks pass at60/120Hz.**

## v0.7.1 control refinement

In **Controls**, choose **The Step / early grips + feet**. Hold LMB/RMB on the
two low contacts, use W to climb, then alternate hands onto the higher points.
A short D while holding W can help move the right shoulder toward the second
destination. A held distant selection remains unladen until actual contact.

This revision improves achieved-posture tracking under elastic load, explicit
swing reversals and the initial A/D sign on horizontal supports. `EXTENDED`
marks a hand close to anatomical reach. Physics budgets and startup defaults
are preserved. The previous v0.7 executable remains available for comparison.

See the [v0.7.1 changes and validation](docs/validation/v071/comparison_summary.md).
**3504 automated checks +32 scripted native checks pass at60/120Hz.**
The positive human feedback concerns the v0.7 baseline; this refinement still
needs hands-on comparison. Mantle and the new reactive challenge remain later gates.

## v0.7 intent-driven body travel (opt-in candidate)

In **Controls**, choose **The Step / physical feet ON** for the first comparison.
Hold LMB/RMB on the low wall contacts. W/S requests up/down travel and A/D
requests traverse through real supports. Mouse movement only aims. Release one
hand, select the higher surface and keep its button held to attempt the next grip.
The Step / hands only, The Hang, The Traverse and The Corner are separate small
arenas. **Compare v0.6 / current arena** switches back on the same geometry.

Profile4 coordinates bounded arm targets, existing foot contacts and reacted
swing. It never applies a free body movement force, chooses a new handhold or
uses a pending hand as support. Startup remains profile2; the new controller and
physical feet remain OFF by default. P0 and existing physical budgets are preserved.

**3348 automated checks +30 scripted native checks pass at60/120Hz.** This is
technical feasibility evidence; the human M5 comparison remains open. Mantle
and the new reactive challenge are conditional follow-ons and have not started.
See [v0.7 implementation and comparison](docs/validation/v07/comparison_summary.md),
[physics audit](docs/validation/v07/movement_controller_physics.md),
[decision](docs/validation/v07/decision.md) and
[human protocol](docs/validation/v07/human_playtest_protocol.md).

## v0.6 early target selection (opt-in)

In Controls, open **v0.6 / Early targets: swing** or **moving beam**.
Hold LMB/RMB on a visible grabbable destination, even outside anatomical reach.
The selected material point persists while held; walk or swing into real contact.
Pending hands exert no force. Pointer movement never retargets a held selection;
mouse-up cancels/releases, including over UI. Force, torque and reach limits are unchanged.

The checkbox is OFF by default and applies to independent-aim profile3 and intent profile4.
Startup profile2 and earlier comparison modes remain available. The full matrix
passes **3116 automated checks**, plus **46 scripted native checks** at60/120Hz.
These are technical results; the v0.6 comparative human pilot remains pending.

See the [complete Portuguese system report](docs/reports/SISTEMA_IMPLEMENTADO_V06_PT.md),
[physics supplement](docs/reports/FISICA_IMPLEMENTADA_V06_PT.md),
[v0.6 evidence and decision](docs/validation/V06.md) and
[human comparison protocol](docs/playtests/V06_PILOT.md).

## v0.5 transfer, posture and reach study

**Controls / 05 / Ten transfers** opens independent aim with per-attempt
geometry/transit/retention diagnostics. Eleven painted guides support ten
alternating transfers; every wall surface remains grippable. **06 / Swing-required
route** separately tests out-of-static-reach catches. Hold LMB/RMB; aiming never
changes arm length. WASD walks or requests supported swing. R retries; Tab shows
actual reach, path, force, twist/pendulum and measured swing work.

Compare P0 (v0.4 suspension), P1 (material-relative axial twist) and P2 (tilt
research). The new refinement checkbox is OFF and P0 is selected by default.
P1 improves rotating-support twist in the measured fixture. P2 is more upright
but can shorten capture windows, so it is **rejected as a default improvement**.
The separate reach advisory and held catch buffer are also OFF by default.
The advisory never authorizes a grip. The optional buffer remembers one point
for120ms while held (configurable100?150ms), requiring actual finite contact.
All variants retain the same360N/20Nm/150Nm budgets and anatomical reach.

Attempts and optional ratings are stored under `user://transfer_sessions/` in
separate session files. The old v0.4 profile and startup comparison profile2
remain available. One native interactive P0 sequence reaches ten transfers
with zero recoveries; comparative comfort/agency ratings and the full human
pilot are still pending. Automated passes do not establish better game feel.
See the [v0.5 decision and evidence](docs/validation/V05.md),
[M2 comparison](docs/validation/V05_M2.md), [swing report](docs/validation/V05_M3.md),
and [reach/buffer report](docs/validation/V05_M4.md).

## v0.4 independent aim (opt-in experiment)

Open **Controls / Esc**, choose **3 / v0.4 Independent aim + physical posture**.
The preserved startup comparison is still profile 2. In profile 3, the visible
pointer only selects real surface contacts: it never changes supporting arm
lengths, posture plans or effort. Hold LMB/RMB for each hand; mouse-up releases
that hand, including over UI. MMB orbits; wheel dollies. WASD walks on the ground
and requests physically supported swing when attached.

Compare **A / hold length**, **B / bounded auto-pull**, and **C / load-aware pull**
on the same geometry and strength. B/C produce finite geometric settling goals
per support configuration. Target speed is 0.25 m/s, acceleration 1 m/s?; blockers,
slip, saturation and a 2 s deadline stop advancement. Repeated identical anchors
reuse absolute goals. Controls exposes posture, limited tilt and supported-swing
switches. Space launch, predictive catches and physical feet stay optional OFF.

Limits stay 12 kg, 360 N shared hands, 20 Nm assistance, 150 Nm total torque,
0.65708 m selectable reach, 0.18?0.62 m targets and 4 m/s reaching speed.
The limited gripper moment has a dynamic support reaction; it does not freeze
the torso. Actual length, requested length and planned length remain separate.
Tab opens diagnostics; optional JSONL logging includes plan reasons and failures.

All 2,012 automated checks pass at the supported frequencies. B/C complete ten
alternating transfers at 0.16 and 0.20 m vertical spacing on an unadorned lane of
the existing wall, with deliberate timed A/D input. The central protrusions can
still block a route. This is automated feasibility evidence, not human skill or
comfort validation. **Recommendation: REVISE / continue human comparison.**
See [v0.4 report](docs/validation/V04.md) and archived evidence in
`docs/validation/v04/`. Earlier profiles 0, 1 and 2 remain available.

## Contextual Arm Control (preserved startup comparison)

The game now opens in **Profile 2**. Relative mouse movement directs anatomical
virtual targets for FREE hands; L/R reticles mark each hand's aim. Real raycasts,
finite hand travel and obstacle checks determine whether a surface can be caught.
Hold LMB/RMB to acquire and retain each grip; mouse-up releases that hand.

With one grip the mouse aims the other hand and requests supported effort.
With two grips it requests supported posture and pull. **Drag down to pull**,
following the user's latest inversion request. **Move up to request supported extension/lowering** as well as aim higher.
The controller retains physically achieved contraction or extension, using
geometry and bounded effort rather than accumulated cursor displacement.
W/S retains depth swing; A/D retains lateral swing. Ground walking stays active
when hands are free, with arm-only aiming IK layered over the authored gait.

The cursor is captured for relative motion without screen edges. **Escape**
opens/closes Controls and frees/recaptures the cursor. MMB orbits, wheel dollies.
Focus loss releases grips; the first resume click is consumed. No aiming clutch
or extra modifier is required. Profiles 0 and 1 remain explicit comparisons.
Space launch, predictive catches and physical feet remain optional and OFF.

With one attached hand, aiming and physical effort share mouse movement, as
requested in the contextual design. Virtual hand aims use a camera-facing plane
with anatomical reach limits.
This shared aim/effort mapping was rejected as the independent-aim solution.
It remains available for comparison; human comfort still needs playtesting.
See `docs/validation/CONTEXTUAL.md` and `docs/specs/contextual_arm_control.md`.

## Earlier 0.3: hold, drag and supported swing

**Profile 1** preserves the earlier pixel-driven arm-drag experiment for comparison. Hold LMB/RMB to keep each hand attached. Move the
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
| Relative mouse, no grips | Aim the two free anatomical hand targets |
| Relative mouse, one grip | Aim the free hand and request supported effort |
| Relative mouse, two grips | Request supported posture and effort |
| Mouse down / up, gripping | Request physical contraction / extension |
| W / S, gripping | Request forward / backward supported swing |
| A / D, gripping | Request left / right supported swing |
| Space | Disabled by default in experimental profiles; optional launch comparison |
| Middle mouse drag / wheel | Orbit / dolly |
| R | Immediate retry from checkpoint or start |
| Tab | Physics diagnostics |
| F, reactive test | Restart same geometry fixed or hinged |

Controls opens remapping with conflict checks and saved bindings. Hold-to-grip is
mandatory in experimental profiles; select baseline profile 0 before comparing toggle mode. Mouse-up cancels a
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
Profiles 1 and 2 replace their W/S arm commands; the route timings below are baseline results.

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

Run the current complete suite with `python tools/run_regressions.py contextual`.
The earlier v0.3 archive contains 1,556 passing checks in `docs/validation/v03/`.
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
