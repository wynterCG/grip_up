# GRIP UP finite arm core

2026-10-19. Engine actually exercised: Godot 4.7.2.stable.steam.ed1daf0bf, integrated Jolt. Runtime module is independent of janga_proto and uses explicit preloads, without global class-name registration.

## Concrete reuse

Read-only source: `C:/Users/Wynter/janga_proto/runtime/physics_grabber.gd`, SHA256 `8AB923AC1D903E8DCC8ED2A2E4F9F8C5CEC326A3217CB4A9D8F00036557E7DAD`. Source tuning was also inspected at `janga_proto/data/grabber_tuning.gd`. Neither legacy file was changed.

| Existing implementation | New implementation and adaptation |
| --- | --- |
| Lines 20/28/64, material-local `body.to_local(world_point)` | `grip_anchor.gd` stores support-local point and normal and transforms them each physics step. A WeakRef handles support deletion. |
| Line 155, `v + omega.cross(lever)` | Same equation in `arm_actuator.gd::point_velocity` and `grip_anchor.gd::point_velocity`; damping uses the relative velocity of BOTH material points. |
| Lines 160–162, rotational inverse effective mass and implicit spring denominator | Same cross-product expression and denominator in `arm_actuator.gd`; stiffness/damping are multiplied by smooth hand allocation, replacing original division by grip count. Dynamic-support inverse mass is added. |
| Line 143, smoothstep attachment blend | Same `smoothstep(0, duration, elapsed)` in climbing controller, over 0.18 seconds. |
| Lines 178–200, sum of force magnitudes, resultant torque including assist, one shared scale | Same allocation equation in climbing controller; two hands share 360 N and 150 Nm. Opposing forces cannot hide effort in vector cancellation. Shoulder moments use the actual COM. |

The existing 6DOF pose-target servo is deliberately not applied to the torso. Each adapter now computes an axial, unilateral tension spring against an adjustable rest length. W shortens it; S extends it without compression. No transform, linear velocity, angular velocity, freeze, mass or gravity assignment exists in the controller. A/D biases dual allocation/contraction; with one loaded hand it supplies bounded angular effort. Dynamic supports receive the equal opposite point force and their allocated opposite assist torque.

## Why forces instead of a built-in pin for the arms

