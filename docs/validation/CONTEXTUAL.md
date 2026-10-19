# Contextual Arm Control

**Control-design review remains open:** the user reports that sharing mouse Y
between aim and physical effort still prevents independently pulling while
aiming higher. The physical checks below establish actuator behavior, not that
this shared binding solves that interaction problem. Input separation is pending.

The current experiment implements the user's contextual-control proposal and
latest direction choice: **mouse down contracts; mouse up requests physical
extension**. It replaces the prior direct relative-pixels-to-arm-length mapping
as the default, while preserving profiles 0 and 1 for comparison.

Open `E:\Godot Games\grip_up\project.godot` or run
`E:\Godot Games\grip_up\builds\GripUp-contextual.exe`.
The default is **profile 2**. The specification is
`../specs/contextual_arm_control.md`.

## Playable behavior

| State | Mouse behavior |
|---|---|
| Both hands free | Relative movement aims both anatomical virtual hand targets |
| One hand attached | Aims the free hand and requests supported effort through the attached hand |
| Both hands attached | Requests posture and contraction/extension through both arms |

Hold LMB/RMB to reach and retain the corresponding grip. Mouse-up immediately
releases only that hand. L/R reticles indicate the free hands' real raycast
aims; unavailable surfaces are gray. The hand endpoint approaches at its
existing finite speed, respects anatomical reach and sweeps against obstacles.
FREE hands now use arm-only aiming IK on the ground while the authored leg
gait remains in control of walking.

Mouse down requests pulling; mouse up requests supported extension/lowering.
With one attached hand, aim and effort share that relative movement, as in the
user's proposal. Upward aiming can therefore physically lower the body.
The cursor no longer has a fixed screen position or a pixel-length integral
that determines the arm target; it is captured for unrestricted relative input.
Actual achieved posture, geometry, gravity, collisions and force limits govern
the result. Horizontal movement requests bounded supported lateral effort.

W/S still requests camera-depth swing and A/D lateral swing. Per-key gesture
frames remain stable during camera orbit. Grounded walking remains unchanged.
MMB owns relative motion for orbit; the wheel dollies. **Escape opens/closes
Controls**, freeing/recapturing the cursor. Focus loss clears input and releases
grips. The first resume click is consumed to avoid an accidental catch.
No Shift/Alt aiming clutch or toggle grip was added.

## Physical and input implementation

Each free hand has a camera-plane target relative to its anatomical shoulder.
The plane lies 35% of anatomical reach toward camera-horizontal forward; the
remaining planar radius is computed from the same reach sphere. Mouse movement
uses 0.0018 m/pixel by default, adjustable in Controls. Targets clamp immediately
without accumulating an off-boundary tail. Surface selection uses real camera
rays; the controller's reach and contact checks remain authoritative.

Supported effort is computed from raw relative motion per physics step,
normalized by 700 pixels/second. It is transient and filtered with an 80 ms
response. Arm actuation uses a small effort offset (0.10 m at full effort)
relative to actual physical arm geometry, with target-rate caps of 0.6 m/s for
contraction and 0.35 m/s for extension. It
retains achieved contraction or extension using the existing elastic tolerance;
unachieved requests relax when effort ends. A blocked body cannot ratchet an
arbitrary stored target. A zero mouse gesture maintains achieved posture while
the body continues to obey physics.

The hand force budget remains 360 N shared, with 20 Nm assistance and 150 Nm
combined climbing torque. Mouse posture and WASD effort share these limits.
Dynamic supports receive opposite force/torque reactions. FREE/REACHING hands
provide no support force, and an unsupported body receives no air motor. No
runtime torso transform or velocity writes, mass changes or hidden impulses
were introduced.

One newly exposed transfer case involved a FREE palm beside a rounded hold:
the straight initial approach could hit its flank. Profile 2 now checks that
segment and, when necessary, first withdraws toward an unobstructed anatomical
waypoint. Every departure/approach segment remains swept and limited to 4 m/s;
colliders are not ignored to make the transfer succeed.

## Validation and reproducibility

Current automated results: 1,746 passing checks, including 65 physical and
30 integrated contextual checks at each frequency. Native capture completes
13/13 checks at both rates, with about 9 cm actual rise and controlled lowering
in the authored scene. These measurements do not override the user's reported
control-design failure.

`python tools/run_regressions.py contextual` runs the complete preserved suites
plus contextual input and physics at 60/120 Hz. Individual check counts, console
logs and totals are archived in `contextual/results.json` and adjacent files.
The new input suite uses actual held mouse events with a constant absolute
cursor position, proving that aiming uses relative motion. It covers anatomical
limits, saturation recovery, physical pulling/lowering, retained achieved
posture, second-hand contact, independent release, MMB, UI, focus and reset.

The physics suite additionally covers blocked bodies, bidirectional actuation,
no unachieved target accumulation, reaction conservation, FREE endpoint sweeps,
REACHING target ownership, the exact rounded-hold transfer geometry and the
unchanged hand/assistance/combined budgets. Prior routes explicitly select
their preserved baseline profile; their route timings do not establish the
new profile's difficulty or completion reliability.

Godot MCP Pro invokes `capture_contextual.gd` in the native game window at
both frequencies. It checks actual relative capture, held raycast acquisition,
physical rise and lowering, second-hand contact, shared force budget, camera
ownership and UI cursor release/recapture. Native reports, screenshots and
20 Hz JSONL samples are in `contextual/`. Samples include relative aim offsets,
requested/filtered effort, actual arm actuation rates, states, lengths, forces
and camera basis. The Windows executable is checked with a three-frame rendered
launch; `contextual/verification.json` records its hash and suite totals.

## Remaining evaluation

Human coordination, comfort, fatigue, precision and enjoyment remain to be
evaluated. The shared aim/effort gesture is a gameplay experiment. Virtual aim
currently uses a camera-facing plane rather than independent 3D hand-depth
input; both FREE hands share mouse movement until one attaches. Existing
predictive catches and physical feet remain optional and default OFF. The
v0.2 posture, directional-quality, new reactive-challenge and mantle milestones
remain separate work.