A pin is an effective rigid attachment and still suits the reactive level's environmental hinge. The player needs finite pulling strength, elastic reach, extension, overload and a force budget shared by two arms. Godot's Jolt integration currently does not support PinJoint3D bias, damping or impulse_clamp. Consequently the native pin API cannot directly enforce this arm contract. See [Jolt joint differences](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html#joint-properties) and [PinJoint3D](https://docs.godotengine.org/en/stable/classes/class_pinjoint3d.html).

The separate real PinJoint3D baseline in `test_physics.gd` suspends a 50 kg body (490 N weight) from the world for 2 seconds. Anchor drift is 0.00003 m at 120 Hz and 0.00010 m at 60 Hz, despite the player budget being only 360 N. In contrast the actual force actuator reaches exactly 360 N and cannot freely lift that overweight torso. This is a boundedness comparison, not a claim that the custom solver is globally more stable or faster than Jolt joints.

Forces are applied once per physics update, with world-oriented offsets from body origin, as required by [RigidBody3D.apply_force](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html#class-rigidbody3d-method-apply-force). The lever used for torque/effective mass is instead measured from world COM, including custom COM offsets.

## Verification

Run from PowerShell:

```powershell
& 'C:/Users/Wynter/WrapRush/tools/godot.exe' --headless --path 'C:/Users/Wynter/grip_up' --fixed-fps 120 --script res://features/grip_up/tests/test_physics.gd
& 'C:/Users/Wynter/WrapRush/tools/godot.exe' --headless --path 'C:/Users/Wynter/grip_up' --fixed-fps 120 --script res://features/grip_up/tests/test_physics.gd -- --60hz
```

The runner exits with a failure code and prints `GRIP UP PHYSICS RESULTS`. This Windows engine distribution may report zero through some process wrappers despite `quit(1)`; automation should also inspect the footer and script errors.

45 checks cover spring signs and the reused equation; exact uncontrolled freefall under unattached WASD; finite reach; no attach/release/reset pose or velocity changes; range, real surface and obstruction checks; a steep ray matching the actual first level hold; finite front-normal approach around a hold underside; obstruction or moving candidate during reaching; occupied-hand rejection; two-hand climb, single-hand remainder and extension; shared 360 N single/dual budgets; a 2 Nm torque stress limit including assist; material-local dynamic anchors and angular point velocity; conserved pair linear momentum; deleted supports; deterministic weak-grip slip/release; physical swing; and the pin baseline.

| Physical measurement | 120 Hz | 60 Hz |
| --- | --- | --- |
| 12 kg torso height after 2 s contraction, start 0.55 m | 1.1963 m | 1.1880 m |
| Single / dual peak force | 360 / 360 N | 360 / 360 N |
| Torso / dynamic support vertical displacement in 0.6 s, gravity disabled on pair | +0.1518 / −0.1822 m | +0.1550 / −0.1860 m |
| Pair linear momentum magnitude | <0.000001 kg m/s | <0.000001 kg m/s |
| Pumped swing lateral span / peak lateral speed | 1.0866 m / 1.3626 m/s | 1.0775 m / 1.3475 m/s |

The fixtures set initial transforms and gravity/damping parameters to isolate behavior; no fixture teleports an active torso. The climb and swing arise from actual forces. These are headless actuator tests, not mouse targeting, human ergonomics, complete level solutions or a rendering performance benchmark. A sample 120 Hz suite took ~0.36 s wall time for 2329 physics frames on this machine; concurrent processes and headless acceleration make that only a rough throughput figure.

Integrated replay subsequently passes all six static holds and the reactive beam transfer with unchanged arm gains. A finite normal approach waypoint resolves the hand-path corner case; removal of an obstructing rest ledge and selecting actual accessible surfaces resolves the original level blockers. The static/reactive runner passes 15 checks at both 120 and 60 Hz. The swing/catch runner passes 10 checks at both rates, with one successful second-hand reach request. These use the actual controller and Input actions, without editing active torso transforms or velocities. A separate integration runner passes 16 checks, including real viewport LMB/RMB acquisition, camera independence, checkpoints, window enlargement and physically different fixed/hinged responses. Full source provenance remains unchanged.

The aggressive four-second swing ends FREE at 120 Hz after transient overload, but stays ATTACHED at 60 Hz. Threshold outcomes are not bit-identical across timesteps; the useful swing and force bounds pass in both. Climbing at 2 seconds is still moving (~1.24 m/s), not a settled hover. Grip integrity is a deterministic load threshold model, not simulated finger friction. Hand collision uses swept line segments, not solid hand shapes. Endpoint LOS extends the actual shoulder-to-point line through the selected surface by 0.025 m; offsetting along its normal was found to falsely reject steep rays and was corrected with a regression test.


## Wall clearance revision

After a human report of the torso hitting shelf-like holds, the six static wall holds were replaced with shallow rounded convex profiles: about 0.36 x 0.24 x 0.20 m, embedded at z=-0.40 beside the wall face z=-0.45. Actual outward protrusion is about 0.15 m. Mesh vertices are baked into the convex collider, with no hidden box shelf. Torso collisions remain enabled, and no strength, damping, torque, reach or body transform controller was changed. Full ascent passes at 60/120 Hz, including a one-second overlap of both hands at each transfer. The aligned-obstacle fixture retains real contact and measures less obstruction than the old shelf; it is not a claim that a body can climb straight through any hold.

A separately confirmed recovery bug was also fixed: FREE hand rest positions previously entered the wall when the torso lay on its side, making subsequent reaches fail at their own embedded start. FREE endpoints now start at the shoulder, clip their resting target to solids and sweep toward it at bounded hand speed. The observed fallen snapshot can reacquire with either hand and physically rise again. Core 45 checks and the 42-check probe pass at both rates.

## Biped and hold-to-grip revision (2026-10-19)

The user explicitly chose a biped instead of the robot and hold-to-grip instead
of toggle. The CC0 Quaternius model is visual only. Native TwoBoneIK3D solves
arms and passive legs, followed by a visual palm alignment modifier. Authored
root-motion animations are stopped. No bone changes the physical torso.

The actual upperarm/forearm chain measures 0.27444 + 0.27264 m; a 0.11 m palm
offset gives approximately 0.657 m anatomical reach. Physical shoulders match
the skeleton within 0.1 mm. The biped profile uses max arm 0.62 m, elastic
allowance 0.04 m, min 0.18 m, K=6000, D=220 and a 0.06 s attach blend. The
one-body proxy uses head sphere, torso capsule and a central leg capsule with
custom COM at the pelvis. A 0.36 x 0.08 x 0.28 m flat sole completes its support
polygon. The rounded leg capsule alone reproduced idle toppling before any
input; the sole fixes that with real ground contact, not balance forces. All
three spawn platforms are checked for 30 seconds at 60/120 Hz. It is not a
ragdoll and has no feet actuators.

Controlled whole-capsule and compound comparisons reproduced wall friction
locking the body under dual contraction with friction 1.0. Reducing only body
friction to 0.12 permits ascent while retaining real collisions and unchanged
support traction/load limits. Fresh single-hand hangs at near full reach peak
at 0.633 m (120 Hz) / 0.640 m (60 Hz), below 0.66 m. Dynamic support reaction
continues to conserve pair momentum. The force law and shared budgets remain
unchanged; only FREE endpoint rest offsets became configurable, retaining the
original robot defaults. The biped rests its hands lower and closer to its sides,
with a relaxed elbow pole, instead of the robot's flexed resting stance.

Static holds now measure 0.18 x 0.12 x 0.099 m, centres x=+/-0.34 m and vertical
steps 0.22 m. Both hands stabilize after each acquisition; release only the hand
that will move next. Single-hand yaw and actual obstruction remain physical.
The reactive route requires a deliberate second-hand regrip farther along the
beam before transferring to EXIT. All three complete routes pass at 60/120 Hz
without editing torso transforms, velocities or controller forces.

Current dedicated checks: 58 biped profile, 17 static/reactive route, 10 swing
route, 24 integration and 14 visual-rig checks, at each timestep. The 12-check
asset import suite also passes. Historical robot clearance fixtures remain
isolated at their original scale. Hold mouse-up is processed before GUI input,
cancels REACHING and releases only its hand; focus loss releases held hands.
Toggle remains available for human comparison. Automated replays demonstrate
technical feasibility, not human comfort or fun.

## Explicit ground locomotion scope change

The user subsequently requested normal third-person character control whenever
not climbing. This explicitly overrides v0.1's exclusion of leg locomotion.
GroundLocomotion is separate from the grip solver, using the same dynamic torso.
It applies finite camera-relative movement, braking and upright/turn effort only
when the sole is on a walkable surface and neither hand is reaching, attached or
slipping. There is no midair drive. Ground drive and grip drive are exclusive.
Moving ground receives equal opposite force and the compensating moment;
braking uses support contact-point velocity. The sole check rejects a gap over
0.018 m instead of enabling walking merely because a floor is within ray range.
The legs use render-only alternating foot IK while walking. No separate limb
rigid bodies, foot grips, jumping or animation-driven torso motion were added.

## Camera-relative climbing direction

A human report identified that A/D's single-grip torque used torso-local Z;
yaw and roll therefore rotated the controls, and its sign moved the COM in the
opposite direction to the requested side. Input now supplies a horizontal camera
right vector to the controller. Single-grip effort uses its cross product with
the actual shoulder-to-COM lever, with natural fade when that lever cannot
produce lateral motion. This accounts for yaw, roll and inverted poses without
freezing orientation or applying an extra translation force.

With two grips, the anchor span projected onto camera right selects effort and
contraction bias, rather than left/right hand identity. Crossing arms no longer
reverses this input; vertically aligned or coincident anchors have neutral
lateral bias. Allocation blending, strength/torque caps and opposite support
reactions remain in the same path. The rightward swing route now uses W+D.

## Passive legs and suspended posture

The user clarified that the rigid-looking legs were the priority and that a
fully suspended climber should have extended, hanging legs. The arm solver and
body drag were kept unchanged. A diagnostic pendulum runner confirms that the
existing body already swings; its third/first passive peak ratio is about 63%
with one grip and 76% with two. Reducing radial damping increased transfer jerk,
so that was not used as a substitute for leg motion.

Each visual leg now has its own world-space direction and angular velocity.
The driving acceleration is gravity minus filtered hip acceleration, including
torso angular motion. This produces inertial lag and rebound instead of welding
the feet to torso-local offsets. The actual imported thigh/calf/ankle chain is
0.82979 m. In suspension, the target extends to 99.9% of that length, leaving
the knees nearly straight. Contact targets can shorten it; release extends it
at a bounded 0.85 m/s rather than keeping a permanent tuck.

Hip angle limits, filtered/clamped acceleration and finite angular speed keep
the passive solver bounded. Floor and toe queries choose reachable contact
targets per foot. Native leg IK preserves bone lengths; target and pole positions
interpolate between fixed physics steps. This secondary-motion layer has no
torso force or pose output. Ground walking and the original compound-body
collision proxies remain the source of physical contact response.

## Control and free-surface iteration

The user's next feedback identified arm jerk, uncontrolled trunk rotation and
weak third-person control. Biped intent now ramps over 120 ms, allocation over
140 ms and initial grip force blending over 100 ms. The original 6000/220 arm
spring and body drag remain unchanged. A bounded 16 Nm/rad + 3 Nms assistance
acts only about the longitudinal trunk axis; it does not lock pendular tilt.
It shares the existing 20 Nm assist / 150 Nm total cap and supplies the opposite
reaction to held dynamic bodies, including when the axial arm is lightly loaded.
The comparative pendulum runner measured approximately 77% lower A/D command
jerk and 55% lower transfer jerk, with passive swing decay effectively unchanged.
Fresh catches at the exact 0.62 m maximum remain attached at both 60/120 Hz;
their force jump did not universally decrease, so that is not claimed.

Ground control uses 14 m/s² acceleration, 18 m/s² braking and a bounded yaw-rate
servo. Authored Idle/Walk clips blend into physical limb IK on reaching. Animation
and passive leg targets still cannot edit the body pose or apply extra force.
In suspension, weak symmetric direction/velocity coupling lets the legs follow
each other without removing independent contact flexion or the common swing.

The user explicitly overrode the designated-grip-surface restriction. Ordinary
level solids now accept arbitrary real surface points. A same-surface regrip
first clears its old contact along the old normal, then traverses to the new
approach point. This prevents the old surface from blocking its own departure.
The complete free-wall route uses camera cursor rays, does not touch any
coloured hold, and can trigger checkpoint/finish by height. The reactive route
uses intermediate uncrossed transfers rather than relying on uncontrolled yaw.

## Charged launch and complete reach

The user requested an active upward launch and placement at full arm extension.
Launch charge extends existing arm targets for 0.45 s. Releasing the remappable
Space action contracts at up to 2 m/s for 0.30 s, then releases only the original
anchors. It never assigns body velocity/pose or adds an independent impulse;
the same implicit axial actuator, shared 360 N / 150 Nm allocation and opposite
dynamic-support reactions produce the launch. A new catch remains attached.
No unattached launch effort is possible; focus loss/UI/reset cancel charging.
Practical tests include a free-wall route, launch, and a higher wall point that
was initially beyond reach. Floor contact can limit the loading stroke.

Selection range is now separate from the spring target maximum: 0.65708 m
measured wrist chain plus palm versus the existing 0.62 m target / 0.04 m elastic
limit. The surface-approach normal offset is clipped to the same reach sphere.
A glancing-surface test at 100% reach verifies attachment and native rendered
wrist/target agreement, with authored bone lengths preserved. Gravity/load
regressions remain separate from this stationary anatomical fixture.
